# Lumin

Aplicativo Flutter para organizar os cuidados e a vida do pet, com avatar Rive.

Na Home, **Vida do pet** abre estoque de ração, consultas, medicamentos e relatório
compartilhável. O sino configura lembretes locais Android com imagem do avatar.
Saúde/estoque ainda são locais; tarefas diárias usam o backend quando configurado.

Detalhes e limitações: [Vida do pet](../docs/PET_LIFE.md).

```powershell
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
..\flutter\bin\flutter.bat pub get
..\flutter\bin\flutter.bat run
..\flutter\bin\flutter.bat analyze --no-pub
..\flutter\bin\flutter.bat test --no-pub
```

Backend: aplicar a migration de `../supabase/migrations` no projeto e fornecer
`--dart-define=SUPABASE_URL=...` e `--dart-define=SUPABASE_ANON_KEY=...`.
Ativar Auth anônima e configurar OAuth/retornos antes de usar convites e Google/Apple.
Nunca embutir `service_role`. O build Android exige SDK 37.

Notificações: [documentação do plugin](https://pub.dev/packages/flutter_local_notifications).

