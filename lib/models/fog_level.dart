/// 포그 오브 워 레벨 정의
enum FogLevel {
  /// 1단계: 완전 노출 (1km 반경, 실시간)
  clear(1),
  
  /// 2단계: 회색 반투명 (30일간 보존)
  gray(2),
  
  /// 3단계: 검정 (미방문 지역)
  black(3);
  
  const FogLevel(this.level);
  final int level;
  
  /// 레벨 번호로부터 FogLevel 생성
  static FogLevel fromLevel(int level) {
    switch (level) {
      case 1:
        return FogLevel.clear;
      case 2:
        return FogLevel.gray;
      case 3:
        return FogLevel.black;
      default:
        return FogLevel.black;
    }
  }
  
  /// 포그 레벨에 따른 설명
  String get description {
    switch (this) {
      case FogLevel.clear:
        return '완전 노출 (1km 반경)';
      case FogLevel.gray:
        return '회색 반투명 (30일간 보존)';
      case FogLevel.black:
        return '검정 (미방문 지역)';
    }
  }
}
