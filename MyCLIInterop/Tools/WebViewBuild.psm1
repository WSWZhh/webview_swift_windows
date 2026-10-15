Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path $PSScriptRoot -Parent

function Invoke-WebViewTool {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

function Initialize-WebViewToolchain {
    param([string]$VisualStudioPath)
    if (-not $VisualStudioPath) { $VisualStudioPath = $env:VSINSTALLDIR }
    if (-not $VisualStudioPath) {
        $vswhere = Get-Command vswhere.exe -ErrorAction SilentlyContinue
        $locator = if ($vswhere) { $vswhere.Source } else {
            Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        }
        if (Test-Path -LiteralPath $locator) {
            $VisualStudioPath = & $locator -latest -products '*' `
                -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        }
    }
    if (-not $VisualStudioPath) {
        throw 'Visual Studio C++ x64 tools not found. Install them or pass -VisualStudioPath.'
    }
    $devShell = Join-Path $VisualStudioPath 'Common7\Tools\Launch-VsDevShell.ps1'
    if (-not (Test-Path -LiteralPath $devShell)) { throw "Developer shell not found: $devShell" }
    & $devShell -Arch amd64 -HostArch amd64 -NoLogo -SkipAutomaticLocation
    $swift = Get-Command swiftc.exe -ErrorAction Stop
    $script:swiftCompiler = $swift.Source
    $script:cxxCompiler = Join-Path (Split-Path $swift.Source -Parent) 'clang++.exe'
    if (-not (Test-Path -LiteralPath $script:cxxCompiler)) {
        throw 'clang++.exe was not found beside swiftc.exe.'
    }
}

function New-WebViewLibrary {
    param([Parameter(Mandatory)][string]$OutputDirectory)
    $sdk = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Force $sdk | Out-Null
    $sdkTools = Join-Path $sdk 'Tools'
    New-Item -ItemType Directory -Force $sdkTools | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'WebViewBuild.psm1') -Destination $sdkTools -Force
    $headers = Join-Path $sdk 'Sources\WebViewBridge\include'
    New-Item -ItemType Directory -Force $headers | Out-Null
    Copy-Item -Path (Join-Path $packageRoot 'Sources\WebViewBridge\include\*') -Destination $headers -Force
    $vendor = Join-Path $sdk 'Vendor'
    New-Item -ItemType Directory -Force $vendor | Out-Null
    foreach ($dependency in @('webview', 'webview2')) {
        $destination = Join-Path $vendor $dependency
        New-Item -ItemType Directory -Force $destination | Out-Null
        Copy-Item -Path (Join-Path $packageRoot "Vendor\$dependency\*") -Destination $destination -Recurse -Force
    }
    $object = Join-Path $sdk 'WebViewBridge.obj'
    Invoke-WebViewTool $script:cxxCompiler @(
        '-std=c++17', '-fms-runtime-lib=dll', '-DWEBVIEW_STATIC', '-I', $headers,
        '-c', (Join-Path $packageRoot 'Sources\WebViewBridge\WebViewBridge.cpp'), '-o', $object
    )
    $sources = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'Sources\SwiftWebView') -Filter '*.swift' -Recurse | ForEach-Object FullName)
    # Swift's Windows static-library driver mishandles a quoted absolute -o path.
    Push-Location $sdk
    try {
    Invoke-WebViewTool $script:swiftCompiler (@(
        '-swift-version', '6', '-cxx-interoperability-mode=default',
        '-module-cache-path', (Join-Path (Split-Path $sdk -Parent) 'module-cache'),
        '-Xcc', '-fmodules', '-Xcc', '-fcxx-modules', '-Xcc', '-std=c++17',
        '-I', $headers, '-module-name', 'SwiftWebView', '-parse-as-library',
        '-emit-library', '-static', '-emit-module',
        '-emit-module-path', 'SwiftWebView.swiftmodule',
        '-o', 'SwiftWebView.lib'
    ) + $sources + @($object))
    } finally { Pop-Location }
    Write-Host "Library SDK: $sdk"
}

function New-WebViewApplication {
    param(
        [Parameter(Mandatory)][string]$LibraryDirectory,
        [Parameter(Mandatory)][string]$SourceDirectory,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [string]$ApplicationName = 'MyCLIInterop',
        [string]$ResourceDirectory
    )
    if ($ApplicationName -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        throw 'ApplicationName must be a Swift module identifier.'
    }
    $sdk = [IO.Path]::GetFullPath($LibraryDirectory)
    $output = [IO.Path]::GetFullPath($OutputDirectory)
    $source = (Resolve-Path -LiteralPath $SourceDirectory).Path
    $sources = @(Get-ChildItem -LiteralPath $source -Filter '*.swift' -Recurse | ForEach-Object FullName)
    if ($sources.Count -eq 0) { throw "No Swift sources found in $source" }
    New-Item -ItemType Directory -Force $output | Out-Null
    Invoke-WebViewTool $script:swiftCompiler (@(
        '-swift-version', '6', '-cxx-interoperability-mode=default',
        '-module-cache-path', (Join-Path $output 'module-cache'),
        '-Xcc', '-fmodules', '-Xcc', '-fcxx-modules', '-Xcc', '-std=c++17',
        '-I', $sdk, '-I', (Join-Path $sdk 'Sources\WebViewBridge\include'),
        '-module-name', $ApplicationName,
        '-o', (Join-Path $output "$ApplicationName.exe")
    ) + $sources + @(
        (Join-Path $sdk 'SwiftWebView.lib'),
        '-ladvapi32', '-lole32', '-lshell32', '-lshlwapi', '-luser32', '-lversion'
    ))
    if ($ResourceDirectory) {
        $resources = (Resolve-Path -LiteralPath $ResourceDirectory).Path
        if ($output -eq $resources -or $output.StartsWith($resources.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'OutputDirectory must not be inside ResourceDirectory.'
        }
        Get-ChildItem -LiteralPath $resources -Force | Copy-Item -Destination $output -Recurse -Force
    }
    Write-Host "Application: $output\$ApplicationName.exe"
}

Export-ModuleMember -Function Initialize-WebViewToolchain, New-WebViewLibrary, New-WebViewApplication
