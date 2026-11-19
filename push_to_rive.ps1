# =============================================================================
# Script para autenticar e enviar o projeto `rive_pets` para a sua conta Rive
# e abri-lo direto no Rive Web Editor.
# =============================================================================
$ErrorActionPreference = "Stop"
$RiveExe = "C:\Users\Crrea\.rive\versions\1.9.2\rive.exe"
$ProjectDir = Join-Path $PSScriptRoot "rive_pets"

Write-Host "1. Verificando sessao da sua conta Rive..." -ForegroundColor Cyan
& $RiveExe whoami
if ($LASTEXITCODE -ne 0) {
    Write-Host "Abrindo login no navegador para vincular sua conta Rive..." -ForegroundColor Yellow
    & $RiveExe login
}

Write-Host "`n2. Validando a cena RML e o script Luau (rive --verify)..." -ForegroundColor Cyan
& $RiveExe $ProjectDir --verify

Write-Host "`n3. Enviando o projeto 'lumin_pets' para a sua conta Rive (rive push)..." -ForegroundColor Cyan
Write-Host "   (Use as setas para escolher o projeto/pasta na sua conta Rive e pressione Enter)" -ForegroundColor Gray
Set-Location $ProjectDir
& $RiveExe push

Write-Host "`n4. Compilando o arquivo .riv para o app Flutter (rive --publish)..." -ForegroundColor Cyan
& $RiveExe . --publish

Write-Host "`nPronto! O arquivo já está salvo na sua conta Rive (para abrir no Rive Editor web) e exportado para app/assets/pets/lumin_pets.riv!" -ForegroundColor Green
