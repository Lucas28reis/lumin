import os
import math
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

IMG_PATH = r"C:/Users/Crrea/.gemini/antigravity/brain/cd30241b-7ed0-4672-a538-e89df833248f/.user_uploaded/media_1794952754836_cda26eea.png"
RML_OUT = r"c:\Users\Crrea\Documents\lumin\rive_pets\scene.rml"
DART_OUT = r"c:\Users\Crrea\Documents\lumin\app\lib\features\avatar\presentation\flat_pet_paths.dart"


def trace_boundary(mask: np.ndarray) -> list[tuple[float, float]]:
    padded = np.pad(mask.astype(np.uint8), 1, mode="constant", constant_values=0)
    ys, xs = np.where(padded > 0)
    if len(xs) == 0:
        return []

    start_y, start_x = int(ys[0]), int(xs[0])
    dirs = [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)]

    contour = [(float(start_x - 1), float(start_y - 1))]
    cy, cx = start_y, start_x
    backtrack_dir = 6

    max_steps = mask.size * 2
    for _ in range(max_steps):
        found = False
        for i in range(8):
            d = (backtrack_dir + 1 + i) % 8
            ny, nx = cy + dirs[d][0], cx + dirs[d][1]
            if padded[ny, nx] > 0:
                cy, cx = ny, nx
                backtrack_dir = (d + 4) % 8
                found = True
                break
        if not found:
            break
        if cy == start_y and cx == start_x:
            break
        contour.append((float(cx - 1), float(cy - 1)))

    return contour


def rdp_simplify(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    if len(points) < 3:
        return points

    x1, y1 = points[0]
    x2, y2 = points[-1]
    dx, dy = x2 - x1, y2 - y1
    length_sq = dx * dx + dy * dy

    max_dist = -1.0
    index = 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        if length_sq == 0:
            dist = math.hypot(px - x1, py - y1)
        else:
            t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / length_sq))
            proj_x = x1 + t * dx
            proj_y = y1 + t * dy
            dist = math.hypot(px - proj_x, py - proj_y)
        if dist > max_dist:
            max_dist = dist
            index = i

    if max_dist > epsilon:
        left = rdp_simplify(points[: index + 1], epsilon)
        right = rdp_simplify(points[index:], epsilon)
        return left[:-1] + right
    else:
        return [points[0], points[-1]]


def simplify_closed_contour(contour: list[tuple[float, float]], epsilon: float = 1.6) -> list[tuple[float, float]]:
    if len(contour) < 6:
        return contour
    n = len(contour)
    smoothed = []
    for i in range(n):
        sx = sum(contour[(i + k) % n][0] for k in range(-2, 3)) / 5.0
        sy = sum(contour[(i + k) % n][1] for k in range(-2, 3)) / 5.0
        smoothed.append((sx, sy))

    half = len(smoothed) // 2
    p1 = rdp_simplify(smoothed[: half + 1], epsilon)
    p2 = rdp_simplify(smoothed[half:] + [smoothed[0]], epsilon)
    pts = p1[:-1] + p2[:-1]

    area = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        area += x1 * y2 - x2 * y1
    if area < 0:
        pts.reverse()
    return pts


def connected_components(mask: np.ndarray, min_area: int = 25) -> list[np.ndarray]:
    h, w = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    comps = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not visited[y, x]:
                comp = np.zeros_like(mask, dtype=bool)
                stack = [(y, x)]
                visited[y, x] = True
                count = 0
                while stack:
                    cy, cx = stack.pop()
                    comp[cy, cx] = True
                    count += 1
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            if dy == 0 and dx == 0:
                                continue
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not visited[ny, nx]:
                                visited[ny, nx] = True
                                stack.append((ny, nx))
                if count >= min_area:
                    comps.append((count, comp))
    comps.sort(key=lambda item: item[0], reverse=True)
    return [c for _, c in comps]


def centroid_of(pts: list[tuple[float, float]]) -> tuple[float, float]:
    return (
        sum(p[0] for p in pts) / len(pts),
        sum(p[1] for p in pts) / len(pts),
    )


def extract_clean_shapes():
    im = Image.open(IMG_PATH).convert("RGB")
    crop = im.crop((160, 30, 800, 645))
    arr = np.array(crop, dtype=np.float32)
    h, w, _ = arr.shape
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    yy, xx = np.mgrid[0:h, 0:w]

    is_green = (g > r + 5) & (g > 70)
    is_terracotta = (r > 150) & (r < 232) & (g > 80) & (g < 152) & (~is_green)
    is_peach = (r >= 225) & (g >= 145) & (~is_green) & (~is_terracotta)
    colored = is_green | is_terracotta | is_peach

    col_pil = Image.fromarray((colored.astype(np.uint8) * 255), mode="L")
    closed_19 = np.array(col_pil.filter(ImageFilter.MaxFilter(21)).filter(ImageFilter.MinFilter(21))) > 128
    closed_45 = np.array(col_pil.filter(ImageFilter.MaxFilter(45)).filter(ImageFilter.MinFilter(45))) > 128

    near_7 = (np.array(col_pil.filter(ImageFilter.MaxFilter(13))) > 128) & (~colored)

    # Zonas exatas dos traços pretos da ilustração (evita qualquer artefato nas bordas externas!)
    in_face_features = (xx > 405) & (xx < 525) & (yy > 100) & (yy < 238) & closed_19 & (~colored)
    in_right_brow = (xx > 488) & (xx < 522) & (yy > 102) & (yy < 132) & near_7
    in_chin_shadow = (xx > 375) & (xx < 495) & (yy > 215) & (yy < 292) & closed_45 & (~colored)
    in_nose = (((xx - 522.0) / 22.0) ** 2 + ((yy - 174.0) / 19.0) ** 2 <= 1.0) & (~colored) & (yy > 152)
    in_ear_tip_outline = (xx > 265) & (xx < 388) & (yy > 215) & (yy < 312) & (
        (np.array(col_pil.filter(ImageFilter.MaxFilter(7))) > 128) & (~colored)
    )
    in_leg_strokes = (xx > 225) & (xx < 595) & (yy > 305) & (yy < 612) & closed_19 & (~colored)
    in_paw_tips = (xx > 350) & (xx < 592) & (yy > 530) & (yy < 612) & (
        (np.array(col_pil.filter(ImageFilter.MaxFilter(7))) > 128) & (~colored)
    )
    in_tail_fold = (xx > 100) & (xx < 172) & (yy > 365) & (yy < 498) & near_7

    black_features = (
        in_face_features
        | in_right_brow
        | in_chin_shadow
        | in_nose
        | in_ear_tip_outline
        | in_leg_strokes
        | in_paw_tips
        | in_tail_fold
    ) & (r < 60)

    # Corpo pêssego sólido (sem frestas sob manchas ou traços internos)
    solid_body_mask = is_peach | is_terracotta | (closed_19 & (~is_green))
    terra_padded = is_terracotta | (
        (np.array(Image.fromarray((is_terracotta.astype(np.uint8) * 255), mode="L").filter(ImageFilter.MaxFilter(5))) > 128)
        & black_features
    )

    body_comps = connected_components(solid_body_mask, min_area=500)
    terra_comps = connected_components(terra_padded, min_area=140)
    green_comps = connected_components(is_green, min_area=140)
    black_comps = connected_components(black_features, min_area=22)

    scale = 430.0 / max(w, h)
    off_x = (500.0 - w * scale) / 2.0
    off_y = (500.0 - h * scale) / 2.0 + 10.0

    def to_pts(comp, eps):
        raw = trace_boundary(comp)
        simp = simplify_closed_contour(raw, epsilon=eps)
        return [(round(x * scale + off_x, 1), round(y * scale + off_y, 1)) for x, y in simp]

    body_polys = [to_pts(c, 1.5) for c in body_comps]
    terra_polys = [to_pts(c, 1.4) for c in terra_comps]
    green_polys = [to_pts(c, 1.3) for c in green_comps]
    black_polys = [to_pts(c, 1.0) for c in black_comps]

    return body_polys, terra_polys, green_polys, black_polys


def build_rml_shape(
    name: str,
    shape_id: str,
    pts: list[tuple[float, float]],
    color_hex: str,
    bind_prop_id: str | None = None,
    corner_radius: float = 3.5,
) -> str:
    verts = "\n".join(
        f'                <StraightVertex x="{x}" y="{y}" radius="{corner_radius}"/>'
        for x, y in pts
    )
    bind_xml = (
        f'\n                    <DataBindContext sourcePathIds="0:40-{bind_prop_id}" propertyKey="37"/>'
        if bind_prop_id
        else ""
    )
    return f"""        <Shape x="0" y="0" name="{name}" id="{shape_id}">
            <PointsPath isClosed="true" isClockwise="true" name="{name}Path">
{verts}
            </PointsPath>
            <Fill name="{name}Fill">
                <SolidColor colorValue="{color_hex}" name="{name}Color">{bind_xml}
                </SolidColor>
            </Fill>
        </Shape>"""


def write_rml(body_polys, terra_polys, green_polys, black_polys):
    """
    Escreve o `rive_pets/scene.rml` na ordem de desenho do Rive (primeiro declarado pinta no topo!):
    1. Pointer Input Layer (topo, captura mouse/toque)
    2. Detalhes Pretos (Olhos dentro de EyesGazeRig, Nariz, Sorriso, Sobrancelhas, Linhas das pernas/orelha)
    3. Acessórios Verdes (Florzinha na cabeça + Coleira no pescoço -> vinculados a `accessoryColor` 0:58)
    4. Manchas Terracota (Orelha caída, Topete, Mancha do olho, Mancha do peito, Patinhas -> vinculadas a `patternColor` 0:45)
    5. Silhueta Base Pêssego (Corpo + Cabeça + Rabo -> vinculada a `baseColor` 0:44)
    """
    next_id = 200
    shapes_top_to_bottom = []

    # Separa olhos dos outros traços pretos para colocá-los no EyesGazeRig (que segue o mouse!)
    eye_shapes = []
    other_black_shapes = []

    for i, pts in enumerate(black_polys):
        if len(pts) < 3:
            continue
        cx, cy = centroid_of(pts)
        sid = f"0:{next_id}"
        next_id += 1
        # Os dois olhos estão em x ~ 335..405, y ~ 120..155 no espaço 500x500
        if 325 <= cx <= 410 and 118 <= cy <= 152 and len(pts) <= 18:
            # Coordenadas relativas ao centro do EyesGazeRig (368, 134)
            rel_pts = [(round(x - 368.0, 1), round(y - 134.0, 1)) for x, y in pts]
            eye_shapes.append(
                build_rml_shape(f"Eye_{i}", sid, rel_pts, "FF0D0D0D", None, corner_radius=4.0)
            )
        else:
            label = f"LineDetail_{i}"
            if cy < 120:
                label = f"Eyebrow_{i}"
            elif cx > 400 and cy < 175:
                label = "NoseTip"
            elif 320 <= cx <= 390 and 150 <= cy <= 190:
                label = "SmileLine"
            elif 300 <= cx <= 395 and 185 <= cy <= 240:
                label = "ChinShadow"
            other_black_shapes.append(
                build_rml_shape(label, sid, pts, "FF0D0D0D", None, corner_radius=2.5)
            )

    eyes_rig_xml = f"""        <Node x="368" y="134" name="EyesGazeRig" id="0:108">
            <DataBindContext sourcePathIds="0:40-0:54" propertyKey="13"/>
            <DataBindContext sourcePathIds="0:40-0:55" propertyKey="14"/>
{chr(10).join(eye_shapes)}
        </Node>"""

    green_shapes = []
    for i, pts in enumerate(green_polys):
        if len(pts) < 3:
            continue
        cx, cy = centroid_of(pts)
        sid = f"0:{next_id}"
        next_id += 1
        name = "FlowerAccessory" if cy < 150 else "CollarStrap"
        green_shapes.append(
            build_rml_shape(name, sid, pts, "FF5D8373", "0:58", corner_radius=4.0)
        )

    terra_shapes = []
    for i, pts in enumerate(terra_polys):
        if len(pts) < 3:
            continue
        cx, cy = centroid_of(pts)
        sid = f"0:{next_id}"
        next_id += 1
        if cy < 115:
            name = "HairWavePatch"
        elif 300 <= cx <= 375 and 115 <= cy <= 165:
            name = "EyeSpotPatch"
        elif cx < 315 and cy < 250:
            name = "FloppyEarPatch"
        elif 250 <= cy <= 400 and cx > 230:
            name = "ChestSpotPatch"
        elif cx < 230 and cy > 280:
            name = "BackSpotPatch"
        else:
            name = f"PawSpotPatch_{i}"
        terra_shapes.append(
            build_rml_shape(name, sid, pts, "FFCE7A6E", "0:45", corner_radius=4.5)
        )

    body_shapes = []
    for i, pts in enumerate(body_polys):
        if len(pts) < 3:
            continue
        sid = f"0:{next_id}"
        next_id += 1
        body_shapes.append(
            build_rml_shape(f"DogBodySilhouette_{i}", sid, pts, "FFFBB49A", "0:44", corner_radius=5.0)
        )

    all_dog_children = "\n".join(
        [eyes_rig_xml] + other_black_shapes + green_shapes + terra_shapes + body_shapes
    )

    rml = f"""<Rive version="1" kind="fragment">
    <!-- ===================================================================
         Lumin Pets — Vector Flat/Line-Art Dog (Exact match to reference art)
         Every region (Body, Ear, Hair Wave, Eye Spot, Chest Spot, Flower,
         Collar, Eyes, Eyebrows, Nose, Smile, and Line-Art Strokes) is an
         editable native Rive PointsPath Shape bound to the PetAvatar ViewModel!
         =================================================================== -->
    <Artboard defaultStateMachineId="0:7" viewModelId="0:40" viewModelInstanceId="0:41"
              clip="true" width="500" height="500" styleId="0:5" name="PetArtboard" id="0:2">
        <LayoutComponentStyle name="Artboard Style" id="0:5"/>

        <!-- Interactive Pointer Layer (captures cursor & click events) -->
        <LayoutComponent width="500" height="500" styleId="0:11" name="Pointer Input Layer" id="0:10">
            <LayoutComponentStyle layoutWidthScaleType="1" layoutHeightScaleType="1"
                                  widthUnitsValue="3" heightUnitsValue="3" name="Layout Style" id="0:11"/>
            <ScriptedLayout scriptAssetId="0:80" name="PointerTracker" id="0:12"/>
        </LayoutComponent>

        <!-- Root Pet Rig (anchored at ground y=445 for breathing & jump squash/stretch) -->
        <Node x="0" y="0" name="PetRootRig" id="0:140">
{all_dog_children}
        </Node>

        <!-- Soft Ground Shadow -->
        <Shape x="260" y="454" name="GroundShadow" id="0:20">
            <Ellipse width="320" height="24" originX="0.5" originY="0.5" name="ShadowPath"/>
            <Fill fillRule="clockwise" name="ShadowFill">
                <SolidColor colorValue="22000000" name="ShadowColor"/>
                <Feather strength="10" name="ShadowFeather"/>
            </Fill>
        </Shape>

        <StateMachine name="PetStateMachine" id="0:7">
            <StateMachineLayer name="IdleBreathingLayer" id="0:8">
                <AnyState x="200" y="-120"/>
                <ExitState x="400" y="-120"/>
                <EntryState x="40" y="0">
                    <StateTransition stateToId="0:15"/>
                </EntryState>
                <AnimationState x="220" y="0" animationId="0:6" id="0:15"/>
            </StateMachineLayer>

            <StateMachineLayer name="BarkActionLayer" id="0:9">
                <AnyState x="200" y="-120"/>
                <ExitState x="400" y="-120"/>
                <EntryState x="40" y="0">
                    <StateTransition stateToId="0:16"/>
                </EntryState>
                <AnimationState x="200" y="0" animationId="0:18" id="0:16">
                    <StateTransition stateToId="0:17" duration="100">
                        <TransitionViewModelCondition>
                            <TransitionPropertyViewModelComparator>
                                <BindablePropertyTrigger>
                                    <DataBindContext sourcePathIds="0:40-0:49" propertyKey="686"/>
                                </BindablePropertyTrigger>
                            </TransitionPropertyViewModelComparator>
                            <TransitionValueTriggerComparator/>
                        </TransitionViewModelCondition>
                    </StateTransition>
                </AnimationState>
                <AnimationState x="420" y="0" animationId="0:19" reset="true" id="0:17">
                    <StateTransition stateToId="0:16" duration="150"
                                     enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
            </StateMachineLayer>

            <StateMachineListenerSingle targetId="0:10" listenerTypeValue="click" name="TapPetToBark" id="0:21">
                <ListenerViewModelChange>
                    <BindablePropertyTrigger propertyValue="1">
                        <DataBindContext sourcePathIds="0:40-0:49" propertyKey="686" direction="true"/>
                    </BindablePropertyTrigger>
                </ListenerViewModelChange>
            </StateMachineListenerSingle>
        </StateMachine>

        <!-- Continuous Breathing Animation -->
        <LinearAnimation loopValue="loop" fps="60" duration="120" name="IdleBreathing" id="0:6">
            <KeyedObject objectId="0:140">
                <KeyedProperty property="y">
                    <KeyFrameDouble value="0" frame="0" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.42" y1="0" x2="0.58" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="-4" frame="60" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.42" y1="0" x2="0.58" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="0" frame="120"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>

        <LinearAnimation duration="30" name="RestPose" id="0:18">
            <KeyedObject objectId="0:140">
                <KeyedProperty property="y">
                    <KeyFrameDouble value="0" frame="0"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>

        <LinearAnimation duration="40" fps="60" name="BarkJump" id="0:19">
            <KeyedObject objectId="0:140">
                <KeyedProperty property="y">
                    <KeyFrameDouble value="0" frame="0"/>
                    <KeyFrameDouble value="-18" frame="12"/>
                    <KeyFrameDouble value="0" frame="26"/>
                    <KeyFrameDouble value="-10" frame="33"/>
                    <KeyFrameDouble value="0" frame="40"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>
    </Artboard>

    <ViewModel defaultInstanceId="0:41" name="PetAvatar" id="0:40">
        <ViewModelPropertyNumber name="species" id="0:42"/>
        <ViewModelPropertyNumber name="mood" id="0:43"/>
        <ViewModelPropertyColor name="baseColor" id="0:44"/>
        <ViewModelPropertyColor name="patternColor" id="0:45"/>
        <ViewModelPropertyNumber name="patternType" id="0:46"/>
        <ViewModelPropertyNumber name="earStyle" id="0:47"/>
        <ViewModelPropertyNumber name="snoutStyle" id="0:48"/>
        <ViewModelPropertyTrigger name="barkTrigger" id="0:49"/>
        <ViewModelPropertyNumber name="headX" id="0:50"/>
        <ViewModelPropertyNumber name="headY" id="0:51"/>
        <ViewModelPropertyNumber name="headRot" id="0:52"/>
        <ViewModelPropertyNumber name="tailRot" id="0:53"/>
        <ViewModelPropertyNumber name="eyeX" id="0:54"/>
        <ViewModelPropertyNumber name="eyeY" id="0:55"/>
        <ViewModelPropertyNumber name="eyeStyle" id="0:56"/>
        <ViewModelPropertyNumber name="accessoryType" id="0:57"/>
        <ViewModelPropertyColor name="accessoryColor" id="0:58"/>

        <ViewModelInstance exports="true" name="DefaultPet" id="0:41">
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="0:42"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="0:43"/>
            <ViewModelInstanceColor propertyValue="FFFBB49A" viewModelPropertyId="0:44"/>
            <ViewModelInstanceColor propertyValue="FFCE7A6E" viewModelPropertyId="0:45"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="0:46"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="0:47"/>
            <ViewModelInstanceNumber propertyValue="1" viewModelPropertyId="0:48"/>
            <ViewModelInstanceTrigger viewModelPropertyId="0:49"/>
            <ViewModelInstanceNumber propertyValue="250" viewModelPropertyId="0:50"/>
            <ViewModelInstanceNumber propertyValue="175" viewModelPropertyId="0:51"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="0:52"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="0:53"/>
            <ViewModelInstanceNumber propertyValue="368" viewModelPropertyId="0:54"/>
            <ViewModelInstanceNumber propertyValue="134" viewModelPropertyId="0:55"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="0:56"/>
            <ViewModelInstanceNumber propertyValue="0" viewModelPropertyId="0:57"/>
            <ViewModelInstanceColor propertyValue="FF5D8373" viewModelPropertyId="0:58"/>
        </ViewModelInstance>
    </ViewModel>

    <ScriptAsset file="pet_controller.luau" name="pet_controller" id="0:80"/>
</Rive>
"""
    with open(RML_OUT, "w", encoding="utf-8") as f:
        f.write(rml)
    print("Wrote RML to", RML_OUT)


def write_dart_paths(body_polys, terra_polys, green_polys, black_polys):
    def fmt_poly_list(polys):
        items = []
        for pts in polys:
            if len(pts) < 3:
                continue
            coords = ", ".join(f"{x}, {y}" for x, y in pts)
            items.append(f"  <double>[{coords}],")
        return "<List<double>>[\n" + "\n".join(items) + "\n]"

    dart_code = f"""// GENERATED FROM REFERENCE FLAT VECTOR ART — DO NOT EDIT BY HAND
abstract final class FlatPetVectorData {{
  static const List<List<double>> dogBodyPolys = {fmt_poly_list(body_polys)};
  static const List<List<double>> dogPatternPolys = {fmt_poly_list(terra_polys)};
  static const List<List<double>> dogAccessoryPolys = {fmt_poly_list(green_polys)};
  static const List<List<double>> dogStrokePolys = {fmt_poly_list(black_polys)};
}}
"""
    with open(DART_OUT, "w", encoding="utf-8") as f:
        f.write(dart_code)
    print("Wrote Dart vector paths to", DART_OUT)


def main():
    body_polys, terra_polys, green_polys, black_polys = extract_clean_shapes()
    print(
        f"Clean Polygons: body={len(body_polys)}, terra={len(terra_polys)}, green={len(green_polys)}, black={len(black_polys)}"
    )

    preview = Image.new("RGB", (500, 500), (255, 251, 245))
    draw = ImageDraw.Draw(preview)
    for pts in body_polys:
        if len(pts) >= 3:
            draw.polygon(pts, fill=(251, 180, 154))
    for pts in terra_polys:
        if len(pts) >= 3:
            draw.polygon(pts, fill=(206, 122, 110))
    for pts in green_polys:
        if len(pts) >= 3:
            draw.polygon(pts, fill=(93, 131, 115))
    for pts in black_polys:
        if len(pts) >= 3:
            draw.polygon(pts, fill=(12, 12, 12))

    preview.save(r"c:\Users\Crrea\Documents\lumin\scripts\vector_reconstruction_preview.png")
    write_rml(body_polys, terra_polys, green_polys, black_polys)
    write_dart_paths(body_polys, terra_polys, green_polys, black_polys)


if __name__ == "__main__":
    main()
