import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin이 이미 초기화되었는지 확인
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// 타일 ID 계산 (서버용)
function getKmTileId(lat: number, lng: number): string {
  const tileSize = 0.009; // 1km 근사
  const tileLat = Math.floor(lat / tileSize);
  const tileLng = Math.floor(lng / tileSize);
  return `tile_${tileLat}_${tileLng}`;
}

// 포스트 생성/업데이트 시 역색인 생성
export const indexPostToTiles = functions.firestore
  .document('posts/{postId}')
  .onWrite(async (change, context) => {
    const postId = context.params.postId;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    try {
      // 삭제된 경우
      if (!after) {
        await removePostFromAllTiles(postId);
        return;
      }

      const post = after;
      const location = post.location; // GeoPoint
      
      if (!location) {
        console.warn(`포스트 ${postId}에 위치 정보가 없습니다.`);
        return;
      }

      const tileId = getKmTileId(location.latitude, location.longitude);
      
      // 이전 위치와 다른 경우 이전 타일에서 제거
      if (before && before.location) {
        const oldTileId = getKmTileId(before.location.latitude, before.location.longitude);
        if (oldTileId !== tileId) {
          await removePostFromTile(oldTileId, postId);
        }
      }

      // 새 위치에 추가
      await addPostToTile(tileId, postId, post);

      console.log(`포스트 ${postId}를 타일 ${tileId}에 인덱싱했습니다.`);

    } catch (error) {
      console.error(`포스트 ${postId} 인덱싱 오류:`, error);
    }
  });

// 포스트를 특정 타일에 추가
async function addPostToTile(tileId: string, postId: string, postData: any) {
  const tileRef = db.collection('posts_by_tile').doc(tileId);
  const postRef = tileRef.collection('posts').doc(postId);

  // 최소 필드만 저장 (읽기 최적화)
  const indexedData = {
    postId: postData.postId || postId,
    creatorId: postData.creatorId,
    location: postData.location, // GeoPoint
    reward: postData.reward || 0,
    isActive: postData.isActive !== false,
    isCollected: postData.isCollected === true,
    canUse: postData.canUse === true,
    isSuperPost: postData.isSuperPost === true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    // 메타데이터
    title: postData.title || '',
    description: postData.description || '',
    expiresAt: postData.expiresAt,
    createdAt: postData.createdAt
  };

  await postRef.set(indexedData);
}

// 포스트를 특정 타일에서 제거
async function removePostFromTile(tileId: string, postId: string) {
  const postRef = db.collection('posts_by_tile')
    .doc(tileId)
    .collection('posts')
    .doc(postId);
  
  await postRef.delete();
}

// 포스트를 모든 타일에서 제거 (삭제 시)
async function removePostFromAllTiles(postId: string) {
  // 모든 posts_by_tile 컬렉션을 검색하는 것은 비효율적이므로
  // 실제로는 포스트 데이터에서 tileId를 추적하거나
  // 별도의 인덱스 컬렉션을 유지하는 것이 좋습니다.
  
  // 간단한 구현: 모든 타일을 순회 (실제로는 최적화 필요)
  const tilesSnapshot = await db.collection('posts_by_tile').get();
  
  const batch = db.batch();
  let batchCount = 0;
  
  for (const tileDoc of tilesSnapshot.docs) {
    const postRef = tileDoc.ref.collection('posts').doc(postId);
    batch.delete(postRef);
    batchCount++;
    
    // Firestore 배치 제한 (500개)
    if (batchCount >= 500) {
      await batch.commit();
      batchCount = 0;
    }
  }
  
  if (batchCount > 0) {
    await batch.commit();
  }
}

// 포스트 상태 업데이트 시 역색인도 동기화
export const syncPostStatus = functions.firestore
  .document('posts/{postId}')
  .onUpdate(async (change, context) => {
    const postId = context.params.postId;
    const before = change.before.data();
    const after = change.after.data();

    // 상태 변경 감지
    const statusChanged = 
      before.isActive !== after.isActive ||
      before.isCollected !== after.isCollected ||
      before.canUse !== after.canUse;

    if (!statusChanged) return;

    try {
      const location = after.location;
      if (!location) return;

      const tileId = getKmTileId(location.latitude, location.longitude);
      const postRef = db.collection('posts_by_tile')
        .doc(tileId)
        .collection('posts')
        .doc(postId);

      // 상태만 업데이트
      await postRef.update({
        isActive: after.isActive,
        isCollected: after.isCollected,
        canUse: after.canUse,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`포스트 ${postId} 상태를 타일 ${tileId}에 동기화했습니다.`);

    } catch (error) {
      console.error(`포스트 ${postId} 상태 동기화 오류:`, error);
    }
  });
