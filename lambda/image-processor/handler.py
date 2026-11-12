import hashlib
import json
import os
from urllib.parse import unquote_plus
import boto3

from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.utilities.data_classes import S3Event
from aws_lambda_powertools.utilities.data_classes.s3_event import S3EventRecord
from botocore.exceptions import ClientError

from blurhash import compute_blurhash
from metadata import put_image_metadata
from resize import VARIANT_SIZES, get_variant_key, resize_image

tracer = Tracer()
logger = Logger()

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_FILE_SIZE = 50 * 1024 * 1024

PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
s3 = boto3.client("s3")


def _download_from_s3(bucket: str, key: str) -> tuple[bytes, str]:
    resp = s3.get_object(Bucket=bucket, Key=key)
    content_type = resp.get("ContentType", "application/octet-stream")
    return resp["Body"].read(), content_type


def _upload_to_s3(bucket: str, key: str, data: bytes) -> None:
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType="image/jpeg",
        ServerSideEncryption="aws:kms",
        SSEKMSKeyId=os.environ.get("KMS_KEY_ARN"),
    )


@tracer.capture_lambda_handler
@logger.inject_lambda_context
def handler(event: dict, context) -> dict:
    try:
        s3_event = S3Event(event)
        records = list(s3_event.records)
        for record in records:
            _process_record(record)
        return {"statusCode": 200, "body": json.dumps({"processed": len(records)})}
    except Exception as e:
        logger.exception("Processing failed")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}


def _process_record(record: S3EventRecord) -> None:
    bucket = record.s3.bucket.name
    key = unquote_plus(record.s3.get_object.key)

    # Enforce idempotency: use deterministic SHA-256 hash of bucket + key as image_id
    # rather than random UUID so duplicate S3 events resolve to the same ID.
    image_id = hashlib.sha256(f"{bucket}/{key}".encode()).hexdigest()[:16]

    tracer.put_annotation(key="image_id", value=image_id)
    logger.info("Processing", extra={"bucket": bucket, "key": key, "image_id": image_id})

    image_bytes, content_type = _download_from_s3(bucket, key)
    original_size = len(image_bytes)

    if content_type not in ALLOWED_CONTENT_TYPES:
        logger.warning("Unsupported content type", extra={"content_type": content_type, "key": key})
        return

    if original_size > MAX_FILE_SIZE:
        logger.warning("File exceeds maximum size", extra={"size": original_size, "key": key})
        return

    variants = []
    for variant in VARIANT_SIZES:
        variant_key = get_variant_key(key, variant)
        variant_data = resize_image(image_bytes, variant)
        _upload_to_s3(PROCESSED_BUCKET, variant_key, variant_data)
        variants.append(variant_key)

    blurhash = compute_blurhash(image_bytes)

    try:
        put_image_metadata(
            image_id=image_id,
            original_key=key,
            variants=variants,
            file_size=original_size,
            content_type=content_type,
            blurhash=blurhash,
        )
    except ClientError as e:
        if e.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            logger.info(
                "Duplicate processing detected; item exists",
                extra={"image_id": image_id},
            )
            return
        raise

    tracer.put_annotation(key="variant_count", value=len(variants))

    logger.info(
        "Completed",
        extra={
            "image_id": image_id,
            "variants": len(variants),
            "blurhash": blurhash,
        },
    )
