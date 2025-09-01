#!/usr/bin/env python3
"""
간단한 Fog of War 타일 서버 (개발용)

이 서버는 동적으로 타일을 생성하여 HTTP 기반 TileOverlay 시스템을 테스트할 수 있게 해줍니다.

사용법:
python tile_server.py

URL 예시:
http://localhost:8080/tiles/user123/15/26910/12667.png
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import re
from urllib.parse import urlparse, parse_qs
from PIL import Image, ImageDraw
import io
import math

class TileHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """GET 요청 처리"""
        path = self.path
        
        # CORS 헤더 추가 (Flutter Web용)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        
        # 타일 요청 패턴 매칭
        tile_pattern = r'/tiles/([^/]+)/(\d+)/(\d+)/(\d+)\.png'
        match = re.match(tile_pattern, path)
        
        if match:
            user_id, zoom, x, y = match.groups()
            zoom, x, y = int(zoom), int(x), int(y)
            
            print(f"🎯 타일 요청: user={user_id}, z={zoom}, x={x}, y={y}")
            
            try:
                tile_png = self.generate_fog_tile(user_id, zoom, x, y)
                
                self.send_response(200)
                self.send_header('Content-Type', 'image/png')
                self.send_header('Cache-Control', 'public, max-age=3600')  # 1시간 캐시
                self.end_headers()
                self.wfile.write(tile_png)
                
                print(f"✅ 타일 전송 완료: {len(tile_png)} bytes")
                
            except Exception as e:
                print(f"❌ 타일 생성 오류: {e}")
                self.send_error(500, f"타일 생성 실패: {e}")
                
        elif path == '/health':
            # 헬스 체크
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = json.dumps({"status": "ok", "service": "fog-tile-server"})
            self.wfile.write(response.encode())
            
        else:
            self.send_error(404, "Not Found")
    
    def do_OPTIONS(self):
        """CORS preflight 요청 처리"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()
    
    def generate_fog_tile(self, user_id, zoom, x, y):
        """동적 Fog 타일 생성"""
        size = 256
        
        # 서울 중심 좌표 (타일 좌표계)
        seoul_center_x = 26910
        seoul_center_y = 12667
        
        # 현재 타일과 서울 중심과의 거리 계산
        distance = math.sqrt((x - seoul_center_x)**2 + (y - seoul_center_y)**2)
        
        # 거리에 따른 fog level 결정
        if distance <= 1:
            # 중심부 - 투명 (밝음)
            fog_level = 'clear'
        elif distance <= 3:
            # 중간 지역 - 회색
            fog_level = 'gray'
        elif distance <= 6:
            # 외곽 지역 - 어두운 회색
            fog_level = 'dark_gray'
        else:
            # 원거리 - 검은색
            fog_level = 'dark'
        
        # 특별한 패턴 (테스트용)
        if (x + y) % 4 == 0:
            fog_level = 'test'  # 격자 패턴
        
        # 이미지 생성
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        if fog_level == 'clear':
            # 투명 - 지도 완전히 보임
            pass
        elif fog_level == 'gray':
            # 회색 틴트 (50% 불투명)
            draw.rectangle([0, 0, size, size], fill=(128, 128, 128, 128))
        elif fog_level == 'dark_gray':
            # 어두운 회색 (70% 불투명)
            draw.rectangle([0, 0, size, size], fill=(64, 64, 64, 179))
        elif fog_level == 'dark':
            # 검은 포그 (90% 불투명)
            draw.rectangle([0, 0, size, size], fill=(0, 0, 0, 230))
        elif fog_level == 'test':
            # 테스트용 빨간색 격자
            draw.rectangle([0, 0, size, size], fill=(255, 0, 0, 100))
            # 격자 그리기
            for i in range(0, size, 32):
                draw.line([(i, 0), (i, size)], fill=(255, 255, 255, 200), width=2)
                draw.line([(0, i), (size, i)], fill=(255, 255, 255, 200), width=2)
            # 타일 좌표 표시
            try:
                draw.text((10, 10), f"{zoom}/{x}/{y}", fill=(255, 255, 255, 255))
            except:
                pass
        
        # PNG로 변환
        img_buffer = io.BytesIO()
        img.save(img_buffer, format='PNG')
        img_buffer.seek(0)
        
        return img_buffer.read()
    
    def log_message(self, format, *args):
        """로그 메시지 포맷팅"""
        print(f"🌐 {self.address_string()} - {format % args}")

def run_server(host='localhost', port=8080):
    """타일 서버 실행"""
    server_address = (host, port)
    httpd = HTTPServer(server_address, TileHandler)
    
    print(f"🚀 Fog of War 타일 서버 시작됨")
    print(f"📍 주소: http://{host}:{port}")
    print(f"🧪 테스트 URL: http://{host}:{port}/tiles/user123/15/26910/12667.png")
    print(f"❤️ 헬스 체크: http://{host}:{port}/health")
    print(f"🛑 중지하려면 Ctrl+C")
    print("=" * 60)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print(f"\n🛑 서버 종료 중...")
        httpd.shutdown()
        print(f"✅ 서버가 정상적으로 종료되었습니다")

if __name__ == "__main__":
    import sys
    
    # 포트 번호 옵션
    port = 8080
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("❌ 올바른 포트 번호를 입력하세요")
            sys.exit(1)
    
    run_server('localhost', port)
