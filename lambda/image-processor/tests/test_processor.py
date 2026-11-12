import io
import json
import os
import sys
from dataclasses import dataclass
from unittest.mock import patch
from PIL import Image
import pytest

os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["POWERTOOLS_TRACE_DISABLED"] = "true"
os.environ["POWERTOOLS_SERVICE_NAME"] = "image-processor"
os.environ["PROCESSED_BUCKET"] = "test-processed-bucket"
os.environ["METADATA_TABLE"] = "test-metadata-table"
os.environ["KMS_KEY_ARN"] = "arn:aws:kms:us-east-1:123456789012:key/test-key"

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from blurhash import compute_blurhash  # noqa: E402
import handler  # noqa: E402
import metadata  # noqa: E402
from resize import VARIANT_SIZES, get_variant_key, resize_image, validate_image  # noqa: E402


@dataclass
class LambdaContext:
    function_name: str = "image-processor"
    memory_limit_in_mb: int = 512
    invoked_function_arn: str = "arn:aws:lambda:us-east-1:123456789012:function:image-processor"
    aws_request_id: str = "52fdfc07-2182-154f-163f-5f0f9a621d72"


dummy_context = LambdaContext()


def _create_test_image(width=400, height=300, color="red", fmt="JPEG") -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGB", (width, height), color=color)
    img.save(buf, format=fmt)
    return buf.getvalue()


def test_get_variant_key():
    assert get_variant_key("photos/vacation.jpg", "thumbnail") == "photos/vacation_thumbnail.jpg"
    assert get_variant_key("sample", "web") == "sample_web.jpg"


def test_validate_image_valid():
    img_bytes = _create_test_image(100, 100)
    img = validate_image(img_bytes)
    assert img.width == 100
    assert img.height == 100


def test_validate_image_corrupt():
    with pytest.raises(ValueError, match="Invalid or corrupted image"):
        validate_image(b"not-an-image-data")


def test_validate_image_oversized_dimensions():
    img_bytes = _create_test_image(10, 10)
    with patch("PIL.Image.Image.width", new=10001):
        with pytest.raises(ValueError, match="exceed limit"):
            validate_image(img_bytes)


def test_resize_image_variants():
    img_bytes = _create_test_image(500, 500)
    for variant in ["thumbnail", "web", "preview"]:
        resized = resize_image(img_bytes, variant)
        assert len(resized) > 0
        with Image.open(io.BytesIO(resized)) as out_img:
            target_w, target_h = VARIANT_SIZES[variant]
            assert out_img.width <= target_w
            assert out_img.height <= target_h


def test_resize_image_invalid_variant():
    img_bytes = _create_test_image(100, 100)
    with pytest.raises(ValueError, match="Unknown variant"):
        resize_image(img_bytes, "unsupported_variant")


def test_compute_blurhash():
    img_bytes = _create_test_image(100, 100, color="blue")
    hash_str = compute_blurhash(img_bytes)
    assert isinstance(hash_str, str)
    assert len(hash_str) > 0


@patch.object(metadata, "table")
def test_put_image_metadata(mock_table):
    item = metadata.put_image_metadata(
        image_id="img-123",
        original_key="test.jpg",
        variants=["test_thumbnail.jpg"],
        file_size=1024,
        content_type="image/jpeg",
        blurhash="LEHLk~WB2yk8pyo0adR*.7kCMdnj",
    )
    assert item["image_id"] == "img-123"
    assert item["status"] == "completed"
    mock_table.put_item.assert_called_once_with(
        Item=item,
        ConditionExpression="attribute_not_exists(image_id)",
    )


@patch.object(metadata, "table")
def test_update_status(mock_table):
    metadata.update_status("img-123", "failed", error="Decoding error")
    mock_table.update_item.assert_called_once()


@patch.object(handler, "s3")
@patch.object(handler, "put_image_metadata")
def test_handler_success(mock_put_meta, mock_s3):
    img_bytes = _create_test_image(300, 300)
    mock_s3.get_object.return_value = {
        "Body": io.BytesIO(img_bytes),
        "ContentType": "image/jpeg",
    }

    event = {
        "Records": [
            {
                "eventVersion": "2.1",
                "eventSource": "aws:s3",
                "awsRegion": "us-east-1",
                "eventTime": "2026-01-01T00:00:00.000Z",
                "eventName": "ObjectCreated:Put",
                "s3": {
                    "s3SchemaVersion": "1.0",
                    "configurationId": "testConfigRule",
                    "bucket": {
                        "name": "imageflow-uploads",
                        "arn": "arn:aws:s3:::imageflow-uploads",
                    },
                    "object": {
                        "key": "uploads%2Fsample.jpg",
                        "size": len(img_bytes),
                    },
                },
            }
        ]
    }

    resp = handler.handler(event, dummy_context)
    assert resp["statusCode"] == 200
    assert json.loads(resp["body"])["processed"] == 1
    assert mock_s3.put_object.call_count == len(VARIANT_SIZES)
    assert mock_put_meta.call_count == 1


@patch.object(handler, "s3")
def test_handler_unsupported_content_type(mock_s3):
    mock_s3.get_object.return_value = {
        "Body": io.BytesIO(b"dummy text"),
        "ContentType": "text/plain",
    }
    event = {
        "Records": [
            {
                "s3": {
                    "bucket": {"name": "imageflow-uploads"},
                    "object": {"key": "test.txt", "size": 100},
                }
            }
        ]
    }
    resp = handler.handler(event, dummy_context)
    assert resp["statusCode"] == 200
    assert mock_s3.put_object.call_count == 0


@patch.object(handler, "s3")
def test_handler_oversized_file(mock_s3):
    mock_s3.get_object.return_value = {
        "Body": io.BytesIO(b"x" * (handler.MAX_FILE_SIZE + 10)),
        "ContentType": "image/jpeg",
    }
    event = {
        "Records": [
            {
                "s3": {
                    "bucket": {"name": "imageflow-uploads"},
                    "object": {
                        "key": "huge.jpg",
                        "size": handler.MAX_FILE_SIZE + 10,
                    },
                }
            }
        ]
    }
    resp = handler.handler(event, dummy_context)
    assert resp["statusCode"] == 200
    assert mock_s3.put_object.call_count == 0
