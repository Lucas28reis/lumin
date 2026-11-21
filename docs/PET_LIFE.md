# Vida do pet — direção e implementação

O Lumin organiza alimentação, estoque, consultas, medicamentos, próximos cuidados
e coordenação familiar. O avatar representa o vínculo com esse pet. Este documento
atualiza o escopo e o estado de implementação da SPEC_MVP v2.

## Disponível no código

- Home → **Vida do pet**: estoque de ração e histórico de saúde.
- Quantidade inicial em kg, gramas/refeição, refeições/dia, data inicial e
  antecedência do lembrete. Atualizar permite informar um novo saco ou corrigir
  o saldo real, sempre com a data correspondente.
- Projeção por dias de calendário, sem baixa adicional por toque em Alimentar.
  Exemplo: 20.000 g / (200 g × 2) = 50 dias. Após 35 dias completos: 6.000 g,
  30 refeições, 15 dias. O saldo não fica negativo. Não é uma medição real.
- Consultas: data, clínica/profissional/motivo, procedimentos/medicamentos em notas
  e próxima data opcional. Medicamentos: nome, data de administração, observações
  para dose prescrita e próxima data informada pelo tutor. Nenhuma dose é calculada.
- Edição e registro de retorno/nova administração preservam o registro anterior.
- Relatório textual compartilhável, ordenado por data. Não é laudo veterinário.
- Estoque e histórico salvos localmente por pet, inclusive após reabrir o app.
- Cuidados diários persistem localmente, com virada do dia e ofensiva simples.
  Com Supabase configurado, usam tarefas e registros reais, `log_care`, `undo_care`,
  `pet_streak`, Realtime e atualização periódica. Não há simulação de co-tutor.
- Conta vinculada só é reconhecida pela sessão autenticada; `linkIdentity` inicia
  a vinculação. Provedores OAuth e URLs de retorno precisam estar configurados.

## Lembretes

O sino na Home ativa/desativa notificações locais Android. A aceitação no
onboarding abre essa configuração; só a permissão do Android ativa os avisos.
A imagem é uma captura PNG do avatar personalizado com humor `worried`
(olhos e orelhas ajustados), pois a bandeja não reproduz animação Rive.

Até 3 lembretes/dia, entre 7h e 22h. A rotina é planejada para 14 dias e renovada
ao abrir o app; reposição e retornos futuros são agendados também além dessa janela.
Cuidados concluídos cancelam os respectivos avisos de hoje ao atualizar o plano.
Programações idênticas não são recriadas em cada atualização do backend.

Agendamento inexato, sem permissão de alarme exato: o Android pode atrasar a
entrega. Reinício, permissão e imagem ainda precisam ser validados em aparelho.
iOS/web não oferecem notificações do sistema nesta etapa.

Sem push, um cuidado marcado por outro tutor só cancela o aviso quando este
aparelho sincroniza. Para coordenação com o app fechado, implementar FCM/APNs
com validação dos registros no servidor, preferências, silêncio e deduplicação.

## Integrações ainda não ativadas

- Não há lojas parceiras; a interface informa isso. Faltam catálogo, vínculo da
  ração com SKU, preços/estoque e checkout do parceiro.
- Saúde e estoque **ainda são locais**, mesmo com Supabase. A sincronização atual
  cobre os cuidados diários existentes. A migração do histórico precisa de tabelas
  com RLS por família, controle de revisão e importação idempotente.
- No modo Supabase, cuidado precisa de confirmação online. Falhas não geram uma
  vitória falsa; fila offline durável para o modo compartilhado continua pendente.
- Congelamentos de ofensiva pertencem ao backend; a contagem local é simples.
- Google/Apple precisam de provedores e links de retorno configurados. Nenhuma
  integração foi validada contra um projeto Supabase remoto nesta entrega.

## Avatares e agentes

O app usa `rive_pets/scene.rml` compilado em `app/assets/pets/lumin_pets.riv`.
O helper resolve a raiz pelo próprio arquivo e aceita `RIVE_EXE` por variável de
ambiente. O mapa atual contém **65 vínculos**; o número 55 das instruções antigas
está desatualizado. A validação usa o mapa, não um limiar de contagem.

O helper restaura vínculos individuais ausentes/incorretos, falha se um destino
canônico desapareceu e gera previews dos dois artboards. Não executar
`--sync-cloud` apenas para testar. `--verify` e screenshots não publicam online.

## Verificação

```powershell
cd app
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
..\flutter\bin\flutter.bat pub get
..\flutter\bin\flutter.bat analyze --no-pub
..\flutter\bin\flutter.bat test --no-pub
```

Na raiz: `python -m unittest discover -s scripts -p test_rive_pet_agent_helper.py`.
Testes cobrem estoque após 35 dias, saldo zero, entradas inválidas, reabertura,
retorno preservando histórico, persistência dos cuidados, virada do dia,
silêncio/limite dos avisos, tela de celular e reparo parcial do rig.

Notificações usam `flutter_local_notifications` 23: Android compileSdk 37 e
desugaring já configurados. Falta Android SDK neste ambiente para compilar APK.
Os testes Windows usam o fallback quando `rive_native.dll` não está disponível;
isso não valida o desenho nativo. Rive `--verify` passou, mas a captura de previews
encerrou sem imagem neste ambiente. Nenhuma publicação no Rive Online foi feita.
