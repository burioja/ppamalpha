# Firebase Storage CORS 설정 가이드

## 문제 상황
- 이미지 URL은 정상적으로 생성됨
- Flutter Web에서 이미지 로딩 시 `statusCode: 0` 에러 발생
- 원인: CORS (Cross-Origin Resource Sharing) 미설정

## 해결 방법: Google Cloud Console에서 CORS 설정

### 1단계: Google Cloud Console 접속

1. https://console.cloud.google.com/ 접속
2. 프로젝트 선택: **ppamproto-439623**

### 2단계: Cloud Storage 버킷 찾기

1. 좌측 상단 햄버거 메뉴(☰) 클릭
2. **Storage** → **Buckets** 선택
3. 버킷 목록에서 **ppamproto-439623.appspot.com** 클릭

### 3단계: CORS 구성 추가

1. 버킷 상세 페이지 상단의 **"Configuration"** 탭 클릭
2. 페이지를 아래로 스크롤하여 **"CORS"** 섹션 찾기
3. **"Edit"** 버튼 클릭 (연필 아이콘)
4. 텍스트 입력 창에 다음 JSON을 **정확히** 복사/붙여넣기:

```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600
  }
]
```

5. **"Save"** 버튼 클릭
6. 확인 대화상자가 나타나면 **"Confirm"** 클릭

### 4단계: 설정 확인

CORS 설정 완료 후:

1. Flutter 앱 브라우저 새로고침 (F5)
2. Place Detail 화면에서 이미지 로딩 확인
3. 개발자 도구 콘솔에서 확인:
   - ✅ "Image loaded successfully[0]" 로그 표시
   - ❌ "statusCode: 0" 에러 사라짐

### 5단계: 문제 지속 시

만약 CORS 설정 후에도 문제가 계속되면:

1. 브라우저 캐시 완전 삭제:
   - Chrome: Ctrl+Shift+Delete → "Cached images and files" 체크 → Clear data
2. 시크릿 모드(Incognito)에서 테스트
3. 최대 5분 대기 (CORS 설정 전파 시간)

## 참고: CORS 설정 의미

- **origin**: 어떤 도메인에서 접근을 허용할지 (`"*"` = 모든 도메인)
- **method**: 허용할 HTTP 메서드 (GET, HEAD = 읽기 전용)
- **maxAgeSeconds**: 브라우저가 CORS 정보를 캐시하는 시간 (1시간)

## 대체 방법: gsutil 사용 (선택사항)

Google Cloud SDK가 설치되어 있다면:

```bash
gsutil cors set cors.json gs://ppamproto-439623.appspot.com
```

cors.json 파일은 프로젝트 루트에 이미 생성되어 있음.

## 보안 참고사항

현재 설정(`"origin": ["*"]`)은 개발/테스트용입니다.
프로덕션 배포 시에는 특정 도메인만 허용하도록 변경 권장:

```json
{
  "origin": ["https://yourdomain.com", "https://www.yourdomain.com"],
  "method": ["GET", "HEAD"],
  "maxAgeSeconds": 3600
}
```
