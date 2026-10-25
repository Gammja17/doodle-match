# 이 레포의 git 훅 폴더를 tools/hooks 로 돌린다 (.git/hooks 는 커밋이 안 되므로).
# 클론마다 한 번만 실행: powershell -File tools/install-hooks.ps1
git -C (Split-Path $PSScriptRoot -Parent) config core.hooksPath tools/hooks
Write-Output "훅 설치됨: core.hooksPath = tools/hooks"
