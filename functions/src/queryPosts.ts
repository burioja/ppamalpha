import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin이 이미 초기화되었는지 확인
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// --- 타일 유틸리티 (서버용) ---
function getKmTileId(lat: number, lng: number): string {
  const tileSize = 0.009; // 1km 근사
  const tileLat = Math.floor(lat / tileSize);
  const tileLng = Math.floor(lng / tileSize);
  return `tile_${tileLat}_${tileLng}`;
}

// 거리 계산 함수 (미터 단위)
function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000; // 지구 반지름 (미터)
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function getSurroundingTilesForCircle(
  lat: number, 
  lng: number, 
  radiusKm: number
): string[] {
  const tiles = new Set<string>();
  const tileSize = 0.009; // 1km 근사
  
  // 원의 경계 박스 계산
  const latDelta = radiusKm / 111.0; // 대략적 위도 차이 (1도 ≈ 111km)
  const lngDelta = radiusKm / (111.0 * Math.cos(lat * Math.PI / 180));
  
  const minLat = lat - latDelta;
  const maxLat = lat + latDelta;
  const minLng = lng - lngDelta;
  const maxLng = lng + lngDelta;
  
  // 경계 박스 내 모든 타일 검사
  for (let tileLat = Math.floor(minLat / tileSize); tileLat <= Math.floor(maxLat / tileSize); tileLat++) {
    for (let tileLng = Math.floor(minLng / tileSize); tileLng <= Math.floor(maxLng / tileSize); tileLng++) {
      const tileId = `tile_${tileLat}_${tileLng}`;
      
      // 타일 중심점 계산
      const tileCenterLat = tileLat * tileSize + (tileSize / 2);
      const tileCenterLng = tileLng * tileSize + (tileSize / 2);
      
      // 원과 타일이 교차하는지 정확 판정
      if (circleIntersectsTile(lat, lng, radiusKm, tileCenterLat, tileCenterLng, tileSize)) {
        tiles.add(tileId);
      }
    }
  }
  
  return Array.from(tiles);
}

// 원-사각형 교차 정확 판정
function circleIntersectsTile(
  centerLat: number,
  centerLng: number,
  radiusKm: number,
  tileCenterLat: number,
  tileCenterLng: number,
  tileSize: number
): boolean {
  const halfTileSize = tileSize / 2;
  
  // 타일 경계
  const tileMinLat = tileCenterLat - halfTileSize;
  const tileMaxLat = tileCenterLat + halfTileSize;
  const tileMinLng = tileCenterLng - halfTileSize;
  const tileMaxLng = tileCenterLng + halfTileSize;
  
  // 원 중심에서 타일 경계까지의 최근접점 찾기
  const closestLat = Math.max(tileMinLat, Math.min(centerLat, tileMaxLat));
  const closestLng = Math.max(tileMinLng, Math.min(centerLng, tileMaxLng));
  
  // 최근접점과 원 중심의 거리 계산
  const distance = haversineKm(centerLat, centerLng, closestLat, closestLng);
  
  return distance <= radiusKm;
}

// 하버사인 거리 계산 (km)
function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371; // 지구 반지름 (km)
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 + 
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
            Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Fog1 타일 집합 계산
async function getFog1Tiles(
  uid: string, 
  centers: {lat: number, lng: number}[], 
  radiusKm: number
): Promise<Set<string>> {
  const fog = new Set<string>();

  try {
    // 1) 30일 이내 방문 타일
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 30 * 24 * 3600 * 1000)
    );
    
    const visitedSnap = await db.collection("users").doc(uid)
      .collection("visited_tiles")
      .where("lastVisitTime", ">=", cutoff)
      .get();
    
    visitedSnap.forEach(doc => fog.add(doc.id));

    // 2) 각 center의 1km 원과 교차하는 타일 추가
    for (const center of centers) {
      const tiles = getSurroundingTilesForCircle(center.lat, center.lng, radiusKm);
      tiles.forEach(tile => fog.add(tile));
    }

    console.log(`Fog1 타일 계산 완료: ${fog.size}개`);
    return fog;
  } catch (error) {
    console.error("Fog1 타일 계산 오류:", error);
    return new Set();
  }
}

// 메인 쿼리 함수
export const queryPosts = functions.https.onCall(async (data, context) => {
  try {
    const uid = data.userId as string;
    const centers = data.centers as {lat: number, lng: number}[];
    const radiusKm = data.radiusKm as number;
    const pageSize = Math.min(data.pageSize ?? 500, 1000); // 안전 상한
    const pageToken = data.pageToken as string | null;
    const filters = data.filters || {};

    if (!uid || !centers?.length) {
      throw new functions.https.HttpsError(
        "invalid-argument", 
        "userId/centers required"
      );
    }

    console.log(`쿼리 요청: uid=${uid}, centers=${centers.length}개, radius=${radiusKm}km`);

    // 1) Fog1 타일 집합 계산
    const fogTiles = await getFog1Tiles(uid, centers, radiusKm);
    if (fogTiles.size === 0) {
      return { items: [], nextPageToken: null };
    }

    // 2) posts_by_tile 병렬 조회
    const tileList = Array.from(fogTiles).sort();
    let tileIdx = 0;
    let lastDocId: string | null = null;

    // 페이지네이션 토큰 파싱
    if (pageToken) {
      try {
        const token = JSON.parse(Buffer.from(pageToken, "base64").toString());
        tileIdx = token.tileIdx ?? 0;
        lastDocId = token.lastDocId ?? null;
      } catch (e) {
        console.warn("잘못된 페이지 토큰:", pageToken);
      }
    }

    const result: any[] = [];
    const seen = new Set<string>();

    // 타일별로 순차 조회 (병렬로 하면 너무 많은 동시 쿼리)
    while (tileIdx < tileList.length && result.length < pageSize) {
      const tileId = tileList[tileIdx];
      
      try {
        let query = db.collection("posts_by_tile").doc(tileId).collection("posts")
          .where("isActive", "==", true)
          .where("isCollected", "==", false)
          .orderBy("updatedAt", "desc")
          .limit(pageSize - result.length);

        if (lastDocId) {
          const lastDoc = await db.collection("posts_by_tile")
            .doc(tileId).collection("posts").doc(lastDocId).get();
          if (lastDoc.exists) {
            query = query.startAfter(lastDoc);
          }
          lastDocId = null;
        }

        const snap = await query.get();
        
        if (snap.empty) {
          tileIdx++;
          continue;
        }

        // 서버 사이드 필터링
        for (const doc of snap.docs) {
          const post = doc.data();
          
          // 거리 필터: centers 중 하나라도 반경 이내면 통과
          const loc = post.location; // GeoPoint
          const passDistance = centers.some(center => 
            haversineKm(center.lat, center.lng, loc.latitude, loc.longitude) <= radiusKm
          );
          if (!passDistance) continue;

          // 추가 필터들
          if (filters.showCouponsOnly && !post.canUse) continue;
          if (filters.myPostsOnly && post.creatorId !== uid) continue;
          if (filters.minReward && (post.reward ?? 0) < filters.minReward) continue;

          // 중복 제거
          if (!seen.has(post.postId)) {
            result.push({
              ...post,
              id: doc.id,
              // GeoPoint를 일반 객체로 변환
              location: {
                latitude: loc.latitude,
                longitude: loc.longitude
              }
            });
            seen.add(post.postId);
            
            if (result.length >= pageSize) break;
          }
        }

        // 다음 페이지 준비
        if (snap.size < (pageSize - result.length)) {
          tileIdx++;
          lastDocId = null;
        } else {
          lastDocId = snap.docs[snap.docs.length - 1].id;
        }

      } catch (error) {
        console.error(`타일 ${tileId} 조회 오류:`, error);
        tileIdx++;
        lastDocId = null;
      }
    }

    // 다음 페이지 토큰 생성
    const nextToken = (tileIdx >= tileList.length && !lastDocId)
      ? null
      : Buffer.from(JSON.stringify({ tileIdx, lastDocId })).toString("base64");

    console.log(`쿼리 완료: ${result.length}개 결과, nextToken=${nextToken ? "있음" : "없음"}`);
    
    return { 
      items: result, 
      nextPageToken: nextToken,
      totalTiles: tileList.length,
      processedTiles: tileIdx
    };

  } catch (error) {
    console.error("queryPosts 오류:", error);
    throw new functions.https.HttpsError("internal", "서버 오류가 발생했습니다.");
  }
});

// 슈퍼포스트 전용 쿼리
export const querySuperPosts = functions.https.onCall(async (data, context) => {
  try {
    const uid = data.userId as string;
    const centers = data.centers as {lat: number, lng: number}[];
    const radiusKm = data.radiusKm as number;
    const pageSize = Math.min(data.pageSize ?? 200, 500);
    const pageToken = data.pageToken as string | null;

    if (!uid || !centers?.length) {
      throw new functions.https.HttpsError(
        "invalid-argument", 
        "userId/centers required"
      );
    }

    let query = db.collection("posts")
      .where("isActive", "==", true)
      .where("isCollected", "==", false)
      .where("isSuperPost", "==", true)
      .orderBy("updatedAt", "desc")
      .limit(pageSize);

    if (pageToken) {
      try {
        const lastDoc = await db.collection("posts").doc(pageToken).get();
        if (lastDoc.exists) {
          query = query.startAfter(lastDoc);
        }
      } catch (e) {
        console.warn("잘못된 슈퍼포스트 페이지 토큰:", pageToken);
      }
    }

    const snap = await query.get();
    const result: any[] = [];

    for (const doc of snap.docs) {
      const post = doc.data();
      const loc = post.location; // GeoPoint
      
      // 거리 필터만 적용 (포그레벨 무시)
      const passDistance = centers.some(center => 
        haversineKm(center.lat, center.lng, loc.latitude, loc.longitude) <= radiusKm
      );
      
      if (passDistance) {
        result.push({
          ...post,
          id: doc.id,
          location: {
            latitude: loc.latitude,
            longitude: loc.longitude
          }
        });
      }
    }

    const nextToken = snap.docs.length === pageSize 
      ? snap.docs[snap.docs.length - 1].id 
      : null;

    return { 
      items: result, 
      nextPageToken: nextToken 
    };

  } catch (error) {
    console.error("querySuperPosts 오류:", error);
    throw new functions.https.HttpsError("internal", "슈퍼포스트 조회 중 오류가 발생했습니다.");
  }
});

// 수령 가능한 포스트 조회 (마커 기반)
export const queryReceivablePosts = functions.https.onCall(async (data, context) => {
  try {
    const { lat, lng, radius = 100, uid } = data;
    
    console.log(`수령 가능 포스트 조회 요청: lat=${lat}, lng=${lng}, radius=${radius}, uid=${uid}`);
    
    if (!uid) {
      console.log('사용자 인증 실패: uid가 없음');
      throw new functions.https.HttpsError("unauthenticated", "사용자 인증이 필요합니다.");
    }

    // 1. 반경 내 마커 조회
    const now = admin.firestore.Timestamp.now();
    const markersSnap = await db.collection('markers')
      .where('isActive', '==', true)
      .where('expiresAt', '>', now)
      .get();

    console.log(`전체 활성 마커 개수: ${markersSnap.docs.length}`);

    // 2. 거리 필터링 및 본인 마커 제외
    const eligibleMarkers = [];
    
    for (const doc of markersSnap.docs) {
      const marker = doc.data();
      const location = marker.location;
      
      if (!location || !location.latitude || !location.longitude) {
        continue;
      }

      // 거리 계산 (미터 단위)
      const distance = calculateDistance(lat, lng, location.latitude, location.longitude);
      
      if (distance <= radius) {
        // 본인 마커 제외
        if (marker.creatorId !== uid) {
          eligibleMarkers.push({
            ...marker,
            id: doc.id,
            location: {
              latitude: location.latitude,
              longitude: location.longitude
            }
          });
        }
      }
    }

    console.log(`거리 필터링 및 본인 제외 후: ${eligibleMarkers.length}개`);

    // 3. 이미 받은 마커 제외
    const receivedMarkerIds = await getReceivedMarkerIds(uid);
    console.log(`이미 받은 마커 ID 개수: ${receivedMarkerIds.length}`);
    
    const finalMarkers = eligibleMarkers.filter(marker => 
      !receivedMarkerIds.includes(marker.id)
    );

    console.log(`최종 수령 가능 마커 개수: ${finalMarkers.length}`);
    return finalMarkers;

  } catch (error) {
    console.error("queryReceivablePosts 오류:", error);
    console.error("오류 상세:", {
      message: error.message,
      code: error.code,
      stack: error.stack
    });
    throw new functions.https.HttpsError("internal", "수령 가능 포스트 조회 중 오류가 발생했습니다.");
  }
});

// 사용자가 이미 받은 마커 ID 목록 조회
async function getReceivedMarkerIds(uid: string): Promise<string[]> {
  try {
    const snap = await db.collection('receipts')
      .doc(uid)
      .collection('items')
      .select('markerId')
      .get();
    
    return snap.docs.map(doc => doc.id);
  } catch (error) {
    console.error("getReceivedMarkerIds 오류:", error);
    return [];
  }
}
