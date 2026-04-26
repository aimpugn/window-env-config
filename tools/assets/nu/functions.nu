# `use <모듈>` 경우 `my-module say-hello`처럼 모듈 이름과 함수 이름을 함께 사용해야 합니다.
#
# 하지만 `use <모듈> *`의 경우 모듈 파일의 모든 export된 정의를 현재 스코프로 직접 가져오므로,
# 모듈 이름을 생략하고 함수를 바로 호출할 수 있습니다
use ./functions/general-function.nu *
use ./functions/git-function.nu *
use ./functions/kcf-function.nu *
use ./functions/bin-tools.nu *
