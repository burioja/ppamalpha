import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Firebase Admin이 이미 초기화되었는지 확인
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// 마커 확인 시 리워드 지급 트리거
export const onReceiptConfirmed = functions.firestore
  .document('receipts/{uid}/items/{markerId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    
    // 확인 상태가 변경되었을 때만 처리
    if (!before.confirmed && after.confirmed) {
      const { uid, markerId } = context.params;
      const confirmId = `${markerId}_${uid}`;
      
      try {
        // 멱등성 보장
        const confirmRef = db.collection('confirmations').doc(confirmId);
        const confirmSnap = await confirmRef.get();
        if (confirmSnap.exists) {
          console.log(`이미 처리된 확인: ${confirmId}`);
          return;
        }

        // 트랜잭션으로 정산 처리
        await db.runTransaction(async (tx) => {
          // 마커 정보 조회
          const markerRef = db.collection('markers').doc(markerId);
          const markerSnap = await tx.get(markerRef);
          if (!markerSnap.exists) {
            throw new Error('Marker not found');
          }

          const markerData = markerSnap.data();
          const reward = markerData?.reward || 0;
          
          if (reward <= 0) {
            console.log(`마커 ${markerId}에 리워드가 없음`);
            return; // 리워드가 없으면 스킵
          }

          // 80/20 분배
          const toUser = Math.floor(reward * 0.8);
          const toOperator = reward - toUser;

          // 원장 기록
          const ledgerRef = db.collection('ledger').doc();
          tx.set(ledgerRef, {
            type: 'credit',
            to: uid,
            from: 'escrow',
            amount: toUser,
            memo: `marker:${markerId} confirmed reward`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const operatorRef = db.collection('ledger').doc();
          tx.set(operatorRef, {
            type: 'credit',
            to: 'operator',
            from: 'escrow',
            amount: toOperator,
            memo: `marker:${markerId} operator fee`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // escrow 상태 업데이트
          const escrowRef = db.collection('rewards').doc('escrow')
            .collection('items').doc(confirmId);
          tx.set(escrowRef, {
            markerId,
            receiverId: uid,
            status: 'released',
            amount: reward,
            releasedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });

          // 멱등성 키 설정
          tx.set(confirmRef, {
            ok: true,
            at: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`리워드 정산 완료: ${markerId} -> ${uid} (${toUser}원)`);
        });
      } catch (error) {
        console.error(`리워드 정산 실패: ${markerId}`, error);
        // 에러가 발생해도 트리거는 성공으로 처리 (재시도 가능)
      }
    }
  });
