#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Serverless ImageFlow - Load Generation Script
# =============================================================================
# Simulates upload traffic to test the pipeline under load.
#
# Usage:
#   ./scripts/generate-load.sh [dev|prod] [requests] [concurrency]
#
# Prerequisites:
#   - hey or artillery installed (tries hey first)
#   - AWS CLI configured
# =============================================================================

ENVIRONMENT="${1:-dev}"
REQUESTS="${2:-50}"
CONCURRENCY="${3:-5}"
AWS_REGION="${AWS_REGION:-us-east-1}"

API_URL="${API_URL:-}"
UPLOADS_BUCKET="imageflow-${ENVIRONMENT}-uploads"

# Determine load tool
LOAD_TOOL=""
if command -v hey &> /dev/null; then
  LOAD_TOOL="hey"
elif command -v artillery &> /dev/null; then
  LOAD_TOOL="artillery"
elif command -v ab &> /dev/null; then
  LOAD_TOOL="ab"
else
  echo "Error: No load testing tool found."
  echo "Install one of: hey, artillery, or apache2-utils (ab)"
  echo ""
  echo "Quick install:"
  echo "  brew install hey            # macOS"
  echo "  go install github.com/rakyll/hey@latest  # Go"
  echo "  sudo apt install apache2-utils  # Ubuntu/Debian"
  exit 1
fi

echo "=== Serverless ImageFlow Load Test ==="
echo "Environment: $ENVIRONMENT"
echo "Requests:    $REQUESTS"
echo "Concurrency: $CONCURRENCY"
echo "Tool:        $LOAD_TOOL"
echo ""

# ---------------------------------------------------------------------------
# Mode 1: API Gateway load test
# ---------------------------------------------------------------------------
test_api() {
  if [ -z "$API_URL" ]; then
    # Try to get API URL from CloudFormation outputs
    API_URL=$(aws cloudformation describe-stacks \
      --stack-name "ImageFlow-${ENVIRONMENT}" \
      --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
      --output text 2>/dev/null || echo "")
  fi

  if [ -z "$API_URL" ]; then
    echo "API_URL not set and could not detect from CloudFormation."
    echo "Set API_URL environment variable and try again."
    return 1
  fi

  echo "Testing API Gateway: ${API_URL}/health"
  echo ""

  case "$LOAD_TOOL" in
    hey)
      hey -n "$REQUESTS" -c "$CONCURRENCY" -t 10 "${API_URL}/health"
      ;;
    artillery)
      cat > /tmp/artillery-imageflow.yml << EOF
config:
  target: "${API_URL}"
  phases:
    - duration: 30
      arrivalRate: ${CONCURRENCY}
  defaults:
    headers:
      Content-Type: "application/json"
scenarios:
  - flow:
      - get:
          url: "/health"
EOF
      artillery run /tmp/artillery-imageflow.yml
      ;;
    ab)
      ab -n "$REQUESTS" -c "$CONCURRENCY" "${API_URL}/health"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Mode 2: S3 upload simulation
# ---------------------------------------------------------------------------
test_upload() {
  echo "Simulating S3 uploads to ${UPLOADS_BUCKET}..."
  echo ""

  # Generate a test image
  TEST_FILE="/tmp/imageflow-load-test-${ENVIRONMENT}.jpg"
  python3 -c "
from PIL import Image
import random
w, h = random.randint(800, 4000), random.randint(600, 3000)
img = Image.new('RGB', (w, h), color=(random.randint(0,255), random.randint(0,255), random.randint(0,255)))
img.save('${TEST_FILE}', 'JPEG', quality=85)
print(f'Generated test image: {w}x{h}')
" 2>/dev/null || {
    # Fallback: create a small test file
    dd if=/dev/urandom of="$TEST_FILE" bs=1M count=1 2>/dev/null
  }

  echo "Uploading ${REQUESTS} copies with concurrency ${CONCURRENCY}..."
  START_TIME=$(date +%s)

  for i in $(seq 1 "$REQUESTS"); do
    KEY="load-test/image-$(date +%s)-${i}.jpg"
    aws s3 cp "$TEST_FILE" "s3://${UPLOADS_BUCKET}/${KEY}" \
      --content-type "image/jpeg" \
      --region "$AWS_REGION" \
      --no-cli-pager &
    # Throttle concurrency
    if [ $((i % CONCURRENCY)) -eq 0 ]; then
      wait
    fi
  done
  wait

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  echo ""
  echo "Uploaded ${REQUESTS} images in ${DURATION}s"
  echo "Rate: $((REQUESTS / (DURATION > 0 ? DURATION : 1))) req/s"

  rm -f "$TEST_FILE"
}

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------
test_api || echo "API test skipped (no URL configured)"
echo ""
echo "---"
test_upload

echo ""
echo "=== Load test complete ==="
echo "Check the CloudWatch dashboard at:"
echo "https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=ImageFlow-${ENVIRONMENT}"
echo ""
echo "Metrics to verify:"
echo "  - Lambda invocations and errors"
echo "  - DynamoDB consumed capacity"
echo "  - S3 request rates"
echo "  - Step Functions execution count"
