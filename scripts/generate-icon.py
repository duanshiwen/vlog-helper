#!/usr/bin/env python3
"""VlogPack icon v4 — VP + semi-transparent play button."""
from PIL import Image, ImageDraw, ImageFont
import os, subprocess, tempfile

SIZE = 1024


def create():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── 背景：纯白圆角 ─────────────────────────────
    draw.rounded_rectangle(
        [(0, 0), (SIZE - 1, SIZE - 1)],
        radius=228,
        fill=(255, 255, 255),
    )

    # ── VP 文字 ────────────────────────────────────
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", 640)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 640)
        except:
            font = ImageFont.load_default()

    text = "VP"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2 - bbox[0]
    ty = (SIZE - th) // 2 - bbox[1] + 10
    draw.text((tx, ty), text, fill=(40, 40, 50), font=font)

    # ── 半透明播放三角（覆盖在文字中间，YouTube 风格）──
    cx, cy = SIZE // 2, SIZE // 2
    tri_size = 300
    tri_cx = cx + 10
    tri_cy = cy
    h = tri_size
    w = int(h * 0.866)
    tri_points = [
        (tri_cx - w // 3, tri_cy - h // 2),
        (tri_cx - w // 3, tri_cy + h // 2),
        (tri_cx + w * 2 // 3, tri_cy),
    ]
    # 半透明白色三角
    draw.polygon(tri_points, fill=(255, 255, 255, 140))

    # 整体半透明（alpha 乘 0.75）
    alpha = img.split()[3]
    alpha = alpha.point(lambda x: int(x * 0.75))
    img.putalpha(alpha)

    return img


def generate_icns(img, path):
    d = tempfile.mkdtemp(suffix=".iconset")
    for name, sz in {
        "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
    }.items():
        img.resize((sz, sz), Image.LANCZOS).save(os.path.join(d, name))
    subprocess.run(["iconutil", "-c", "icns", d, "-o", path], check=True)
    print(f"✅ {path} ({os.path.getsize(path) // 1024}KB)")


if __name__ == "__main__":
    img = create()
    out = os.path.join(os.path.dirname(__file__), "..", "Sources", "VlogPackApp")
    os.makedirs(out, exist_ok=True)
    generate_icns(img, os.path.join(out, "AppIcon.icns"))
    img.save(os.path.join(out, "AppIcon.png"))
    print("✅ done")
