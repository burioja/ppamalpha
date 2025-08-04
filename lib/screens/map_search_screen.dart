import 'package:flutter/material.dart';

class MapSearchScreen extends StatelessWidget {
  const MapSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextField(
          decoration: InputDecoration(
            hintText: '검?�어�??�력?�세??,
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
            child: Text('?�� ?�주 찾는 ?�소', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...List.generate(3, (i) => const ListTile(title: Text('?�주 찾는 ?�소?�니??), subtitle: Text('지??���?))),

          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('?�� 최근 검??, style: TextStyle(fontWeight: FontWeight.bold)),
                Text('??��', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          ...List.generate(10, (i) => const ListTile(title: Text('최근 검?�한 ?�어?�니??), subtitle: Text('지??���?))),
        ],
      ),
    );
  }
}
