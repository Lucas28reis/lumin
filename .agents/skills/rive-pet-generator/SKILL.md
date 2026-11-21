---
name: rive-pet-generator
description: >-
  Use esta skill sempre que o usuário pedir para criar, remodelar, adaptar ou
  gerar novas formas de cachorro ou gato no Rive (`rive_pets/scene.rml` e
  `app/assets/pets/lumin_pets.riv`) a partir de uma foto, imagem de referência
  ou solicitação textual, mantendo 100% da hierarquia rigada, animações
  (`IdleBreathing`, `BarkJump`, `State Machine 1`) e os 55 vínculos
  `DataBindContext` do ViewModel `Fundo`.
---

# Rive Pet Generator (Foto + Prompt -> RML Rigado & Compilado)

Esta skill transforma fotos ou ilustrações de referência + instruções do usuário em formas vetoriais `<PointsPath>` nativas do Rive dentro de `c:\Users\Crrea\Documents\lumin\rive_pets\scene.rml`, preservando a arquitetura rigada de `app/assets/pets/lumin_pets.riv` e aplicando padrões avançados de produção aprendidos de arquivos reais do Rive (`wienerwalk-reworked`, `mood-interaction`, `character_selection_menu`, `snake-raster-animation`, `character_customization_ui`).

Para receitas detalhadas de rigging, estados de humor (`Happy`/`Sad`/`Sleepy`/`BarkJump`), depth layering 2.5D, slots modulares (`Solo`) e tabelas de proporções por raça, consulte:
- [Biblioteca de Padrões Avançados Rive](./references/rive_patterns_library.md)

## 1. Arquitetura Obrigatória do `lumin_pets.riv` (`scene.rml`)

Todo animal gerado ou modificado **DEVE** respeitar a estrutura rigada abaixo para que as animações `IdleBreathing`, `BarkJump`, o script `pet_controller.luau` e o Flutter (`AvatarView`) funcionem sem quebrar:

### Artboards
- **`Artboard 1` (`id="1:2"`):** Cachorro (500×500, `viewModelId="1:14"`, `viewModelInstanceId="1:15"`, `defaultStateMachineId="1:7"`).
- **`CatArtboard` (`id="5:2"`):** Gato (500×500, `viewModelId="1:14"`, `viewModelInstanceId="1:15"`, `defaultStateMachineId="5:7"`).

### Hierarquia Anatômica (Nodes Animados)
Cada Artboard possui um pivô raiz `PetRootRing` (`x="260" y="440"`), que divide o pet em grupos anatômicos independentes:
1. **`HeadRig` (`id="1:177"` no cão / `id="5:177"` no gato):**
   - `DogWhiskers` (`id="8:100"`) / `Whiskers` (`id="5:300"`)
   - `Mouth` (`id="2:169"` / `id="5:169"`)
   - `Nose` (`id="1:181"` / `id="5:181"`)
   - `EyeSpot` (`id="1:179"` / `id="5:179"`): `PupilRight`, `EyeRigth`/`EyeRight`, `PupilLeft`, `EyeLeft` e mancha ocular opcional.
   - `EarRig` (`id="1:182"` / `id="5:182"`): orelhas articuladas com escala/rotação controlada pelo ViewModel.
   - `HeadBase` (`id="1:180"` / `id="5:178"`): crânio, focinho (`id="1:210"` / `MuzzleCreamPatch`), manchas/listras da cabeça e sombra do pescoço (`ShadeNeck`).
2. **`BackHand` (`id="1:157"` / `id="5:1570"`):** Pata/dedos traseiros em primeiro plano.
3. **`FrontHand` (`id="1:130"` / `id="6:130"`):** Patas/dedos dianteiros (`Left`, `Right` e linhas dos dedos).
4. **`BodyGroup` (`id="1:24"` / `id="5:24"`):**
   - `CollarStrap` (`id="1:176"` / `id="5:1760"`): coleira/bandana.
   - `BackLeg` (`id="1:101"`): coxa traseira dobrada (cão).
   - `FrontLeg` (`id="1:88"`): pernas dianteiras (`Left` e `Right`).
   - `TorsoOutline` / `TorsoBase 2`: contorno externo do tronco.
   - `ChestSpot` (`id="1:56"` / `id="5:56"`) e `BackTabbyStripes` (`id="7:520"`): manchas/listras recortadas (`ClippingShape`) pelo `TorsoBase`.
   - `TorsoBase` (`id="1:29"` / `id="5:29"`): preenchimento principal do tronco.
5. **`TailRing` (`id="1:110"` / `id="5:110"`):** Cauda animada com rotação em `IdleBreathing` e `BarkJump`.
6. **`GroundShadow` (`id="2:178"` / `id="5:1780"`):** Sombra elíptica no chão (`y="446"`).

---

## 2. Regras Críticas de RML & DataBind (NUNCA VIOLAR)

1. **`<DataBindContext>` de cor (`propertyKey="37"`) DEVE ficar DENTRO de `<SolidColor>`:**
   ```xml
   <Fill fillRule="clockwise" id="1:31">
       <SolidColor colorValue="FFDFC49D" id="1:32">
           <DataBindContext sourcePathIds="1:14-8:1" propertyKey="37"/>
       </SolidColor>
   </Fill>
   ```
2. **Bordas pretas (`Stroke` com `#FF0D0D0D`) NUNCA devem ter `DataBindContext` para `baseColor` (`8:1`)** e **NUNCA** devem ter `<TrimPath start="1"/>` sem `end` menor que `1`.
3. **Proibido `isolated="true"` ou `visibleOverride="true"`:** Sempre remova qualquer atributo `isolated="true"` ou `visibleOverride="true"` antes de compilar.
4. **Separação obrigatória:** Nunca coloque manchas/listras/bigodes no mesmo `Shape` da pelagem base; use `Shape` separado com `<ClippingShape>` apontando para o preenchimento base.

---

## 3. Fluxo Passo a Passo para Gerar/Adaptar Formas a Partir de Foto + Solicitação

### Passo 1: Analisar a Foto e Medir as Proporções Reais (OBRIGATÓRIO)
1. Leia a imagem enviada pelo usuário com `read_file` e execute:
   ```powershell
   python c:\Users\Crrea\Documents\lumin\scripts\rive_pet_agent_helper.py analyze --image "<CAMINHO_DA_FOTO>" --extract-rml
   ```
2. **Regra de Fidelidade Proporcional:** NUNCA force uma cabeça pequena em um corpo triangular genérico. Meça na imagem base:
   - A razão `largura / altura` total e a fração da altura ocupada pela **cabeça vs tronco** (ex.: no Pug a cabeça ocupa ~52% da altura e quase a mesma largura do corpo; no Dachshund o tronco é alongado horizontalmente).
   - O **encaixe cabeça-tronco**: se a raça na foto não tem pescoço fino/coleira visível, não deixe buraco preto (`ShadeNeck`) nem coleira flutuando; sobreponha cabeça e tronco com dobrinhas suaves.
   - **Contornos parciais (`isClosed="false"`):** pernas dianteiras e coxas traseiras integradas ao corpo devem usar preenchimento sem borda no topo e contorno preto apenas nas bordas externas/curvas abertas, como em ilustrações vetoriais profissionais.
3. Consulte [rive_patterns_library.md](./references/rive_patterns_library.md) para mapear o perfil da raça/foto.

### Passo 2: Construir ou Atualizar os `<PointsPath>` no `rive_pets/scene.rml`
- Use 6 a 14 vértices limpos por peça (`StraightVertex radius="..."` ou `CubicDetachedVertex`) respeitando o sistema de coordenadas:
  - **`Artboard 1` (Cachorro):** coordenadas locais relativas ao `Node` pai (`PetRootRing` em `260, 440`).
  - **`CatArtboard` (Gato):** coordenadas absolutas de tela `0..500 × 0..500` dentro dos nós `HeadSpace`, `BodySpace`, `TailSpace`, `FrontHand`, `BackHand`.

### Passo 3: Validar Integridade, Compilar e Inspecionar Visualmente (Cão + Gato)
Execute:
```powershell
python c:\Users\Crrea\Documents\lumin\scripts\rive_pet_agent_helper.py build --sync-cloud
```
- **Obrigatório:** Leia `rive_pets/build/preview_dog.png` e `rive_pets/build/preview_cat.png` com `read_file` para inspecionar visualmente bordas, proporções, olhos e patinhas antes de responder ao usuário!
