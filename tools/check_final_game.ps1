param([switch]$FindEndingPaths, [switch]$GraphicalUI)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$enginePath = Join-Path $projectRoot 'Godot_v4.7.2-stable_win64.exe'
$logDirectory = Join-Path $projectRoot '.godot\final-checks'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$checks = @('run_startup_test','run_final_rules_test','run_final_systems_test','run_final_regressions','run_final_ui_test','run_final_replay_test','run_story_locations','run_biome_locations','run_side_walk_input')
if ($FindEndingPaths) { $checks += 'run_final_endings' }
foreach ($checkName in $checks) {
    $logPath = Join-Path $logDirectory ($checkName + '.log')
    $arguments = @('--headless','--path',('"' + $projectRoot + '"'),'--script',('tests/' + $checkName + '.gd'),'--log-file',('"' + $logPath + '"'))
    $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    $logText = Get-Content -LiteralPath $logPath -Raw -Encoding utf8
    $logText -split '\r?\n' | Select-String -CaseSensitive 'checks=|failures=|^FAIL(?:\s|$)|SCRIPT ERROR|Parse Error|FULL_ENDINGS|FINAL_REPLAY'
    if ($process.ExitCode -ne 0) { throw ($checkName + ' failed. See ' + $logPath) }
    if ($logText -match 'SCRIPT ERROR|Parse Error' -or $logText -notmatch 'failures=0(?:\s|$)') {
        throw ($checkName + ' did not complete successfully. See ' + $logPath)
    }
}
if ($GraphicalUI) {
  foreach ($graphicCheck in @('run_final_ui_test','run_story_locations','run_biome_locations')) {
    $logPath = Join-Path $logDirectory ('graphical_' + $graphicCheck + '.log')
    $arguments = @('--path',('"' + $projectRoot + '"'),'--position','-20000,-20000','--audio-driver','Dummy','--script',('tests/' + $graphicCheck + '.gd'),'--log-file',('"' + $logPath + '"'))
    $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    $logText = Get-Content -LiteralPath $logPath -Raw -Encoding utf8
    $logText -split '\r?\n' | Select-String -CaseSensitive 'checks=|^FAIL(?:\s|$)|SCRIPT ERROR|Parse Error'
    if ($process.ExitCode -ne 0 -or $logText -match 'SCRIPT ERROR|Parse Error' -or $logText -notmatch 'failures=0(?:\s|$)') {
        throw ('Graphical UI failed. See ' + $logPath)
    }
  }
}
