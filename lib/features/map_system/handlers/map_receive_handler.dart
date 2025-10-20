import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'package:vibration/vibration.dart';
import '../../../core/models/marker/marker_model.dart';
import '../../../core/services/data/post_collection_service.dart';
import '../models/receipt_item.dart';
import '../widgets/receive_carousel.dart';

/// 맵 화면 포스트 수령 핸들러
/// 
/// **책임**: 
/// - 주변 마커 수령 처리
/// - 수령 캐러셀 표시
/// - 수령 후 업데이트
class MapReceiveHandler {
  /// 모두 수령하기 처리
  /// 
  /// [context]: BuildContext
  /// [currentPosition]: 현재 위치
  /// [markers]: 현재 표시 중인 마커 목록
  /// [onComplete]: 수령 완료 후 콜백
  static Future<void> handleReceiveAll({
    required BuildContext context,
    required LatLng currentPosition,
    required List<MarkerModel> markers,
    required VoidCallback onComplete,
  }) async {
    final actuallyReceived = <ReceiptItem>[];
    final failedToReceive = <String>[];
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      // 1. 현재 위치에서 200m 이내의 마커들 찾기
      final nearbyMarkers = <MarkerModel>[];
      
      for (final marker in markers) {
        // 마커와 현재 위치 간의 거리 계산
        final distance = _calculateDistance(currentPosition, marker.position);
        
        // 200m 이내이고, 본인이 배포한 마커가 아니고, 수량이 있는 경우
        if (distance <= 200 && 
            marker.creatorId != user.uid && 
            marker.remainingQuantity > 0 && 
            marker.isActive) {
          nearbyMarkers.add(marker);
        }
      }

      if (nearbyMarkers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('200m 이내에 수령 가능한 포스트가 없습니다'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 2. 각 마커의 포스트 수령
      final postCollectionService = PostCollectionService();
      
      for (final marker in nearbyMarkers) {
        try {
          // PostCollectionService 사용
          await postCollectionService.collectPost(
            postId: marker.postId,
            userId: user.uid,
          );
          
          // 수령 성공 - receipts 컬렉션에 기록
          final receiptRef = FirebaseFirestore.instance
              .collection('receipts')
              .doc(user.uid)
              .collection('items')
              .doc(marker.markerId);

          // 포스트 정보 가져오기
          String imageUrl = '';
          try {
            final postDoc = await FirebaseFirestore.instance
                .collection('posts')
                .doc(marker.postId)
                .get();
            if (postDoc.exists) {
              final postData = postDoc.data();
              final mediaUrls = postData?['mediaUrl'] as List<dynamic>?;
              imageUrl = (mediaUrls != null && mediaUrls.isNotEmpty) 
                  ? mediaUrls.first.toString() 
                  : '';
            }
          } catch (e) {
            // 이미지 조회 실패해도 계속 진행
          }

          await receiptRef.set({
            'markerId': marker.markerId,
            'postId': marker.postId,
            'imageUrl': imageUrl,
            'title': marker.title,
            'receivedAt': FieldValue.serverTimestamp(),
            'confirmed': false,
            'statusBadge': '미션 중',
          });
          
          actuallyReceived.add(ReceiptItem(
            markerId: marker.markerId,
            imageUrl: imageUrl,
            title: marker.title,
            receivedAt: DateTime.now(),
            confirmed: false,
            statusBadge: '미션 중',
          ));
        } catch (e) {
          failedToReceive.add('${marker.title} (수령 실패)');
        }
      }

      // 3. 결과 표시
      if (actuallyReceived.isNotEmpty) {
        // 진동/효과음
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 200);
        }
        
        // 캐러셀 표시
        showReceiveCarousel(
          context: context,
          receipts: actuallyReceived,
        );
        
        // 완료 콜백
        onComplete();
      }
      
      // 실패 알림
      if (failedToReceive.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일부 포스트 수령 실패: ${failedToReceive.length}개'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('포스트 수령 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// 수령 캐러셀 표시
  static void showReceiveCarousel({
    required BuildContext context,
    required List<ReceiptItem> receipts,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiveCarousel(
        items: receipts,
        onConfirmTap: (markerId) async {
          // 확인 처리
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('receipts')
                  .doc(user.uid)
                  .collection('items')
                  .doc(markerId)
                  .update({
                'confirmed': true,
                'confirmedAt': FieldValue.serverTimestamp(),
                'statusBadge': '완료',
              });
            }
          } catch (e) {
            // 확인 실패해도 계속 진행
          }
        },
      ),
    );
  }
  
  /// 두 좌표 간의 거리 계산 (미터)
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }
}

