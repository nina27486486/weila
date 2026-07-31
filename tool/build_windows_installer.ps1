[CmdletBinding()]
param(
    [string]$ReleaseDirectory,
    [string]$OutputDirectory,
    [string]$InnoCompilerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$innoVersion = '7.0.2'
$innoInstallerName = "innosetup-$innoVersion-x64.exe"
$innoInstallerUri = 'https://github.com/jrsoftware/issrc/releases/download/is-7_0_2/innosetup-7.0.2-x64.exe'
$innoInstallerSha256 = '5AD54CA3DEF786F8F4212552E54CC6D8D61329E2D24A1CFEE0571D42C2684FF1'

function Get-WorkspaceVersion {
    param([Parameter(Mandatory = $true)][string]$Workspace)

    $match = Select-String `
        -Path (Join-Path $Workspace 'pubspec.yaml') `
        -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)'
    if ($null -eq $match -or $match.Matches.Count -ne 1) {
        throw 'Unable to read the application version from pubspec.yaml.'
    }
    return $match.Matches[0].Groups[1].Value
}

function Get-VerifiedInnoCompiler {
    param(
        [Parameter(Mandatory = $true)][string]$CacheDirectory,
        [string]$RequestedCompilerPath
    )

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($RequestedCompilerPath)) {
        $candidates += $RequestedCompilerPath
    }
    $candidates += @(
        (Join-Path $CacheDirectory 'compiler-7.0.2-x64\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }

    New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
    $installerPath = Join-Path $CacheDirectory $innoInstallerName
    if (Test-Path -LiteralPath $installerPath) {
        $cachedHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
        if ($cachedHash -ne $innoInstallerSha256) {
            Remove-Item -LiteralPath $installerPath -Force
        }
    }

    if (-not (Test-Path -LiteralPath $installerPath)) {
        $temporaryPath = "$installerPath.download"
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
        try {
            Write-Host "Downloading Inno Setup $innoVersion from the pinned official release..."
            & curl.exe `
                --location `
                --fail `
                --silent `
                --show-error `
                --retry 3 `
                --retry-delay 2 `
                --retry-all-errors `
                --connect-timeout 30 `
                --max-time 300 `
                --output $temporaryPath `
                $innoInstallerUri
            if ($LASTEXITCODE -ne 0) {
                throw "Inno Setup download failed with exit code $LASTEXITCODE."
            }
            $actualHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash
            if ($actualHash -ne $innoInstallerSha256) {
                throw "Inno Setup checksum mismatch. Actual SHA-256: $actualHash"
            }
            Move-Item -LiteralPath $temporaryPath -Destination $installerPath -Force
        } finally {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }
        }
    }

    $compilerDirectory = Join-Path $CacheDirectory 'compiler-7.0.2-x64'
    Write-Host "Installing the pinned Inno Setup compiler into the local build cache..."
    $arguments = @(
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CURRENTUSER',
        "/DIR=$compilerDirectory"
    )
    $process = Start-Process `
        -FilePath $installerPath `
        -ArgumentList $arguments `
        -Wait `
        -PassThru `
        -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        throw "Inno Setup bootstrap failed with exit code $($process.ExitCode)."
    }

    $compilerPath = Join-Path $compilerDirectory 'ISCC.exe'
    if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
        throw "Inno Setup compiler was not found after bootstrap: $compilerPath"
    }
    return $compilerPath
}

if ($env:OS -ne 'Windows_NT') {
    throw 'This script only supports Windows.'
}

$workspace = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$resolvedReleaseDirectory = if ([string]::IsNullOrWhiteSpace($ReleaseDirectory)) {
    Join-Path $workspace 'build\windows\x64\runner\Release'
} else {
    [IO.Path]::GetFullPath($ReleaseDirectory)
}
$resolvedOutputDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $workspace 'build\release'
} else {
    [IO.Path]::GetFullPath($OutputDirectory)
}

$applicationPath = Join-Path $resolvedReleaseDirectory 'weila.exe'
if (-not (Test-Path -LiteralPath $applicationPath -PathType Leaf)) {
    throw "Windows release is missing. Build it first: $applicationPath"
}

$cacheRoot = if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    Join-Path ([IO.Path]::GetTempPath()) 'weila\build-cache\inno-setup'
} else {
    Join-Path $env:LOCALAPPDATA 'weila\build-cache\inno-setup'
}
$compiler = Get-VerifiedInnoCompiler `
    -CacheDirectory $cacheRoot `
    -RequestedCompilerPath $InnoCompilerPath
$version = Get-WorkspaceVersion -Workspace $workspace
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$scriptPath = Join-Path $workspace 'installer\weila.iss'
& $compiler `
    "/DMyAppVersion=$version" `
    "/DSourceDir=$resolvedReleaseDirectory" `
    "/DOutputDir=$resolvedOutputDirectory" `
    $scriptPath
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

$installerPath = Join-Path `
    $resolvedOutputDirectory `
    "weila-$version-windows-x64-setup.exe"
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw "Expected installer was not created: $installerPath"
}

Write-Host "Windows installer created: $installerPath"
