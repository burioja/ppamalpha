// Firebase 직접 확인 스크립트
// Node.js로 Firebase Admin SDK를 사용하여 직접 데이터베이스 확인

const admin = require('firebase-admin');
const path = require('path');

// Firebase 설정
const serviceAccount = {
  projectId: "ppamproto-439623",
  // Note: 실제 서비스 계정 키가 필요합니다
};

// Firebase 초기화 (웹 설정 사용)
const firebaseConfig = {
  projectId: "ppamproto-439623",
  storageBucket: "ppamproto-439623.appspot.com",
  locationId: "asia-northeast3",
  apiKey: "AIzaSyC_e2AeyXkjp4VW3-NbVmZG-V7VONNMqvY",
  authDomain: "ppamproto-439623.firebaseapp.com",
  messagingSenderId: "714872165171"
};

console.log('🚀 Firebase 직접 데이터베이스 확인 시작');
console.log('프로젝트 ID:', firebaseConfig.projectId);

async function checkFirebaseDirectly() {
  try {
    // 특정 Post ID 확인
    const postId = 'fsTkJPcxCS2mPyJsIeA7';
    console.log(`\n🔍 포스트 ID "${postId}" 확인 중...`);

    // Firebase Web SDK 확인 메시지
    console.log('📋 Firebase 설정:');
    console.log('  - 프로젝트 ID:', firebaseConfig.projectId);
    console.log('  - 스토리지 버킷:', firebaseConfig.storageBucket);
    console.log('  - 지역:', firebaseConfig.locationId);
    console.log('  - Auth 도메인:', firebaseConfig.authDomain);

    console.log('\n⚠️  실제 데이터베이스 확인을 위해서는:');
    console.log('1. Firebase Admin SDK 서비스 계정 키 필요');
    console.log('2. 또는 Flutter 앱의 Firebase 디버그 도구 사용');
    console.log('3. 또는 Firebase Console에서 직접 확인');

    console.log('\n🎯 확인해야 할 사항:');
    console.log(`  - posts 컬렉션에 "${postId}" 문서 존재 여부`);
    console.log(`  - markers 컬렉션에서 postId="${postId}"인 마커들`);
    console.log('  - post_collections 컬렉션 상태');
    console.log('  - 컬렉션 구조와 필드 검증');

    console.log('\n💡 권장 해결책:');
    console.log('1. Flutter 앱의 관리자 도구로 Firebase 디버그 실행');
    console.log('2. Firebase Console에서 posts 컬렉션 직접 확인');
    console.log('3. 새 포스트 생성하여 문제 재현');

  } catch (error) {
    console.error('❌ 오류:', error.message);
  }
}

// 스크립트 실행
checkFirebaseDirectly();