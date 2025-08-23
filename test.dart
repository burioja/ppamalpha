late TabController _tabController;
final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

final TextEditingController _searchController = TextEditingController();
String _searchQuery = '';
String _statusFilter = 'all';
String _periodFilter = 'all';
String _sortBy = 'createdAt';
String _sortOrder = 'desc';

final List<PostModel> _allPosts = [];
final List<PostModel> _filteredPosts = [];
bool _isLoading = false;
bool _isLoadingMore = false;
// _ 는 Dart에서 private 변수를 의미합니다 (이 dart 파일 내에서만 접근 가능)
// public 변수는 _없이 선언하며 다른 dart 파일에서도 접근이 가능합니다
// protected 변수는 Dart에서 지원하지 않습니다
// 이 변수는 더 불러올 데이터가 있는지를 나타냅니다
// DocumentSnapshot은 Firebase에서 제공하는 데이터 타입으로 문서의 스냅샷을 나타냅니다
// 문서의 스냅샷이란 특정 시점의 문서 데이터를 의미합니다. 마치 사진을 찍은 것처럼 
// 해당 시점의 데이터 상태를 담고 있습니다
bool _hasMoreData;
// End of Selection
DocumentSnapshot? _lastDocument;
statuc const int _pageSize=20; 

// @override 데코레이터는 부모 클래스의 메서드를 재정의(override)한다는 것을 명시적으로 표시합니다.
// 이는 코드의 가독성을 높이고 실수로 메서드 시그니처를 잘못 작성하는 것을 방지합니다.
@override
void initState() {
    // super.initState()는 부모 클래스의 initState() 메서드를 호출합니다.
    // Flutter의 StatefulWidget에서 initState()는 위젯이 생성될 때 처음으로 호출되는 메서드입니다.
    // 반드시 super.initState()를 먼저 호출해야 하며, 이는 부모 클래스의 초기화 로직이 
    // 자식 클래스의 초기화보다 먼저 실행되어야 하기 때문입니다.
    super.initState();
    // TabController는 Flutter에서 제공하는 클래스로, 탭 기반 UI의 상태를 관리합니다.
    // length: 2는 탭의 개수가 2개임을 의미합니다.
    // vsync: this는 애니메이션 동기화를 위한 TickerProvider를 제공합니다.
    // this가 TickerProviderStateMixin을 구현한 State 클래스여야 합니다.
    _tabController = TabController(length: 2, vsync: this);
    // addListener는 TabController의 상태 변화를 감지하는 리스너(listener)를 등록하는 메서드입니다.
    // 리스너는 탭이 변경될 때마다 자동으로 호출되는 콜백 함수입니다.
    // setState(() {})가 빈 콜백으로 호출되는 이유는 화면을 다시 그리라는 신호만 보내는 것입니다.
    // 실제 UI를 그리는 build() 메서드는 이 setState() 호출 이후에 자동으로 실행됩니다.
    // build() 메서드에서 TabController의 현재 상태에 따라 적절한 UI가 그려질 것입니다.
    _tabController.addListener(() { setState(() {}); });
    // WidgetsBinding.instance.addPostFrameCallback는 Flutter에서 위젯이 처음 렌더링된 직후에 
    // 실행될 콜백 함수를 등록하는 메서드입니다.
    // 이는 build가 완료된 후 실행되어야 하는 작업들을 안전하게 처리할 수 있게 해줍니다.
    // (_)는 사용하지 않는 매개변수를 나타내며, 여기서는 Duration 타입의 timeStamp를 받지만 사용하지 않습니다.
    // _loadInitialData()는 초기 데이터를 로드하는 메서드로, 화면이 완전히 구성된 후 실행됩니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitialData();
    });
}

Future<void> _loadInitialData() async {
    if (_isLoading) return;
    setState((){
        _isLoading = true;
        _allPosts.clear();
        _filteredPosts.clear();
        _lastDocument = null;
        _hasMoreData = true;
    });

    try {
        await _loadMoreData();
    } finally {
        setState(() {
            _isLoading = false;
        });
    }

Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() { _isLoadingMore = true; });
    try {
        final newPosts = await _postService.getUserFlyers(
            _currentUserId!,
            limit: _pageSize,
            lastDocument: _lastDocument,
    };

    if (newPosts.isNotEmpty) {
        _allPosts.addAll(newPosts);
        _hasMoreData = newPosts.length == _pageSize;
    } else {
        _hasMoreData = false;
    }

    _applyFiltersAndSorting();
} catch (e) {
    debugPrint('❌ 추가 데이터 로딩 실패: $e');
} finally {
    setState(() {
        _isLoadingMore = false;
    });
}

void _applyFiltersAndSorting() {
    _filteredPosts.clear();
    _filteredPosts.addAll(_filterAndSortPosts(_allPosts));
}
}

// FutureBuilder는 비동기 데이터를 처리하고 UI를 구축하는 위젯입니다.
// Future의 상태(로딩/완료/에러)에 따라 다른 UI를 보여줄 수 있습니다.
// List<PostModel>은 PostModel 객체들의 리스트(배열)를 의미합니다.
// PostModel은 게시물의 데이터 구조를 정의한 모델 클래스입니다.
// Dart에서는 Map<Key, Value>를 사용하여 key:value 형태의 사전(dictionary)을 표현합니다.
// 예: Map<String, dynamic> post = {'title': '제목', 'content': '내용'};
FutureBuilder<List<PostModel>>(
// End of Selection
    // _postService는 PostService 클래스의 인스턴스로, 이 클래스는 일반적으로 생성자나 initState에서 초기화됩니다.
    // 예: final _postService = PostService(); 또는 PostService.instance
    //
    // future: 는 FutureBuilder의 필수 속성으로, 비동기로 실행될 작업을 지정합니다.
    // FutureBuilder는 이 future의 상태(로딩/완료/에러)에 따라 UI를 다르게 표시합니다.
    // 여기서는 사용자의 게시물 목록을 비동기로 가져오는 작업을 수행합니다.
    future: _postService.getUserFlyers(_currentUserId!, limit: _pageSize, lastDocument: _lastDocument),
    builder: ...
)