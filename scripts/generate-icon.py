#!/usr/bin/env python3
"""Generate a macOS .icns icon for VlogPack."""
from PIL import Image, ImageDraw, ImageFont
import os, subprocess, tempfile

SIZE = 1024
CANVAS = (SIZE, SIZE)

def create_icon_image():
    img = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. 圆角矩形背景 — 模拟 macOS Big Sur 风格
    # 先画一个渐变色背景
    for y in range(SIZE):
        ratio = y / SIZE
        # 深蓝到青色渐变
        r = int(20 + ratio * 40)
        g = int(60 + ratio * 120)
        b = int(140 + ratio * 100)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

    # 2. 圆角蒙版
    mask = Image.new("L", CANVAS, 0)
    mask_draw = ImageDraw.Draw(mask)
    radius = 220  # macOS standard corner radius ~22.4% of 1024
    mask_draw.rounded_rectangle([(0, 0), (SIZE - 1, SIZE - 1)], radius=radius, fill=255)
    img.putalpha(mask)

    # 3. 半透明高光叠加（顶部）
    overlay = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ov_draw = ImageDraw.Draw(overlay)
    for y in range(SIZE // 2):
        alpha = int(40 * (1 - y / (SIZE // 2)))
        ov_draw.line([(0, y), (SIZE, y)], fill=(255, 255, 255, alpha))
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # 4. 中心元素 — 播放按钮 (三角形 + 圆形)
    cx, cy = SIZE // 2, SIZE // 2 - 30

    # 外圈 — 半透明白色
    outer_r = 280
    draw.ellipse(
        [(cx - outer_r, cy - outer_r), (cx + outer_r, cy + outer_r)],
        fill=(255, 255, 255, 30),
        outline=(255, 255, 255, 80),
        width=4,
    )

    # 内圈
    inner_r = 200
    draw.ellipse(
        [(cx - inner_r, cy - inner_r), (cx + inner_r, cy + inner_r)],
        fill=(255, 255, 255, 50),
        outline=(255, 255, 255, 120),
        width=3,
    )

    # 播放三角形
    triangle_offset = 40  # 稍微右移，视觉居中
    tx = cx + triangle_offset
    ty = cy
    tri_size = 140
    points = [
        (tx - tri_size // 2, ty - int(tri_size * 0.866 // 2)),  # 左上
        (tx - tri_size // 2, ty + int(tri_size * 0.866 // 2)),  # 左下
        (tx + tri_size // 2, ty),  # 右中
    ]
    draw.polygon(points, fill=(255, 255, 255, 230))

    # 5. 底部文字 "VP"
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", 160)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 160)
        except:
            font = ImageFont.load_default()

    text = "VP"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2
    ty = SIZE - 260
    draw.text((tx, ty), text, fill=(255, 255, 255, 200), font=font)

    # 6. 胶片齿孔装饰（左右两侧）
    hole_color = (255, 255, 255, 25)
    hole_r = 20
    for side_x in [80, SIZE - 80]:
        for i in range(5):
            hy = 200 + i * 140
            draw.rounded_rectangle(
                [(side_x - hole_r, hy - hole_r), (side_x + hole_r, hy + hole_r)],
                radius=8,
                fill=hole_color,
            )

    return img


def generate_icns(img, output_path):
    """Generate .icns file using iconutil."""
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
        ["iconutil", "-c", "icns", iconset_dir, "-o", output_path],
        check=True,
    )
    print(f"✅ Generated: {output_path} ({os.path.getsize(output_path) // 1024}KB)")


if __name__ == "__main__":
    img = create_icon_image()
    out_dir = os.path.join(os.path.dirname(__file__), "..", "Sources", "VlogPackApp")
    os.makedirs(out_dir, exist_ok=True)
    icns_path = os.path.join(out_dir, "AppIcon.icns")
    generate_icns(img, icns_path)
    # Also save a PNG preview
    img.save(os.path.join(out_dir, "AppIcon.png"))
    print(f"✅ Preview: {os.path.join(out_dir, 'AppIcon.png')}")
