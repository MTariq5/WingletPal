param(
    [Parameter(Mandatory = $true)][string]$QtRoot,
    [Parameter(Mandatory = $true)][string]$CompilerRoot,
    [Parameter(Mandatory = $true)][string]$OpenCvDir,
    [Parameter(Mandatory = $true)][string]$OpenCvSource,
    [Parameter(Mandatory = $true)][string]$InnoCompiler,
    [string]$CMake = 'cmake',
    [string]$Ninja = 'ninja'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $repoRoot 'build-release'
$packageRoot = Join-Path $buildDir ('package-' + [guid]::NewGuid().ToString('N'))
$payload = Join-Path $packageRoot 'app'
$qmlScan = Join-Path $packageRoot 'qml-source'
$qtSource = [IO.Path]::GetFullPath((Join-Path $QtRoot '../Src'))
$env:PATH = (Join-Path $QtRoot 'bin') + ';' + (Join-Path $CompilerRoot 'bin') + ';' + $env:PATH

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

foreach ($required in @($QtRoot, $CompilerRoot, $OpenCvDir, $OpenCvSource, $InnoCompiler, $qtSource)) {
    if (!(Test-Path -LiteralPath $required)) { throw "Missing prerequisite: $required" }
}

Invoke-Checked $CMake @('-S', $repoRoot, '-B', $buildDir, '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release', "-DCMAKE_PREFIX_PATH=$QtRoot",
    "-DCMAKE_CXX_COMPILER=$CompilerRoot/bin/g++.exe", "-DCMAKE_MAKE_PROGRAM=$Ninja",
    "-DOpenCV_DIR=$OpenCvDir")
Invoke-Checked $CMake @('--build', $buildDir, '--parallel', '6')
New-Item -ItemType Directory -Path $payload, $qmlScan -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $buildDir 'appAvionicsClock.exe') -Destination (Join-Path $payload 'WingletPal.exe')

# Scan only files included in the application module, never local tests or old builds.
$cmakeText = Get-Content -LiteralPath (Join-Path $repoRoot 'CMakeLists.txt') -Raw
$cmakeText = [regex]::Replace($cmakeText, '(?m)#.*$', '')
$qmlPaths = [regex]::Matches($cmakeText, '(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.qml') |
    ForEach-Object { $_.Value } | Sort-Object -Unique
foreach ($qmlPath in $qmlPaths) {
    $destination = Join-Path $qmlScan $qmlPath
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot $qmlPath) -Destination $destination
}
Invoke-Checked (Join-Path $QtRoot 'bin/windeployqt.exe') @('--release', '--compiler-runtime',
    '--qmldir', $qmlScan, '--skip-plugin-types', 'qmltooling,platforminputcontexts',
    '--include-plugins', 'qsvg,qtgeoservices_osm,qschannelbackend',
    (Join-Path $payload 'WingletPal.exe'))

Copy-Item -LiteralPath (Join-Path $repoRoot 'opensky.ini.example') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install-info.txt') -Destination $payload
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dependencies.txt') -Destination $payload
Set-Content -LiteralPath (Join-Path $payload 'qt.conf') -Value "[Paths]`nPrefix=.`nPlugins=.`nQmlImports=qml" -Encoding Ascii

# Include the license texts shipped with the dependency sources and installed Qt kit.
$licenseDir = Join-Path $payload 'licenses'
New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null
Copy-Item -Path (Join-Path $repoRoot 'licenses/*') -Destination $licenseDir -Recurse
Copy-Item -LiteralPath (Join-Path $qtSource 'LICENSES') -Destination (Join-Path $licenseDir 'Qt') -Recurse
Copy-Item -LiteralPath (Join-Path $OpenCvSource 'LICENSE') -Destination (Join-Path $licenseDir 'OpenCV-LICENSE.txt')
foreach ($runtime in @('gcc', 'mingw-w64', 'winpthreads')) {
    Copy-Item -LiteralPath (Join-Path $CompilerRoot "licenses/$runtime") -Destination (Join-Path $licenseDir "MinGW-$runtime") -Recurse
}
$qtModules = @('qtbase', 'qtdeclarative', 'qt5compat', 'qtimageformats', 'qtlocation',
    'qtpositioning', 'qtmultimedia', 'qtshadertools', 'qtsvg', 'qttranslations')
foreach ($module in $qtModules) {
    $moduleRoot = Join-Path $qtSource $module
    Get-ChildItem -LiteralPath $moduleRoot -Recurse -File |
        Where-Object { $_.Name -match '^(LICENSE|COPYING|COPYRIGHT|NOTICE|qt_attribution)' } |
        ForEach-Object {
            $relative = $_.FullName.Substring($moduleRoot.Length + 1)
            $destination = Join-Path $licenseDir "Qt/$module/$relative"
            New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $destination
        }
}
Get-ChildItem -LiteralPath (Join-Path $OpenCvSource '3rdparty') -Recurse -File |
    Where-Object { $_.Name -match '^(LICENSE|COPYING|COPYRIGHT|NOTICE)' } |
    ForEach-Object {
        $relative = $_.FullName.Substring($OpenCvSource.TrimEnd('/','\').Length + 1)
        $destination = Join-Path $licenseDir "OpenCV/$relative"
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }
if (Test-Path -LiteralPath (Join-Path $payload 'opensky.ini')) { throw 'Credentials must not be packaged' }

Invoke-Checked $InnoCompiler @("/DPackageDir=$payload", (Join-Path $PSScriptRoot 'WingletPal.iss'))
$installer = Join-Path $PSScriptRoot 'WingletPal-0.1.0-Windows-x64-Setup.exe'
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath ($installer + '.sha256') -Value "$hash  $([IO.Path]::GetFileName($installer))" -Encoding Ascii
Write-Output "Installer: $installer"
Write-Output "Payload: $payload"
