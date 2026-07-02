$ErrorActionPreference = "Stop"

Set-Location (Resolve-Path "$PSScriptRoot\..\..\ui")

$ProjectRoot = Resolve-Path "$PSScriptRoot\..\.."
$NodeVersion = "v24.15.0"
$NodeFolderName = "node-$NodeVersion-win-x64"
$ProjectNodeDir = Join-Path $ProjectRoot ".local\node\$NodeFolderName"
$ProjectNodeExe = Join-Path $ProjectNodeDir "node.exe"

function Test-NodeVersion {
    param([string] $NodeExe)

    if (-not (Test-Path $NodeExe)) {
        return $false
    }

    $rawVersion = (& $NodeExe --version).Trim()
    if ($rawVersion -notmatch '^v(\d+)\.(\d+)\.(\d+)$') {
        return $false
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]

    if ($major -gt 26) {
        return $true
    }
    if ($major -eq 26) {
        return $true
    }
    if ($major -eq 24) {
        return ($minor -gt 15) -or ($minor -eq 15 -and $patch -ge 0)
    }
    if ($major -eq 22) {
        return ($minor -gt 22) -or ($minor -eq 22 -and $patch -ge 3)
    }
    return $false
}

function Install-ProjectNode {
    if (Test-NodeVersion $ProjectNodeExe) {
        return
    }

    $nodeRoot = Split-Path $ProjectNodeDir -Parent
    New-Item -ItemType Directory -Force -Path $nodeRoot | Out-Null
    $zipPath = Join-Path $nodeRoot "$NodeFolderName.zip"
    $url = "https://nodejs.org/dist/$NodeVersion/$NodeFolderName.zip"

    Invoke-WebRequest -Uri $url -OutFile $zipPath
    if (Test-Path $ProjectNodeDir) {
        Remove-Item -Recurse -Force $ProjectNodeDir
    }
    Expand-Archive -Path $zipPath -DestinationPath $nodeRoot -Force
    Remove-Item -Force $zipPath
}

function Find-NodeDir {
    if (Test-NodeVersion $ProjectNodeExe) {
        return $ProjectNodeDir
    }

    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($null -ne $nodeCommand -and (Test-NodeVersion $nodeCommand.Source)) {
        return Split-Path $nodeCommand.Source -Parent
    }

    $runtimeNode = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
    if (Test-NodeVersion $runtimeNode) {
        return Split-Path $runtimeNode -Parent
    }

    $found = Get-ChildItem -Path (Join-Path $env:USERPROFILE ".cache\codex-runtimes") -Filter node.exe -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Test-NodeVersion $_.FullName } |
        Select-Object -First 1
    if ($null -ne $found) {
        return Split-Path $found.FullName -Parent
    }

    Install-ProjectNode
    if (Test-NodeVersion $ProjectNodeExe) {
        return $ProjectNodeDir
    }

    return $null
}

function Find-Pnpm {
    $pnpmCommand = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($null -ne $pnpmCommand) {
        return $pnpmCommand.Source
    }

    $runtimePnpm = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\bin\pnpm.cmd"
    if (Test-Path $runtimePnpm) {
        return $runtimePnpm
    }

    $found = Get-ChildItem -Path (Join-Path $env:USERPROFILE ".cache\codex-runtimes") -Filter pnpm.cmd -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $found) {
        return $found.FullName
    }

    return $null
}

$nodeDir = Find-NodeDir
if ($null -eq $nodeDir) {
    throw "node.exe was not found. Install Node.js LTS, restart VS Code, and run the task again."
}

$env:PATH = "$nodeDir;$env:PATH"

$pnpmPath = Find-Pnpm
if ($null -eq $pnpmPath) {
    $corepack = Get-Command corepack -ErrorAction SilentlyContinue
    if ($null -eq $corepack) {
        throw "pnpm/corepack was not found. Install Node.js LTS, restart VS Code, and run the task again."
    }
    & $corepack.Source enable
    $pnpmPath = (Get-Command pnpm -ErrorAction Stop).Source
}

& $pnpmPath @args
exit $LASTEXITCODE
