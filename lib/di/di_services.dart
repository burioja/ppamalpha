import '../features/map_system/services/clustering/marker_clustering_service.dart';
import '../features/map_system/services/fog/fog_service.dart';
import '../features/map_system/services/interaction/marker_interaction_service.dart';
import '../features/map_system/services/filtering/filter_service.dart';

import 'di_repositories.dart';

/// DI - Service 팩토리
/// 
/// **역할**: Service 인스턴스 생성 및 의존성 주입
/// **사용**: 필요한 곳에서 호출
class DIServices {
  /// MarkerClusteringService (Stateless)
  static MarkerClusteringService getMarkerClusteringService() {
    return MarkerClusteringService();
  }

  /// FogService (Stateless)
  static FogService getFogService() {
    return FogService();
  }

  /// FilterService (Stateless)
  static FilterService getFilterService() {
    return FilterService();
  }

  /// MarkerInteractionService (Repository 의존)
  static MarkerInteractionService getMarkerInteractionService() {
    return MarkerInteractionService(
      repository: DIRepositories.getMarkersRepository(),
    );
  }
}

