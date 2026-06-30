[CmdletBinding()]
param(
    [string]$JunctionPath = "$env:SystemDrive\weila_build_src",
    [switch]$SkipClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][object]$Path)

    $values = @($Path)
    if ($values.Count -ne 1) {
        throw "Expected one path value, received $($values.Count)."
    }

    return [IO.Path]::GetFullPath([string]$values[0]).TrimEnd('\')
}

function Invoke-Flutter {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter command failed: flutter $($Arguments -join ' ')"
    }
}

function Ensure-VerifiedArchive {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Sha256,
        [Parameter(Mandatory = $true)][string]$CacheDirectory,
        [Parameter(Mandatory = $true)][string]$SeedDirectory
    )

    New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
    $cachedArchive = Join-Path $CacheDirectory $Name
    $expectedHash = $Sha256.ToUpperInvariant()

    if (Test-Path -LiteralPath $cachedArchive) {
        $actualHash = (Get-FileHash -LiteralPath $cachedArchive -Algorithm SHA256).Hash
        if ($actualHash -eq $expectedHash) {
            Write-Host "Using verified build dependency: $Name"
            return $cachedArchive
        }

        Remove-Item -LiteralPath $cachedArchive -Force
    }

    $seedArchive = Join-Path $SeedDirectory $Name
    if (Test-Path -LiteralPath $seedArchive) {
        $seedHash = (Get-FileHash -LiteralPath $seedArchive -Algorithm SHA256).Hash
        if ($seedHash -eq $expectedHash) {
            Copy-Item -LiteralPath $seedArchive -Destination $cachedArchive -Force
            Write-Host "Seeded verified build dependency: $Name"
            return $cachedArchive
        }
    }

    $temporaryFile = [IO.Path]::GetTempFileName()
    try {
        Write-Host "Downloading and verifying build dependency: $Name"
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
            --output $temporaryFile `
            $Uri
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed for $Name with exit code $LASTEXITCODE."
        }
        $actualHash = (Get-FileHash -LiteralPath $temporaryFile -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) {
            throw "Checksum mismatch for $Name. Actual SHA-256: $actualHash"
        }

        Move-Item -LiteralPath $temporaryFile -Destination $cachedArchive -Force
        return $cachedArchive
    } finally {
        if (Test-Path -LiteralPath $temporaryFile) {
            Remove-Item -LiteralPath $temporaryFile -Force
        }
    }
}

function New-ReleasePackage {
    param(
        [Parameter(Mandatory = $true)][string]$Workspace,
        [Parameter(Mandatory = $true)][string]$ReleaseDirectory
    )

    foreach ($document in @('LICENSE', 'README.md', 'CHANGELOG.md')) {
        Copy-Item `
            -LiteralPath (Join-Path $Workspace $document) `
            -Destination (Join-Path $ReleaseDirectory $document) `
            -Force
    }

    $versionLine = Select-String `
        -Path (Join-Path $Workspace 'pubspec.yaml') `
        -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)'
    if ($null -eq $versionLine -or $versionLine.Matches.Count -ne 1) {
        throw 'Unable to read the application version from pubspec.yaml.'
    }

    $version = $versionLine.Matches[0].Groups[1].Value
    $packagePath = Join-Path `
        (Split-Path -Parent $ReleaseDirectory) `
        "weila-$version-windows-x64.zip"
    if (Test-Path -LiteralPath $packagePath) {
        Remove-Item -LiteralPath $packagePath -Force
    }

    Compress-Archive `
        -Path (Join-Path $ReleaseDirectory '*') `
        -DestinationPath $packagePath `
        -CompressionLevel Optimal
    return $packagePath
}

if ($env:OS -ne 'Windows_NT') {
    throw 'This script only supports Windows.'
}

$workspace = Get-NormalizedPath (Split-Path -Parent $PSScriptRoot)
$junction = Get-NormalizedPath $JunctionPath
if (Test-Path -LiteralPath $junction) {
    throw "Temporary build path already exists: $junction"
}

$localAppData = if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    [IO.Path]::GetTempPath()
} else {
    $env:LOCALAPPDATA
}
$dependencyCache = Join-Path $localAppData 'weila\build-cache'

$archives = @(
    @{
        Name = 'mpv-dev-x86_64-20230924-git-652a1dd.7z'
        Uri = 'https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z'
        Sha256 = 'DCE982222D7A23E4A1C6F0FB6CC39F6E899A6714624B95EA49CFF6558EE97572'
    },
    @{
        Name = 'ANGLE.7z'
        Uri = 'https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z'
        Sha256 = 'CC5911BB15D596FD5A2B362613AD35B7093B427117269A7359054A65746A5F9A'
    }
)

New-Item -ItemType Junction -Path $junction -Target $workspace | Out-Null

try {
    $link = Get-Item -LiteralPath $junction -Force
    $target = Get-NormalizedPath $link.Target
    if ($link.LinkType -ne 'Junction' -or
        -not ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $target -ne $workspace) {
        throw 'Temporary build junction verification failed.'
    }

    Set-Location $junction
    $seedDirectory = Join-Path $junction 'build\windows\x64'
    $verifiedArchives = @{}
    foreach ($archive in $archives) {
        $verifiedArchives[$archive.Name] = Ensure-VerifiedArchive `
            -Name $archive.Name `
            -Uri $archive.Uri `
            -Sha256 $archive.Sha256 `
            -CacheDirectory $dependencyCache `
            -SeedDirectory $seedDirectory
    }

    if (-not $SkipClean) {
        Invoke-Flutter @('clean')
    }
    Invoke-Flutter @('pub', 'get')

    $buildCache = Join-Path $junction 'build\windows\x64'
    New-Item -ItemType Directory -Force -Path $buildCache | Out-Null
    foreach ($archive in $archives) {
        Copy-Item -LiteralPath $verifiedArchives[$archive.Name] `
            -Destination (Join-Path $buildCache $archive.Name) `
            -Force
    }

    Invoke-Flutter @('build', 'windows', '--release', '--no-pub')

    $releaseDirectory = Join-Path $workspace 'build\windows\x64\runner\Release'
    $packagePath = New-ReleasePackage `
        -Workspace $workspace `
        -ReleaseDirectory $releaseDirectory
    Write-Host "Windows release build completed: $releaseDirectory"
    Write-Host "Windows release package created: $packagePath"
} finally {
    Set-Location $workspace
    if (Test-Path -LiteralPath $junction) {
        $link = Get-Item -LiteralPath $junction -Force
        $target = Get-NormalizedPath $link.Target
        if ($link.LinkType -eq 'Junction' -and
            ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
            $target -eq $workspace) {
            [IO.Directory]::Delete($junction)
        } else {
            Write-Warning "Temporary path changed and was not removed: $junction"
        }
    }
}
