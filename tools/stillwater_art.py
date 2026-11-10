r"""Stillwater's textures: a soft ring of light, drawn white so the addon can tint it in the race's colour.

  uv run --no-project --with pillow --with numpy python tools/stillwater_art.py [--preview <png>]

Writes addon/Stillwater/ring.tga (256 x 256). The addon squashes the square texture into a flat ellipse, so it
lies on the ground round the character's feet like a ripple on still water. The ring is a thin bright core inside
a wide soft glow; both fall off as Gaussians across the ring's radius, so there is no hard edge to look at.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "addon" / "Stillwater"
N = 256
R = 0.80        # the ring's radius, as a fraction of the half-width
CORE = 0.018    # the bright core's Gaussian width
GLOW = 0.075    # the soft glow's Gaussian width


def ring():
    """Return the ring as an RGBA image: white, with the light in the alpha channel."""
    y, x = np.mgrid[0:N, 0:N]
    r = np.hypot(x - (N - 1) / 2, y - (N - 1) / 2) / (N / 2)
    core = np.exp(-((r - R) / CORE) ** 2 / 2)
    glow = np.exp(-((r - R) / GLOW) ** 2 / 2)
    a = np.clip(0.95 * core + 0.45 * glow, 0, 1)
    rgba = np.zeros((N, N, 4), dtype=np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (a * 255).round().astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def write_tga(im, path):
    """Write an uncompressed 32-bit TGA, top-left origin, the layout WoW reads."""
    a = np.asarray(im)
    head = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]) + im.width.to_bytes(2, "little") + \
        im.height.to_bytes(2, "little") + bytes([32, 0x28])
    path.write_bytes(head + a[..., [2, 1, 0, 3]].tobytes())


def main(preview=None):
    OUT.mkdir(parents=True, exist_ok=True)
    im = ring()
    write_tga(im, OUT / "ring.tga")
    if preview:   # tinted moonflower lavender, squashed to the ground ellipse, on night grass
        bg = Image.new("RGBA", (400, 200), (44, 58, 44, 255))
        tint = np.asarray(im).astype(float)
        tint[..., :3] *= np.array([240, 236, 255]) / 255
        flat = Image.fromarray(tint.astype("uint8"), "RGBA").resize((300, 120), Image.LANCZOS)
        bg.alpha_composite(flat, (50, 40))
        bg.save(preview)
    print("written to", OUT)


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[a.index("--preview") + 1] if "--preview" in a else None)
