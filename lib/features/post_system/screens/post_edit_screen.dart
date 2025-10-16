import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import '../../../core/models/post/post_model.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/period_slider_with_input.dart';
import '../widgets/price_calculator.dart';
import '../widgets/post_edit_media_handler.dart';
import '../widgets/post_edit_helpers.dart';
import '../widgets/post_edit_widgets.dart';
import 'post_place_selection_screen.dart';

/// 포스트 편집 화면
class PostEditScreen extends StatefulWidget {
  final PostModel post;

  const PostEditScreen({super.key, required this.post});

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _postService = PostService();
  final _firebaseService = FirebaseService();

  late final TextEditingController _titleController;
  late final TextEditingController _rewardController;
  late final TextEditingController _contentController;
  late final TextEditingController _youtubeUrlController;

  bool _canRespond = false;
  bool _canForward = false;
  bool _canRequestReward = true;
  bool _isSaving = false;

  List<String> _selectedGenders = ['male', 'female'];
  RangeValues _selectedAgeRange = const RangeValues(20, 30);
  int _selectedPeriod = 7;

  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];
  String _selectedFunction = 'Using';

  List<String> _imageUrls = [];
  PlaceModel? _place;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPostData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _contentController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  /// 컨트롤러 초기화
  void _initializeControllers() {
    _titleController = TextEditingController();
    _rewardController = TextEditingController();
    _contentController = TextEditingController();
    _youtubeUrlController = TextEditingController();
  }

  /// 포스트 데이터 로드
  Future<void> _loadPostData() async {
    try {
      // 포스트 데이터 설정
      _titleController.text = widget.post.title;
      _contentController.text = widget.post.description;
      _rewardController.text = widget.post.reward.toString();
      _youtubeUrlController.text = ''; // youtubeUrl 필드 없음
      
      _selectedGenders = [widget.post.targetGender]; // targetGender는 단일 값
      _selectedAgeRange = RangeValues(
        widget.post.targetAge.isNotEmpty ? widget.post.targetAge[0].toDouble() : 20,
        widget.post.targetAge.length > 1 ? widget.post.targetAge[1].toDouble() : 30,
      );
      _selectedPeriod = 7; // period 필드 없음, 기본값 사용
      _selectedFunction = 'Using'; // function 필드 없음, 기본값 사용
      
      _canRespond = widget.post.canRespond;
      _canForward = widget.post.canForward;
      _canRequestReward = widget.post.canRequestReward;
      
      _imageUrls = List<String>.from(widget.post.mediaUrl);

      // 플레이스 데이터 로드
      if (widget.post.placeId != null && widget.post.placeId!.isNotEmpty) {
        _place = await PostEditHelpers.loadPlace(widget.post.placeId!);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('포스트 데이터 로드 실패: $e');
    }
  }

  /// 이미지 추가
  Future<void> _addImage() async {
    try {
      // TODO: 이미지 선택 구현 필요
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 업로드 기능은 준비 중입니다.')),
      );
    } catch (e) {
      debugPrint('이미지 추가 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 추가 중 오류가 발생했습니다: $e')),
      );
    }
  }

  /// 이미지 제거
  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  /// 포스트 저장
  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final validationError = PostEditHelpers.validatePost(
      title: _titleController.text,
      content: _contentController.text,
      reward: _rewardController.text,
      imageUrls: _imageUrls,
      placeId: widget.post.placeId ?? '',
    );

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final postData = PostEditHelpers.buildPostData(
        title: _titleController.text,
        content: _contentController.text,
        reward: _rewardController.text,
        imageUrls: _imageUrls,
        placeId: widget.post.placeId ?? '',
        selectedGenders: _selectedGenders,
        selectedAgeRange: _selectedAgeRange,
        selectedPeriod: _selectedPeriod,
        selectedFunction: _selectedFunction,
        canRespond: _canRespond,
        canForward: _canForward,
        canRequestReward: _canRequestReward,
        youtubeUrl: _youtubeUrlController.text,
      );

      final success = await PostEditHelpers.updatePost(widget.post.postId, postData);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('포스트가 성공적으로 저장되었습니다.')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장 중 오류가 발생했습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('포스트 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 취소
  void _cancel() {
    Navigator.pop(context);
  }

  /// 미리보기 데이터 생성
  Map<String, dynamic> _getPreviewData() {
    return PostEditHelpers.buildPreviewData(
      title: _titleController.text,
      content: _contentController.text,
      reward: _rewardController.text,
      imageUrls: _imageUrls,
      placeName: _place?.name ?? '플레이스 없음',
      selectedGenders: _selectedGenders,
      selectedAgeRange: _selectedAgeRange,
      selectedPeriod: _selectedPeriod,
      selectedFunction: _selectedFunction,
      canRespond: _canRespond,
      canForward: _canForward,
      canRequestReward: _canRequestReward,
      youtubeUrl: _youtubeUrlController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포스트 편집'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  /// 메인 바디 위젯
  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 포스트 헤더
          PostEditWidgets.buildPostHeader(
            post: widget.post,
            place: _place,
          ),
          
          // 기본 정보 섹션
          PostEditWidgets.buildBasicInfoSection(
            formKey: _formKey,
            titleController: _titleController,
            contentController: _contentController,
            rewardController: _rewardController,
            youtubeUrlController: _youtubeUrlController,
          ),
          
          // 타겟 설정 섹션
          PostEditWidgets.buildTargetSection(
            selectedGenders: _selectedGenders,
            onGenderChanged: (genders) {
              setState(() {
                _selectedGenders = genders;
              });
            },
            selectedAgeRange: _selectedAgeRange,
            onAgeRangeChanged: (ageRange) {
              setState(() {
                _selectedAgeRange = ageRange;
              });
            },
            selectedPeriod: _selectedPeriod,
            onPeriodChanged: (period) {
              setState(() {
                _selectedPeriod = period;
              });
            },
          ),
          
          // 기능 설정 섹션
          PostEditWidgets.buildFunctionSection(
            selectedFunction: _selectedFunction,
            onFunctionChanged: (function) {
              setState(() {
                _selectedFunction = function;
              });
            },
          ),
          
          // 권한 설정 섹션
          PostEditWidgets.buildPermissionSection(
            canRespond: _canRespond,
            onCanRespondChanged: (canRespond) {
              setState(() {
                _canRespond = canRespond;
              });
            },
            canForward: _canForward,
            onCanForwardChanged: (canForward) {
              setState(() {
                _canForward = canForward;
              });
            },
            canRequestReward: _canRequestReward,
            onCanRequestRewardChanged: (canRequestReward) {
              setState(() {
                _canRequestReward = canRequestReward;
              });
            },
          ),
          
          // 미디어 섹션
          PostEditWidgets.buildMediaSection(
            imageUrls: _imageUrls,
            onAddImage: _addImage,
            onRemoveImage: _removeImage,
          ),
          
          // 미리보기 섹션
          PostEditWidgets.buildPreviewSection(
            previewData: _getPreviewData(),
          ),
          
          // 액션 버튼들
          PostEditWidgets.buildActionButtons(
            onSave: _savePost,
            onCancel: _cancel,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }
}