param([switch]$DepsOnly)
$ErrorActionPreference = 'Stop'

$root            = Resolve-Path "$PSScriptRoot\.."
$integrationDir  = Join-Path $root "integration_tests"

# Load env vars from .env
Get-Content (Join-Path $integrationDir ".env") |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } |
    ForEach-Object {
        $k, $v = $_ -split '=', 2
        [System.Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim(), 'Process')
    }

# Stage a clean copy of the root package WITHOUT integration_tests/.
# This breaks the recursive path dbt creates when copying ../  which includes
# integration_tests/packages.yml -> local ../ -> repeat -> WinError 206.
$stage = Join-Path $env:TEMP "dbt_cortex_agent_pkg"
Write-Host "Staging package to $stage ..."
if (Test-Path $stage) {
    $empty = New-Item -ItemType Directory -Force "$env:TEMP\empty_wipe"
    robocopy $empty $stage /MIR /NFL /NDL /NJH /NJS | Out-Null
    Remove-Item $stage -Recurse -Force
    Remove-Item $empty -Recurse -Force
}
robocopy $root $stage /E /XD integration_tests dbt_packages target .venv .git /NFL /NDL /NJH /NJS | Out-Null

# Temporarily patch packages.yml to point at the staged copy
$pkgFile  = Join-Path $integrationDir "packages.yml"
$original = Get-Content $pkgFile -Raw
$stagePath = $stage -replace '\\', '/'
$patched  = $original -replace [regex]::Escape('- local: ../'), "- local: $stagePath/"
Set-Content $pkgFile $patched -NoNewline

try {
    Push-Location $integrationDir
    Write-Host "Running dbt deps ..."
    dbt deps
    if (-not $DepsOnly) {
        Write-Host "Running dbt build ..."
        dbt build
    }
} finally {
    Pop-Location
    Set-Content $pkgFile $original -NoNewline
    Write-Host "packages.yml restored."
}
