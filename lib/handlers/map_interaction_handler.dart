import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/map_marker_controller.dart';
import '../models/post_model.dart';
import '../widgets/map_popup_widget.dart';
import '../widgets/map_info_dialog.dart';

/// 사용자 상호작용을 담당하는 핸들러
class MapInteractionHandler {
  final MapMarkerController _markerController;
  final Function(LatLng) onNavigateToLocation;
  final Function(PostModel) onCollectPost;
  final Function(PostModel) onSharePost;
  final Function(PostModel) onEditPost;
  final Function(PostModel) onDeletePost;
  final Function(String) onShowSnackBar;

  // 상호작용 상태
  MapMarkerItem? _selectedMarkerItem;
  PostModel? _selectedPost;
  bool _isPopupVisible = false;
  bool _isDialogVisible = false;

  // 콜백 함수들
  MapInteractionHandler({
    required MapMarkerController markerController,
    required this.onNavigateToLocation,
    required this.onCollectPost,
    required this.onSharePost,
    required this.onEditPost,
    required this.onDeletePost,
    required this.onShowSnackBar,
  }) : _markerController = markerController;

  // Getters
  MapMarkerItem? get selectedMarkerItem => _selectedMarkerItem;
  PostModel? get selectedPost => _selectedPost;
  bool get isPopupVisible => _isPopupVisible;
  bool get isDialogVisible => _isDialogVisible;

  /// 마커 클릭 처리
  void onMarkerTapped(String markerId) {
    final markerItem = _markerController.findMarkerItem(markerId);
    final post = _markerController.findPost(markerId);
    
    if (markerItem != null) {
      _handleMarkerItemTap(markerItem);
    } else if (post != null) {
      _handlePostTap(post);
    }
  }

  /// 마커 아이템 탭 처리
  void _handleMarkerItemTap(MapMarkerItem markerItem) {
    _selectedMarkerItem = markerItem;
    _selectedPost = null;
    _isPopupVisible = true;
    
    onShowSnackBar('마커 선택됨: ${markerItem.title}');
  }

  /// 포스트 탭 처리
  void _handlePostTap(PostModel post) {
    _selectedPost = post;
    _selectedMarkerItem = null;
    _isPopupVisible = true;
    
    onShowSnackBar('포스트 선택됨: ${post.title}');
  }

  /// 마커 롱프레스 처리
  void onMarkerLongPress(String markerId) {
    final markerItem = _markerController.findMarkerItem(markerId);
    final post = _markerController.findPost(markerId);
    
    if (markerItem != null) {
      _showMarkerItemDialog(markerItem);
    } else if (post != null) {
      _showPostDialog(post);
    }
  }

  /// 마커 아이템 다이얼로그 표시
  void _showMarkerItemDialog(MapMarkerItem markerItem) {
    _selectedMarkerItem = markerItem;
    _selectedPost = null;
    _isDialogVisible = true;
    _isPopupVisible = false;
  }

  /// 포스트 다이얼로그 표시
  void _showPostDialog(PostModel post) {
    _selectedPost = post;
    _selectedMarkerItem = null;
    _isDialogVisible = true;
    _isPopupVisible = false;
  }

  /// 지도 롱프레스 처리 (새 마커 생성)
  void onMapLongPress(LatLng position) {
    _showCreateMarkerDialog(position);
  }

  /// 새 마커 생성 다이얼로그 표시
  void _showCreateMarkerDialog(LatLng position) {
    // TODO: 새 마커 생성 다이얼로그 구현
    onShowSnackBar('새 마커 생성: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
  }

  /// 지도 탭 처리 (팝업/다이얼로그 닫기)
  void onMapTap() {
    _closeAllOverlays();
  }

  /// 모든 오버레이 닫기
  void _closeAllOverlays() {
    _isPopupVisible = false;
    _isDialogVisible = false;
    _selectedMarkerItem = null;
    _selectedPost = null;
  }

  /// 팝업 닫기
  void closePopup() {
    _isPopupVisible = false;
  }

  /// 다이얼로그 닫기
  void closeDialog() {
    _isDialogVisible = false;
  }

  /// 길찾기 실행
  void navigateToLocation() {
    final position = _getSelectedPosition();
    if (position != null) {
      onNavigateToLocation(position);
      _closeAllOverlays();
    }
  }

  /// 포스트 수집
  void collectPost() {
    if (_selectedPost != null) {
      onCollectPost(_selectedPost!);
      onShowSnackBar('포스트가 수집되었습니다');
      _closeAllOverlays();
    }
  }

  /// 포스트 공유
  void sharePost() {
    if (_selectedPost != null) {
      onSharePost(_selectedPost!);
      onShowSnackBar('포스트가 공유되었습니다');
    }
  }

  /// 포스트 편집
  void editPost() {
    if (_selectedPost != null) {
      onEditPost(_selectedPost!);
      _closeAllOverlays();
    }
  }

  /// 포스트 삭제
  void deletePost() {
    if (_selectedPost != null) {
      onDeletePost(_selectedPost!);
      onShowSnackBar('포스트가 삭제되었습니다');
      _closeAllOverlays();
    }
  }

  /// 선택된 위치 가져오기
  LatLng? _getSelectedPosition() {
    if (_selectedMarkerItem != null) {
      return _selectedMarkerItem!.position;
    } else if (_selectedPost != null) {
      return LatLng(_selectedPost!.location.latitude, _selectedPost!.location.longitude);
    }
    return null;
  }

  /// 팝업 위젯 생성
  Widget? buildPopupWidget() {
    if (!_isPopupVisible) return null;
    
    if (_selectedMarkerItem != null) {
      return MapPopupWidget(
        markerItem: _selectedMarkerItem,
        onClose: closePopup,
        onNavigate: navigateToLocation,
        onCollect: _selectedMarkerItem!.data['type'] == 'post_place' ? collectPost : null,
        onShare: sharePost,
        isMyPost: _isMyPost(_selectedMarkerItem!),
      );
    } else if (_selectedPost != null) {
      return MapPopupWidget(
        post: _selectedPost,
        onClose: closePopup,
        onNavigate: navigateToLocation,
        onCollect: collectPost,
        onShare: sharePost,
        isMyPost: _isMyPost(_selectedPost!),
      );
    }
    
    return null;
  }

  /// 다이얼로그 위젯 생성
  Widget? buildDialogWidget() {
    if (!_isDialogVisible) return null;
    
    if (_selectedMarkerItem != null) {
      return MapInfoDialog(
        markerItem: _selectedMarkerItem,
        onNavigate: navigateToLocation,
        onCollect: _selectedMarkerItem!.data['type'] == 'post_place' ? collectPost : null,
        onShare: sharePost,
        onEdit: _isMyPost(_selectedMarkerItem!) ? editPost : null,
        onDelete: _isMyPost(_selectedMarkerItem!) ? deletePost : null,
        isMyPost: _isMyPost(_selectedMarkerItem!),
      );
    } else if (_selectedPost != null) {
      return MapInfoDialog(
        post: _selectedPost,
        onNavigate: navigateToLocation,
        onCollect: collectPost,
        onShare: sharePost,
        onEdit: _isMyPost(_selectedPost!) ? editPost : null,
        onDelete: _isMyPost(_selectedPost!) ? deletePost : null,
        isMyPost: _isMyPost(_selectedPost!),
      );
    }
    
    return null;
  }

  /// 내 포스트인지 확인
  bool _isMyPost(dynamic item) {
    // TODO: 현재 사용자 ID와 비교하여 내 포스트인지 확인
    // 임시로 false 반환
    return false;
  }

  /// 상태 초기화
  void reset() {
    _closeAllOverlays();
  }

  /// 리소스 정리
  void dispose() {
    _closeAllOverlays();
  }
}
