const admin = require('firebase-admin');

// Firebase Admin SDK 초기화
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkVisitedTiles(userId = null) {
  console.log('=== 방문 타일 데이터 확인 ===\n');

  try {
    // 1. visits_tiles 컬렉션의 모든 사용자 확인
    console.log('1. visits_tiles 컬렉션 사용자 목록:');
    const visitsTilesSnapshot = await db.collection('visits_tiles').get();
    console.log(`총 ${visitsTilesSnapshot.size}명의 사용자가 타일을 방문했습니다.`);
    
    const userIds = [];
    visitsTilesSnapshot.forEach(doc => {
      console.log(`- 사용자 ID: ${doc.id}`);
      userIds.push(doc.id);
    });

    // 2. 특정 사용자 또는 첫 번째 사용자의 방문 타일 확인
    const targetUserId = userId || userIds[0];
    if (!targetUserId) {
      console.log('\n❌ 방문한 타일이 있는 사용자가 없습니다.');
      return;
    }

    console.log(`\n2. 사용자 "${targetUserId}"의 방문 타일:`);
    const visitedSnapshot = await db
      .collection('visits_tiles')
      .doc(targetUserId)
      .collection('visited')
      .orderBy('visitedAt', 'desc')
      .limit(20) // 최근 20개만
      .get();

    console.log(`총 ${visitedSnapshot.size}개의 방문 타일`);
    
    let clearCount = 0, grayCount = 0, darkCount = 0;
    
    visitedSnapshot.forEach(doc => {
      const data = doc.data();
      const fogLevel = data.fogLevel || 3;
      const distance = data.distance || 0;
      const visitedAt = data.visitedAt ? data.visitedAt.toDate() : null;
      
      // fog level 분류
      if (fogLevel === 1) clearCount++;
      else if (fogLevel === 2) grayCount++;
      else darkCount++;
      
      console.log(`- 타일 ID: ${doc.id}`);
      console.log(`  fogLevel: ${fogLevel} (${getFogLevelName(fogLevel)})`);
      console.log(`  distance: ${distance.toFixed(3)}km`);
      console.log(`  visitedAt: ${visitedAt ? visitedAt.toLocaleString() : 'N/A'}`);
      if (data.location) {
        console.log(`  location: ${data.location.latitude}, ${data.location.longitude}`);
      }
      console.log('');
    });

    console.log('📊 방문 타일 통계:');
    console.log(`- 투명 (fogLevel 1): ${clearCount}개`);
    console.log(`- 회색 (fogLevel 2): ${grayCount}개`);
    console.log(`- 검은색 (fogLevel 3): ${darkCount}개`);

    // 3. 최신 타일의 좌표 정보 출력 (서버 테스트용)
    if (visitedSnapshot.size > 0) {
      const latestDoc = visitedSnapshot.docs[0];
      const tileId = latestDoc.id;
      const [zoom, x, y] = tileId.split('_').map(Number);
      
      console.log(`\n🎯 최신 방문 타일 서버 테스트 URL:`);
      console.log(`http://localhost:8080/tiles/${targetUserId}/${zoom}/${x}/${y}.png`);
    }

  } catch (error) {
    console.error('오류 발생:', error);
  }

  console.log('\n=== 확인 완료 ===');
  process.exit(0);
}

function getFogLevelName(level) {
  switch(level) {
    case 1: return '투명';
    case 2: return '회색';
    case 3: return '검은색';
    default: return '알수없음';
  }
}

// 실행
const userId = process.argv[2]; // 옵션: node check_visited_tiles.js USER_ID
checkVisitedTiles(userId);
