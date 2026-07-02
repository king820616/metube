$ErrorActionPreference = "Stop"

Set-Location (Resolve-Path "$PSScriptRoot\..\..")

function Find-Uv {
    $uvCommand = Get-Command uv -ErrorAction SilentlyContinue
    if ($null -ne $uvCommand) {
        return $uvCommand.Source
    }

    $userBase = (python -m site --user-base).Trim()
    $directPath = Join-Path $userBase "Scripts\uv.exe"
    if (Test-Path $directPath) {
        return $directPath
    }

    $found = Get-ChildItem -Path $userBase -Filter uv.exe -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $found) {
        return $found.FullName
    }

    return $null
}

$uvPath = Find-Uv
if ($null -eq $uvPath) {
    python -m pip install --user uv
    $uvPath = Find-Uv
}
if ($null -eq $uvPath) {
    throw "uv was installed, but uv.exe was not found. Add Python user Scripts to PATH or install uv manually."
}

& $uvPath @args
exit $LASTEXITCODE
