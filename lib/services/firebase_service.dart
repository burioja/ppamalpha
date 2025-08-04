import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle; // ê²½ë¡œ ?˜ì •

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // JSON ?Œì¼???½ì–´ Firebase???…ë¡œ?œf?˜ëŠ” ?¨ìˆ˜
  Future<void> uploadWorkplaces() async {
    try {
      // JSON ?Œì¼ ?½ê¸°
      final String response = await rootBundle.loadString('assets/workplaces.json');
      final data = json.decode(response)['workplaces'];

      // Firestore??workplaces ì»¬ë ‰?˜ì— ?°ì´??ì¶”ê?
      for (var workplace in data) {
        final String id = workplace['id'].toString();
        final docRef = _firestore.collection('workplaces').doc(id);

        // IDê°€ ì¡´ì¬?˜ëŠ”ì§€ ?•ì¸
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          await docRef.set(workplace);
          // ?Œí¬?Œë ˆ?´ìŠ¤ '$id'ê°€ Firebase??ì¶”ê??˜ì—ˆ?µë‹ˆ??
        } else {
          // ?Œí¬?Œë ˆ?´ìŠ¤ '$id'???´ë? ì¡´ì¬?©ë‹ˆ?? ê±´ë„ˆ?ë‹ˆ??
        }
      }

      // JSON ?°ì´?°ê? Firebase???±ê³µ?ìœ¼ë¡??…ë¡œ?œë˜?ˆìŠµ?ˆë‹¤.
    } catch (e) {
      // ?…ë¡œ??ì¤??¤ë¥˜ ë°œìƒ: $e
    }
  }
}

