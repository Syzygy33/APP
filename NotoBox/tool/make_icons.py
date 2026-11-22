"""从用户提供的方形图标生成 Android 启动图标资源。

处理逻辑：
1. 按实测圆角矩形边界生成蒙版，把框外的黑色留白与投影统一刷成白色，
   框内图案（含阴影）完整保留；
2. 生成各密度传统 ic_launcher.png（满幅白底）；
3. 生成自适应图标前景 ic_launcher_foreground.png（图案缩至 80% 居中，四周透明）。
"""
from PIL import Image, ImageDraw, ImageFilter
import os

SRC = r"C:\Users\Syzygy\.workbuddy\clipboard-images\clipboard-2026-11-21T07-24-48-769Z-1119099b.jpg"
RES = r"E:\Project\NotoBox\android\app\src\main\res"
ASSETS = r"E:\Project\NotoBox\assets\branding"

im = Image.open(SRC).convert("RGBA")
w, h = im.size

# 图块实测边界：x 75..1178, y 61..1181，圆角半径约 250px
TILE = (75, 61, 1178, 1181)
RADIUS = 250

mask = Image.new("L", (w, h), 0)
d = ImageDraw.Draw(mask)
# 略向内收 2px，连同边界描边一起去掉
d.rounded_rectangle(
    (TILE[0] + 8, TILE[1] + 8, TILE[2] - 8, TILE[3] - 8),
    radius=RADIUS,
    fill=255,
)
# 羽化边缘，避免生硬白边
mask = mask.filter(ImageFilter.GaussianBlur(6))

white = Image.new("RGBA", (w, h), (255, 255, 255, 255))
im = Image.composite(im, white, mask)

im.save(os.path.join(ASSETS, "app_icon_1024.png"))
master = im.convert("RGB")

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

for dens, size in DENSITIES.items():
    dpath = os.path.join(RES, f"mipmap-{dens}")
    os.makedirs(dpath, exist_ok=True)

    # 传统图标：满幅
    master.resize((size, size), Image.LANCZOS).save(
        os.path.join(dpath, "ic_launcher.png"), optimize=True
    )

    # 自适应前景：图案占 80%，四周透明，供系统遮罩裁切
    fs = FOREGROUND[dens]
    canvas = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
    inner = int(fs * 0.8)
    art = master.resize((inner, inner), Image.LANCZOS).convert("RGBA")
    off = (fs - inner) // 2
    canvas.paste(art, (off, off))
    canvas.save(os.path.join(dpath, "ic_launcher_foreground.png"), optimize=True)

print("done:", ", ".join(DENSITIES))
