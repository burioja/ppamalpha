#!/usr/bin/env python3
"""
Fog of War 타일 생성기 (테스트용)

이 스크립트는 간단한 PNG 타일들을 생성하여 
HTTP 기반 TileOverlay 시스템을 테스트할 수 있게 해줍니다.

사용법:
python tile_generator.py

생성되는 파일 구조:
tiles/
├── user123/
    └── 15/
        ├── 12345/
            ├── 67890.png (검은 타일)
            ├── 67891.png (회색 타일)
            └── 67892.png (투명 타일)
"""

from PIL import Image, ImageDraw
import os
import sys

def create_tile(status, size=256):
    """타일 이미지 생성"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    if status == 'dark':
        # 검은 포그 (80% 불투명)
        draw.rectangle([0, 0, size, size], fill=(0, 0, 0, 204))
    elif status == 'gray':
        # 회색 틴트 (50% 불투명)
        draw.rectangle([0, 0, size, size], fill=(100, 100, 100, 128))
    elif status == 'clear':
        # 투명 (지도 보임)
        pass
    elif status == 'test':
        # 테스트용 빨간색
        draw.rectangle([0, 0, size, size], fill=(255, 0, 0, 100))
        # 격자 그리기
        for i in range(0, size, 32):
            draw.line([(i, 0), (i, size)], fill=(255, 255, 255, 200), width=1)
            draw.line([(0, i), (size, i)], fill=(255, 255, 255, 200), width=1)
    
    return img

def generate_test_tiles():
    """테스트용 타일들 생성"""
    base_dir = "tiles"
    user_id = "user123"
    zoom = 15
    
    # 서울 주변 타일 좌표들 (예시)
    test_tiles = [
        (26910, 12667),  # 서울 중심
        (26911, 12667),  # 서울 동쪽
        (26910, 12668),  # 서울 남쪽
        (26909, 12667),  # 서울 서쪽
        (26910, 12666),  # 서울 북쪽
    ]
    
    statuses = ['dark', 'gray', 'clear', 'test']
    
    for i, (x, y) in enumerate(test_tiles):
        # 각 타일마다 다른 상태 적용
        status = statuses[i % len(statuses)]
        
        # 디렉토리 생성
        tile_dir = f"{base_dir}/{user_id}/{zoom}/{x}"
        os.makedirs(tile_dir, exist_ok=True)
        
        # 타일 이미지 생성 및 저장
        img = create_tile(status)
        file_path = f"{tile_dir}/{y}.png"
        img.save(file_path)
        
        print(f"✅ 생성됨: {file_path} ({status})")
    
    print(f"\n🎉 테스트용 타일 {len(test_tiles)}개 생성 완료!")
    print(f"📁 경로: {os.path.abspath(base_dir)}")
    print(f"\n🔧 Flutter에서 baseUrl을 다음과 같이 설정하세요:")
    print(f"   baseUrl: 'http://localhost:8000'")
    print(f"\n🚀 간단한 HTTP 서버 실행:")
    print(f"   python -m http.server 8000")

def generate_pattern_tiles(user_id, zoom, x_range, y_range, pattern='radial'):
    """패턴 기반 타일 생성"""
    base_dir = "tiles"
    center_x = sum(x_range) // 2
    center_y = sum(y_range) // 2
    
    print(f"🎨 패턴 타일 생성 중... (패턴: {pattern})")
    
    count = 0
    for x in range(x_range[0], x_range[1] + 1):
        for y in range(y_range[0], y_range[1] + 1):
            # 중심에서의 거리 계산
            distance = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            
            # 거리에 따른 상태 결정
            if pattern == 'radial':
                if distance <= 1:
                    status = 'clear'
                elif distance <= 3:
                    status = 'gray'
                else:
                    status = 'dark'
            elif pattern == 'test':
                status = 'test'
            else:
                status = 'dark'
            
            # 디렉토리 생성
            tile_dir = f"{base_dir}/{user_id}/{zoom}/{x}"
            os.makedirs(tile_dir, exist_ok=True)
            
            # 타일 이미지 생성 및 저장
            img = create_tile(status)
            file_path = f"{tile_dir}/{y}.png"
            img.save(file_path)
            
            count += 1
    
    print(f"✅ {count}개 패턴 타일 생성 완료!")

if __name__ == "__main__":
    print("🗺️ Fog of War 타일 생성기")
    print("=" * 40)
    
    if len(sys.argv) > 1 and sys.argv[1] == "pattern":
        # 패턴 타일 생성 (더 많은 타일)
        generate_pattern_tiles(
            user_id="user123",
            zoom=15,
            x_range=(26905, 26915),  # 서울 주변 11x11 타일
            y_range=(12662, 12672),
            pattern='radial'
        )
    else:
        # 기본 테스트 타일 생성
        generate_test_tiles()
    
    print("\n🌐 다음 단계:")
    print("1. HTTP 서버 실행: python -m http.server 8000")
    print("2. Flutter 앱에서 baseUrl을 'http://localhost:8000'으로 설정")
    print("3. 앱을 실행하여 타일이 표시되는지 확인")
