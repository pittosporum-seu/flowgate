# FlowGate 一键集成测试
# 用法: .\run_tests.ps1
# 前置: 设备 USB 连接 + FlowGate 已启动

$ErrorActionPreference = "Stop"
$ADB = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$PORT = 19840
$TESTS_DIR = $PSScriptRoot

Write-Host "=== FlowGate Integration Test ===" -ForegroundColor Cyan

# 1. 检查 adb 设备
Write-Host "`n[1/4] Checking device..." -ForegroundColor Yellow
$devices = & $ADB devices 2>&1 | Select-String "device$"
if (-not $devices) {
    Write-Host "ERROR: No Android device connected." -ForegroundColor Red
    exit 1
}
Write-Host "  Device found: $($devices.Line.Split("`t")[0])"

# 2. 端口转发
Write-Host "`n[2/4] Setting up adb forward tcp:$PORT..." -ForegroundColor Yellow
& $ADB forward tcp:$PORT tcp:$PORT 2>&1 | Out-Null
Write-Host "  Forwarding localhost:$PORT -> device:$PORT"

# 3. 等待 Server 就绪
Write-Host "`n[3/4] Waiting for API server..." -ForegroundColor Yellow
$ready = $false
for ($i = 0; $i -lt 10; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$PORT/api/v1/health" -TimeoutSec 2 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $ready) {
    Write-Host "ERROR: API server not reachable. Is FlowGate running?" -ForegroundColor Red
    & $ADB forward --remove tcp:$PORT 2>$null
    exit 1
}
Write-Host "  Server ready!" -ForegroundColor Green

# 4. 运行 pytest
Write-Host "`n[4/4] Running pytest..." -ForegroundColor Yellow
Push-Location $TESTS_DIR
try {
    python -m pytest api/ -v --tb=short
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

# 清理端口转发
& $ADB forward --remove tcp:$PORT 2>$null
Write-Host "`nPort forward removed." -ForegroundColor Gray

if ($exitCode -eq 0) {
    Write-Host "`n=== ALL TESTS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "`n=== SOME TESTS FAILED ===" -ForegroundColor Red
}
exit $exitCode
