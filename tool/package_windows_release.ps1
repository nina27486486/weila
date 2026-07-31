[CmdletBinding()]
param(
    [string]$JunctionPath = "$env:SystemDrive\weila_build_src",
    [string]$InnoCompilerPath,
    [switch]$SkipClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$releaseArguments = @{
    JunctionPath = $JunctionPath
}
if ($SkipClean) {
    $releaseArguments.SkipClean = $true
}

& (Join-Path $PSScriptRoot 'build_windows_release.ps1') @releaseArguments
if ($LASTEXITCODE -ne 0) {
    throw "Windows release build failed with exit code $LASTEXITCODE."
}

$installerArguments = @{}
if (-not [string]::IsNullOrWhiteSpace($InnoCompilerPath)) {
    $installerArguments.InnoCompilerPath = $InnoCompilerPath
}
& (Join-Path $PSScriptRoot 'build_windows_installer.ps1') @installerArguments
if ($LASTEXITCODE -ne 0) {
    throw "Windows installer build failed with exit code $LASTEXITCODE."
}

& (Join-Path $PSScriptRoot 'write_release_hashes.ps1')
if ($LASTEXITCODE -ne 0) {
    throw "Release checksum generation failed with exit code $LASTEXITCODE."
}

Write-Host 'Windows release artifacts are ready in build\release.'
