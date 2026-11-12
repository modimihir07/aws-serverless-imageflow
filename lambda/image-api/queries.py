import os
import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

TABLE_NAME = os.environ["METADATA_TABLE"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def get_image(image_id: str) -> dict | None:
    try:
        resp = table.query(
            KeyConditionExpression=Key("image_id").eq(image_id),
            Limit=1,
            ScanIndexForward=False,
        )
        items = resp.get("Items", [])
        return items[0] if items else None
    except ClientError:
        return None


def list_images(
    limit: int = 20,
    status: str | None = None,
    last_evaluated_key: dict | None = None,
) -> tuple[list[dict], dict | None]:
    kwargs = {
        "IndexName": "status-upload_date-index",
        "Limit": limit,
        "ScanIndexForward": False,
    }
    if status:
        kwargs["KeyConditionExpression"] = Key("status").eq(status)
    else:
        kwargs["KeyConditionExpression"] = Key("status").eq("completed")
    if last_evaluated_key:
        kwargs["ExclusiveStartKey"] = last_evaluated_key

    try:
        resp = table.query(**kwargs)
        return resp.get("Items", []), resp.get("LastEvaluatedKey")
    except ClientError:
        return [], None
