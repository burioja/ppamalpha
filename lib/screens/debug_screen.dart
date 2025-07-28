import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _data = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final Map<String, dynamic> data = {};

      // workplaces 컬렉션 확인
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      data['workplaces'] = {
        'count': workplacesSnapshot.docs.length,
        'documents': workplacesSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList(),
      };

      // places 컬렉션 확인
      final placesSnapshot = await _firestore.collection('places').get();
      data['places'] = {
        'count': placesSnapshot.docs.length,
        'documents': placesSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList(),
      };

      // users 컬렉션 확인
      final usersSnapshot = await _firestore.collection('users').get();
      data['users'] = {
        'count': usersSnapshot.docs.length,
        'documents': usersSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList(),
      };

      // user_tracks 컬렉션 확인
      final tracksSnapshot = await _firestore.collection('user_tracks').get();
      data['user_tracks'] = {
        'count': tracksSnapshot.docs.length,
        'documents': tracksSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList(),
      };

      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      print('데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore 데이터 확인'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Firestore 데이터베이스 현황',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  ..._data.entries.map((entry) => _buildCollectionCard(entry.key, entry.value)),
                ],
              ),
            ),
    );
  }

  Widget _buildCollectionCard(String collectionName, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          '$collectionName (${data['count']}개)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('총 문서 수: ${data['count']}'),
                const SizedBox(height: 8),
                if (data['documents'].isNotEmpty) ...[
                  const Text('문서 목록:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...data['documents'].map<Widget>((doc) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${doc['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('데이터: ${doc['data']}'),
                      ],
                    ),
                  )).toList(),
                ] else ...[
                  const Text('문서가 없습니다.', style: TextStyle(color: Colors.grey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 