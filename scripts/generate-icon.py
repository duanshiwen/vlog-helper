#!/usr/bin/env python3
"""Generate a polished macOS .icns icon for VlogPack — v2."""
from PIL import Image, ImageDraw, ImageFont
import math, os, subprocess, tempfile

SIZE = 1024
CANVAS = (SIZE, SIZE)


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def create_icon_image():
    img = Image.new("RGBA", CANVAS, (0, 0, 0, 0))

    # ── 1. 渐变背景 ──────────────────────────────────
    # 用 Pillow 逐行渐变：紫→深蓝→靛
    for y in range(SIZE):
        t = y / SIZE
        if t < 0.5:
            c = lerp_color((88, 40, 180), (30, 50, 160), t * 2)
        else:
            c = lerp_color((30, 50, 160), (10, 100, 180), (t - 0.5) * 2)
        ImageDraw.Draw(img).line([(0, y), (SIZE, y)], fill=(*c, 255))

    # ── 2. 圆角蒙版 ──────────────────────────────────
    mask = Image.new("L", CANVAS, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (SIZE - 1, SIZE - 1)], radius=228, fill=255
    )
    img.putalpha(mask)

    draw = ImageDraw.Draw(img)

    # ── 3. 顶部微光 ──────────────────────────────────
    highlight = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)
    for y in range(int(SIZE * 0.45)):
        a = int(30 * (1 - y / (SIZE * 0.45)) ** 2)
        h_draw.line([(0, y), (SIZE, y)], fill=(255, 255, 255, a))
    img = Image.alpha_composite(img, highlight)
    draw = ImageDraw.Draw(img)

    # ── 4. 主元素：胶片帧 + 播放三角 ──────────────────
    cx, cy = SIZE // 2, SIZE // 2 - 20

    # 胶片外框（圆角矩形）
    film_w, film_h = 480, 360
    film_x = cx - film_w // 2
    film_y = cy - film_h // 2
    draw.rounded_rectangle(
        [(film_x, film_y), (film_x + film_w, film_y + film_h)],
        radius=24,
        fill=(0, 0, 0, 90),
        outline=(255, 255, 255, 100),
        width=3,
    )

    # 胶片齿孔（顶部 & 底部）
    hole_w, hole_h = 36, 24
    hole_gap = 60
    for row_y in [film_y + 14, film_y + film_h - 14 - hole_h]:
        hx = film_x + 20
        while hx + hole_w < film_x + film_w - 10:
            draw.rounded_rectangle(
                [(hx, row_y), (hx + hole_w, row_y + hole_h)],
                radius=5,
                fill=(255, 255, 255, 40),
            )
            hx += hole_gap

    # 播放三角形（居中，略微右移视觉补偿）
    tri_cx = cx + 15
    tri_cy = cy
    tri_h = 160
    tri_w = int(tri_h * 0.866)
    tri_points = [
        (tri_cx - tri_w // 3, tri_cy - tri_h // 2),
        (tri_cx - tri_w // 3, tri_cy + tri_h // 2),
        (tri_cx + tri_w * 2 // 3, tri_cy),
    ]
    # 三角形带微光
    draw.polygon(tri_points, fill=(255, 255, 255, 230))

    # 三角形内部高光
    inner = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    inner_draw = ImageDraw.Draw(inner)
    inner_points = [
        (tri_cx - tri_w // 3 + 15, tri_cy - tri_h // 2 + 30),
        (tri_cx - tri_w // 3 + 15, tri_cy + tri_h // 2 - 30),
        (tri_cx + tri_w * 2 // 3 - 30, tri_cy),
    ]
    inner_draw.polygon(inner_points, fill=(255, 255, 255, 40))
    img = Image.alpha_composite(img, inner)

    # ── 5. 底部小字 ──────────────────────────────────
    draw = ImageDraw.Draw(img)
    try:
        font_small = ImageFont.truetype(
            "/System/Library/Fonts/SFNSRounded.ttf", 56
        )
    except:
        font_small = ImageFont.truetype(
            "/System/Library/Fonts/Helvetica.ttc", 56
        )
    label = "VlogPack"
    bbox = draw.textbbox((0, 0), label, font=font_small)
    tw = bbox[2] - bbox[0]
    draw.text(
        ((SIZE - tw) // 2, film_y + film_h + 40),
        label,
        fill=(255, 255, 255, 160),
        font=font_small,
    )

    # ── 6. 外圈微弱光晕 ──────────────────────────────
    glow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for r in range(380, 340, -1):
        a = int(8 * (1 - (r - 340) / 40))
        glow_draw.ellipse(
            [(cx - r, cy - r), (cx + r, cy + r)],
            outline=(180, 160, 255, a),
            width=1,
        )
    img = Image.alpha_composite(img, glow)

    return img


def generate_icns(img, output_path):
    iconset_dir = tempfile.mkdtemp(suffix=".iconset")
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in sizes.items():
        resized = img.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))
    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", output_path], check=True
    )
    print(f"✅ {output_path} ({os.path.getsize(output_path) // 1024}KB)")


if __name__ == "__main__":
    img = create_icon_image()
    out_dir = os.path.join(os.path.dirname(__file__), "..", "Sources", "VlogPackApp")
    os.makedirs(out_dir, exist_ok=True)
    icns_path = os.path.join(out_dir, "AppIcon.icns")
    generate_icns(img, icns_path)
    img.save(os.path.join(out_dir, "AppIcon.png"))
    print(f"✅ Preview PNG saved")
