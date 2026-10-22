# ClearCopy 0.4.2 - run the regression suite against the published ..\ClearCopy-0.4.2.exe.
# Uses the test programs in Tests\prebuilt (compiled against that exact exe), so no compiler is needed.
$ErrorActionPreference = 'Stop'
$here   = $PSScriptRoot
$app    = Join-Path (Split-Path -Parent $here) 'ClearCopy-0.4.2.exe'
$pre    = Join-Path $here 'Tests\prebuilt'
$log    = Join-Path $here 'test-log.txt'
"ClearCopy 0.4.2 test run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') on $env:COMPUTERNAME" | Set-Content -LiteralPath $log -Encoding utf8
function Log($m) { Write-Host $m; Add-Content -LiteralPath $log -Value $m -Encoding utf8 }
if (-not (Test-Path -LiteralPath $app)) { Log "FAILED: $app not found."; exit 2 }
Log "Testing: $app  SHA-256 $((Get-FileHash -LiteralPath $app -Algorithm SHA256).Hash)"

$testRoot = Join-Path $env:TEMP ('ClearCopy-0.4.2-tests-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if ([IO.DriveInfo]::new([IO.Path]::GetPathRoot($testRoot)).DriveType -ne [IO.DriveType]::Fixed) { Log 'FAILED: TEMP is not on a fixed local drive.'; exit 3 }
$bin = Join-Path $testRoot 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
# Test programs load the app by assembly name, so it must sit beside them as ClearCopy.exe.
Copy-Item -LiteralPath $app -Destination (Join-Path $bin 'ClearCopy.exe')
Copy-Item -LiteralPath "$app.config" -Destination (Join-Path $bin 'ClearCopy.exe.config')
Copy-Item -LiteralPath (Join-Path $here 'Tests\Fixtures\legacy354job.xml') -Destination $bin
Log "Test folder: $testRoot"

$failures = @()
foreach ($name in @('Phase1Regression','TransferCheck','SafetyCheck','CheckpointCheck')) {
    $exe = Join-Path $bin "$name.exe"
    Copy-Item -LiteralPath (Join-Path $pre "$name.exe") -Destination $exe
    Copy-Item -LiteralPath "$app.config" -Destination "$exe.config"
    $fixture = Join-Path $testRoot $name
    if ($name -eq 'SafetyCheck') {
        New-Item -ItemType Directory -Path $fixture | Out-Null
        $linkTarget = Join-Path $fixture 'link-target'
        New-Item -ItemType Directory -Path $linkTarget | Out-Null
        New-Item -ItemType Junction -Path (Join-Path $fixture 'junction') -Target $linkTarget | Out-Null
    }
    Log "---- $name"
    & $exe $fixture 70 2>&1 | Tee-Object -FilePath (Join-Path $testRoot "$name.txt") | ForEach-Object { Log $_ }
    $code = $LASTEXITCODE
    Log "HARNESS $name EXIT $code"
    if ($code -ne 0) { $failures += "$name (exit $code)" }
}
Log ''
if ($failures.Count) { Log ('RESULT: FAILED - ' + ($failures -join ', ')); exit 1 }
Log 'RESULT: ALL TESTS PASSED'
exit 0
