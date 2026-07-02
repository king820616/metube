$ErrorActionPreference = "Stop"

Set-Location (Resolve-Path "$PSScriptRoot\..\..")

$dirs = @(
    ".local\downloads",
    ".local\audio",
    ".local\state",
    ".local\temp",
    ".local\cookies"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
