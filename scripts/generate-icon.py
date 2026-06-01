#!/usr/bin/env python3
"""VlogPack icon v3 — modern flat, Apple-style."""
from PIL import Image, ImageDraw
import os, subprocess, tempfile

SIZE = 1024


def create():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── 背景：纯色 深靛蓝 ─────────────────────────
    draw.rounded_rectangle(
        [(0, 0), (SIZE - 1, SIZE - 1)],
        radius=228,
        fill=(30, 35, 80),
    )

    cx, cy = SIZE // 2, SIZE // 2 - 10

    # ── 播放按钮：纯白圆角方形 + 三角 ──────────────
    # 圆角方形背景（纯白，不透明）
    box = 340
    bx, by = cx - box // 2, cy - box // 2
    draw.rounded_rectangle(
        [(bx, by), (bx + box, by + box)],
        radius=72,
        fill=(255, 255, 255, 240),
    )

    # 三角形（深靛蓝，和背景呼应）
    tri_cx = cx + 22
    tri_cy = cy
    s = 110
    draw.polygon(
        [
            (tri_cx - s // 3, tri_cy - int(s * 0.577)),
            (tri_cx - s // 3, tri_cy + int(s * 0.577)),
            (tri_cx + s * 2 // 3, tri_cy),
        ],
        fill=(30, 35, 80),
    )

    # ── 底部小圆点（三个，表示多片段） ────────────
    dot_y = by + box + 60
    dot_r = 14
    for i, dx in enumerate([-50, 0, 50]):
        a = 180 if i == 1 else 100
        draw.ellipse(
            [(cx + dx - dot_r, dot_y - dot_r), (cx + dx + dot_r, dot_y + dot_r)],
            fill=(255, 255, 255, a),
        )

    # ── 外圈微光（极淡） ──────────────────────────
    for r in range(420, 380, -1):
        a = 4
        draw.ellipse(
            [(cx - r, cy - r), (cx + r, cy + r)],
            outline=(140, 160, 255, a),
            width=1,
        )

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
