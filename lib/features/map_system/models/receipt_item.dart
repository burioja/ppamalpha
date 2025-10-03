import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptItem {
  final String markerId; // postId에서 markerId로 변경
  final String imageUrl;
  final String title;
  final DateTime receivedAt;
  final bool confirmed;
  final DateTime? confirmedAt;
  final String statusBadge;

  ReceiptItem({
    required this.markerId,
    required this.imageUrl,
    required this.title,
    required this.receivedAt,
    required this.confirmed,
    this.confirmedAt,
    required this.statusBadge,
  });

  factory ReceiptItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptItem(
      markerId: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      title: data['title'] ?? '',
      receivedAt: (data['receivedAt'] as Timestamp).toDate(),
      confirmed: data['confirmed'] ?? false,
      confirmedAt: data['confirmedAt'] != null 
          ? (data['confirmedAt'] as Timestamp).toDate() 
          : null,
      statusBadge: data['statusBadge'] ?? '미션 중',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'markerId': markerId,
      'imageUrl': imageUrl,
      'title': title,
      'receivedAt': Timestamp.fromDate(receivedAt),
      'confirmed': confirmed,
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'statusBadge': statusBadge,
    };
  }

  ReceiptItem copyWith({
    String? markerId,
    String? imageUrl,
    String? title,
    DateTime? receivedAt,
    bool? confirmed,
    DateTime? confirmedAt,
    String? statusBadge,
  }) {
    return ReceiptItem(
      markerId: markerId ?? this.markerId,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      receivedAt: receivedAt ?? this.receivedAt,
      confirmed: confirmed ?? this.confirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      statusBadge: statusBadge ?? this.statusBadge,
    );
  }
}
