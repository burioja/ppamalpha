import 'package:flutter/material.dart';

class MapSearchScreen extends StatelessWidget {
  const MapSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextField(
          decoration: InputDecoration(
            hintText: 'ê²€?‰ì–´ë¥??…ë ¥?˜ì„¸??,
            border: InputBorder.none,
          ),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('?”¹ ?ì£¼ ì°¾ëŠ” ?¥ì†Œ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...List.generate(3, (i) => const ListTile(title: Text('?ì£¼ ì°¾ëŠ” ?¥ì†Œ?…ë‹ˆ??), subtitle: Text('ì§€?? •ë³?))),

          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('?•’ ìµœê·¼ ê²€??, style: TextStyle(fontWeight: FontWeight.bold)),
                Text('?? œ', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          ...List.generate(10, (i) => const ListTile(title: Text('ìµœê·¼ ê²€?‰í•œ ?¨ì–´?…ë‹ˆ??), subtitle: Text('ì§€?? •ë³?))),
        ],
      ),
    );
  }
}
