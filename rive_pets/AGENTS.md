# AGENTS — Rive Pet Generator (`rive_pets`)

Este diretório contém o projeto Rive CLI dos avatares do **Lumin** ([scene.rml](./scene.rml) -> [../app/assets/pets/lumin_pets.riv](../app/assets/pets/lumin_pets.riv)).

Sempre que o usuário enviar uma **foto** ou pedir para **criar/modificar formas de cachorro ou gato**:
1. Leia e siga a skill [SKILL.md](../.agents/skills/rive-pet-generator/SKILL.md).
2. Use o utilitário [rive_pet_agent_helper.py](../scripts/rive_pet_agent_helper.py):
   - `python ..\scripts\rive_pet_agent_helper.py analyze --image "<FOTO>"` para extrair paleta Hex e proporções da foto.
   - `python ..\scripts\rive_pet_agent_helper.py pull` para baixar edições do Rive Online restaurando automaticamente os 55 vínculos `DataBindContext` do `ViewModel "Fundo"` e limpando `isolated="true"`.
   - `python ..\scripts\rive_pet_agent_helper.py build --sync-cloud` para higienizar o `scene.rml`, validar com `rive . --verify`, gerar screenshot de preview, publicar `../app/assets/pets/lumin_pets.riv` e sincronizar com o Rive Online.
