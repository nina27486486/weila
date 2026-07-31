[CmdletBinding()]
param(
    [string]$ArtifactDirectory,
    [switch]$SkipLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CheckedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru `
        -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        throw "Process failed with exit code $($process.ExitCode): $FilePath"
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'This script only supports Windows.'
}

$workspace = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$resolvedArtifactDirectory = if ([string]::IsNullOrWhiteSpace($ArtifactDirectory)) {
    Join-Path $workspace 'build\release'
} else {
    [IO.Path]::GetFullPath($ArtifactDirectory)
}
$versionMatch = Select-String `
    -Path (Join-Path $workspace 'pubspec.yaml') `
    -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)'
if ($null -eq $versionMatch -or $versionMatch.Matches.Count -ne 1) {
    throw 'Unable to read the application version from pubspec.yaml.'
}
$version = $versionMatch.Matches[0].Groups[1].Value
$zipPath = Join-Path $resolvedArtifactDirectory "weila-$version-windows-x64.zip"
$installerPath = Join-Path `
    $resolvedArtifactDirectory `
    "weila-$version-windows-x64-setup.exe"
$hashPath = Join-Path $resolvedArtifactDirectory 'SHA256SUMS.txt'
foreach ($path in @($zipPath, $installerPath, $hashPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Release artifact is missing: $path"
    }
}

$expectedHashes = @{}
foreach ($line in Get-Content -LiteralPath $hashPath) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
        throw "Invalid SHA256SUMS.txt line: $line"
    }
    $expectedHashes[$Matches[2]] = $Matches[1].ToUpperInvariant()
}
foreach ($path in @($zipPath, $installerPath)) {
    $name = Split-Path -Leaf $path
    $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if (-not $expectedHashes.ContainsKey($name) -or
        $expectedHashes[$name] -ne $actualHash) {
        throw "Checksum validation failed: $name"
    }
}

$temporaryRoot = Join-Path `
    ([IO.Path]::GetTempPath()) `
    "weila-package-smoke-$([guid]::NewGuid().ToString('N'))"
$expandedZip = Join-Path $temporaryRoot 'zip'
$installDirectory = Join-Path $temporaryRoot 'installed'
$roamingSentinel = Join-Path $env:APPDATA 'Weila\installer-smoke.keep'
$localSentinel = Join-Path $env:LOCALAPPDATA 'Weila\installer-smoke.keep'
$credentialTarget = "Weila/InstallerSmoke-$([guid]::NewGuid().ToString('N'))"

$existingInstall = Get-ItemProperty `
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.PSChildName -like '*18B8E9C7-F74B-413A-AE3E-6A002938FF67*'
    } |
    Select-Object -First 1
if ($null -ne $existingInstall) {
    throw 'A per-user Weila installation already exists; refusing to mutate it during smoke testing.'
}

try {
    New-Item -ItemType Directory -Force -Path $expandedZip | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $expandedZip
    foreach ($relativePath in @(
        'weila.exe',
        'flutter_windows.dll',
        'data\icudtl.dat',
        'data\flutter_assets\AssetManifest.bin'
    )) {
        $path = Join-Path $expandedZip $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Portable package content is missing: $relativePath"
        }
    }

    foreach ($sentinel in @($roamingSentinel, $localSentinel)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sentinel) |
            Out-Null
        Set-Content -LiteralPath $sentinel -Value 'keep' -NoNewline
    }
    & cmdkey.exe "/generic:$credentialTarget" '/user:smoke' '/pass:keep'
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create the Credential Manager smoke sentinel.'
    }

    Invoke-CheckedProcess `
        -FilePath $installerPath `
        -Arguments @(
            '/VERYSILENT',
            '/SUPPRESSMSGBOXES',
            '/NORESTART',
            '/CURRENTUSER',
            "/DIR=$installDirectory"
        )

    $installedExecutable = Join-Path $installDirectory 'weila.exe'
    if (-not (Test-Path -LiteralPath $installedExecutable -PathType Leaf)) {
        throw 'Silent install did not create weila.exe.'
    }

    if (-not $SkipLaunch) {
        $application = Start-Process `
            -FilePath $installedExecutable `
            -WorkingDirectory $installDirectory `
            -PassThru `
            -WindowStyle Hidden
        Start-Sleep -Seconds 5
        if ($application.HasExited) {
            throw "Installed application exited during startup with code $($application.ExitCode)."
        }
        Stop-Process -Id $application.Id -Force
        $application.WaitForExit()
    }

    $uninstaller = Join-Path $installDirectory 'unins000.exe'
    if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
        throw 'Silent install did not create the uninstaller.'
    }
    Invoke-CheckedProcess `
        -FilePath $uninstaller `
        -Arguments @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')

    if (Test-Path -LiteralPath $installedExecutable) {
        throw 'Silent uninstall did not remove the application executable.'
    }
    foreach ($sentinel in @($roamingSentinel, $localSentinel)) {
        if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
            throw "Uninstall removed a user-data sentinel: $sentinel"
        }
    }
    $credentialList = (& cmdkey.exe '/list') -join "`n"
    if ($credentialList -notmatch [regex]::Escape($credentialTarget)) {
        throw 'Uninstall removed the Credential Manager sentinel.'
    }

    Write-Host 'Windows ZIP, silent install, launch, uninstall, and data-retention smoke tests passed.'
} finally {
    & cmdkey.exe "/delete:$credentialTarget" | Out-Null
    foreach ($sentinel in @($roamingSentinel, $localSentinel)) {
        if (Test-Path -LiteralPath $sentinel) {
            Remove-Item -LiteralPath $sentinel -Force
        }
    }
    if (Test-Path -LiteralPath $temporaryRoot) {
        $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
        $resolvedSystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTemporaryRoot.StartsWith(
            $resolvedSystemTemp,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to clean an unexpected smoke-test path: $resolvedTemporaryRoot"
        }
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
    }
}
