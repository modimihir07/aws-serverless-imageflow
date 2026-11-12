#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Serverless ImageFlow - Seed Sample Images
# =============================================================================
# Downloads sample images from Unsplash and uploads to the uploads S3 bucket,
# triggering the image processing pipeline.
#
# Usage:
#   ./scripts/seed-sample-images.sh [dev|prod]
#
# Prerequisites:
#   - AWS CLI configured
#   - curl installed
# =============================================================================

ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
UPLOADS_BUCKET="imageflow-${ENVIRONMENT}-uploads"

echo "=== Seeding sample images for $ENVIRONMENT ==="

# Check bucket exists
if ! aws s3 ls "s3://${UPLOADS_BUCKET}" 2>/dev/null; then
  echo "Error: Bucket ${UPLOADS_BUCKET} does not exist."
  echo "Deploy the infrastructure first with ./scripts/deploy.sh"
  exit 1
fi

# Sample image URLs (high-quality free photos)
IMAGES=(
  "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1920"  # Nature
  "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1920"  # Architecture
  "https://images.unsplash.com/photo-1448375240586-882707db888b?w=1920"  # Forest
  "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1920"  # Mountain scenery
  "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=1920"  # Mountain
  "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=1920"  # Lake
  "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1920"  # Road
  "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1920"  # Beach
  "https://images.unsplash.com/photo-1511767594664-026e0a8a9b97?w=1920"  # City
  "https://images.unsplash.com/photo-1518173946687-a36f968f7f3d?w=1920"  # Sunset
)

echo "Downloading ${#IMAGES[@]} sample images..."

TEMP_DIR="/tmp/imageflow-seed-$$"
mkdir -p "$TEMP_DIR"

COUNT=0
for URL in "${IMAGES[@]}"; do
  COUNT=$((COUNT + 1))
  FILENAME="sample-${COUNT}.jpg"
  FILEPATH="${TEMP_DIR}/${FILENAME}"

  echo "[$COUNT/${#IMAGES[@]}] Downloading ${FILENAME}..."
  if curl -sL -o "$FILEPATH" "$URL" --max-time 30; then
    # Resize to reasonable size before uploading (max 1920px)
    if command -v convert &> /dev/null; then
      convert "$FILEPATH" -resize "1920x1920>" -quality 85 "$FILEPATH" 2>/dev/null || true
    fi

    echo "  Uploading to s3://${UPLOADS_BUCKET}/${FILENAME}..."
    aws s3 cp "$FILEPATH" "s3://${UPLOADS_BUCKET}/${FILENAME}" \
      --content-type "image/jpeg" \
      --region "$AWS_REGION" \
      --no-cli-pager

    echo "  -> Processing pipeline triggered!"
  else
    echo "  Warning: Failed to download $URL"
  fi
done

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "=== Seeded $COUNT images ==="
echo "Check the uploads bucket: s3://${UPLOADS_BUCKET}"
echo "Images will be automatically processed by the Lambda function."
echo "Check the CloudWatch dashboard for processing status."
