const admin = require('firebase-admin');

// Firebase Admin SDK 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'ppamproto-439623'
  });
}

const db = admin.firestore();

async function checkCollectedPosts() {
  const userId = 'v1W8RxAGO8REFnIIBTt1jMQXDOM2';
  
  try {
    console.log(`🔍 사용자 ${userId}의 수령된 포스트 확인 중...`);
    
    // posts 컬렉션에서 collectedBy 필드가 해당 사용자 ID인 문서들 찾기
    const collectedPostsQuery = await db.collection('posts')
      .where('collectedBy', '==', userId)
      .get();
    
    console.log(`\n=== posts 컬렉션에서 수령된 포스트 (${collectedPostsQuery.size}개) ===`);
    if (collectedPostsQuery.size > 0) {
      collectedPostsQuery.forEach(doc => {
        const data = doc.data();
        console.log(`🎉 수령된 포스트 발견!`);
        console.log(`📄 ID: ${doc.id}`);
        console.log(`📝 제목: ${data.title || 'N/A'}`);
        console.log(`👤 수령자: ${data.collectedBy || 'N/A'}`);
        console.log(`⏰ 수령 시간: ${data.collectedAt ? data.collectedAt.toDate() : 'N/A'}`);
        console.log(`✅ 수령 여부: ${data.isCollected || false}`);
        console.log(`👤 생성자: ${data.creatorId || 'N/A'}`);
        console.log(`💰 리워드: ${data.reward || 0}원`);
        console.log('---');
      });
    } else {
      console.log('❌ 수령된 포스트가 없습니다.');
    }
    
    // isCollected가 true인 포스트도 별도로 확인
    const collectedTrueQuery = await db.collection('posts')
      .where('isCollected', '==', true)
      .get();
    
    console.log(`\n=== isCollected=true인 모든 포스트 (${collectedTrueQuery.size}개) ===`);
    if (collectedTrueQuery.size > 0) {
      collectedTrueQuery.forEach(doc => {
        const data = doc.data();
        console.log(`📄 ID: ${doc.id}`);
        console.log(`📝 제목: ${data.title || 'N/A'}`);
        console.log(`👤 수령자: ${data.collectedBy || 'N/A'}`);
        console.log(`⏰ 수령 시간: ${data.collectedAt ? data.collectedAt.toDate() : 'N/A'}`);
        console.log(`👤 생성자: ${data.creatorId || 'N/A'}`);
        console.log('---');
      });
    }
    
  } catch (error) {
    console.error('❌ 데이터 조회 중 오류 발생:', error);
  }
}

checkCollectedPosts().then(() => {
  console.log('🏁 완료');
  process.exit(0);
});