param(
    [switch]$Run,
    [switch]$SmokeTest,
    [switch]$LibraryOnly,
    [string]$VisualStudioPath,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '.build-library'),
    [string]$SourceDirectory = (Join-Path $PSScriptRoot 'Sources\MyCLIInterop'),
    [string]$ResourceDirectory,
    [string]$ApplicationName = 'MyCLIInterop'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Tools\WebViewBuild.psm1') -Force
Initialize-WebViewToolchain -VisualStudioPath $VisualStudioPath
$output = [IO.Path]::GetFullPath($OutputDirectory)
$sdk = Join-Path $output 'sdk'
New-WebViewLibrary -OutputDirectory $sdk
if ($LibraryOnly) { return }

New-WebViewApplication -LibraryDirectory $sdk -SourceDirectory $SourceDirectory `
    -OutputDirectory $output -ApplicationName $ApplicationName -ResourceDirectory $ResourceDirectory
# Keep the existing example page editable in its original location.
if (-not $ResourceDirectory -and (Resolve-Path -LiteralPath $SourceDirectory).Path -eq (Join-Path $PSScriptRoot 'Sources\MyCLIInterop')) {
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Sources') -Filter '*.html' | Copy-Item -Destination $output -Force
}
if ($Run -or $SmokeTest) {
    $demoArguments = @()
    if ($SmokeTest) { $demoArguments += '--smoke-test' }
    & (Join-Path $output "$ApplicationName.exe") @demoArguments
    if ($LASTEXITCODE -ne 0) { throw "Application exited with code $LASTEXITCODE" }
}
