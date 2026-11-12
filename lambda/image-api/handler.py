import os
import json
from datetime import datetime, timezone

from aws_lambda_powertools import Tracer, Logger
from aws_lambda_powertools.event_handler import APIGatewayRestResolver
from aws_lambda_powertools.event_handler.api_gateway import CORSConfig

from queries import get_image, list_images

tracer = Tracer()
logger = Logger()
cors_config = CORSConfig(
    allow_origin=os.environ.get("ALLOWED_ORIGINS", "https://localhost:3000"),
    allow_headers=["Content-Type", "Authorization"],
    max_age=3600,
)
app = APIGatewayRestResolver(cors=cors_config)


@app.get("/images")
@tracer.capture_method
def list_images_handler():
    params = app.current_event.query_string_parameters or {}
    limit = int(params.get("limit", 20))
    status = params.get("status")
    cursor = params.get("cursor")

    last_key = json.loads(cursor) if cursor else None
    items, next_key = list_images(limit=limit, status=status, last_evaluated_key=last_key)

    return {
        "images": items,
        "next_cursor": json.dumps(next_key) if next_key else None,
        "count": len(items),
    }


@app.get("/images/<image_id>")
@tracer.capture_method
def get_image_handler(image_id: str):
    item = get_image(image_id)
    if not item:
        return {"error": "Image not found"}, 404
    return item


@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now(timezone.utc).isoformat()}


@tracer.capture_lambda_handler
@logger.inject_lambda_context
def handler(event: dict, context) -> dict:
    return app.resolve(event, context)
