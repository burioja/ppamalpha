# 바이브 코딩 효율화 규칙

ppam 프로젝트의 AI 기반 개발(바이브 코딩) 효율성을 극대화하기 위한 종합 가이드입니다.

## 기본 5대 원칙

### 1. CLAUDE.md 공통화
- 프로젝트 루트의 `CLAUDE.md` 파일을 팀 전체가 공유
- 공통 룰과 프로젝트 특화 룰을 명확히 구분
- 버전 관리: 주요 변경 시 문서 상단에 버전 번호 명시
- 팀원별 커스터마이징은 선택적 섹션으로 분리

### 2. 이모지 사용 금지
- 모든 마크다운 문서에서 이모지 사용 금지
- AI 생성 코드 및 문서에서도 이모지 제외
- 간결하고 전문적인 문서 유지

### 3. 레퍼런스 템플릿 프로젝트
- 검증된 오픈소스 프로젝트를 레퍼런스로 활용
- `/docs/REFERENCE_PROJECTS.md` 참조
- AI에게 레퍼런스 프로젝트 경로를 명시적으로 전달

### 4. AI 세션 문서화
- 모든 AI 활용 내역을 날짜 + 제목 형식으로 기록
- 저장 위치: `/docs/ai-sessions/YYYY-MM/`
- 파일명 형식: `YYYY-MM-DD-작업-제목.md`

**문서 템플릿:**
```markdown
# [날짜] - [작업 제목]

## Context
작업 배경 및 목적

## Problems Encountered
발생한 문제들

## Solutions Applied
적용한 해결책

## Code Changes
주요 코드 변경사항 (파일 경로 포함)

## Learnings
배운 점 및 다음 개선 사항

## Related Files
- 관련 파일 경로들
```

### 5. 문서 저장 폴더 규칙
**절대 루트 폴더에 문서/테스트 저장 금지**

권장 폴더 구조:
- `/docs` - 모든 문서 및 마크다운 파일
- `/tests` - 테스트 파일
- `/src` 또는 `/lib` - 소스 코드
- `/scripts` - 유틸리티 스크립트
- `/assets` - 정적 리소스

---

## 추가 권장 방법론

### 6. 컨텍스트 파일 시스템

AI에게 프로젝트 상황을 빠르게 전달하는 핵심 시스템

**필수 컨텍스트 파일:**
```
/docs/context/
  - PROJECT_OVERVIEW.md        # 프로젝트 전체 구조 및 목표
  - CURRENT_STATUS.md          # 현재 진행 상황 (매주 업데이트)
  - TECH_STACK.md              # 기술 스택 및 의존성
  - KNOWN_ISSUES.md            # 알려진 문제 및 해결 방법
  - CODING_CONVENTIONS.md      # 코딩 컨벤션
  - ARCHITECTURE_DECISIONS.md  # 주요 아키텍처 결정 사항 (ADR)
```

**활용 방법:**
```
AI 세션 시작 시:
"@docs/context/PROJECT_OVERVIEW.md를 읽고 현재 상황을 파악한 후 작업해줘"
```

### 7. Progressive Prompting 전략

대규모 기능 개발 시 단계별 접근으로 품질 향상

**단계:**
1. 요구사항 분석 (Plan Mode)
2. 아키텍처 설계 검토
3. 구현 계획 수립
4. 단위별 구현 (작은 단위로 분할)
5. 통합 및 테스트

### 8. 체크리스트 기반 검증

AI가 작업 완료 시 자동 확인하도록 강제

**체크리스트 파일:**
```
/docs/checklists/
  - feature-implementation-checklist.md
  - code-review-checklist.md
  - ui-implementation-checklist.md
  - deployment-checklist.md
```

**사용 예시:**
```
AI 프롬프트에 추가:
"작업 완료 후 @docs/checklists/feature-implementation-checklist.md 확인"
```

### 9. 스니펫 라이브러리

자주 사용하는 코드 패턴을 저장하여 재사용

**구조:**
```
/docs/snippets/
  - firebase-crud-operations.dart
  - provider-boilerplate.dart
  - error-handling-pattern.dart
  - navigation-patterns.dart
```

### 10. Iteration Log (반복 작업 기록)

동일한 문제가 반복될 때 빠른 해결을 위한 기록

**구조:**
```
/docs/iteration-logs/
  - firebase-auth-errors.md
  - flutter-build-issues.md
  - state-management-problems.md
```

**포맷:**
```markdown
# [문제 카테고리]

## Problem: [문제 설명]
### Symptoms
- 증상 설명

### Root Cause
- 근본 원인

### Solution
```dart
// 해결 코드
```

### Prevention
- 재발 방지 방법

## Last Occurred: YYYY-MM-DD
```

### 11. AI 프롬프트 템플릿 라이브러리

효과적인 프롬프트를 템플릿화하여 재사용

**구조:**
```
/docs/prompts/
  - feature-implementation-template.md
  - debugging-template.md
  - refactoring-template.md
  - code-review-template.md
```

### 12. Git Commit Convention 강화

AI가 생성하는 커밋 메시지 표준화

**형식:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `refactor`: 리팩토링
- `docs`: 문서 변경
- `style`: 코드 포맷팅
- `test`: 테스트 추가/수정
- `chore`: 빌드/설정 변경

**AI 세션 커밋:**
Footer에 AI 세션 정보 추가:
```
AI-Session: 2025-01-27-feature-name
```

### 13. Dependency Decision Log

외부 라이브러리 선택 이유를 문서화

**파일:** `/docs/DEPENDENCIES.md`

**포맷:**
```markdown
## [패키지명] (^버전)
**Purpose:** 목적
**Alternatives Considered:** 고려한 대안들
**Decision Reason:** 선택 이유
**Date Added:** YYYY-MM-DD
```

### 14. Error Dictionary

프로젝트에서 발생하는 에러 카탈로그

**파일:** `/docs/ERROR_DICTIONARY.md`

**포맷:**
```markdown
## E001: [에러명]
**Error Message:** `error-code`
**Cause:** 발생 원인
**Solution:** 해결 방법
**Frequency:** High/Medium/Low
**Last Updated:** YYYY-MM-DD
```

### 15. Weekly Sync Document

팀원 간 / AI 세션 간 동기화

**구조:**
```
/docs/weekly-syncs/
  - YYYY-Wxx-sync.md
```

**포맷:**
```markdown
# Week xx, YYYY (MM DD - MM DD)

## Completed
- [x] 완료된 작업들

## In Progress
- [ ] 진행 중인 작업들

## Blockers
- 차단 요소들

## Next Week Priority
1. 우선순위 1
2. 우선순위 2

## AI Session Notes
- Session 1 (날짜): 주요 내용
```

---

## Figma to Flutter 워크플로우

### Design System 구조

**필수 문서:**
```
/docs/design-system/
  - FIGMA_TO_FLUTTER_GUIDE.md      # Figma → Flutter 변환 가이드
  - DESIGN_TOKENS.md               # 디자인 토큰 정의
  - COMPONENT_MAPPING.md           # 컴포넌트 매핑표
  - FIGMA_INTEGRATION.md           # 플러그인 및 워크플로우
  - DESIGN_TO_CODE_WORKFLOW.md    # 전체 프로세스
  - UI_IMPLEMENTATION_CHECKLIST.md # UI 구현 체크리스트
```

### Design Tokens 개념

Figma Variables/Styles를 Flutter 코드로 변환:

**매핑 원칙:**
- Figma Colors → Flutter Color Constants
- Figma Text Styles → Flutter TextStyle
- Figma Auto Layout Spacing → Flutter EdgeInsets
- Figma Corner Radius → Flutter BorderRadius
- Figma Effects (Shadow) → Flutter BoxShadow

**Flutter Theme 구조:**
```
/lib/theme/
  - design_tokens.dart  # 중앙 집중식 토큰
  - colors.dart
  - typography.dart
  - spacing.dart
  - app_theme.dart
```

### Component Mapping

**Atomic Design 패턴:**
```
/lib/widgets/
  - atoms/          # 기본 요소 (버튼, 입력 등)
  - molecules/      # 조합 컴포넌트 (카드, 리스트 아이템)
  - organisms/      # 복잡한 컴포넌트 (헤더, 섹션)
```

**매핑 테이블 예시:**

| Figma Component | Flutter Widget | 파일 경로 |
|----------------|----------------|----------|
| Button/Primary | PrimaryButton | lib/widgets/atoms/buttons/ |
| Card/Place | PlaceCard | lib/widgets/molecules/cards/ |
| Header/Main | MainHeader | lib/widgets/organisms/headers/ |

### Figma 플러그인 활용

**추천 플러그인:**
1. **Figma to Code** - Flutter 코드 자동 생성
2. **Design Tokens** - Variables를 JSON Export
3. **Measure Plugin** - 정확한 spacing 측정

### Design to Code 프로세스

**Phase 1: Figma 디자인 준비**
- Auto Layout 적용
- Components 정의
- Design Tokens 정의
- Variants 정의

**Phase 2: Export & Document**
- Figma Variables → JSON Export
- 컴포넌트 스펙 문서화
- 인터랙션 요구사항 작성

**Phase 3: Flutter 구현**
- Design Tokens → Dart 클래스 변환
- Atoms → Molecules → Organisms 순서로 구현
- 화면 조립

**Phase 4: AI 활용**

AI 프롬프트 템플릿:
```
다음 Figma 화면을 Flutter로 구현해줘:

Figma URL: [링크]
Screen Name: [화면명]
Design Tokens: @lib/theme/design_tokens.dart 사용
참고 위젯: @lib/widgets/atoms/ 재사용
레퍼런스: @reference-projects/[프로젝트명] 패턴 참고
체크리스트: @docs/checklists/ui-implementation-checklist.md 확인

디자인 스펙:
- [주요 스펙 나열]
```

---

## 권장 폴더 구조

```
ppamalpha/
├── docs/
│   ├── context/                 # 프로젝트 컨텍스트
│   │   ├── PROJECT_OVERVIEW.md
│   │   ├── CURRENT_STATUS.md
│   │   ├── TECH_STACK.md
│   │   ├── KNOWN_ISSUES.md
│   │   ├── CODING_CONVENTIONS.md
│   │   └── ARCHITECTURE_DECISIONS.md
│   ├── design-system/           # Figma 관련
│   │   ├── FIGMA_TO_FLUTTER_GUIDE.md
│   │   ├── DESIGN_TOKENS.md
│   │   ├── COMPONENT_MAPPING.md
│   │   ├── FIGMA_INTEGRATION.md
│   │   ├── DESIGN_TO_CODE_WORKFLOW.md
│   │   └── UI_IMPLEMENTATION_CHECKLIST.md
│   ├── references/              # 레퍼런스 자료
│   │   ├── architecture/
│   │   ├── code-templates/
│   │   ├── best-practices/
│   │   └── patterns/
│   ├── ai-sessions/             # AI 세션 기록
│   │   └── YYYY-MM/
│   ├── checklists/              # 체크리스트
│   ├── snippets/                # 코드 스니펫
│   ├── prompts/                 # AI 프롬프트 템플릿
│   ├── iteration-logs/          # 반복 문제 기록
│   ├── weekly-syncs/            # 주간 동기화
│   ├── VIBE_CODING_RULES.md     # 이 문서
│   ├── REFERENCE_PROJECTS.md    # 레퍼런스 프로젝트
│   ├── ERROR_DICTIONARY.md
│   ├── DEPENDENCIES.md
│   └── GIT_COMMIT_CONVENTION.md
├── lib/
│   ├── theme/                   # Design Tokens
│   │   ├── design_tokens.dart
│   │   ├── colors.dart
│   │   ├── typography.dart
│   │   └── spacing.dart
│   └── widgets/                 # Atomic Design
│       ├── atoms/
│       ├── molecules/
│       └── organisms/
├── reference-projects/          # 레퍼런스 프로젝트 Clone
│   └── (git clone repositories)
└── CLAUDE.md                    # 메인 AI 설정
```

---

## 우선순위별 도입 로드맵

### Phase 1: 즉시 적용 (이번 주)
1. CLAUDE.md 검토 및 보완
2. 폴더 구조 정리 (`/docs` 하위)
3. 컨텍스트 파일 작성 (PROJECT_OVERVIEW, CURRENT_STATUS)
4. 기본 체크리스트 작성

### Phase 2: 1-2주 내 (다음 주)
5. 레퍼런스 프로젝트 선정 및 Clone
6. 스니펫 라이브러리 구축
7. AI 세션 문서화 시작
8. Error Dictionary 작성

### Phase 3: 1개월 내
9. 프롬프트 템플릿 라이브러리 구축
10. Iteration Log 시스템 정착
11. Weekly Sync 프로세스 정착
12. Figma Design System 완성

---

## 핵심 성공 요인

1. **일관성**: 한번 정한 룰은 모든 세션에서 일관되게 적용
2. **점진적 도입**: 한번에 모든 것을 하지 말고 우선순위대로
3. **문서 최신화**: 변경사항 발생 시 관련 문서 즉시 업데이트
4. **AI 훈련**: 좋은 레퍼런스와 예시로 AI 품질 향상
5. **피드백 루프**: 효과적인 방법을 지속적으로 관찰하고 개선

---

## AI 프롬프트 작성 팁

### 효과적인 프롬프트 구조:

```
[명확한 작업 지시]

컨텍스트:
- @docs/context/PROJECT_OVERVIEW.md
- 현재 작업: [작업 내용]
- 관련 파일: [파일 경로]

요구사항:
1. [요구사항 1]
2. [요구사항 2]

기술 제약사항:
- [제약사항들]

레퍼런스:
- @reference-projects/[프로젝트명]/[경로]
- @docs/snippets/[스니펫명]

체크리스트:
- @docs/checklists/[체크리스트명]
```

### 피해야 할 패턴:

- 모호한 지시 ("좀 더 좋게 만들어줘")
- 컨텍스트 없는 요청
- 너무 큰 범위의 작업 한번에 요청
- 레퍼런스 없이 새로운 패턴 요청

---

## 문서 업데이트 규칙

- **주기:** 주요 변경 시 즉시, 최소 월 1회 검토
- **책임자:** 팀 리드 또는 담당자 지정
- **버전 관리:** Git으로 문서 변경 이력 추적
- **리뷰:** 새로운 룰 추가 시 팀 전체 리뷰

---

최종 업데이트: 2025-01-27
