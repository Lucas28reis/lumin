#!/usr/bin/env python3
"""
Utilitário do Agente Rive Pet Generator (`lumin_pets.riv` / `rive_pets/scene.rml`).

Comandos:
  1. `analyze --image <path> [--extract-rml]`
     Extrai a paleta de cores dominante (baseColor, patternColor, secondaryColor),
     proporções da silhueta (bounding box normalizada em canvas 500x500) e, com
     `--extract-rml`, gera contornos vetoriais `<PointsPath>` suavizados da foto.

  2. `pull`
     Faz `rive pull --yes` do Rive Online (`fileId: 2734785`) e reconecta
     automaticamente todos os vínculos `DataBindContext` e o `ViewModel "Fundo"`,
     removendo flags acidentais `isolated="true"` ou `visibleOverride="true"`.

  3. `build [--sync-cloud] [--message "..."]`
     Saneia `rive_pets/scene.rml`, valida com `rive . --verify`, gera screenshots
     headless de preview para `Artboard 1` (Cachorro) e `CatArtboard` (Gato),
     publica o binário assinado em `app/assets/pets/lumin_pets.riv` e opcionalmente
     faz `rive push`.
"""

import argparse
import math
import re
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT_DIR = Path(r"c:\Users\Crrea\Documents\lumin")
RIVE_DIR = ROOT_DIR / "rive_pets"
SCENE_RML = RIVE_DIR / "scene.rml"
RIVE_EXE = Path(r"C:\Users\Crrea\.rive\versions\1.9.2\rive.exe")

CANONICAL_DATABINDS: dict[str, str] = {
    # --- CACHORRO (Artboard 1) ---
    "8:100": '<DataBindContext sourcePathIds="1:14-8:9" propertyKey="18"/>',
    "2:168": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "2:157": '<DataBindContext sourcePathIds="1:14-8:18" propertyKey="18"/>',
    "2:161": '<DataBindContext sourcePathIds="1:14-8:17" propertyKey="17"/><DataBindContext sourcePathIds="1:14-8:16" propertyKey="16"/>',
    "2:147": '<DataBindContext sourcePathIds="1:14-8:18" propertyKey="18"/>',
    "2:135": '<DataBindContext sourcePathIds="1:14-8:17" propertyKey="17"/><DataBindContext sourcePathIds="1:14-8:16" propertyKey="16"/>',
    "2:182": '<DataBindContext sourcePathIds="1:14-8:6" propertyKey="18"/>',
    "2:185": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "1:182": '<DataBindContext sourcePathIds="1:14-8:12" propertyKey="15"/><DataBindContext sourcePathIds="1:14-8:11" propertyKey="17"/><DataBindContext sourcePathIds="1:14-8:10" propertyKey="16"/>',
    "1:230": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "1:191": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "1:210": '<DataBindContext sourcePathIds="1:14-8:8" propertyKey="17"/><DataBindContext sourcePathIds="1:14-8:7" propertyKey="16"/>',
    "1:213": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "11:12973": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "1:154": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "2:67": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "1:176": '<DataBindContext sourcePathIds="1:14-8:5" propertyKey="18"/>',
    "1:207": '<DataBindContext sourcePathIds="1:14-8:4" propertyKey="37"/>',
    "1:104": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "1:91": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "1:56": '<DataBindContext sourcePathIds="1:14-8:6" propertyKey="18"/>',
    "1:59": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "1:32": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "1:127": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    # --- GATO (CatArtboard) ---
    "5:300": '<DataBindContext sourcePathIds="1:14-8:19" propertyKey="18"/>',
    "5:169": '<DataBindContext sourcePathIds="1:14-8:7" propertyKey="16"/>',
    "5:157": '<DataBindContext sourcePathIds="1:14-8:18" propertyKey="18"/>',
    "5:161": '<DataBindContext sourcePathIds="1:14-8:17" propertyKey="17"/><DataBindContext sourcePathIds="1:14-8:16" propertyKey="16"/>',
    "5:147": '<DataBindContext sourcePathIds="1:14-8:18" propertyKey="18"/>',
    "5:135": '<DataBindContext sourcePathIds="1:14-8:17" propertyKey="17"/><DataBindContext sourcePathIds="1:14-8:16" propertyKey="16"/>',
    "5:182": '<DataBindContext sourcePathIds="1:14-8:15" propertyKey="15"/><DataBindContext sourcePathIds="1:14-8:14" propertyKey="17"/><DataBindContext sourcePathIds="1:14-8:13" propertyKey="16"/>',
    "5:230": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "7:220": '<DataBindContext sourcePathIds="1:14-8:6" propertyKey="18"/>',
    "7:249": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "7:260": '<DataBindContext sourcePathIds="1:14-8:8" propertyKey="17"/>',
    "7:270": '<DataBindContext sourcePathIds="1:14-8:3" propertyKey="37"/>',
    "5:191": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "5:266": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "7:424": '<DataBindContext sourcePathIds="1:14-8:6" propertyKey="18"/>',
    "7:441": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "7:452": '<DataBindContext sourcePathIds="1:14-8:3" propertyKey="37"/>',
    "7:464": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "7:486": '<DataBindContext sourcePathIds="1:14-8:3" propertyKey="37"/>',
    "5:1760": '<DataBindContext sourcePathIds="1:14-8:5" propertyKey="18"/>',
    "7:503": '<DataBindContext sourcePathIds="1:14-8:4" propertyKey="37"/>',
    "7:520": '<DataBindContext sourcePathIds="1:14-8:6" propertyKey="18"/>',
    "7:552": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "5:59": '<DataBindContext sourcePathIds="1:14-8:3" propertyKey="37"/>',
    "5:3200": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "7:602": '<DataBindContext sourcePathIds="1:14-8:6" propertyKey="18"/>',
    "7:614": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "7:624": '<DataBindContext sourcePathIds="1:14-8:3" propertyKey="37"/>',
    "7:635": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
    "7:715": '<DataBindContext sourcePathIds="1:14-8:6" propertyKey="18"/>',
    "7:747": '<DataBindContext sourcePathIds="1:14-8:2" propertyKey="37"/>',
    "7:758": '<DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>',
}

CANONICAL_VIEWMODEL_XML = """    <ViewModel defaultInstanceId="1:15" name="Fundo" id="1:14">
        <ViewModelPropertyColor name="baseColor" id="8:1"/>
        <ViewModelPropertyColor name="patternColor" id="8:2"/>
        <ViewModelPropertyColor name="secondaryColor" id="8:3"/>
        <ViewModelPropertyColor name="accessoryColor" id="8:4"/>
        <ViewModelPropertyNumber name="accessoryOpacity" id="8:5"/>
        <ViewModelPropertyNumber name="patternOpacity" id="8:6"/>
        <ViewModelPropertyNumber name="snoutScaleX" id="8:7"/>
        <ViewModelPropertyNumber name="snoutScaleY" id="8:8"/>
        <ViewModelPropertyNumber name="dogWhiskersOpacity" id="8:9"/>
        <ViewModelPropertyNumber name="dogEarScaleX" id="8:10"/>
        <ViewModelPropertyNumber name="dogEarScaleY" id="8:11"/>
        <ViewModelPropertyNumber name="dogEarRot" id="8:12"/>
        <ViewModelPropertyNumber name="catEarScaleX" id="8:13"/>
        <ViewModelPropertyNumber name="catEarScaleY" id="8:14"/>
        <ViewModelPropertyNumber name="catEarRot" id="8:15"/>
        <ViewModelPropertyNumber name="eyeScaleX" id="8:16"/>
        <ViewModelPropertyNumber name="eyeScaleY" id="8:17"/>
        <ViewModelPropertyNumber name="pupilOpacity" id="8:18"/>
        <ViewModelPropertyNumber name="catWhiskersOpacity" id="8:19"/>
        <ViewModelPropertyTrigger name="barkTrigger" id="8:20"/>
        <ViewModelInstance exports="true" name="DefaultInstance" id="1:15">
            <ViewModelInstanceColor propertyValue="FFDFC49D" viewModelPropertyId="8:1"/>
            <ViewModelInstanceColor propertyValue="FFC1A780" viewModelPropertyId="8:2"/>
            <ViewModelInstanceColor propertyValue="FFFDE3BA" viewModelPropertyId="8:3"/>
            <ViewModelInstanceColor propertyValue="FF589686" viewModelPropertyId="8:4"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:5"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:6"/>
            <ViewModelInstanceNumber propertyValue="1.1011559" viewModelPropertyId="8:7"/>
            <ViewModelInstanceNumber propertyValue="1.0668852" viewModelPropertyId="8:8"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="8:9"/>
            <ViewModelInstanceNumber propertyValue="1.097561" viewModelPropertyId="8:10"/>
            <ViewModelInstanceNumber propertyValue="1.6958541" viewModelPropertyId="8:11"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="8:12"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:13"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:14"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="8:15"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:16"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:17"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:18"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="8:19"/>
            <ViewModelInstanceTrigger viewModelPropertyId="8:20"/>
        </ViewModelInstance>
    </ViewModel>
</Rive>
"""


def sanitize_and_restore_databind(rml_path: Path = SCENE_RML) -> int:
    content = rml_path.read_text(encoding="utf-8")

    # 1. Remove flags de isolamento / solo
    content = content.replace(' isolated="true"', "").replace(' visibleOverride="true"', "")

    # 2. Corrige SolidColor auto-fechado antes de DataBindContext
    content = re.sub(
        r'(<SolidColor\b[^>]*?)\s*/>\s*(<DataBindContext\b[^>]*?propertyKey="37"[^>]*?/>)',
        r"\1>\2</SolidColor>",
        content,
    )

    # 3. Se ViewModel foi esvaziado por `rive pull`, restaura o ViewModel completo
    if "ViewModelPropertyColor" not in content:
        vm_idx = content.find('<ViewModel defaultInstanceId="1:15"')
        if vm_idx != -1:
            content = content[:vm_idx] + CANONICAL_VIEWMODEL_XML

    # 4. Garante que cada ID canônico possua seu DataBindContext se ainda não tiver
    restored = 0
    if content.count("<DataBindContext") < 40:
        out_lines = []
        for line in content.splitlines():
            m = re.search(r'id="([0-9]+:[0-9]+)"', line)
            if m and m.group(1) in CANONICAL_DATABINDS and "DataBindContext" not in line:
                el_id = m.group(1)
                dbs = CANONICAL_DATABINDS[el_id]
                if "<SolidColor" in line and "/>" in line:
                    line = line.replace("/>", f">{dbs}</SolidColor>", 1)
                    restored += 1
                elif ">" in line:
                    line = line.replace(">", f">{dbs}", 1)
                    restored += 1
            out_lines.append(line)
        content = "\n".join(out_lines) + "\n"

    rml_path.write_text(content, encoding="utf-8")
    return restored


def _trace_boundary(mask: np.ndarray) -> list[tuple[float, float]]:
    padded = np.pad(mask.astype(np.uint8), 1, mode="constant", constant_values=0)
    ys, xs = np.where(padded > 0)
    if len(xs) == 0:
        return []
    start_y, start_x = int(ys[0]), int(xs[0])
    dirs = [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)]
    contour = [(float(start_x - 1), float(start_y - 1))]
    cy, cx = start_y, start_x
    backtrack_dir = 6
    for _ in range(mask.size * 2):
        found = False
        for i in range(8):
            d = (backtrack_dir + 1 + i) % 8
            ny, nx = cy + dirs[d][0], cx + dirs[d][1]
            if padded[ny, nx] > 0:
                cy, cx = ny, nx
                backtrack_dir = (d + 4) % 8
                found = True
                break
        if not found or (cy == start_y and cx == start_x):
            break
        contour.append((float(cx - 1), float(cy - 1)))
    return contour


def _rdp(points: list[tuple[float, float]], eps: float) -> list[tuple[float, float]]:
    if len(points) < 3:
        return points
    x1, y1 = points[0]
    x2, y2 = points[-1]
    dx, dy = x2 - x1, y2 - y1
    lsq = dx * dx + dy * dy
    max_d, idx = -1.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        if lsq == 0:
            d = math.hypot(px - x1, py - y1)
        else:
            t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / lsq))
            d = math.hypot(px - (x1 + t * dx), py - (y1 + t * dy))
        if d > max_d:
            max_d, idx = d, i
    if max_d > eps:
        return _rdp(points[: idx + 1], eps)[:-1] + _rdp(points[idx:], eps)
    return [points[0], points[-1]]


def analyze_image(image_path: str, extract_rml: bool = False) -> None:
    im = Image.open(image_path).convert("RGBA")
    w, h = im.size
    arr = np.array(im, dtype=np.float32)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]

    border_pixels = np.concatenate(
        [rgb[0, :, :], rgb[h - 1, :, :], rgb[:, 0, :], rgb[:, w - 1, :]], axis=0
    )
    bg_color = np.median(border_pixels, axis=0)
    dist_bg = np.linalg.norm(rgb - bg_color[None, None, :], axis=2)
    fg_mask = (dist_bg > 24.0) & (alpha > 32)

    ys, xs = np.where(fg_mask)
    if len(xs) == 0:
        fg_mask = alpha > 32
        ys, xs = np.where(fg_mask)

    min_x, max_x = int(xs.min()), int(xs.max())
    min_y, max_y = int(ys.min()), int(ys.max())
    fg_w = max(1, max_x - min_x)
    fg_h = max(1, max_y - min_y)

    fg_pixels = rgb[fg_mask]
    lum = 0.299 * fg_pixels[:, 0] + 0.587 * fg_pixels[:, 1] + 0.114 * fg_pixels[:, 2]
    coat_pixels = fg_pixels[lum > 38.0]
    if len(coat_pixels) == 0:
        coat_pixels = fg_pixels

    quant = (coat_pixels // 24).astype(int)
    unique, counts = np.unique(quant, axis=0, return_counts=True)
    order = np.argsort(-counts)

    palette_hex = []
    for idx in order[:6]:
        q = unique[idx]
        mask_q = np.all(quant == q, axis=1)
        mean_rgb = coat_pixels[mask_q].mean(axis=0).astype(int)
        r_c, g_c, b_c = int(mean_rgb[0]), int(mean_rgb[1]), int(mean_rgb[2])
        hex_str = f"#{r_c:02X}{g_c:02X}{b_c:02X}"
        rive_hex = f"FF{r_c:02X}{g_c:02X}{b_c:02X}"
        pct = 100.0 * counts[idx] / len(coat_pixels)
        palette_hex.append((hex_str, rive_hex, pct))

    print(f"=== ANALISE DA FOTO PARA O RIVE ({w}x{h}) ===")
    print(f"Bounding Box do Pet: x=[{min_x}..{max_x}] ({fg_w}px), y=[{min_y}..{max_y}] ({fg_h}px)")
    print(f"Proporcao Altura/Largura: {fg_h / fg_w:.2f}")
    print("\nPaleta de Pelagem Extraida (Hex Flutter / RML colorValue):")
    labels = ["baseColor (8:1)", "patternColor (8:2)", "secondaryColor (8:3)", "extra1", "extra2", "extra3"]
    for i, (hx, rhx, pct) in enumerate(palette_hex):
        print(f"  - {labels[i]}: {hx}  (RML: colorValue=\"{rhx}\") [{pct:.1f}%]")

    if extract_rml:
        # Suaviza a máscara e mapeia a silhueta para o canvas Rive 500x500 (chão em y=440)
        mask_img = Image.fromarray((fg_mask.astype(np.uint8) * 255), mode="L").filter(
            ImageFilter.MedianFilter(5)
        )
        smooth_mask = np.array(mask_img) > 127
        contour = _trace_boundary(smooth_mask)
        if len(contour) >= 6:
            half = len(contour) // 2
            pts = _rdp(contour[: half + 1], 4.0)[:-1] + _rdp(contour[half:] + [contour[0]], 4.0)[:-1]
            target_h = 290.0
            scale = target_h / fg_h
            cx_fg = (min_x + max_x) * 0.5
            print("\n=== SILHUETA EXTRAIDA EM COORDENADAS 500x500 (Pés em y=440) ===")
            print('<PointsPath isClosed="true">')
            for px, py in pts:
                rx = 260.0 + (px - cx_fg) * scale
                ry = 440.0 - (max_y - py) * scale
                print(f'    <StraightVertex radius="12" x="{rx:.1f}" y="{ry:.1f}"/>')
            print("</PointsPath>")


def run_build(sync_cloud: bool = False, message: str = "Update pet shapes via Rive Pet Agent") -> None:
    restored = sanitize_and_restore_databind(SCENE_RML)
    print(f"[1/5] scene.rml higienizado (isolated removido, DataBinds verificados/restaurados: {restored})")

    subprocess.run([str(RIVE_EXE), str(RIVE_DIR), "--verify"], check=True)
    print("[2/5] rive --verify passou com 0 erros!")

    build_dir = RIVE_DIR / "build"
    build_dir.mkdir(exist_ok=True)
    dog_png = build_dir / "preview_dog.png"
    cat_png = build_dir / "preview_cat.png"
    subprocess.run(
        [str(RIVE_EXE), str(RIVE_DIR), f"--screenshot={dog_png}", "--artboard=Artboard 1", "--advance=1"],
        check=True,
    )
    subprocess.run(
        [str(RIVE_EXE), str(RIVE_DIR), f"--screenshot={cat_png}", "--artboard=CatArtboard", "--advance=1"],
        check=True,
    )
    print(f"[3/5] Screenshots salvos em:\n  - {dog_png}\n  - {cat_png}")

    subprocess.run([str(RIVE_EXE), str(RIVE_DIR), "--publish"], cwd=str(RIVE_DIR), check=True)
    print("[4/5] Publicado em app/assets/pets/lumin_pets.riv com sucesso!")

    if sync_cloud:
        subprocess.run(
            [str(RIVE_EXE), "push", "--yes", f"--name={message}"],
            cwd=str(RIVE_DIR),
            check=True,
        )
        print(f"[5/5] Sincronizado com o Rive Online: '{message}'")


def run_pull() -> None:
    subprocess.run([str(RIVE_EXE), "pull", "--yes"], cwd=str(RIVE_DIR), check=True)
    restored = sanitize_and_restore_databind(SCENE_RML)
    print(f"[Pull] Download do Rive Online concluido! DataBinds reconectados: {restored}")
    run_build(sync_cloud=False)


def main() -> None:
    parser = argparse.ArgumentParser(description="Rive Pet Generator Agent Helper")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_analyze = sub.add_parser("analyze")
    p_analyze.add_argument("--image", required=True, help="Caminho da foto/imagem de referência")
    p_analyze.add_argument("--extract-rml", action="store_true", help="Extrai PointsPath normalizado para 500x500")

    p_build = sub.add_parser("build")
    p_build.add_argument("--sync-cloud", action="store_true", help="Enviar tambem para o Rive Online")
    p_build.add_argument("--message", default="Update pet shapes via Rive Pet Agent")

    sub.add_parser("pull")

    args = parser.parse_args()
    if args.cmd == "analyze":
        analyze_image(args.image, extract_rml=args.extract_rml)
    elif args.cmd == "build":
        run_build(sync_cloud=args.sync_cloud, message=args.message)
    elif args.cmd == "pull":
        run_pull()


if __name__ == "__main__":
    main()
