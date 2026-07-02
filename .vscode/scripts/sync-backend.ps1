$ErrorActionPreference = "Stop"

& "$PSScriptRoot\run-uv.ps1" sync --frozen --group dev
exit $LASTEXITCODE
