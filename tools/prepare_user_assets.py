from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
MASCOT_DIR = ROOT / "assets" / "mascot"
SOURCE_DIR = ROOT / "assets" / "source"

IMAGE_1 = Path(r"C:\Users\wisteria\AppData\Local\Temp\codex-clipboard-3e0a4593-aa4d-4176-a8fd-2d254dcae7b1.png")
IMAGE_2 = Path(r"C:\Users\wisteria\AppData\Local\Temp\codex-clipboard-b179ab2a-96ae-491e-8e8e-4993d629d4eb.png")


def cover_crop(img: Image.Image, size: tuple[int, int], center_y: float = 0.55) -> Image.Image:
    src_w, src_h = img.size
    dst_w, dst_h = size
    src_ratio = src_w / src_h
    dst_ratio = dst_w / dst_h

    if src_ratio > dst_ratio:
        new_h = src_h
        new_w = round(src_h * dst_ratio)
        left = (src_w - new_w) // 2
        box = (left, 0, left + new_w, new_h)
    else:
        new_w = src_w
        new_h = round(src_w / dst_ratio)
        top = round((src_h - new_h) * center_y)
        top = max(0, min(src_h - new_h, top))
        box = (0, top, new_w, top + new_h)

    return img.crop(box).resize(size, Image.Resampling.LANCZOS)


def rounded_feather_mask(size: tuple[int, int], radius: int, feather: int) -> Image.Image:
    w, h = size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    inset = feather
    draw.rounded_rectangle((inset, inset, w - inset, h - inset), radius=radius, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(feather / 2))


def blend_edges(img: Image.Image, bg: tuple[int, int, int], radius: int = 34, feather: int = 22) -> Image.Image:
    img = img.convert("RGB")
    bg_img = Image.new("RGB", img.size, bg)
    mask = rounded_feather_mask(img.size, radius, feather)
    return Image.composite(img, bg_img, mask)


def soft_square(
    img: Image.Image,
    size: int,
    center_y: float,
    bg: tuple[int, int, int],
    enhance: bool = False,
) -> Image.Image:
    cropped = cover_crop(img, (size, size), center_y=center_y)
    if enhance:
        cropped = ImageOps.autocontrast(cropped, cutoff=0.5)
    return blend_edges(cropped, bg, radius=36, feather=20)


def soft_scene(img: Image.Image, center_y: float, bg: tuple[int, int, int]) -> Image.Image:
    scene = cover_crop(img, (560, 360), center_y=center_y)
    return blend_edges(scene, bg, radius=30, feather=24)


def soft_banner(
    img: Image.Image,
    size: tuple[int, int],
    center_y: float,
    bg: tuple[int, int, int],
) -> Image.Image:
    banner = cover_crop(img, size, center_y=center_y)
    return blend_edges(banner, bg, radius=26, feather=18)


def main() -> None:
    MASCOT_DIR.mkdir(parents=True, exist_ok=True)
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)

    img1 = Image.open(IMAGE_1).convert("RGB")
    img2 = Image.open(IMAGE_2).convert("RGB")

    img1.save(SOURCE_DIR / "user_scene_01.png")
    img2.save(SOURCE_DIR / "user_scene_02.png")

    cream = (255, 253, 247)
    mist_blue = (217, 238, 242)
    sky_blue = (209, 238, 249)
    mint = (173, 235, 171)
    pink = (247, 200, 216)
    yellow = (255, 247, 214)

    soft_square(img2, 180, 0.82, mist_blue).save(MASCOT_DIR / "idle.png")
    soft_square(img2, 180, 0.82, mint).save(MASCOT_DIR / "loading.png")
    soft_square(img2, 180, 0.82, yellow).save(MASCOT_DIR / "success.png")
    soft_square(img2, 180, 0.82, pink).save(MASCOT_DIR / "error.png")
    soft_square(img2, 180, 0.82, cream).save(MASCOT_DIR / "helper.png")
    soft_banner(img2, (520, 300), 1.00, mint).save(MASCOT_DIR / "left_corner.png")
    soft_banner(img1, (520, 300), 0.68, sky_blue).save(MASCOT_DIR / "right_corner_blue.png")

    soft_scene(img1, 0.62, cream).save(MASCOT_DIR / "preprocess_welcome.png")
    soft_scene(img2, 0.72, cream).save(MASCOT_DIR / "recognition_welcome.png")
    soft_scene(img1, 0.65, cream).save(MASCOT_DIR / "camera_welcome.png")
    soft_scene(img2, 0.75, cream).save(MASCOT_DIR / "result_welcome.png")


if __name__ == "__main__":
    main()
