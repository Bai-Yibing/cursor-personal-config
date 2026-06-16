# Windows: merge personal config into a local project .cursor/
param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$ConfigDir = Join-Path $env:USERPROFILE ".cursor\cursor-personal-config"
$ManifestPath = Join-Path $ConfigDir "sync-manifest.json"

if (-not (Test-Path $ManifestPath)) {
    throw "Clone repo first: git clone <repo_url> $ConfigDir"
}

if (Test-Path (Join-Path $ConfigDir ".git")) {
    Push-Location $ConfigDir
    git pull -q 2>$null
    Pop-Location
}

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$cursorDir = Join-Path $ProjectRoot ".cursor"
New-Item -ItemType Directory -Force -Path (Join-Path $cursorDir "rules"), (Join-Path $cursorDir "skills") | Out-Null

foreach ($rule in $manifest.rules) {
    $src = Join-Path $ConfigDir "rules\$rule"
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $cursorDir "rules\$rule") -Force
        Write-Host "  rule: $rule"
    }
}
foreach ($skill in $manifest.skills) {
    $src = Join-Path $ConfigDir "skills\$skill"
    $dst = Join-Path $cursorDir "skills\$skill"
    if (Test-Path $src) {
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Copy-Item $src $dst -Recurse -Force
        Write-Host "  skill: $skill"
    }
}

$meta = @{
    synced_at = (Get-Date -Format "o")
    source    = $ConfigDir
    mode      = "git"
    rules     = @($manifest.rules)
    skills    = @($manifest.skills)
} | ConvertTo-Json -Depth 5
Set-Content (Join-Path $cursorDir "global-sync-manifest.json") $meta -Encoding UTF8
Write-Host "Done -> $cursorDir"
