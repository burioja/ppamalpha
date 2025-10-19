export 'di_providers.dart';
export 'di_repositories.dart';
export 'di_services.dart';

/// DI 컨테이너 엔트리 포인트
/// 
/// **사용법**:
/// ```dart
/// import 'package:ppamalpha/di/di_container.dart';
/// 
/// // Provider 등록
/// MultiProvider(
///   providers: DIProviders.getProviders(),
///   child: MyApp(),
/// )
/// 
/// // Repository 사용
/// final repo = DIRepositories.getMarkersRepository();
/// 
/// // Service 사용
/// final service = DIServices.getMarkerClusteringService();
/// ```

