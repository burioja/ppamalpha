import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<List<String>> _dataGroups = [];
  List<Color> _groupColors = [];
  int _currentGroupIndex = 0;
  int _currentContentIndex = 3; // 각 그룹의 마지막 인덱스
  final double _sensitivity = 50.0;
  Offset _dragStartOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _fetchWorkplaces();
  }

  // Firebase Firestore에서 동적으로 workplace 데이터 가져오기
  void _fetchWorkplaces() async {

    final userId = 'user-id'; // 실제로는 로그인한 사용자 ID를 가져와야 함
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final workplaces = List<String>.from(snapshot['workPlaces'] ?? []);

    setState(() {
      _dataGroups = workplaces.map((workplace) => [workplace]).toList();
      _groupColors = List<Color>.generate(
        _dataGroups.length,
            (_) => Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0),
      );
      _currentContentIndex = _dataGroups[_currentGroupIndex].length - 1;
    });
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartOffset = details.localPosition;
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    double dragDistance = _dragStartOffset.dx - details.velocity.pixelsPerSecond.dx;

    setState(() {
      if (dragDistance > _sensitivity && _currentContentIndex < _dataGroups[_currentGroupIndex].length - 1) {
        _currentContentIndex++;
      } else if (dragDistance < -_sensitivity && _currentContentIndex > 0) {
        _currentContentIndex--;
      }
    });
  }

  void _handleVerticalDrag(DragEndDetails details) {
    double dragDistance = _dragStartOffset.dy - details.velocity.pixelsPerSecond.dy;

    setState(() {
      if (dragDistance > _sensitivity) {
        _currentGroupIndex = (_currentGroupIndex + 1) % _dataGroups.length;
      } else if (dragDistance < -_sensitivity) {
        _currentGroupIndex = (_currentGroupIndex - 1 + _dataGroups.length) % _dataGroups.length;
      }
      _currentContentIndex = _dataGroups[_currentGroupIndex].length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragEnd: _handleHorizontalDrag,
      onVerticalDragStart: _onDragStart,
      onVerticalDragEnd: _handleVerticalDrag,
      child: _dataGroups.isEmpty
          ? const Center(child: CircularProgressIndicator()) // 데이터 로딩 중
          : Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _groupColors[_currentGroupIndex],
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          _dataGroups[_currentGroupIndex][_currentContentIndex],
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
