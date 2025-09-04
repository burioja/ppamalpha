// 간단한 Firestore 연결 테스트 (서비스 계정 키 없이)
console.log('🔍 Firestore 연결 테스트 중...');

const admin = require('firebase-admin');

// Application Default Credentials 시도
try {
  admin.initializeApp({
    projectId: 'ppamproto-439623'
  });
  
  const db = admin.firestore();
  
  console.log('✅ Firebase Admin SDK 초기화 성공');
  console.log('📊 프로젝트 ID: ppamproto-439623');
  
  // 간단한 테스트 쿼리
  db.collection('visits_tiles').limit(1).get()
    .then(snapshot => {
      console.log(`📈 visits_tiles 컬렉션: ${snapshot.size}개 문서 발견`);
      process.exit(0);
    })
    .catch(error => {
      console.log('❌ Firestore 접근 오류:', error.message);
      console.log('💡 서비스 계정 키가 필요합니다');
      process.exit(1);
    });
    
} catch (error) {
  console.log('❌ Firebase 초기화 오류:', error.message);
  process.exit(1);
}
