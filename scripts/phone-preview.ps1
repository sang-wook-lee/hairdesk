# 폰으로 앱 보기 (같은 와이파이)
#
# 하는 일: 이 PC의 와이파이 주소를 찾아서 → 그 주소를 서버 주소로 박아 앱을 빌드하고 → 같은 와이파이의 폰이 열 수 있게 띄운다.
# 먼저 백엔드를 켜 두세요: backend 폴더에서  ./gradlew bootRun   (Docker Desktop 실행 필요)
#
# 실행 (저장소 맨 위 폴더에서):
#   powershell -ExecutionPolicy Bypass -File scripts\phone-preview.ps1
#   주소를 직접 정하려면:  ... -File scripts\phone-preview.ps1 -Ip 192.168.0.12
# 끝내려면 이 창에서 Ctrl+C.
#
# 주의: 같은 와이파이에서만 열린다. 카페 같은 낯선 와이파이에서는 하지 않는다 (docs/adr/0009 참고).

param(
    [string]$Ip,                                          # 비우면 자동으로 찾는다
    [int]$AppPort = 5173,                                 # 앱(웹 페이지)을 여는 포트
    [int]$ApiPort = 8080,                                 # 백엔드 서버 포트
    [string]$Flutter = "C:\dev\flutter\bin\flutter.bat"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

# 1) 이 PC의 집 와이파이 주소 찾기. 가상 어댑터(WSL, Hyper-V, Docker 등)의 주소는 폰이 쓸 수 없으니 뺀다.
if (-not $Ip) {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            ($_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*") -and
            $_.InterfaceAlias -notmatch "vEthernet|WSL|Loopback|VirtualBox|VMware|Docker"
        }
    if (-not $candidates) {
        Write-Error "와이파이 주소를 찾지 못했습니다. -Ip 192.168.x.x 처럼 직접 알려 주세요. (cmd에서 ipconfig 로 확인)"
    }
    $Ip = ($candidates | Select-Object -First 1).IPAddress
    if (@($candidates).Count -gt 1) {
        Write-Host "주소 후보가 여러 개입니다: $(($candidates.IPAddress) -join ', ')  → $Ip 를 씁니다. 다르면 -Ip 로 지정하세요."
    }
}
$apiUrl = "http://${Ip}:${ApiPort}"
$appUrl = "http://${Ip}:${AppPort}"

# 2) 백엔드가 켜져 있는지 확인 (꺼져 있으면 앱이 빈 화면 + 연결 오류만 보인다)
try {
    Invoke-WebRequest -Uri "http://localhost:${ApiPort}/actuator/health" -UseBasicParsing -TimeoutSec 3 | Out-Null
    Write-Host "백엔드 확인: 켜져 있습니다 (포트 $ApiPort)"
} catch {
    Write-Warning "백엔드가 꺼져 있습니다. 다른 창에서 backend 폴더로 가서 ./gradlew bootRun 을 먼저 실행하세요. (계속 진행은 합니다)"
}

# 3) 서버 주소를 이 PC의 와이파이 주소로 박아서 빌드. (폰에게 localhost는 폰 자신이라서)
Write-Host "앱을 빌드합니다 (서버 주소: $apiUrl) ..."
Push-Location (Join-Path $repo "app")
try {
    & $Flutter build web --release "--dart-define=API_BASE_URL=$apiUrl"
    if ($LASTEXITCODE -ne 0) { throw "빌드에 실패했습니다." }
} finally {
    Pop-Location
}

# 4) 빌드 결과를 0.0.0.0(모든 네트워크)으로 띄운다. 127.0.0.1로만 띄우면 폰이 못 연다.
Write-Host ""
Write-Host "==============================================="
Write-Host " 폰 브라우저에서 열 주소:  $appUrl"
Write-Host " (같은 와이파이여야 합니다. 끝내려면 Ctrl+C)"
Write-Host "==============================================="
Write-Host "Windows 방화벽 창이 뜨면 '개인 네트워크'만 허용하세요."
Write-Host ""
python -m http.server $AppPort --bind 0.0.0.0 --directory (Join-Path $repo "app\build\web")
