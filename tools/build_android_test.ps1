param(
    [string]$EnginePath,
    [string]$AndroidSdkPath = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$JavaPath = 'C:\Program Files\Java\jdk-17',
    [string]$DebugKeystore = "$env:APPDATA\Godot\keystores\debug.keystore",
    [string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $EnginePath){$EnginePath=Join-Path $projectRoot 'Godot_v4.7.2-stable_win64.exe'}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $projectRoot 'export\android'}
$versionMatch=[regex]::Match((Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw -Encoding UTF8),'config/version="([^"]+)"')
if(-not $versionMatch.Success){throw 'Project version is missing'}
$version=$versionMatch.Groups[1].Value
$buildRoot=Join-Path $projectRoot '.godot\android-build'
New-Item -ItemType Directory -Force -Path $buildRoot,$OutputDirectory | Out-Null
$unsigned=Join-Path $buildRoot ('convoy-v'+$version+'-arm64-unsigned.apk')
$signed=Join-Path $OutputDirectory ('convoy-v'+$version+'-arm64-test.apk')
function Invoke-Godot([string[]]$EngineArguments,[string]$LogName) {
    $log=Join-Path $buildRoot ($LogName+'.log')
    $arguments=@('--headless','--path',('"'+$projectRoot+'"'))+$EngineArguments+@('--log-file',('"'+$log+'"'))
    $process=Start-Process -FilePath $EnginePath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    $text=Get-Content -LiteralPath $log -Raw -Encoding UTF8
    if($process.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR|Parse Error|ERROR: (?!No project icon specified)'){
        throw ('Godot failed; inspect '+$log)
    }
}
Invoke-Godot @('--editor','--import') 'import'
Invoke-Godot @('--export-release','"Android APK"',('"'+$unsigned+'"')) 'export'
& python (Join-Path $PSScriptRoot 'check_android_apk.py') $unsigned --project $projectRoot --output (Join-Path $buildRoot 'apk-resources.json')
if($LASTEXITCODE -ne 0){throw 'APK resource validation failed; no signed package produced'}
if(-not (Test-Path -LiteralPath $DebugKeystore)){throw 'Local Android debug keystore is missing'}
$buildTools=Get-ChildItem -LiteralPath (Join-Path $AndroidSdkPath 'build-tools') -Directory |
    Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat')} |
    Sort-Object { [version]($_.Name -replace '-.*$','') } -Descending | Select-Object -First 1
if(-not $buildTools){throw 'Android apksigner is missing'}
$env:JAVA_HOME=$JavaPath
$signer=Join-Path $buildTools.FullName 'apksigner.bat'
& $signer sign --ks $DebugKeystore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $signed $unsigned
if($LASTEXITCODE -ne 0){throw 'Test signing failed'}
& $signer verify --verbose $signed
if($LASTEXITCODE -ne 0){throw 'APK signature verification failed'}
& python (Join-Path $PSScriptRoot 'check_android_apk.py') $signed --project $projectRoot --output (Join-Path $buildRoot 'signed-apk-resources.json')
if($LASTEXITCODE -ne 0){throw 'Signed APK validation failed'}
Get-Item -LiteralPath $signed | Select-Object FullName,Length
Get-FileHash -LiteralPath $signed -Algorithm SHA256
