import '../core/repositories/markers_repository.dart';
import '../core/repositories/posts_repository.dart';
import '../core/repositories/tiles_repository.dart';

import '../core/datasources/firebase/markers_firebase_ds.dart';
import '../core/datasources/firebase/posts_firebase_ds.dart';
import '../core/datasources/firebase/tiles_firebase_ds.dart';

/// DI - Repository 팩토리
/// 
/// **역할**: Repository 인스턴스 생성 및 Datasource 주입
/// **사용**: Provider나 Service에서 필요 시 호출
class DIRepositories {
  // 싱글톤 인스턴스 (선택사항)
  static MarkersRepository? _markersRepository;
  static PostsRepository? _postsRepository;
  static TilesRepository? _tilesRepository;

  /// MarkersRepository 생성
  /// 
  /// [dataSource]: 테스트 시 Mock Datasource 주입 가능
  static MarkersRepository getMarkersRepository({
    MarkersFirebaseDataSource? dataSource,
  }) {
    if (_markersRepository != null && dataSource == null) {
      return _markersRepository!;
    }

    final repo = MarkersRepository(
      dataSource: dataSource ?? MarkersFirebaseDataSourceImpl(),
    );

    if (dataSource == null) {
      _markersRepository = repo;
    }

    return repo;
  }

  /// PostsRepository 생성
  static PostsRepository getPostsRepository() {
    return _postsRepository ??= PostsRepository();
  }

  /// TilesRepository 생성
  static TilesRepository getTilesRepository() {
    return _tilesRepository ??= TilesRepository();
  }

  /// 싱글톤 초기화 (테스트용)
  static void reset() {
    _markersRepository = null;
    _postsRepository = null;
    _tilesRepository = null;
  }
}

