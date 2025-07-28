# ppamproto

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


firebase 데이터 베이스 구조

# 파이어베이스 데이터 구조

문서의 맥락, 목표, 범위

├── 컬렉션
│   └── {문서}
│       ├── 필드
│       ├── 배열
│       ├── 서브컬렉션
│       │           ├── 필드
│       │           ├── 배열

├── users
│   └── {userId}
│       ├── profile
│       │   ├── nickname

│       │   ├── adress
│       │   ├── secondAdress
│       │   ├── phoneNumber
│       │   ├── email
│       │   ├── profileImageUrl
│       │   ├── account
│       │   ├── gender
│       │   ├── birth
│       │   └── createdAt
│       ├── location
│       ├── wallet
│       │       └── {fileId}
│       │           ├── fileName
│       │           ├── fileUrl: "https://..."
│       │           ├── source: "map_marker" | "chat" | "event"
│       │           ├── sourceId: (markerId, chatId 등)
│       │           ├── receivedAt: (markerId, chatId 등)
│       │           ├── description: (markerId, chatId 등)
│       │           ├── createdAt
│       │           └── metadata: { optional 정보 }
│       ├── workplaces
│       │         ├── workplaceadd
│       │         ├── workplaceinput
│       │         ├── jobTitle
│       │         ├── role
│       │         ├── permissions
│       │         └── createdAt

│
├── user_tracks (팔로잉)
│   └── {userId} ← A 유저가 팔로잉하는 사람들
│       └── following (subcollection)
│           └── {targetUserId}
│               ├── createdAt
│               └── targetNickname (optional 캐시)

├── user_connections (맞팔)
│   └── {userId} ← B 유저와 A가 서로 팔로우하면 저장됨
│       └── connections (subcollection)
│           └── {mutualUserId}
│               ├── createdAt
│
├── user_logs (사용자 활동 로그)
│   └── {userId}
│       └── logs (subcollection)
│           └── {logId}
│               ├── type: "post" | "comment" | "marker" | "vote" | ...
│               ├── targetId: (해당 글/마커의 id)
│               ├── timestamp
│               └── metadata: { optional }

├── posts (커뮤니티 글)
│   └── {postId}
│       ├── userId
│       ├── content
│       ├── imageUrls: []
│       ├── category: "threads" | "recommend" | "vote"
│       ├── createdAt
│       ├── voteOptions (옵션형인 경우)
│       ├── stats
│       │   ├── commentCount
│       │   ├── likeCount
│       │   └── viewCount
│       └── location (작성 위치 또는 지역태그)

├── comments
│   └── {commentId}
│       ├── postId
│       ├── userId
│       ├── content
│       ├── createdAt

├── votes
│   └── {voteId}
│       ├── postId
│       ├── userId
│       ├── selectedOption
│       ├── votedAt

├── map_markers
│   └── {markerId}
│       ├── userId
│       ├── markerImageUrl
│       ├── position: { lat, lng }
│       ├── description
│       ├── filters: {
│             ageRange: [min, max],
│             gender: "male" | "female" | "all",
│             jobTags: ["engineer", "student"]
│         }
│       ├── createdAt
│       └── stats
│           ├── viewCount
│           └── likeCount