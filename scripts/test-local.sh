#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Serverless ImageFlow - Local Test Script
# =============================================================================
# Usage:
#   ./scripts/test-local.sh              # Test everything
#   ./scripts/test-local.sh --processor  # Test only image-processor
#   ./scripts/test-local.sh --api        # Test only image-api
#
# Prerequisites:
#   - Python 3.12 with virtualenv
#   - AWS SAM CLI installed (pip install aws-sam-cli)
#   - Node.js 20 installed (for frontend)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_MODE="${1:---all}"

test_processor() {
  echo ""
  echo "=== Testing Image Processor Lambda ==="

  cd "$PROJECT_DIR/lambda/image-processor"
  python3 -m venv /tmp/imageflow-processor-venv
  source /tmp/imageflow-processor-venv/bin/activate
  pip install -r requirements.txt --quiet
  pip install pytest --quiet

  # Unit tests
  python -c "
from resize import resize_image, get_variant_key, VARIANT_SIZES
import io
from PIL import Image

# Test resize
img = Image.new('RGB', (1920, 1080), color='red')
buf = io.BytesIO()
img.save(buf, format='JPEG')
buf.seek(0)

thumb = resize_image(buf.getvalue(), 'thumbnail')
assert len(thumb) > 0, 'Thumbnail should not be empty'

web = resize_image(buf.getvalue(), 'web')
assert len(web) > 0, 'Web variant should not be empty'

# Test variant key
key = get_variant_key('photos/test.jpg', 'thumbnail')
assert key == 'photos/test_thumbnail.jpg', f'Unexpected key: {key}'
print('All resize tests passed')
"
  deactivate
  cd "$PROJECT_DIR"

  # SAM local invoke test
  if command -v sam &> /dev/null; then
    echo ""
    echo "Running SAM local test..."
    # Create a sample S3 event
    cat > /tmp/sample-s3-event.json << 'EOF'
{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3",
      "awsRegion": "us-east-1",
      "eventName": "ObjectCreated:Put",
      "s3": {
        "s3SchemaVersion": "1.0",
        "bucket": {
          "name": "imageflow-dev-uploads",
          "arn": "arn:aws:s3:::imageflow-dev-uploads"
        },
        "object": {
          "key": "test-image.jpg",
          "size": 1024,
          "contentType": "image/jpeg"
        }
      }
    }
  ]
}
EOF
    echo "Skipping SAM invoke (requires AWS credentials and deployed infra)"
    echo "Run: sam local invoke ImageProcessor -e /tmp/sample-s3-event.json"
  fi
}

test_api() {
  echo ""
  echo "=== Testing Image API Lambda ==="

  cd "$PROJECT_DIR/lambda/image-api"
  python3 -m venv /tmp/imageflow-api-venv
  source /tmp/imageflow-api-venv/bin/activate
  pip install -r requirements.txt --quiet
  pip install pytest httpx --quiet

  python -c "
from queries import get_image, list_images
print('Import tests passed')
print('Note: Actual DynamoDB tests require AWS credentials')
"
  deactivate
  cd "$PROJECT_DIR"
}

test_frontend() {
  echo ""
  echo "=== Testing Frontend ==="

  if command -v npm &> /dev/null; then
    echo "Starting frontend dev server..."
    cd "$PROJECT_DIR/frontend"
    echo "Static frontend - run: npm start"
    echo "Open: http://localhost:3000"
    cd "$PROJECT_DIR"
  else
    echo "Node.js not found. Install Node.js 20 to test the frontend."
  fi
}

case "$TEST_MODE" in
  --processor) test_processor ;;
  --api)       test_api ;;
  --frontend)  test_frontend ;;
  --all|*)
    test_processor
    test_api
    test_frontend
    ;;
esac

echo ""
echo "=== Local tests complete ==="
