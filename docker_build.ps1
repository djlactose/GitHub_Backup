#!/usr/bin/env pwsh
# Local build & push helper. CI (GitHub Actions) is the source of truth for
# published images; this script is for ad-hoc dev pushes.
$ErrorActionPreference = 'Stop'

$Image = 'djlactose/github_backup'

# Tag with the current git short SHA when available, plus :latest.
$Sha = $null
try { $Sha = (git rev-parse --short HEAD).Trim() } catch { $Sha = $null }

$Tags = @("${Image}:latest")
if ($Sha) { $Tags += "${Image}:$Sha" }

$BuildArgs = @('build')
foreach ($t in $Tags) { $BuildArgs += @('-t', $t) }
$BuildArgs += '.'

Write-Host "Building $($Tags -join ', ')..."
& docker @BuildArgs
if ($LASTEXITCODE -ne 0) {
    throw "docker build failed with exit code $LASTEXITCODE"
}

foreach ($t in $Tags) {
    Write-Host "Pushing $t..."
    & docker push $t
    if ($LASTEXITCODE -ne 0) {
        throw "docker push $t failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Done."
