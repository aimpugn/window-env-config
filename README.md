# window-env-config

Windows에서 Nushell을 같은 방식으로 설치하고 사용하기 위한 구성 저장소입니다.

실제 설치 진입점은 `tools\setup.bat`입니다. 이 스크립트는 큰 실행 파일을
Git에 직접 넣지 않고, `tools\tool-manifest.json` 기준으로 `tools\bin`을
복원한 뒤 `tools\install.nu`를 실행합니다.

기본 설치 위치는 `%USERPROFILE%\VscodeProjects\configs\tools`입니다.
다른 위치를 쓰려면 실행 전에 `WINDOW_ENV_CONFIG_HOME` 환경 변수를 지정하면
됩니다.
