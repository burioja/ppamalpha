# 🔥 Firestore 연동 Fog of War 시스템 설정 가이드

## 📦 필요한 패키지 설치

### Python 서버용
```bash
pip install firebase-admin pillow
```

### Node.js 스크립트용 (확인용)
```bash
npm install firebase-admin
```

## 🔑 Firebase 서비스 계정 키 설정

1. **Firebase Console** 이동: https://console.firebase.google.com/
2. 프로젝트 선택
3. **프로젝트 설정** → **서비스 계정** 탭
4. **새 비공개 키 생성** 클릭
5. 다운로드된 JSON 파일을 `scripts/serviceAccountKey.json`으로 저장

```bash
# 파일 위치 확인
scripts/
├── serviceAccountKey.json          # Firebase 서비스 계정 키
├── fog_server_with_firestore.py   # Firestore 연동 서버
├── check_visited_tiles.js          # 데이터 확인 스크립트
└── README_FIRESTORE_SETUP.md       # 이 파일
```

## 🚀 실행 순서

### 1️⃣ Firestore 데이터 확인
```bash
cd scripts
node check_visited_tiles.js
```

**예상 출력:**
```
=== 방문 타일 데이터 확인 ===

1. visits_tiles 컬렉션 사용자 목록:
총 1명의 사용자가 타일을 방문했습니다.
- 사용자 ID: ABC123XYZ

2. 사용자 "ABC123XYZ"의 방문 타일:
총 5개의 방문 타일
- 타일 ID: 15_26910_12667
  fogLevel: 1 (투명)
  distance: 0.050km
  visitedAt: 2024-1-15 14:30:00

📊 방문 타일 통계:
- 투명 (fogLevel 1): 2개
- 회색 (fogLevel 2): 3개
- 검은색 (fogLevel 3): 0개

🎯 최신 방문 타일 서버 테스트 URL:
http://localhost:8080/tiles/ABC123XYZ/15/26910/12667.png
```

### 2️⃣ Firestore 연동 서버 실행
```bash
python fog_server_with_firestore.py
```

**예상 출력:**
```
🚀 Firestore 연동 Fog of War 타일 서버 시작
✅ Firebase 초기화 성공
✅ 서버가 포트 8080에서 실행 중입니다
📡 URL 예시: http://localhost:8080/tiles/USER_ID/15/26910/12667.png
🛑 서버 종료: Ctrl+C
```

### 3️⃣ Flutter 앱 실행
```bash
flutter run
```

## 🎯 동작 원리

### 📱 Flutter App (Client)
1. 사용자가 이동하면 GPS로 위치 감지
2. 300m 반경 내 타일 계산 (원형)
3. Firestore에 방문 타일 저장 (`fogLevel: 1, 2, 3`)
4. 캐시 무효화 → TileOverlay 새로고침

### 🔥 Firestore (Database)
```
visits_tiles/
  {userId}/
    visited/
      {tileId}/          # 예: "15_26910_12667"
        fogLevel: 1      # 1=투명, 2=회색, 3=검은색
        distance: 0.05   # 사용자-타일중심 거리(km)
        visitedAt: Timestamp
        location: GeoPoint
```

### 🐍 Python Server (Tile Provider)
1. HTTP 요청: `/tiles/{userId}/{zoom}/{x}/{y}.png`
2. Firestore에서 해당 타일의 `fogLevel` 조회
3. `fogLevel`에 따라 PNG 이미지 생성:
   - `fogLevel: 1` → 투명 (지도 보임)
   - `fogLevel: 2` → 연한 회색
   - `fogLevel: 3` → 검은색 (지도 안 보임)

## 🔧 문제 해결

### ❌ "serviceAccountKey.json 파일을 찾을 수 없습니다"
→ Firebase Console에서 서비스 계정 키를 다운로드하고 `scripts/` 폴더에 저장

### ❌ "Firebase 초기화 실패"
→ 서비스 계정 키 파일의 권한 확인, JSON 형식 검증

### ❌ "현재 위치가 여전히 검은색"
1. Firestore에 데이터가 올바르게 저장되었는지 확인
2. 서버가 정상 실행 중인지 확인 
3. 앱에서 GPS 권한이 허용되었는지 확인
4. 최소 이동 거리(50m) 이상 이동했는지 확인

### 🔍 디버그 로그 확인
- **Flutter**: Debug Console에서 `🎯`, `✅`, `❌` 로그 확인
- **Python**: 터미널에서 타일 요청 로그 확인
- **Firestore**: Firebase Console에서 `visits_tiles` 컬렉션 직접 확인

## 🎮 테스트 방법

1. **앱 실행** 후 GPS 권한 허용
2. **야외에서 50m 이상 이동** (실제 GPS 신호 필요)
3. **Debug Console**에서 "방문 타일 기록 완료" 메시지 확인
4. **이동한 지역이 투명/회색**으로 변하는지 확인
5. **미이동 지역은 검은색** 유지되는지 확인
