import os
from datetime import datetime, timezone
import boto3

TABLE_NAME = os.environ["METADATA_TABLE"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def put_image_metadata(
    image_id: str,
    original_key: str,
    variants: list[str],
    file_size: int,
    content_type: str,
    blurhash: str | None = None,
) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    item = {
        "image_id": image_id,
        "upload_date": now,
        "original_key": original_key,
        "variants": variants,
        "file_size": file_size,
        "content_type": content_type,
        "status": "completed",
        "blurhash": blurhash or "",
        "ttl": int(datetime.now(timezone.utc).timestamp()) + 86400 * 365,
    }
    # Idempotency fix: Enforce conditional write using attribute_not_exists(image_id).
    # If a duplicate S3 ObjectCreated event arrives, DynamoDB rejects the duplicate write,
    # preventing metadata overwrite and duplicate records.
    table.put_item(
        Item=item,
        ConditionExpression="attribute_not_exists(image_id)",
    )
    return item


def update_status(image_id: str, status: str, error: str | None = None) -> None:
    expr = "SET #s = :s"
    attrs = {":s": status}
    names = {"#s": "status"}
    if error:
        expr += ", error_message = :e"
        attrs[":e"] = error
    table.update_item(
        Key={"image_id": image_id, "upload_date": datetime.now(timezone.utc).isoformat()},
        UpdateExpression=expr,
        ExpressionAttributeValues=attrs,
        ExpressionAttributeNames=names,
    )
