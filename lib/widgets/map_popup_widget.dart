import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/post_model.dart';
import '../controllers/map_marker_controller.dart';

/// 마커 클릭 시 표시되는 팝업 위젯
class MapPopupWidget extends StatelessWidget {
  final MapMarkerItem? markerItem;
  final PostModel? post;
  final VoidCallback? onClose;
  final VoidCallback? onNavigate;
  final VoidCallback? onCollect;
  final VoidCallback? onShare;
  final bool isMyPost;

  const MapPopupWidget({
    super.key,
    this.markerItem,
    this.post,
    this.onClose,
    this.onNavigate,
    this.onCollect,
    this.onShare,
    this.isMyPost = false,
  }) : assert(markerItem != null || post != null, '마커 아이템 또는 포스트 중 하나는 필요합니다');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더 (제목 + 닫기 버튼)
          _buildHeader(context),
          
          // 이미지 (있는 경우)
          if (_hasImage) _buildImage(),
          
          // 내용 정보
          _buildContent(context),
          
          // 액션 버튼들
          _buildActionButtons(context),
        ],
      ),
    );
  }

  /// 헤더 생성
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Row(
        children: [
          // 아이콘
          Icon(
            _getItemIcon(),
            color: Colors.blue[700],
            size: 24.0,
          ),
          
          const SizedBox(width: 12.0),
          
          // 제목
          Expanded(
            child: Text(
              _getItemTitle(),
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 닫기 버튼
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: Colors.grey[600],
              size: 20.0,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32.0,
              minHeight: 32.0,
            ),
          ),
        ],
      ),
    );
  }

  /// 이미지 생성
  Widget _buildImage() {
    final imageUrl = _getItemImageUrl();
    
    return Container(
      width: double.infinity,
      height: 200.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        image: DecorationImage(
          image: NetworkImage(imageUrl!),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 내용 정보 생성
  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 가격 정보
          _buildPriceInfo(),
          
          const SizedBox(height: 12.0),
          
          // 수량/보상 정보
          _buildQuantityInfo(),
          
          const SizedBox(height: 12.0),
          
          // 위치 정보
          _buildLocationInfo(),
          
          const SizedBox(height: 12.0),
          
          // 설명 (있는 경우)
          if (_hasDescription) _buildDescription(),
          
          const SizedBox(height: 12.0),
          
          // 만료 정보 (있는 경우)
          if (_hasExpiry) _buildExpiryInfo(),
        ],
      ),
    );
  }

  /// 가격 정보 생성
  Widget _buildPriceInfo() {
    final price = _getItemPrice();
    final isPostPlace = _isPostPlace();
    
    return Row(
      children: [
        Icon(
          Icons.attach_money,
          color: Colors.green[600],
          size: 20.0,
        ),
        const SizedBox(width: 8.0),
        Text(
          isPostPlace ? '보상: $price원' : '가격: $price원',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: Colors.green[700],
          ),
        ),
      ],
    );
  }

  /// 수량/보상 정보 생성
  Widget _buildQuantityInfo() {
    if (post != null) {
      return Row(
        children: [
          Icon(
            Icons.inventory,
            color: Colors.blue[600],
            size: 20.0,
          ),
          const SizedBox(width: 8.0),
          Text(
            '수량: ${post!.remainingAmount}개',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.grey[700],
            ),
          ),
        ],
      );
    } else if (markerItem != null) {
      return Row(
        children: [
          Icon(
            Icons.inventory,
            color: Colors.blue[600],
            size: 20.0,
          ),
          const SizedBox(width: 8.0),
          Text(
            '수량: ${markerItem!.remainingAmount}개',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.grey[700],
            ),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  /// 위치 정보 생성
  Widget _buildLocationInfo() {
    final position = _getItemPosition();
    
    return Row(
      children: [
        Icon(
          Icons.location_on,
          color: Colors.red[600],
          size: 20.0,
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            '위치: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 설명 생성
  Widget _buildDescription() {
    final description = _getItemDescription();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '설명',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          description!,
          style: TextStyle(
            fontSize: 14.0,
            color: Colors.grey[700],
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 만료 정보 생성
  Widget _buildExpiryInfo() {
    final expiryDate = _getItemExpiryDate();
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: daysLeft <= 3 ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: daysLeft <= 3 ? Colors.red[200]! : Colors.orange[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: daysLeft <= 3 ? Colors.red[600] : Colors.orange[600],
            size: 16.0,
          ),
          const SizedBox(width: 8.0),
          Text(
            daysLeft <= 0 
                ? '만료됨'
                : daysLeft <= 3 
                    ? '${daysLeft}일 후 만료'
                    : '${daysLeft}일 후 만료',
            style: TextStyle(
              fontSize: 12.0,
              color: daysLeft <= 3 ? Colors.red[700] : Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 액션 버튼들 생성
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // 내비게이션 버튼
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.directions, size: 18.0),
              label: const Text('길찾기'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.blue[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12.0),
          
          // 수집/공유 버튼
          if (!isMyPost) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCollect,
                icon: const Icon(Icons.collections_bookmark, size: 18.0),
                label: const Text('수집'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12.0),
          ],
          
          // 공유 버튼
          SizedBox(
            width: 48.0,
            child: IconButton(
              onPressed: onShare,
              icon: Icon(
                Icons.share,
                color: Colors.grey[600],
                size: 20.0,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 헬퍼 메서드들
  
  /// 아이템 아이콘 가져오기
  IconData _getItemIcon() {
    if (post != null) {
      return Icons.post_add;
    } else if (markerItem != null) {
      return markerItem!.data['type'] == 'post_place' 
          ? Icons.post_add 
          : Icons.place;
    }
    return Icons.place;
  }

  /// 아이템 제목 가져오기
  String _getItemTitle() {
    if (post != null) {
      return post!.title;
    } else if (markerItem != null) {
      return markerItem!.title;
    }
    return '알 수 없음';
  }

  /// 아이템 이미지 URL 가져오기
  String? _getItemImageUrl() {
    if (post != null && post!.imageUrl.isNotEmpty) {
      return post!.imageUrl;
    } else if (markerItem != null) {
      return markerItem!.imageUrl;
    }
    return null;
  }

  /// 아이템 가격 가져오기
  String _getItemPrice() {
    if (post != null) {
      return post!.reward.toString();
    } else if (markerItem != null) {
      return markerItem!.price;
    }
    return '0';
  }

  /// 아이템 위치 가져오기
  LatLng _getItemPosition() {
    if (post != null) {
      return LatLng(post!.location.latitude, post!.location.longitude);
    } else if (markerItem != null) {
      return markerItem!.position;
    }
    return const LatLng(0, 0);
  }

  /// 아이템 설명 가져오기
  String? _getItemDescription() {
    if (post != null && post!.description.isNotEmpty) {
      return post!.description;
    } else if (markerItem != null) {
      return markerItem!.data['description'] as String?;
    }
    return null;
  }

  /// 아이템 만료 날짜 가져오기
  DateTime? _getItemExpiryDate() {
    if (post != null) {
      return post!.expiryDate;
    } else if (markerItem != null) {
      return markerItem!.expiryDate;
    }
    return null;
  }

  /// 포스트 플레이스인지 확인
  bool _isPostPlace() {
    if (post != null) {
      return true;
    } else if (markerItem != null) {
      return markerItem!.data['type'] == 'post_place';
    }
    return false;
  }

  /// 이미지가 있는지 확인
  bool get _hasImage => _getItemImageUrl() != null;

  /// 설명이 있는지 확인
  bool get _hasDescription => _getItemDescription() != null && _getItemDescription()!.isNotEmpty;

  /// 만료 날짜가 있는지 확인
  bool get _hasExpiry => _getItemExpiryDate() != null;
}

/// 간단한 마커 정보 팝업 (퀵 뷰용)
class MapQuickInfoPopup extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const MapQuickInfoPopup({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // 부제목
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // 닫기 버튼
            if (onClose != null)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 12.0,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
