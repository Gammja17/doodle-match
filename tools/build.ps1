# 커밋 하나를 Windows·Web 빌드로 뽑아 build/windows, build/web 에 넣는다.
# 작업 폴더가 아니라 커밋된 내용(git archive)을 build/_src 에 풀어서 익스포트하므로
# 다른 세션이 고치는 중인 미커밋 파일은 빌드에 안 섞인다.
# 실패하면 이전 빌드를 그대로 두고 build/last_error.txt 에 남긴다 (커밋은 안 막음).
# 사용: powershell -File tools/build.ps1 [-Ref <커밋>]   (post-commit 훅이 자동으로 부름)
param([string]$Ref = "HEAD")

$ErrorActionPreference = "Stop"
# git 출력(커밋 메시지)을 UTF-8로 받기. 콘솔이 없으면 실패하니 무시
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$Godot = "C:/Users/Dev/tools/Godot4.7.2/Godot_v4.7.2-stable_win64_console.exe"
$Root = Split-Path $PSScriptRoot -Parent
$Build = Join-Path $Root "build"
$Src = Join-Path $Build "_src"
$Stage = Join-Path $Build "_stage"
$Log = Join-Path $Build "build.log"
$ErrorFile = Join-Path $Build "last_error.txt"
$Tar = Join-Path $Build "_src.tar"

New-Item -ItemType Directory -Force $Build | Out-Null
# 고도 에디터가 build/ 안의 사본·빌드 파일을 프로젝트로 읽지 않게
New-Item -ItemType File -Force (Join-Path $Build ".gdignore") | Out-Null

# 커밋이 연달아 들어오면 빌드끼리 겹치지 않게 차례로 돈다
$Mutex = New-Object System.Threading.Mutex($false, "doodle-match-build")
try { [void]$Mutex.WaitOne() } catch [System.Threading.AbandonedMutexException] {}

function Invoke-Godot([string[]]$GodotArgs) {
    $quoted = $GodotArgs | ForEach-Object { "`"$_`"" }
    $p = Start-Process $Godot -ArgumentList $quoted -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput "$Log.out" -RedirectStandardError "$Log.err"
    # 고도 출력은 UTF-8 + 색 코드라 읽기 좋게 정리해서 붙인다
    Get-Content "$Log.out", "$Log.err" -Encoding UTF8 |
        ForEach-Object { $_ -replace "$([char]27)\[[0-9;]*m", "" } | Add-Content $Log -Encoding UTF8
    if ($p.ExitCode -ne 0) { throw "godot $($GodotArgs -join ' ') 실패 (exit $($p.ExitCode))" }
}

try {
    $Hash = (git -C $Root rev-parse $Ref).Trim()
    $Subject = (git -C $Root log -1 --format=%s $Hash).Trim()
    Set-Content $Log "빌드 시작 $(Get-Date -Format s) $Hash" -Encoding UTF8

    # 사본 갱신: 임포트 캐시(.godot)만 남기고 지운 뒤 커밋 내용을 푼다
    New-Item -ItemType Directory -Force $Src | Out-Null
    Get-ChildItem $Src -Force | Where-Object Name -ne ".godot" | Remove-Item -Recurse -Force
    git -C $Root archive -o $Tar $Hash
    & "$env:SystemRoot/System32/tar.exe" -xf $Tar -C $Src
    if ($LASTEXITCODE -ne 0) { throw "tar 풀기 실패" }

    if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
    New-Item -ItemType Directory -Force "$Stage/windows", "$Stage/web" | Out-Null

    Invoke-Godot @("--headless", "--path", $Src, "--import")
    Invoke-Godot @("--headless", "--path", $Src, "--export-release", "Windows Desktop", "$Stage/windows/DoodleMatch.exe")
    Invoke-Godot @("--headless", "--path", $Src, "--export-release", "Web", "$Stage/web/index.html")
    foreach ($f in "$Stage/windows/DoodleMatch.exe", "$Stage/web/index.html", "$Stage/web/index.pck") {
        if (-not (Test-Path $f)) { throw "익스포트 결과가 없음: $f" }
    }

    # 둘 다 성공했을 때만 이전 빌드를 바꾼다
    foreach ($d in "windows", "web") {
        $dest = Join-Path $Build $d
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Move-Item "$Stage/$d" $dest
    }
    Remove-Item $Stage -Recurse -Force
    Set-Content (Join-Path $Build "BUILD_INFO.txt") @(
        "commit:  $Hash",
        "message: $Subject",
        "built:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "godot:   4.7.2.stable",
        "windows: build/windows/DoodleMatch.exe",
        "web:     build/web/index.html (웹 서버로 열어야 함)"
    ) -Encoding UTF8
    if (Test-Path $ErrorFile) { Remove-Item $ErrorFile }
    Add-Content $Log "빌드 끝 $(Get-Date -Format s)" -Encoding UTF8
}
catch {
    Set-Content $ErrorFile @(
        "빌드 실패 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  ref=$Ref",
        $_.ToString(),
        "",
        "--- build.log 끝부분 ---"
    ) -Encoding UTF8
    if (Test-Path $Log) { Get-Content $Log -Tail 40 -Encoding UTF8 | Add-Content $ErrorFile -Encoding UTF8 }
    exit 1
}
finally {
    Remove-Item "$Log.out", "$Log.err", $Tar -ErrorAction SilentlyContinue
    $Mutex.ReleaseMutex()
}
