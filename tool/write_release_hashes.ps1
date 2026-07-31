[CmdletBinding()]
param(
    [string]$ArtifactDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
$artifactNames = @(
    "weila-$version-windows-x64.zip",
    "weila-$version-windows-x64-setup.exe"
)

$lines = foreach ($name in $artifactNames) {
    $path = Join-Path $resolvedArtifactDirectory $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Release artifact is missing: $path"
    }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $name"
}

$hashPath = Join-Path $resolvedArtifactDirectory 'SHA256SUMS.txt'
[IO.File]::WriteAllLines($hashPath, $lines, [Text.UTF8Encoding]::new($false))
Write-Host "Release checksum manifest created: $hashPath"
