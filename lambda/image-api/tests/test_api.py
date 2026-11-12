import importlib.util
import json
import os
import sys
from dataclasses import dataclass
from unittest.mock import patch
from botocore.exceptions import ClientError

os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["POWERTOOLS_TRACE_DISABLED"] = "true"
os.environ["POWERTOOLS_SERVICE_NAME"] = "image-api"
os.environ["METADATA_TABLE"] = "test-metadata-table"
os.environ["ALLOWED_ORIGINS"] = "https://example.com"

_api_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _api_dir not in sys.path:
    sys.path.insert(0, _api_dir)

import queries  # noqa: E402

_spec = importlib.util.spec_from_file_location(
    "image_api_handler", os.path.join(_api_dir, "handler.py")
)
api_handler = importlib.util.module_from_spec(_spec)
sys.modules["image_api_handler"] = api_handler
_spec.loader.exec_module(api_handler)


@dataclass
class LambdaContext:
    function_name: str = "image-api"
    memory_limit_in_mb: int = 128
    invoked_function_arn: str = "arn:aws:lambda:us-east-1:123456789012:function:image-api"
    aws_request_id: str = "52fdfc07-2182-154f-163f-5f0f9a621d72"


dummy_context = LambdaContext()


@patch.object(queries, "table")
def test_get_image_found(mock_table):
    mock_table.query.return_value = {
        "Items": [
            {
                "image_id": "img-001",
                "upload_date": "2026-01-01T00:00:00Z",
                "status": "completed",
            }
        ]
    }
    res = queries.get_image("img-001")
    assert res is not None
    assert res["image_id"] == "img-001"


@patch.object(queries, "table")
def test_get_image_not_found(mock_table):
    mock_table.query.return_value = {"Items": []}
    res = queries.get_image("non-existent")
    assert res is None


@patch.object(queries, "table")
def test_get_image_client_error(mock_table):
    mock_table.query.side_effect = ClientError(
        {"Error": {"Code": "500", "Message": "DB Error"}}, "query"
    )
    res = queries.get_image("img-001")
    assert res is None


@patch.object(queries, "table")
def test_list_images_default(mock_table):
    mock_table.query.return_value = {
        "Items": [{"image_id": "img-1"}, {"image_id": "img-2"}],
        "LastEvaluatedKey": {"image_id": "img-2"},
    }
    items, last_key = queries.list_images(limit=10)
    assert len(items) == 2
    assert last_key == {"image_id": "img-2"}


@patch.object(queries, "table")
def test_list_images_with_status_and_cursor(mock_table):
    mock_table.query.return_value = {
        "Items": [{"image_id": "img-3"}],
        "LastEvaluatedKey": None,
    }
    items, last_key = queries.list_images(
        limit=5, status="failed", last_evaluated_key={"image_id": "img-2"}
    )
    assert len(items) == 1
    assert last_key is None


@patch.object(queries, "table")
def test_list_images_client_error(mock_table):
    mock_table.query.side_effect = ClientError(
        {"Error": {"Code": "500", "Message": "DB Error"}}, "query"
    )
    items, last_key = queries.list_images()
    assert items == []
    assert last_key is None


def test_health_endpoint():
    event = {
        "path": "/health",
        "httpMethod": "GET",
        "headers": {},
        "queryStringParameters": None,
        "requestContext": {
            "resourcePath": "/health",
            "httpMethod": "GET",
            "identity": {"sourceIp": "127.0.0.1"},
        },
    }
    res = api_handler.handler(event, dummy_context)
    assert res["statusCode"] == 200
    body = json.loads(res["body"])
    assert body["status"] == "ok"


@patch.object(api_handler, "get_image")
def test_get_image_endpoint_found(mock_get_img):
    mock_get_img.return_value = {
        "image_id": "img-123",
        "status": "completed",
        "original_key": "sample.jpg",
    }
    event = {
        "path": "/images/img-123",
        "httpMethod": "GET",
        "headers": {},
        "queryStringParameters": None,
        "requestContext": {
            "resourcePath": "/images/{image_id}",
            "httpMethod": "GET",
            "identity": {"sourceIp": "127.0.0.1"},
        },
    }
    res = api_handler.handler(event, dummy_context)
    assert res["statusCode"] == 200
    body = json.loads(res["body"])
    assert body["image_id"] == "img-123"


@patch.object(api_handler, "get_image")
def test_get_image_endpoint_not_found(mock_get_img):
    mock_get_img.return_value = None
    event = {
        "path": "/images/non-existent",
        "httpMethod": "GET",
        "headers": {},
        "queryStringParameters": None,
        "requestContext": {
            "resourcePath": "/images/{image_id}",
            "httpMethod": "GET",
            "identity": {"sourceIp": "127.0.0.1"},
        },
    }
    res = api_handler.handler(event, dummy_context)
    assert res["statusCode"] == 404


@patch.object(api_handler, "list_images")
def test_list_images_endpoint(mock_list_imgs):
    mock_list_imgs.return_value = ([{"image_id": "img-1"}], None)
    event = {
        "path": "/images",
        "httpMethod": "GET",
        "headers": {},
        "queryStringParameters": {"limit": "5"},
        "requestContext": {
            "resourcePath": "/images",
            "httpMethod": "GET",
            "identity": {"sourceIp": "127.0.0.1"},
        },
    }
    res = api_handler.handler(event, dummy_context)
    assert res["statusCode"] == 200
    body = json.loads(res["body"])
    assert body["count"] == 1
    assert len(body["images"]) == 1
