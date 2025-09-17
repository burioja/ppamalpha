const admin = require('firebase-admin');

// Firebase Admin SDK 초기화
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://ppamproto-439623-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function checkPosts() {
  try {
    console.log('🔍 포스트 데이터 확인 중...');
    
    // 1. 전체 포스트 개수 확인
    const allPostsSnapshot = await db.collection('posts').limit(10).get();
    console.log(`📊 전체 포스트 개수: ${allPostsSnapshot.docs.length}개`);
    
    if (allPostsSnapshot.docs.length > 0) {
      console.log('\n📋 샘플 포스트 데이터:');
      allPostsSnapshot.docs.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\n포스트 ${index + 1}:`);
        console.log(`  - ID: ${doc.id}`);
        console.log(`  - 제목: ${data.title || 'N/A'}`);
        console.log(`  - 위치: ${data.location?.latitude}, ${data.location?.longitude}`);
        console.log(`  - 활성: ${data.isActive}`);
        console.log(`  - 수집됨: ${data.isCollected}`);
        console.log(`  - 만료일: ${data.expiresAt?.toDate()}`);
        console.log(`  - 리워드: ${data.reward}`);
        console.log(`  - S2_10: ${data.s2_10 || 'N/A'}`);
        console.log(`  - S2_12: ${data.s2_12 || 'N/A'}`);
        console.log(`  - rewardType: ${data.rewardType || 'N/A'}`);
        console.log(`  - fogLevel: ${data.fogLevel || 'N/A'}`);
      });
    } else {
      console.log('❌ 포스트가 없습니다. 포스트를 먼저 생성해야 합니다.');
    }
    
    // 2. 활성 포스트만 확인
    const activePostsSnapshot = await db.collection('posts')
      .where('isActive', '==', true)
      .limit(10)
      .get();
    console.log(`\n✅ 활성 포스트 개수: ${activePostsSnapshot.docs.length}개`);
    
    // 3. 수집되지 않은 포스트만 확인
    const uncollectedPostsSnapshot = await db.collection('posts')
      .where('isActive', '==', true)
      .where('isCollected', '==', false)
      .limit(10)
      .get();
    console.log(`\n🎯 수집되지 않은 포스트 개수: ${uncollectedPostsSnapshot.docs.length}개`);
    
    // 4. 만료되지 않은 포스트만 확인
    const now = admin.firestore.Timestamp.now();
    const unexpiredPostsSnapshot = await db.collection('posts')
      .where('isActive', '==', true)
      .where('isCollected', '==', false)
      .where('expiresAt', '>', now)
      .limit(10)
      .get();
    console.log(`\n⏰ 만료되지 않은 포스트 개수: ${unexpiredPostsSnapshot.docs.length}개`);
    
  } catch (error) {
    console.error('❌ 오류 발생:', error);
  }
}

checkPosts();
