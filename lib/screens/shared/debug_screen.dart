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

      // workplaces Ïª¨Î†â???ïÏù∏
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      data['workplaces'] = {
        'count': workplacesSnapshot.docs.length,
        'documents': workplacesSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList(),
      };

      // places Ïª¨Î†â???ïÏù∏
      final placesSnapshot = await _firestore.collection('places').get();
      data['places'] = {
        'count': placesSnapshot.docs.length,
        'documents': placesSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList(),
      };

      // users Ïª¨Î†â???ïÏù∏
      final usersSnapshot = await _firestore.collection('users').get();
      data['users'] = {
        'count': usersSnapshot.docs.length,
        'documents': usersSnapshot.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList(),
      };

      // user_tracks Ïª¨Î†â???ïÏù∏
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
      // print πÆ ¡¶∞≈µ 
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore ?∞Ïù¥???ïÏù∏'),
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
                    'Firestore ?∞Ïù¥?∞Î≤†?¥Ïä§ ?ÑÌô©',
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
          '$collectionName (${data['count']}Í∞?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ï¥?Î¨∏ÏÑú ?? ${data['count']}'),
                const SizedBox(height: 8),
                if (data['documents'].isNotEmpty) ...[
                  const Text('Î¨∏ÏÑú Î™©Î°ù:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        Text('?∞Ïù¥?? ${doc['data']}'),
                      ],
                    ),
                  )).toList(),
                ] else ...[
                  const Text('Î¨∏ÏÑúÍ∞Ä ?ÜÏäµ?àÎã§.', style: TextStyle(color: Colors.grey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 
