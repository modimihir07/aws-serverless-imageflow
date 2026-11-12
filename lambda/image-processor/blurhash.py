import io
import os
import sys
from PIL import Image

# Temporarily pop local module from sys.modules and sys.path to import third-party package
_self = sys.modules.pop("blurhash", None)
_orig_path = sys.path[:]
_this_dir = os.path.dirname(os.path.abspath(__file__))
sys.path = [p for p in _orig_path if os.path.abspath(p or ".") != _this_dir]

try:
    import blurhash as _pkg

    _encode = _pkg.encode
finally:
    sys.path = _orig_path
    if _self is not None:
        sys.modules["blurhash"] = _self


def compute_blurhash(image_bytes: bytes, x_components: int = 4, y_components: int = 3) -> str:
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")
    return _encode(img, x_components=x_components, y_components=y_components)
