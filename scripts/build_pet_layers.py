import os
import numpy as np
from PIL import Image, ImageFilter

SRC_DIR = r"C:\Users\Crrea\.gemini\antigravity\brain\cd30241b-7ed0-4672-a538-e89df833248f"
OUT_DIR = r"c:\Users\Crrea\Documents\lumin\app\assets\pets"

SOURCES = {
    "dog_happy": "dog_happy_1794875490366.jpg",
    "dog_bark": "dog_bark_1794875511668.jpg",
    "dog_sad": "dog_sad_1794875533575.jpg",
    "dog_sleepy": "dog_sleepy_1794875557872.jpg",
    "cat_happy": "cat_happy_1794875588705.jpg",
    "cat_meow": "cat_meow_1794875618202.jpg",
    "cat_sad": "cat_sad_1794875647157.jpg",
    "cat_sleepy": "cat_sleepy_1794875680750.jpg",
}


def compute_background_field(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    top = np.median(rgb[0:20, :, :], axis=(0, 1))
    bottom = np.median(rgb[h - 20 : h, :, :], axis=(0, 1))
    y_weights = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None, None]
    bg = top[None, None, :] * (1.0 - y_weights) + bottom[None, None, :] * y_weights
    return np.broadcast_to(bg, (h, w, 3)).copy()


def extract_foreground_alpha(rgb: np.ndarray, bg: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    h, w, _ = rgb.shape
    diff = np.linalg.norm(rgb - bg, axis=2)

    yy, xx = np.mgrid[0:h, 0:w]
    in_collar_box = (
        (yy > int(h * 0.36))
        & (yy < int(h * 0.66))
        & (xx > int(w * 0.30))
        & (xx < int(w * 0.70))
    )

    low, high = 16.0, 42.0
    alpha = np.clip((diff - low) / (high - low), 0.0, 1.0)

    collar_protect = in_collar_box & (rgb[:, :, 2] < 148)
    alpha = np.where(collar_protect, 1.0, alpha)

    not_sky_blue = (rgb[:, :, 0] > rgb[:, :, 2] - 25) | (rgb[:, :, 2] < 120)
    alpha = np.where(not_sky_blue & (diff > 18.0), 1.0, alpha)

    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8), mode="L")
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=0.8))
    alpha = np.array(alpha_img, dtype=np.float32) / 255.0
    alpha = np.where(alpha < 0.05, 0.0, alpha)
    alpha = np.where(alpha > 0.96, 1.0, alpha)

    safe_alpha = np.maximum(alpha[:, :, None], 0.15)
    unmixed = (rgb - (1.0 - alpha[:, :, None]) * bg) / safe_alpha
    unmixed = np.clip(unmixed, 0.0, 255.0)
    fg_rgb = np.where(alpha[:, :, None] < 0.98, unmixed, rgb)

    return fg_rgb, alpha


def split_layers(fg_rgb: np.ndarray, alpha: np.ndarray, key: str, size: int = 512):
    h, w, _ = fg_rgb.shape
    r, g, b = fg_rgb[:, :, 0], fg_rgb[:, :, 1], fg_rgb[:, :, 2]
    yy, xx = np.mgrid[0:h, 0:w]
    yn = yy / float(h)
    xn = xx / float(w)

    max_c = np.maximum(np.maximum(r, g), b)
    min_c = np.minimum(np.minimum(r, g), b)
    sat = (max_c - min_c) / np.maximum(max_c, 1.0)
    lum = 0.299 * r + 0.587 * g + 0.114 * b

    # 1. COLEIRA AZUL + JOIA VERDE
    in_neck = (yn > 0.38) & (yn < 0.65) & (xn > 0.28) & (xn < 0.72)
    is_collar_blue = in_neck & (b > r + 15) & (b > g + 5)
    is_gem_green = in_neck & (g > r + 10) & (g > b + 4)
    collar_raw = (is_collar_blue | is_gem_green).astype(np.uint8) * 255
    collar_dilated = np.array(
        Image.fromarray(collar_raw, mode="L").filter(ImageFilter.MaxFilter(7)),
        dtype=np.float32,
    ) / 255.0
    is_metal_trim = (
        (collar_dilated > 0.5)
        & (sat < 0.15)
        & (lum > 75)
        & (lum < 190)
        & (yn < 0.63)
        & (xn > 0.45)
        & (xn < 0.55)
    )
    collar_bool = (is_collar_blue | is_gem_green | is_metal_trim) & (alpha > 0.05)

    # 2. DETALHES INTERNOS SEM PELAGEM:
    # Em vez de dilatar entre a sobrancelha e o olho, pegamos APENAS:
    # - O branco do olho (esclera) e o brilho especular na faixa yn: 0.20..0.29
    in_eye_balls = (
        (yn > 0.20)
        & (yn < 0.295)
        & ((np.abs(xn - 0.415) < 0.052) | (np.abs(xn - 0.585) < 0.052))
    )
    is_eye_white_or_pupil = in_eye_balls & (((sat < 0.20) & (lum > 145)) | (lum < 45))
    # Lágrimas azuis no cat_sad
    is_tear = (yn > 0.20) & (yn < 0.31) & (xn > 0.33) & (xn < 0.67) & (b > r + 12) & (b > 110)

    # - Boca aberta: semente SOMENTE na língua rosada/vermelha (r > g + 26), e fecha
    #   pequeno (MaxFilter 15 -> MinFilter 13) para cobrir os dentinhos colados na língua!
    in_mouth_zone = (yn > 0.28) & (yn < 0.44) & (xn > 0.37) & (xn < 0.63)
    is_tongue = in_mouth_zone & (r > g + 25) & (g < b + 24) & (r > 95)
    tongue_closed = (
        Image.fromarray((is_tongue.astype(np.uint8) * 255), mode="L")
        .filter(ImageFilter.MaxFilter(15))
        .filter(ImageFilter.MinFilter(11))
    )
    in_mouth_cavity = ((np.array(tongue_closed, dtype=np.float32) / 255.0) > 0.5) & (
        is_tongue | (lum < 75) | ((sat < 0.20) & (lum > 165))
    )

    # - Nariz rosado do gato
    is_cat_pink_nose = (
        key.startswith("cat")
        & (yn > 0.24)
        & (yn < 0.33)
        & (xn > 0.45)
        & (xn < 0.55)
        & (r > g + 22)
    )

    details_bool = (collar_bool | is_eye_white_or_pupil | is_tear | in_mouth_cavity | is_cat_pink_nose) & (alpha > 0.05)
    details_img = Image.fromarray((details_bool.astype(np.uint8) * 255), mode="L")
    details_img = details_img.filter(ImageFilter.GaussianBlur(radius=0.8))
    details_w = (np.array(details_img, dtype=np.float32) / 255.0) * alpha

    # 3. MÁSCARA DE PELAGEM PRIMÁRIA (manchas marrons do cão / laranja tigrado do gato)
    warmness = np.clip(((r - b) - 9.0) / 22.0, 0.0, 1.0) * np.clip((sat - 0.08) / 0.14, 0.0, 1.0)
    in_ear_tops = (yn < 0.28) & ((xn < 0.39) | (xn > 0.61)) & (alpha > 0.1)
    warmness = np.where(in_ear_tops, np.maximum(warmness, 0.90), warmness)

    coat1_w_raw = warmness * (1.0 - details_w * 0.98) * alpha
    coat1_img = Image.fromarray((coat1_w_raw * 255).astype(np.uint8), mode="L").filter(ImageFilter.GaussianBlur(radius=1.6))
    coat1_w = (np.array(coat1_img, dtype=np.float32) / 255.0) * alpha

    # 4. ALBEDO 3D UNIFICADO
    dark_feature_preserve = np.clip((lum - 35.0) / 45.0, 0.0, 1.0)
    lifted_warm_lum = np.clip(lum * 1.46 + 34.0 * dark_feature_preserve, 0.0, 250.0)
    white_lum = np.clip(lum * 1.02, 0.0, 250.0)

    unified_albedo = warmness * lifted_warm_lum + (1.0 - warmness) * white_lum
    albedo_rgb = np.stack([unified_albedo, unified_albedo, unified_albedo], axis=2)

    def make_rgba(rgb_arr: np.ndarray, a_arr: np.ndarray) -> Image.Image:
        out = np.zeros((h, w, 4), dtype=np.uint8)
        out[:, :, 0:3] = np.clip(rgb_arr, 0, 255).astype(np.uint8)
        out[:, :, 3] = np.clip(a_arr * 255.0, 0, 255).astype(np.uint8)
        pil = Image.fromarray(out, mode="RGBA")
        return pil.resize((size, size), Image.Resampling.LANCZOS)

    coat_base_pil = make_rgba(albedo_rgb, alpha)
    coat_patches_pil = make_rgba(albedo_rgb, coat1_w)
    details_pil = make_rgba(fg_rgb, details_w)

    return coat_base_pil, coat_patches_pil, details_pil


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for key, filename in SOURCES.items():
        src_path = os.path.join(SRC_DIR, filename)
        im = Image.open(src_path).convert("RGB")
        rgb = np.array(im, dtype=np.float32)
        bg = compute_background_field(rgb)
        fg_rgb, alpha = extract_foreground_alpha(rgb, bg)
        coat_base, coat_patches, details = split_layers(fg_rgb, alpha, key=key, size=512)

        coat_base.save(os.path.join(OUT_DIR, f"{key}_base.png"), optimize=True)
        coat_patches.save(os.path.join(OUT_DIR, f"{key}_patches.png"), optimize=True)
        details.save(os.path.join(OUT_DIR, f"{key}_details.png"), optimize=True)
        print(f"Processed {key}")


if __name__ == "__main__":
    main()
