const admin = require('firebase-admin');

// Firebase Admin SDK 초기화
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkFirestoreData() {
  console.log('=== Firestore 데이터 확인 ===\n');

  try {
    // 1. workplaces 컬렉션 확인
    console.log('1. workplaces 컬렉션:');
    const workplacesSnapshot = await db.collection('workplaces').get();
    console.log(`총 ${workplacesSnapshot.size}개의 워크플레이스`);
    workplacesSnapshot.forEach(doc => {
      console.log(`- ${doc.id}:`, doc.data());
    });

    // 2. places 컬렉션 확인
    console.log('\n2. places 컬렉션:');
    const placesSnapshot = await db.collection('places').get();
    console.log(`총 ${placesSnapshot.size}개의 플레이스`);
    placesSnapshot.forEach(doc => {
      console.log(`- ${doc.id}:`, doc.data());
    });

    // 3. users 컬렉션 확인
    console.log('\n3. users 컬렉션:');
    const usersSnapshot = await db.collection('users').get();
    console.log(`총 ${usersSnapshot.size}개의 사용자`);
    usersSnapshot.forEach(doc => {
      console.log(`- ${doc.id}:`, doc.data());
    });

    // 4. user_tracks 컬렉션 확인
    console.log('\n4. user_tracks 컬렉션:');
    const tracksSnapshot = await db.collection('user_tracks').get();
    console.log(`총 ${tracksSnapshot.size}개의 트랙`);
    tracksSnapshot.forEach(doc => {
      console.log(`- ${doc.id}:`, doc.data());
    });

  } catch (error) {
    console.error('오류 발생:', error);
  }

  console.log('\n=== 확인 완료 ===');
  process.exit(0);
}

checkFirestoreData(); 