import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'package:intl/intl.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final bool showStatus;
  final bool showExpiry;

  const PostCard({
    super.key, 
    required this.post, 
    this.onTap,
    this.showStatus = true,
    this.showExpiry = true,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = post.isExpired();
    final isCollected = post.isCollected;
    final daysUntilExpiry = post.expiresAt.difference(DateTime.now()).inDays;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 제목과 상태
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.title.isNotEmpty ? post.title : '(제목 없음)',
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusChip(isExpired, isCollected),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // 설명
              if (post.description.isNotEmpty) ...[
                Text(
                  post.description,
                  style: const TextStyle(
                    fontSize: 14, 
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              
              // 메타 정보 행
              Row(
                children: [
                  // 작성자 정보
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.creatorName,
                            style: TextStyle(
                              fontSize: 13, 
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 리워드
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      '₩${NumberFormat('#,###').format(post.reward)}',
                      style: const TextStyle(
                        color: Colors.blue, 
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 하단 정보 행
              Row(
                children: [
                  // 생성일
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('MM/dd').format(post.createdAt)}',
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 만료일 또는 남은 기간
                  if (showExpiry) ...[
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                                                     Icon(
                             isExpired ? Icons.access_time_filled : Icons.timer,
                             size: 14, 
                             color: isExpired ? Colors.red.shade500 : Colors.orange.shade500,
                           ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired 
                              ? '만료됨' 
                              : daysUntilExpiry > 0 
                                ? '${daysUntilExpiry}일 남음'
                                : '오늘 만료',
                            style: TextStyle(
                              fontSize: 12, 
                              color: isExpired ? Colors.red.shade500 : Colors.orange.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              
              // 수집 정보 (주운 포스트인 경우)
              if (isCollected && post.collectedAt != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('MM/dd HH:mm').format(post.collectedAt!)} 수집',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isExpired, bool isCollected) {
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
                         Icon(Icons.access_time_filled, size: 14, color: Colors.red.shade600),
            const SizedBox(width: 4),
            Text(
              '만료',
              style: TextStyle(
                fontSize: 11, 
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    if (isCollected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              '수집됨',
              style: TextStyle(
                fontSize: 11, 
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    if (!post.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              '비활성',
              style: TextStyle(
                fontSize: 11, 
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio_button_checked, size: 14, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text(
            '활성',
            style: TextStyle(
              fontSize: 11, 
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}



