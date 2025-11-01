# 맵 기반 Flutter 레퍼런스 프로젝트

ppam 프로젝트 개발 시 참고할 수 있는 검증된 오픈소스 Flutter 앱 프로젝트 목록입니다.

## 활용 방법

### AI에게 레퍼런스 전달
```
"@reference-projects/[프로젝트명]/[파일경로]를 참고하여
ppam의 [기능명]을 구현해줘. 동일한 패턴을 따르되,
ppam의 [모델명] 모델과 통합해야 해."
```

### 레퍼런스 프로젝트 Clone
```bash
mkdir reference-projects
cd reference-projects
git clone [GitHub URL]
```

---

## 카테고리별 프로젝트

### 1. 차량 공유 / 라이드 헤일링 (Ride Sharing)

#### 1-1. Trippo - Uber Clone
- **GitHub:** https://github.com/hyderali0889/Trippo
- **주요 기능:**
  - 실시간 위치 추적
  - 라이더/드라이버 매칭 시스템
  - 결제 통합
  - 평가 시스템
- **기술 스택:** Flutter + Firebase + Google Maps
- **ppam 연관성:**
  - 실시간 위치 기반 시스템
  - Firebase 통합 패턴
  - 사용자 간 매칭 로직
- **디자인:** Uber 스타일 UI
- **학습 포인트:**
  - 실시간 데이터베이스 활용
  - 위치 기반 매칭 알고리즘

#### 1-2. Uber Clone (offfahad)
- **GitHub:** https://github.com/offfahad/uber-clone
- **주요 기능:**
  - 사용자/드라이버/관리자 3개 패널
  - Google Maps + Geolocator + Geofire
  - 위치 추적 및 푸시 알림
- **기술 스택:** Flutter + Firebase + Geofire
- **ppam 연관성:**
  - 지역 기반 필터링 (Fog of War와 유사)
  - 실시간 위치 업데이트
  - 다중 사용자 타입 관리
- **디자인:** 3가지 역할별 패널 UI
- **학습 포인트:**
  - Geofire 활용한 지역 쿼리
  - 관리자 패널 구조

#### 1-3. Rydr - Ride Hailing
- **GitHub:** https://github.com/demola234/Rydr
- **주요 기능:**
  - BLoC 패턴 상태 관리
  - Google Maps 통합
  - 라이드 예약 시스템
- **기술 스택:** Flutter + BLoC + Google Maps
- **ppam 연관성:**
  - 상태 관리 패턴 (Provider와 유사)
  - 맵 인터랙션 처리
- **디자인:** 현대적인 Material Design UI
- **학습 포인트:**
  - BLoC 패턴 구조
  - 맵 제스처 처리

#### 1-4. Venni Client App
- **GitHub:** https://github.com/abrantesarthur/venni_client_app
- **주요 기능:**
  - 맵 위치 선택 UI
  - 드라이버 실시간 추적
  - 인앱 카드 결제
  - 평가 및 히스토리
- **기술 스택:** Flutter + Payment Integration
- **ppam 연관성:**
  - 장소 선택 UI 패턴
  - 결제 시스템 통합
  - 히스토리 관리
- **디자인:** 완성도 높은 프로덕션 UI
- **학습 포인트:**
  - 위치 선택 UX 패턴
  - 결제 플로우 구현

---

### 2. 음식 배달 (Food Delivery)

#### 2-1. Deliverzler (강력 추천)
- **GitHub:** https://github.com/AhmedLSayed9/deliverzler
- **주요 기능:**
  - Domain-Driven Design (DDD) 아키텍처
  - Riverpod 상태 관리
  - 실시간 배달 추적
  - 로컬 알림 + FCM
  - Navigation 2.0 (GoRouter)
- **기술 스택:** Flutter + Firebase + Riverpod + Google Maps
- **ppam 연관성:**
  - Clean Architecture 패턴
  - 실시간 위치 업데이트
  - 알림 시스템
- **디자인:** 세련된 프로덕션 레벨 UI/UX
- **학습 포인트:**
  - **매우 추천** - 코드 품질 및 아키텍처 레퍼런스
  - DDD 레이어 구조
  - Riverpod 패턴

#### 2-2. Food Delivery App (DevStack06)
- **GitHub:** https://github.com/DevStack06/food-delivery-flutter
- **주요 기능:**
  - Google Maps 통합
  - Zomato 스타일 UI
  - 레스토랑 검색
- **기술 스택:** Flutter + Google Maps
- **ppam 연관성:**
  - 장소 기반 검색
  - 리스트 + 맵 뷰 전환
- **디자인:** Zomato 스타일 UI
- **학습 포인트:**
  - 음식 배달 UI 패턴
  - 레스토랑 카드 디자인

#### 2-3. Complete Food Delivery App
- **GitHub:** https://github.com/helloharendra/Complete-Food-delivery-App
- **주요 기능:**
  - Node.js + MySQL 백엔드
  - 라이브 주문 추적
  - OTP 로그인
  - 멀티 아울렛 지원
- **기술 스택:** Flutter + Node.js + MySQL
- **ppam 연관성:**
  - 멀티 장소 관리
  - 실시간 상태 추적
  - 인증 시스템
- **디자인:** 풀스택 완성 앱 UI
- **학습 포인트:**
  - 백엔드 API 통합 패턴
  - 멀티 아울렛 구조

---

### 3. 여행 / 관광 (Travel & Tourism)

#### 3-1. TouristAssist (강력 추천 - ppam과 도메인 유사)
- **GitHub:** https://github.com/ahmedgulabkhan/TouristAssist
- **주요 기능:**
  - 현재 도시 기반 로컬 가이드 예약
  - 지도에 가이드 위치 표시
  - 위치 기반 추천
- **기술 스택:** Flutter + Firebase + Google Maps
- **ppam 연관성:**
  - **매우 유사** - 장소 기반 서비스 제공자 찾기
  - 지도에 사용자/장소 표시
  - 위치 기반 필터링
  - 예약 시스템
- **디자인:** 관광 앱 UI
- **학습 포인트:**
  - **최우선 추천** - ppam의 PlaceModel과 유사한 구조
  - 가이드 검색 로직
  - 위치 기반 매칭

#### 3-2. Clima Weather App
- **GitHub:** https://github.com/moha-b/Clima
- **주요 기능:**
  - Open-Meteo API 통합
  - Google Maps 위치 선택
  - BLoC 패턴
  - 6일 날씨 예보
- **기술 스택:** Flutter + BLoC + Google Maps + Open-Meteo
- **ppam 연관성:**
  - 맵 위치 기반 정보 표시
  - API 통합 패턴
- **디자인:** 날씨 앱 UI with Maps
- **학습 포인트:**
  - 맵 + API 데이터 결합
  - 날씨 오버레이 표시

---

### 4. 부동산 (Real Estate)

#### 4-1. Realix Real Estate App
- **GitHub:** https://github.com/maniraja1122/Realix-RealEstateApp
- **주요 기능:**
  - Google Maps에서 실시간 위치 근처 매물 표시
  - 자동 Geocoding + Reverse Geocoding
  - 다크/라이트 모드
  - 약속 관리
- **기술 스택:** Flutter + Google Maps + Geocoding
- **ppam 연관성:**
  - 지도에 장소 마커 표시
  - 위치 기반 검색
  - Geocoding 활용
- **디자인:** 부동산 앱 UI
- **학습 포인트:**
  - Geocoding 자동화
  - 매물 마커 클러스터링

#### 4-2. WhereHome
- **GitHub:** https://github.com/Villad-dev/wherehome
- **주요 기능:**
  - Mapbox 지도
  - MongoDB 백엔드
  - 부동산 검색
- **기술 스택:** Flutter + Mapbox + MongoDB
- **ppam 연관성:**
  - Mapbox 대안 참고
  - NoSQL 데이터베이스 패턴
- **디자인:** 모던한 부동산 UI
- **학습 포인트:**
  - Mapbox vs Google Maps 비교
  - MongoDB 스키마 설계

---

### 5. 주차 앱 (Parking)

#### 5-1. PARKZ
- **GitHub:** https://github.com/ParkZ-CapstoneProject/parkz-mobile-app
- **주요 기능:**
  - 목적지 기반 주차장 추천
  - 실시간 주차 가용성 표시
  - 가격 정보 및 정확한 위치
- **기술 스택:** Flutter + Firebase
- **ppam 연관성:**
  - 근처 장소 검색 시스템
  - 실시간 정보 업데이트
  - 필터링 기능
- **디자인:** 주차 앱 UI
- **학습 포인트:**
  - 근처 장소 필터링 알고리즘
  - 가용성 실시간 표시

#### 5-2. Park Buddy
- **GitHub:** https://github.com/mohamedirfansh/Park-Buddy
- **주요 기능:**
  - 주차 편의 경험
  - 주차장 검색
- **기술 스택:** Flutter + Google Maps
- **ppam 연관성:**
  - 위치 기반 장소 검색
- **디자인:** 깔끔한 주차 UI
- **학습 포인트:**
  - 주차장 찾기 UX

---

### 6. 소셜 / 위치 공유 (Social & Location Sharing)

#### 6-1. Spot - Geo-Based Video Sharing (강력 추천)
- **GitHub:** https://github.com/dshukertjr/spot
- **주요 기능:**
  - 지오태그 비디오 공유
  - 지도에서 비디오 탐색
  - 위치별 콘텐츠 저장
- **기술 스택:** Flutter + Supabase + Maps
- **ppam 연관성:**
  - **매우 유사** - 위치 기반 콘텐츠 공유 (ppam의 PostModel과 유사)
  - 지도에서 콘텐츠 탐색
  - 위치별 필터링
- **디자인:** 소셜 미디어 앱 UI
- **학습 포인트:**
  - **강력 추천** - ppam의 포스트 시스템과 유사한 개념
  - 지오태그 구현
  - Supabase 활용

#### 6-2. Location Sharing App
- **GitHub:** https://github.com/ADITISHARMA-22/Location-sharing-app
- **주요 기능:**
  - 실시간 위치 공유
  - 그룹 형성 및 관리
  - 프로필 커스터마이징
  - Google 인증
- **기술 스택:** Flutter + Firebase + Google Maps
- **ppam 연관성:**
  - 그룹 기능
  - 실시간 위치 업데이트
  - 사용자 프로필
- **디자인:** 소셜 앱 UI
- **학습 포인트:**
  - 그룹 관리 시스템
  - 실시간 위치 마커

#### 6-3. Trovami - Live Location Sharing
- **GitHub:** https://github.com/Samaritan1011001/Trovami
- **주요 기능:**
  - 그룹 생성
  - 실시간 위치 공유
- **기술 스택:** Flutter + Firebase
- **ppam 연관성:**
  - 그룹 기반 위치 공유
  - 실시간 동기화
- **디자인:** 미니멀 UI
- **학습 포인트:**
  - 간단한 위치 공유 구현

---

### 7. 자전거 / 공유 모빌리티 (Bike Sharing)

#### 7-1. BikeShare
- **GitHub:** https://github.com/MeriemAfafHaddou/BikeShare-frontend
- **주요 기능:**
  - 근처 자전거 스테이션 검색
  - 자전거 가용성 확인
  - 스테이션까지 경로 안내
  - 예약 시스템
- **기술 스택:** Flutter + Maps
- **ppam 연관성:**
  - 근처 장소 검색
  - 가용성 실시간 표시
  - 경로 안내
- **디자인:** 공유 서비스 UI
- **학습 포인트:**
  - 스테이션 검색 알고리즘
  - 가용성 UI 패턴

#### 7-2. BiciBici App
- **GitHub:** https://github.com/merRen22/bicibici_app
- **주요 기능:**
  - QR 코드 스캔
  - 지도 시각화
  - 사용자 관리
- **기술 스택:** Flutter + Google Maps
- **ppam 연관성:**
  - 스테이션 위치 맵핑
  - QR 코드 통합
- **디자인:** 공유 자전거 UI
- **학습 포인트:**
  - QR 스캔 플로우
  - 자전거 대여 UX

---

## ppam 프로젝트 기준 추천 우선순위

### Top 3 - 최우선 참고

#### 1. TouristAssist
- **이유:** 도메인이 가장 유사 (장소 기반 서비스)
- **참고할 부분:**
  - 장소 검색 및 필터링 로직
  - 지도에 서비스 제공자 표시
  - 위치 기반 매칭 알고리즘
  - Firebase + Google Maps 통합 패턴

#### 2. Spot (Geo-Based Video Sharing)
- **이유:** 위치 기반 콘텐츠 공유 (ppam의 Post 시스템과 매우 유사)
- **참고할 부분:**
  - 지오태그 콘텐츠 저장 구조
  - 지도에서 콘텐츠 탐색 UI
  - 위치별 콘텐츠 필터링
  - Supabase 활용 (Firebase 대안 참고)

#### 3. Deliverzler
- **이유:** 프로덕션 레벨 코드 품질 및 아키텍처
- **참고할 부분:**
  - Clean Architecture 구조
  - Riverpod 상태 관리 패턴
  - 실시간 위치 추적 구현
  - 알림 시스템 통합

---

### 기능별 추천

#### Google Maps + Firebase 통합
- **추천:** Uber Clone (offfahad), Trippo
- **학습:** Geofire, 실시간 위치 업데이트

#### UI/UX 디자인
- **추천:** Deliverzler, Realix, PARKZ
- **학습:** Material Design 패턴, 카드 레이아웃

#### 실시간 위치 추적
- **추천:** Trippo, Rydr, Deliverzler
- **학습:** GPS 권한 처리, 배터리 최적화

#### 검색 및 필터링
- **추천:** PARKZ, BikeShare, Realix
- **학습:** 근처 장소 쿼리, 필터 UI

#### 결제 통합
- **추천:** Venni Client App, Trippo
- **학습:** 인앱 결제 플로우, PCI 준수

#### 소셜 기능
- **추천:** Spot, Location Sharing App
- **학습:** 사용자 간 인터랙션, 콘텐츠 공유

---

## 레퍼런스 활용 워크플로우

### 1. 프로젝트 Clone
```bash
cd reference-projects
git clone https://github.com/ahmedgulabkhan/TouristAssist.git
git clone https://github.com/dshukertjr/spot.git
git clone https://github.com/AhmedLSayed9/deliverzler.git
```

### 2. 주요 패턴 발췌
- 핵심 파일을 `/docs/references/patterns/`에 문서화
- 코드 스니펫을 `/docs/snippets/`에 저장

### 3. AI에게 전달
```
"@reference-projects/TouristAssist/lib/screens/guide_list_screen.dart를 참고하여
ppam의 PlaceListScreen을 구현해줘.
TouristAssist의 가이드 검색 로직을 ppam의 PlaceModel에 맞게 적용해."
```

### 4. 적용 후 문서화
```
/docs/ai-sessions/YYYY-MM/YYYY-MM-DD-place-search-implementation.md
```
- 어떤 레퍼런스를 참고했는지
- 어떤 부분을 수정했는지
- ppam에 맞게 커스터마이징한 부분

---

## 레퍼런스 프로젝트 비교표

| 프로젝트 | 맵 라이브러리 | 상태 관리 | 백엔드 | 인증 | ppam 유사도 |
|---------|------------|----------|--------|------|-----------|
| TouristAssist | Google Maps | Provider | Firebase | Firebase Auth | 매우 높음 |
| Spot | Maps | Riverpod | Supabase | Supabase Auth | 높음 |
| Deliverzler | Google Maps | Riverpod | Firebase | Firebase Auth | 높음 |
| Trippo | Google Maps | Provider | Firebase | Firebase Auth | 중간 |
| Realix | Google Maps | Provider | Custom | Google Auth | 중간 |
| PARKZ | Google Maps | Provider | Firebase | Firebase Auth | 중간 |

---

## 주의사항

1. **라이선스 확인**
   - 각 프로젝트의 LICENSE 파일 확인 필수
   - 대부분 MIT 또는 BSD 라이선스 (상업적 사용 가능)

2. **직접 복사 금지**
   - 코드를 그대로 복사하지 말고 패턴과 아이디어만 참고
   - ppam 프로젝트에 맞게 재구현

3. **버전 호환성**
   - Flutter/Dart 버전 차이 확인
   - 패키지 버전 충돌 주의

4. **API 키 관리**
   - Google Maps API 키는 별도 발급 필요
   - Firebase 설정은 ppam 프로젝트용으로 사용

---

## 문서 업데이트

- **추가 프로젝트 발견 시:** 이 문서에 추가하고 카테고리 분류
- **Star 수 변경:** 정기적으로 업데이트 (분기별)
- **ppam 적용 사례:** `/docs/ai-sessions/`에 기록

---

최종 업데이트: 2025-01-27
작성자: AI Session
다음 리뷰: 2025-02-27
