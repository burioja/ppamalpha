# Firebase Console에서 CORS 설정하기 (대체 방법)

## Google Cloud Console에서 CORS 섹션이 보이지 않을 때

### 방법 1: Cloud Shell 사용 (권장)

1. **Google Cloud Console 접속**: https://console.cloud.google.com/
2. **프로젝트 선택**: ppamproto-439623
3. **우측 상단의 Cloud Shell 아이콘 클릭** (터미널 모양 아이콘)
4. Cloud Shell 터미널에서 다음 명령어 실행:

```bash
# CORS 설정 파일 생성
cat > cors.json << 'EOF'
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600
  }
]
EOF

# CORS 설정 적용
gsutil cors set cors.json gs://ppamproto-439623.appspot.com

# 설정 확인
gsutil cors get gs://ppamproto-439623.appspot.com
```

5. 마지막 명령어 실행 후 CORS 설정이 표시되면 성공!

### 방법 2: Storage 페이지에서 직접 접근

1. **Google Cloud Console**: https://console.cloud.google.com/storage/browser
2. **ppamproto-439623.appspot.com** 버킷 이름 클릭 (체크박스 아님!)
3. 버킷 상세 페이지에서 **"Permissions"** 탭 클릭
4. 페이지 하단의 **"CORS configuration"** 섹션 찾기
5. JSON 입력:

```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600
  }
]
```

### 방법 3: Firebase Storage Rules로 임시 해결

CORS 설정이 안 되는 경우, Storage Rules를 확인:

1. **Firebase Console**: https://console.firebase.google.com/
2. **프로젝트 선택**: ppamproto-439623
3. 좌측 메뉴 **"Build"** → **"Storage"** 클릭
4. **"Rules"** 탭 클릭
5. 다음 규칙 확인/수정:

```
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    match /places/{allPaths=**} {
      allow read: if true;  // 누구나 읽기 가능
      allow write: if request.auth != null;
    }

    match /posts/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    match /users/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    match /stores/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

6. **"Publish"** 버튼 클릭

## 가장 쉬운 방법: Cloud Shell 사용

Cloud Shell을 사용하는 것이 가장 확실합니다:

1. Google Cloud Console 우측 상단의 **터미널 아이콘** 클릭
2. 다음 3줄을 복사해서 붙여넣기:

```bash
echo '[{"origin":["*"],"method":["GET","HEAD"],"maxAgeSeconds":3600}]' > cors.json
gsutil cors set cors.json gs://ppamproto-439623.appspot.com
gsutil cors get gs://ppamproto-439623.appspot.com
```

3. 엔터 → 설정 완료!

## 확인 방법

CORS 설정 후:
1. Flutter 앱 새로고침 (F5)
2. 개발자 도구 콘솔에서 확인:
   - ✅ "Image loaded successfully" 표시
   - ❌ "statusCode: 0" 에러 사라짐
