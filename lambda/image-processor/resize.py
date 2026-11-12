import io
from PIL import Image, UnidentifiedImageError

MAX_IMAGE_DIMENSION = 10000
MAX_IMAGE_PIXELS = 50_000_000

VARIANT_SIZES = {
    "thumbnail": (150, 150),
    "web": (800, 800),
    "preview": (400, 400),
}


def validate_image(image_bytes: bytes) -> Image.Image:
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.verify()
        img = Image.open(io.BytesIO(image_bytes))
    except (UnidentifiedImageError, Exception):
        raise ValueError("Invalid or corrupted image")

    if img.width > MAX_IMAGE_DIMENSION or img.height > MAX_IMAGE_DIMENSION:
        msg = f"Image dimensions {img.width}x{img.height} exceed limit {MAX_IMAGE_DIMENSION}"
        raise ValueError(msg)

    if img.width * img.height > MAX_IMAGE_PIXELS:
        raise ValueError(f"Image pixel count exceeds limit of {MAX_IMAGE_PIXELS}")

    return img


def resize_image(image_bytes: bytes, variant: str) -> bytes:
    size = VARIANT_SIZES.get(variant)
    if not size:
        raise ValueError(f"Unknown variant: {variant}")

    img = validate_image(image_bytes)
    img = img.convert("RGB")
    img.thumbnail(size, Image.Resampling.LANCZOS)

    buf = io.BytesIO()
    quality = 85 if variant == "web" else 90
    img.save(buf, format="JPEG", quality=quality, optimize=True)
    return buf.getvalue()


def get_variant_key(original_key: str, variant: str) -> str:
    prefix, _ = original_key.rsplit(".", 1) if "." in original_key else (original_key, "jpg")
    return f"{prefix}_{variant}.jpg"
