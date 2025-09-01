# 🗺️ HTTP 기반 Fog of War 시스템

## 📋 개요

기존의 메모리 기반 타일 생성 방식에서 **HTTP 기반 CDN/서버 타일 로딩 방식**으로 전환했습니다. 이를 통해 확장성과 성능이 크게 향상되었습니다.

## 🏗️ 아키텍처

```
Flutter App (TileOverlay)
    ↓ HTTP Request
CDN/Server (tiles/{userId}/{z}/{x}/{y}.png)
    ↑ PNG Response
Dynamic Tile Generator (Python/Node.js/Cloud Functions)
    ↑ User Data
Firestore (사용자 방문 기록)
```

## 🚀 빠른 시작 (개발 테스트)

### 1. 테스트 서버 실행

```bash
# Python이 설치되어 있어야 함
cd scripts
python tile_server.py

# 또는 다른 포트로 실행
python tile_server.py 8080
```

출력 예시:
```
🚀 Fog of War 타일 서버 시작됨
📍 주소: http://localhost:8080
🧪 테스트 URL: http://localhost:8080/tiles/user123/15/26910/12667.png
❤️ 헬스 체크: http://localhost:8080/health
🛑 중지하려면 Ctrl+C
```

### 2. Flutter 앱 실행

```bash
flutter run
```

앱이 실행되면 맵에서 다음과 같은 Fog of War 효과를 볼 수 있습니다:
- **투명 영역**: 서울 중심부 (완전히 밝음)
- **회색 영역**: 중간 거리 지역
- **검은 영역**: 원거리 지역
- **빨간 격자**: 테스트 타일 (4의 배수 좌표)

## 📂 파일 구조

```
lib/
├── screens/user/map_screen.dart          # 메인 맵 화면
└── services/
    ├── fog_of_war_tile_provider.dart     # HTTP 기반 타일 프로바이더
    └── fog_of_war_manager.dart           # 위치 추적 매니저

scripts/
├── tile_server.py                       # 개발용 동적 타일 서버
├── tile_generator.py                    # 정적 타일 생성기
└── README_FOG_OF_WAR.md                 # 이 문서
```

## 🔧 주요 컴포넌트

### FogOfWarTileProvider

```dart
FogOfWarTileProvider({
  required String userId,     // 사용자 ID
  required String baseUrl,    // 타일 서버 베이스 URL
  int tileSize = 256,         // 타일 크기
})
```

**주요 기능:**
- HTTP를 통한 타일 이미지 로딩
- 메모리 캐시 (최대 100개 타일)
- 실패 시 기본 검은 타일 반환
- 자동 리소스 정리

### 타일 URL 구조

```
{baseUrl}/tiles/{userId}/{z}/{x}/{y}.png

예시:
http://localhost:8080/tiles/user123/15/26910/12667.png
```

## 🎨 타일 타입별 시각 효과

| 타입 | 색상 | 불투명도 | 효과 |
|------|------|----------|------|
| `clear` | 투명 | 0% | 지도 완전히 보임 |
| `gray` | 회색 | 50% | 지도 흐리게 보임 |
| `dark_gray` | 어두운 회색 | 70% | 지도 어둡게 보임 |
| `dark` | 검은색 | 90% | 지도 거의 안 보임 |
| `test` | 빨간 격자 | 40% | 개발 테스트용 |

## 🌐 프로덕션 배포

### 1. Firebase Storage + CDN

```dart
FogOfWarTileProvider(
  userId: uid,
  baseUrl: 'https://your-project.firebaseapp.com',
)
```

타일 저장 구조:
```
gs://your-bucket/tiles/
├── user123/
    └── 15/
        ├── 26910/
            ├── 12667.png
            ├── 12668.png
            └── ...
```

### 2. AWS S3 + CloudFront

```dart
FogOfWarTileProvider(
  userId: uid,
  baseUrl: 'https://d1234567890.cloudfront.net',
)
```

### 3. Google Cloud Storage + CDN

```dart
FogOfWarTileProvider(
  userId: uid,
  baseUrl: 'https://storage.googleapis.com/your-bucket',
)
```

## 🔥 Cloud Functions 연동

### Firebase Functions 예시

```javascript
const functions = require('firebase-functions');
const { createCanvas } = require('canvas');

exports.generateFogTile = functions.https.onRequest(async (req, res) => {
  const { userId, z, x, y } = req.params;
  
  // Firestore에서 사용자 방문 기록 조회
  const userVisits = await getUserVisits(userId);
  
  // 타일 fog level 계산
  const fogLevel = calculateFogLevel(x, y, z, userVisits);
  
  // PNG 타일 생성
  const tileBuffer = generateTilePNG(fogLevel);
  
  // Firebase Storage에 저장
  await saveTileToStorage(`tiles/${userId}/${z}/${x}/${y}.png`, tileBuffer);
  
  res.set('Content-Type', 'image/png');
  res.send(tileBuffer);
});
```

## 📊 성능 최적화

### 클라이언트 측
- **메모리 캐시**: 최대 100개 타일
- **HTTP 클라이언트 재사용**: 연결 풀링
- **비동기 로딩**: UI 블로킹 방지

### 서버 측
- **CDN 캐싱**: 1시간 캐시 헤더
- **CORS 지원**: Flutter Web 호환
- **배치 생성**: 여러 타일 동시 생성

## 🧪 테스트 방법

### 1. 로컬 테스트

```bash
# 서버 실행
python scripts/tile_server.py

# 브라우저에서 직접 확인
open http://localhost:8080/tiles/user123/15/26910/12667.png
```

### 2. 정적 타일 생성 테스트

```bash
# 기본 테스트 타일 생성
python scripts/tile_generator.py

# 패턴 타일 생성 (11x11 영역)
python scripts/tile_generator.py pattern

# HTTP 서버로 서빙
python -m http.server 8000

# Flutter에서 baseUrl 변경
baseUrl: 'http://localhost:8000'
```

## 🔍 디버깅

### 타일 로딩 로그 확인

```dart
debugPrint('🎯 Fog of War 타일 요청: x=$x, y=$y, zoom=$actualZoom');
debugPrint('✅ 타일 로드 성공: $url');
debugPrint('❌ 타일 로드 오류: $e');
```

### 네트워크 트래픽 모니터링

Flutter DevTools의 Network 탭에서 타일 요청을 확인할 수 있습니다.

### 일반적인 문제들

1. **CORS 오류** (Web)
   - 서버에서 `Access-Control-Allow-Origin: *` 헤더 추가

2. **타일이 표시되지 않음**
   - `baseUrl` 확인
   - 네트워크 연결 확인
   - 서버 로그 확인

3. **성능 이슈**
   - 캐시 크기 조정 (`_maxCacheSize`)
   - 타일 압축 최적화
   - CDN 사용

## 🎯 다음 단계

1. **실시간 타일 생성**: 사용자 이동 시 동적 타일 업데이트
2. **Firebase Functions 연동**: 서버리스 타일 생성
3. **오프라인 지원**: 로컬 타일 캐싱
4. **성능 모니터링**: 타일 로딩 시간 측정
5. **A/B 테스트**: 다양한 Fog 스타일 테스트

---

**🎉 축하합니다! HTTP 기반 Fog of War 시스템이 성공적으로 구축되었습니다!**
