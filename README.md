# window-env-config

Windows에서 Nushell을 같은 방식으로 설치하고 사용하기 위한 구성 저장소입니다.

실제 설치 진입점은 `tools\setup.bat`입니다. 이 스크립트는 `tools\bin\nu.exe`로
`tools\install.nu`를 실행합니다. 큰 실행 파일은 Git에 직접 넣지 않고,
필요한 portable 실행 파일은 `tools\bin`에 따로 둡니다.

`tools` 디렉토리 자체가 설치 기준 경로입니다. 원하는 위치에 이 디렉토리를 둔 뒤
그 안에서 `setup.bat`을 실행하면, Nushell 설정에 해당 경로가 기록됩니다.
