# 펌뱅킹 서비스 액세스 토큰 요청 위한 키 생성
export def gen-tkn-rqs-key [key: string, secret: string] {
    # 표현식당 하나의 값만 반환됩니다.
    # 함수 내에서 여러 표현식이 있을 경우, 오직 마지막 표현식의 값만 반환되고 나머지는 무시됩니다
    # 따라서 debug 위해서는 `print`를 사용해야 합니다.
    # print $"($secret)($key)"
    (do {
        let cur = (date now | format date "%Y%m%d%H%M%S")
        $cur + '.' + ($cur + $"($secret)($key)" | hash sha256)
    })
}

# 운영 하위이용기관 firm-fl1-sds00365-api 계정의 액세스 토큰 발급 받을 수 있는 `rqsBody` 생성
export def gen-prod-fl1-sds00365-tkn-body [] {
    gen-tkn-body "prod" "firm-fl1-sds00365-api"
}

# 운영 이용기관 firm-fu1-sds00365-api 계정의 액세스 토큰 발급 받을 수 있는 `rqsBody` 생성
export def gen-prod-fu1-sds00365-tkn-body [] {
    gen-tkn-body "prod" "firm-fu1-sds00365-api"
}

export def gen-prod-rody-tkn-body [] {
    gen-tkn-body "prod" "rody"
}

export def gen-dev-ecommapi-tkn-body [] {
    gen-tkn-body "dev" "ecommapi"
}

export def gen-dev-fu1-tkn-body [] {
    gen-tkn-body "dev" "firm-fu1-api"
}

export def gen-dev-ft1-tkn-body [] {
    gen-tkn-body "dev" "firm-ft1-api"
}

export def gen-dev-dl1-tkn-body [] {
    gen-tkn-body "dev" "firm-dl1-api"
}

export def gen-prod-dl1-tkn-body [] {
    gen-tkn-body "prod" "firm-dl1-api"
}

# `${HOME}/.kcf-credentials.json` 파일을 읽어서 액세스 토큰 발급 받을 수 있는 `rqsBody`를 리턴합니다.
export def gen-tkn-body [
    target_env: string # prod, dev 등
    target_user: string # `.kcf-credentials.json`에 정의된 유저를 식별할 수 있는 키. 예: "firm-fu1-sds00365-api"
] {
    let kcf_credential_path = ([$nu.home-dir .kcf-credentials.json] | path join)
    let user_info = (
        open-json-and-get-by-keys
            $kcf_credential_path
            $target_env
            $target_user
    )

    let apiCerTknIsnRqsKey = (
        gen-tkn-rqs-key
            ($user_info | get "apiKey")
            ($user_info | get "apiSecret")
    )
    {
        "usrNo": ($user_info | get "userNo"),
        "apiCerTknIsnRqsKey": $apiCerTknIsnRqsKey
    } | to json --indent 4
}
