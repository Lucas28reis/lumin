# Biblioteca de Padrões Avançados Rive (Extraída dos 5 `.riv` de Referência)

Esta referência consolida os padrões reais de produção extraídos dos arquivos analisados (`wienerwalk-reworked.riv`, `mood-interaction.riv`, `character_selection_menu.riv`, `snake-raster-animation.riv` e `character_customization_ui.riv`) para guiar a criação de avatares de cachorro e gato de alta qualidade no `scene.rml`.

---

## 1. Customização Modular por ViewModel (`wienerwalk-reworked.riv` + `character_customization_ui.riv`)

Em vez de criar um Artboard novo por estilo, use **um único Artboard rigado** com **grupos/slots modulares** controlados pelo `ViewModel`:
- **Padrão `active*` (ex.: `activeHat`, `activeGlasses`, `activeNose`, `ativeBody`, `ears`, `snout`, `accessory`):**
  - Use `<Solo>` quando houver variantes mutuamente exclusivas (ex.: 3 formatos de orelha ou 3 tipos de acessório: coleira, bandana, lacinho), vinculando `activeChildIndex` via `<DataBindContext>`.
  - Ou use `opacity` (`propertyKey="18"`) nos `Node`/`Shape` de detalhe (`DogWhiskers`, `ChestSpot`, `CollarStrap`, `HeadTabbyStripes`) para ligar/desligar camadas em tempo real.
- **Regra de OURO:** Nunca misture camadas estruturais (corpo, contorno preto) com camadas opcionais (manchas, bigodes, listras) no mesmo `Shape`. Separe sempre em:
  1. `...Fill` (preenchimento base ligado a `baseColor` `1:14-8:1`)
  2. `...Pattern / ...Stripes / ...Spot` (com `<ClippingShape sourceId="...Fill"/>` e ligado a `patternColor` `1:14-8:2` + `patternOpacity` `1:14-8:6`)
  3. `...Outline` (apenas `<Stroke>` preto `#FF0D0D0D`, **sem** DataBind de cor e **sem** `TrimPath` quebrado)

---

## 2. Expressões de Humor & Transições Orgânicas (`mood-interaction.riv`)

Avatares vivos não ficam apenas respirando — eles reagem com **antecipação + overshoot (bounce) + squash & stretch**:
- **Estados de Humor recomendados na `StateMachine` (`State Machine 1`):**
  - `IdleBreathing` (loop contínuo: respiração suave `scaleY: 1.0 -> 1.04`, abano de cauda `rotation: -0.14 -> +0.28`, leve balanço da cabeça `rotation: 0 -> -0.10`).
  - `Happy` / `BarkJump` (duração ~40 frames: agacha nos frames 0–6 `scaleX: 1.06, scaleY: 0.92` antes de pular, estica no ar no frame 16 `y: -28, scaleX: 0.95, scaleY: 1.06`, aterrissa com squash no frame 28 e estabiliza no frame 40).
  - `Sad` (orelhas caídas/rotacionadas para baixo, `HeadRig` inclinado `y: +6, rotation: +0.08`, olhos levemente comprimidos).
  - `Sleepy` (`eyeScaleY: 0.15` para simular pálpebra fechada, respiração mais lenta e profunda).
- **Interpoladores (`CubicInterpolator`):** Evite `interpolationType="linear"` em saltos e orelhas; prefira curvas ease-out / overshoot para dar peso e elasticidade de desenho animado.

---

## 3. Depth Layering 2.5D (`snake-raster-animation.riv` + `character_selection_menu.riv`)

Para evitar que chapéus, orelhas ou óculos "vazem" ou fiquem errados quando a cabeça inclina:
- Separe acessórios e orelhas atrás/frente da cabeça na árvore de renderização (lembrando que no Rive **os primeiros filhos desenham POR CIMA dos últimos filhos**):
  1. **Primeiro (na frente):** Olhos + Pupilas + Sobrancelhas (`EyeSpot`, `Eyebrow`) → Focinho/Nariz/Boca (`Nose`, `Mouth`, `Whiskers`) → Acessório Frontal (`HatFront`, `GlassesFront`, `CollarStrap`)
  2. **Meio:** Manchas da cabeça (`EyeSpot`, `HeadTabbyStripes`, `MuzzleCreamPatch`) → Cabeça (`HeadBaseFill`, `HeadOutline`)
  3. **Atrás (por último):** Orelha Traseira / `HatBack` → Corpo (`BodyGroup`) → Cauda (`TailRing`) → Sombra no chão (`GroundShadow`).
- **Camada de Sombra Facial (`character_selection_menu.riv`):** Adicionar um `Shape` sutil abaixo das sobrancelhas ou no pescoço (`ShadeNeck`) com opacidade suave (`#26000000` ou tom mais escuro da pelagem) dá profundidade imediata sem poluir o estilo Flat.

---

## 4. Eye-Tracking & Sobrancelhas Expressivas (`character_selection_menu.riv` + `pet_controller.luau`)

- Mantenha `EyeLeft` / `EyeRight` separados de `PupilLeft` / `PupilRight` e de um `Node` `Eyebrow` (opcional) para que:
  - As pupilas possam deslizar suavemente com o ponteiro (`pet_controller.luau` via `pointerMove` ou `Joystick`);
  - O estilo de olho (`round`, `sparkle`, `almond`) escale apenas a íris/olho (`eyeScaleX`/`eyeScaleY`), mantendo a pupila nítida.

---

## 5. Adaptação de Silhuetas por Foto / Raça (Proporções no Canvas 500×500)

Ao adaptar o cachorro ou gato para uma **foto real** enviada pelo usuário, ajuste os `PointsPath` e os pivôs mantendo os pés apoiados na linha base (`y ≈ 440`):

| Perfil / Raça na Foto | Cabeça (`HeadRig`) | Focinho (`Snout`) | Orelhas (`EarRig`) | Tronco (`TorsoBase`) | Cauda (`TailRing`) |
|---|---|---|---|---|---|
| **Salsicha / Dachshund** (`wienerwalk`) | Alongada, `x` levemente à frente | Longo e afilado para a direita | Caídas médias/longas, ponta arredondada | Baixo e comprido horizontalmente | Fina, longa e levemente erguida |
| **Pug / Buldogue / Persa** | Grande e larga (`rx/ry` quase 1:1) | Curto, largo e achatado, bochechas caídas | Pequenas caídas em triângulo (cão) ou baixas/pequenas (gato) | Robusto, peito largo, pescoço curto | Curta e enrolada (cão) / grossa felpuda (gato) |
| **Husky / Pastor / Shiba** | Triangular/angulosa com bochechas marcadas | Médio-longo afilado | Pontudas altas e eretas (`y` acima do topo da cabeça) | Atlético, peito destacado (`ChestSpot` peludo) | Grossa e curvada para cima (espessa) |
| **Poodle / Bichon / Peludo** | Contorno com vários vértices curvos ("nuvem"/fofo) | Médio coberto por pelo fofo | Caídas fofas com borda ondulada | Arredondado e macio | Pompom arredondado ou curva fofa |
| **Gato Siamês / Esguio** | Cabeça mais triangular, olhos amendoados | Fino e delicado | Grandes e pontudas inclinadas para fora | Esguio, pernas dianteiras longas | Longa, fina em S |

---

## 6. Qualidade das Curvas Vetoriais (`<PointsPath>`)

- **Nunca gere polígonos serrilhados com dezenas de vértices retos sem `radius`.**
- Para traços orgânicos e limpos (estilo ilustração profissional):
  - Use **6 a 14 vértices por peça** (`StraightVertex radius="10..35"` para cantos suaves ou `CubicDetachedVertex` para curvas assimétricas de focinho, orelha e cauda).
  - Sempre feche formas preenchidas (`isClosed="true"`) e deixe abertos (`isClosed="false"`) apenas traços internos como dedinhos, boca, bigodes e linhas de contorno parciais (`TrimPath`).
  - Quando usar o comando `analyze --extract-rml` do helper, utilize os `<PointsPath>` extraídos da foto como **base exata de proporção e silhueta**, refinando os pontos de controle para manter o traço limpo e integrado aos nós rigados (`HeadRig`, `BodyGroup`, `TailRing`).
