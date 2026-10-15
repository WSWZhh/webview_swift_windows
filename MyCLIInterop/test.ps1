param([string]$VisualStudioPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Tools\WebViewBuild.psm1') -Force
Initialize-WebViewToolchain -VisualStudioPath $VisualStudioPath
# Deliberately build outside the package and without copying compiler caches.
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('SwiftWebView test ' + [guid]::NewGuid().ToString('N'))
$sdk = Join-Path $testRoot 'original\sdk'
New-WebViewLibrary -OutputDirectory $sdk
$relocated = Join-Path $testRoot 'relocated SDK'
Copy-Item -LiteralPath $sdk -Destination $relocated -Recurse
Import-Module (Join-Path $relocated 'Tools\WebViewBuild.psm1') -Force
Initialize-WebViewToolchain -VisualStudioPath $VisualStudioPath
$app = Join-Path $testRoot 'consumer'
New-WebViewApplication -LibraryDirectory $relocated `
    -SourceDirectory (Join-Path $PSScriptRoot 'Tests\PortableClient') `
    -OutputDirectory $app -ApplicationName PortableClient `
    -ResourceDirectory (Join-Path $PSScriptRoot 'Tests\PortableClient\Resources')
Push-Location $PSScriptRoot
try {
    & (Join-Path $app 'PortableClient.exe')
    if ($LASTEXITCODE -ne 0) { throw "Portable library checks failed: $LASTEXITCODE" }
} finally { Pop-Location }
Write-Host "Test artifacts: $testRoot"
