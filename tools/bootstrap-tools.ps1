param(
    [string]$BinDir = (Join-Path $PSScriptRoot "bin"),
    [string]$ManifestPath = (Join-Path $PSScriptRoot "tool-manifest.json"),
    [string[]]$Tool = @(),
    [switch]$Force,
    [switch]$BestEffort
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-TargetName($tool) {
    if ($tool.PSObject.Properties.Name -contains "targetName" -and $tool.targetName) {
        return $tool.targetName
    }
    return $tool.exeName
}

function Get-ReleaseAsset($tool) {
    $releaseUri = "https://api.github.com/repos/$($tool.repo)/releases/latest"
    $release = Invoke-RestMethod -Uri $releaseUri -Headers @{ "User-Agent" = "window-env-config" }
    $asset = $release.assets | Where-Object { $_.name -match $tool.assetPattern } | Select-Object -First 1
    if (-not $asset) {
        throw "No release asset matched '$($tool.assetPattern)' for $($tool.name) from $releaseUri"
    }

    [pscustomobject]@{
        Version = $release.tag_name
        Asset = $asset
    }
}

function Save-Asset($asset, $destination) {
    Write-Host "Downloading $($asset.name)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $destination -Headers @{ "User-Agent" = "window-env-config" }
}

function Copy-MatchedExecutable($searchRoot, $pattern, $destination) {
    $match = Get-ChildItem -Path $searchRoot -Recurse -File -Filter $pattern | Select-Object -First 1
    if (-not $match) {
        throw "Executable pattern '$pattern' was not found under $searchRoot"
    }

    Copy-Item -Path $match.FullName -Destination $destination -Force
}

function Install-Tool($tool, $binDir) {
    $targetName = Get-TargetName $tool
    $targetPath = Join-Path $binDir $targetName

    if ((Test-Path $targetPath) -and -not $Force) {
        Write-Host "Already present: $targetName"
        return
    }

    $releaseAsset = Get-ReleaseAsset $tool
    $asset = $releaseAsset.Asset
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("window-env-config-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    try {
        $downloadPath = Join-Path $tempRoot $asset.name
        Save-Asset $asset $downloadPath

        if ($asset.name -like "*.zip") {
            $extractDir = Join-Path $tempRoot "extract"
            Expand-Archive -Path $downloadPath -DestinationPath $extractDir -Force
            Copy-MatchedExecutable $extractDir $tool.exeName $targetPath

            if ($tool.PSObject.Properties.Name -contains "extraExePatterns") {
                foreach ($extraPattern in $tool.extraExePatterns) {
                    Get-ChildItem -Path $extractDir -Recurse -File -Filter $extraPattern | ForEach-Object {
                        Copy-Item -Path $_.FullName -Destination (Join-Path $binDir $_.Name) -Force
                    }
                }
            }
        } else {
            Copy-Item -Path $downloadPath -Destination $targetPath -Force
        }

        Write-Host "Installed $($tool.name) $($releaseAsset.Version) -> $targetName"
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $ManifestPath)) {
    throw "Tool manifest not found: $ManifestPath"
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
$selectedTools = $manifest.tools
if ($Tool.Count -gt 0) {
    $selectedTools = $selectedTools | Where-Object { $Tool -contains $_.name }
}

foreach ($toolSpec in $selectedTools) {
    try {
        Install-Tool $toolSpec $BinDir
    } catch {
        if ($BestEffort) {
            Write-Warning $_.Exception.Message
        } else {
            throw
        }
    }
}
