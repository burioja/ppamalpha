import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 여러 요청을 배치로 처리하여 네트워크 요청 수를 최소화하는 서비스
class MapBatchRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 배치 처리 설정
  static const Duration _batchTimeout = Duration(milliseconds: 500);
  static const int _maxBatchSize = 500; // Firestore 배치 제한
  
  // 배치 큐
  final List<BatchRequest> _pendingRequests = [];
  Timer? _batchTimer;
  
  // 배치 처리 상태
  bool _isProcessingBatch = false;
  int _totalBatchesProcessed = 0;
  int _totalRequestsProcessed = 0;
  
  // 배치 처리 통계
  final Map<String, int> _batchStats = {};
  
  // Getters
  bool get isProcessingBatch => _isProcessingBatch;
  int get totalBatchesProcessed => _totalBatchesProcessed;
  int get totalRequestsProcessed => _totalRequestsProcessed;
  int get pendingRequestsCount => _pendingRequests.length;
  Map<String, int> get batchStats => Map.unmodifiable(_batchStats);

  /// 배치 요청 추가
  void addRequest(String action, Map<String, dynamic> data, {
    String? collection,
    String? documentId,
    BatchRequestCallback? callback,
  }) {
    final request = BatchRequest(
      action: action,
      data: data,
      collection: collection,
      documentId: documentId,
      callback: callback,
      timestamp: DateTime.now(),
    );
    
    _pendingRequests.add(request);
    _updateBatchStats(action);
    
    debugPrint('배치 요청 추가: $action (대기 중: ${_pendingRequests.length}개)');
    
    // 배치 타이머 시작
    if (_batchTimer == null) {
      _batchTimer = Timer(_batchTimeout, _processBatch);
    }
    
    // 배치 크기 제한 확인
    if (_pendingRequests.length >= _maxBatchSize) {
      _batchTimer?.cancel();
      _batchTimer = null;
      _processBatch();
    }
  }

  /// 마커 업데이트 배치 요청
  void addMarkerUpdate(String markerId, Map<String, dynamic> updates, {
    BatchRequestCallback? callback,
  }) {
    addRequest(
      'update',
      updates,
      collection: 'markers',
      documentId: markerId,
      callback: callback,
    );
  }

  /// 마커 삭제 배치 요청
  void addMarkerDelete(String markerId, {BatchRequestCallback? callback}) {
    addRequest(
      'delete',
      {},
      collection: 'markers',
      documentId: markerId,
      callback: callback,
    );
  }

  /// 마커 생성 배치 요청
  void addMarkerCreate(Map<String, dynamic> markerData, {
    BatchRequestCallback? callback,
  }) {
    addRequest(
      'create',
      markerData,
      collection: 'markers',
      callback: callback,
    );
  }

  /// 포스트 업데이트 배치 요청
  void addPostUpdate(String postId, Map<String, dynamic> updates, {
    BatchRequestCallback? callback,
  }) {
    addRequest(
      'update',
      updates,
      collection: 'posts',
      documentId: postId,
      callback: callback,
    );
  }

  /// 사용자 방문 기록 배치 요청
  void addVisitRecord(String userId, Map<String, dynamic> visitData, {
    BatchRequestCallback? callback,
  }) {
    addRequest(
      'create',
      visitData,
      collection: 'visits',
      documentId: userId,
      callback: callback,
    );
  }

  /// 배치 처리
  Future<void> _processBatch() async {
    if (_isProcessingBatch || _pendingRequests.isEmpty) return;
    
    _isProcessingBatch = true;
    _batchTimer?.cancel();
    _batchTimer = null;
    
    try {
      final batch = _firestore.batch();
      final requestsToProcess = List<BatchRequest>.from(_pendingRequests);
      _pendingRequests.clear();
      
      debugPrint('배치 처리 시작: ${requestsToProcess.length}개 요청');
      
      // 배치에 작업 추가
      for (final request in requestsToProcess) {
        try {
          _addToBatch(batch, request);
        } catch (e) {
          debugPrint('배치 작업 추가 오류: ${request.action} - $e');
          // 콜백으로 오류 전달
          request.callback?.call(false, e.toString());
        }
      }
      
      // 배치 실행
      await batch.commit();
      
      // 성공 콜백 호출
      for (final request in requestsToProcess) {
        try {
          request.callback?.call(true, null);
        } catch (e) {
          debugPrint('배치 콜백 실행 오류: $e');
        }
      }
      
      _totalBatchesProcessed++;
      _totalRequestsProcessed += requestsToProcess.length;
      
      debugPrint('배치 처리 완료: ${requestsToProcess.length}개 요청');
      
    } catch (e) {
      debugPrint('배치 처리 오류: $e');
      
      // 실패한 요청들을 다시 큐에 추가
      _pendingRequests.addAll(_pendingRequests);
      
      // 실패 콜백 호출
      for (final request in requestsToProcess) {
        try {
          request.callback?.call(false, e.toString());
        } catch (callbackError) {
          debugPrint('배치 실패 콜백 실행 오류: $callbackError');
        }
      }
    } finally {
      _isProcessingBatch = false;
      
      // 남은 요청이 있으면 다음 배치 처리
      if (_pendingRequests.isNotEmpty) {
        _batchTimer = Timer(_batchTimeout, _processBatch);
      }
    }
  }

  /// 배치에 작업 추가
  void _addToBatch(WriteBatch batch, BatchRequest request) {
    switch (request.action) {
      case 'create':
        if (request.collection != null) {
          final docRef = _firestore.collection(request.collection!).doc();
          batch.set(docRef, request.data);
        }
        break;
        
      case 'update':
        if (request.collection != null && request.documentId != null) {
          final docRef = _firestore.collection(request.collection!).doc(request.documentId);
          batch.update(docRef, request.data);
        }
        break;
        
      case 'delete':
        if (request.collection != null && request.documentId != null) {
          final docRef = _firestore.collection(request.collection!).doc(request.documentId);
          batch.delete(docRef);
        }
        break;
        
      default:
        throw ArgumentError('지원하지 않는 배치 작업: ${request.action}');
    }
  }

  /// 즉시 배치 처리 (타이머 대기 없음)
  Future<void> processBatchImmediately() async {
    if (_pendingRequests.isNotEmpty) {
      _batchTimer?.cancel();
      _batchTimer = null;
      await _processBatch();
    }
  }

  /// 배치 통계 업데이트
  void _updateBatchStats(String action) {
    _batchStats[action] = (_batchStats[action] ?? 0) + 1;
  }

  /// 배치 통계 가져오기
  Map<String, dynamic> getDetailedStats() {
    return {
      'totalBatchesProcessed': _totalBatchesProcessed,
      'totalRequestsProcessed': _totalRequestsProcessed,
      'pendingRequestsCount': _pendingRequests.length,
      'isProcessingBatch': _isProcessingBatch,
      'batchStats': Map.unmodifiable(_batchStats),
      'averageRequestsPerBatch': _totalBatchesProcessed > 0 
          ? _totalRequestsProcessed / _totalBatchesProcessed 
          : 0.0,
    };
  }

  /// 배치 큐 상태 확인
  bool hasPendingRequests() {
    return _pendingRequests.isNotEmpty;
  }

  /// 특정 타입의 대기 중인 요청 수
  int getPendingRequestCountByType(String action) {
    return _pendingRequests.where((req) => req.action == action).length;
  }

  /// 배치 큐 정리
  void clearBatchQueue() {
    _pendingRequests.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
    debugPrint('배치 큐 정리 완료');
  }

  /// 배치 처리 강제 중단
  Future<void> forceStopBatchProcessing() async {
    _isProcessingBatch = false;
    _batchTimer?.cancel();
    _batchTimer = null;
    
    // 대기 중인 요청들을 즉시 처리
    if (_pendingRequests.isNotEmpty) {
      await _processBatch();
    }
    
    debugPrint('배치 처리 강제 중단 완료');
  }

  /// 배치 처리 재시작
  void restartBatchProcessing() {
    if (_pendingRequests.isNotEmpty && _batchTimer == null) {
      _batchTimer = Timer(_batchTimeout, _processBatch);
      debugPrint('배치 처리 재시작');
    }
  }

  /// 배치 처리 상태 모니터링
  Stream<BatchProcessingStatus> getBatchProcessingStatus() {
    return Stream.periodic(const Duration(milliseconds: 100), (_) {
      return BatchProcessingStatus(
        isProcessing: _isProcessingBatch,
        pendingCount: _pendingRequests.length,
        totalProcessed: _totalRequestsProcessed,
        totalBatches: _totalBatchesProcessed,
      );
    });
  }

  /// 리소스 정리
  void dispose() {
    _batchTimer?.cancel();
    _pendingRequests.clear();
    _batchStats.clear();
    debugPrint('MapBatchRequestService 리소스 정리 완료');
  }
}

/// 배치 요청 데이터 클래스
class BatchRequest {
  final String action;
  final Map<String, dynamic> data;
  final String? collection;
  final String? documentId;
  final BatchRequestCallback? callback;
  final DateTime timestamp;

  BatchRequest({
    required this.action,
    required this.data,
    this.collection,
    this.documentId,
    this.callback,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'BatchRequest(action: $action, collection: $collection, documentId: $documentId)';
  }
}

/// 배치 요청 콜백 타입
typedef BatchRequestCallback = void Function(bool success, String? error);

/// 배치 처리 상태 클래스
class BatchProcessingStatus {
  final bool isProcessing;
  final int pendingCount;
  final int totalProcessed;
  final int totalBatches;

  BatchProcessingStatus({
    required this.isProcessing,
    required this.pendingCount,
    required this.totalProcessed,
    required this.totalBatches,
  });

  @override
  String toString() {
    return 'BatchProcessingStatus(processing: $isProcessing, pending: $pendingCount, processed: $totalProcessed, batches: $totalBatches)';
  }
}
