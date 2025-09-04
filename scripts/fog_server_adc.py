#!/usr/bin/env python3
"""
Application Default Credentials 사용 Fog of War 타일 서버

이 서버는 Google Cloud SDK의 ADC를 사용하여 Firebase Firestore에 접근합니다.
서비스 계정 키 파일 없이도 작동합니다.

설치 요구사항:
pip install firebase-admin pillow

사용법:
gcloud auth application-default login  # 한 번만 실행
python fog_server_adc.py

URL 예시:
http://localhost:8080/tiles/user123/15/26910/12667.png
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import re
from urllib.parse import urlparse
from PIL import Image, ImageDraw
import io
import math
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import os

# Firebase 초기화 (ADC 사용)
def initialize_firebase():
    """Firebase Admin SDK 초기화 (Application Default Credentials 사용)"""
    try:
        # ADC를 사용하여 초기화
        if not firebase_admin._apps:
            # 프로젝트 ID 설정
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred, {
                'projectId': 'ppamproto-439623',  # google-services.json에서 가져온 프로젝트 ID
            })
            print("✅ Firebase 초기화 성공 (ADC 사용)")
            return True
        else:
            print("✅ Firebase 이미 초기화됨")
            return True
    except Exception as e:
        print(f"❌ Firebase 초기화 실패: {e}")
        print("   'gcloud auth application-default login'을 실행하세요")
        return False

class FogTileHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """GET 요청 처리"""
        path = self.path
        
        # CORS 헤더 추가
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        
        # 타일 요청 URL 파싱: /tiles/{userId}/{zoom}/{x}/{y}.png
        tile_pattern = r'/tiles/([^/]+)/(\d+)/(\d+)/(\d+)\.png'
        match = re.match(tile_pattern, path)
        
        if match:
            user_id, zoom, x, y = match.groups()
            zoom, x, y = int(zoom), int(x), int(y)
            
            print(f"🎯 타일 요청: userId={user_id}, z={zoom}, x={x}, y={y}")
            
            try:
                # Firestore에서 타일 정보 조회
                fog_level = self.get_fog_level_from_firestore(user_id, zoom, x, y)
                
                # 타일 이미지 생성
                tile_data = self.generate_tile_image(x, y, zoom, user_id, fog_level)
                
                # 응답 전송
                self.send_response(200)
                self.send_header('Content-Type', 'image/png')
                self.send_header('Cache-Control', 'no-cache')  # 캐시 비활성화 (개발용)
                self.end_headers()
                self.wfile.write(tile_data)
                
            except Exception as e:
                print(f"❌ 타일 생성 오류: {e}")
                self.send_error(500, f"Internal Server Error: {e}")
        else:
            self.send_error(404, "Invalid tile URL format")
    
    def do_OPTIONS(self):
        """CORS preflight 요청 처리"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()
    
    def get_fog_level_from_firestore(self, user_id, zoom, x, y):
        """Firestore에서 타일의 fog level 조회"""
        try:
            db = firestore.client()
            
            # 타일 ID 생성 (FogOfWarManager와 동일한 방식)
            tile_id = f"{zoom}_{x}_{y}"
            
            # Firestore 경로: visits_tiles/{userId}/visited/{tileId}
            doc_ref = db.collection('visits_tiles').document(user_id).collection('visited').document(tile_id)
            doc = doc_ref.get()
            
            if doc.exists:
                data = doc.to_dict()
                fog_level = data.get('fogLevel', 3)  # 기본값: 3 (검은색)
                visited_at = data.get('visitedAt')
                distance = data.get('distance', 0)
                
                print(f"✅ Firestore 조회 성공: tileId={tile_id}, fogLevel={fog_level}, distance={distance:.3f}km")
                return fog_level
            else:
                print(f"❌ Firestore에 타일 정보 없음: tileId={tile_id}")
                return 3  # 방문하지 않은 타일 = 검은색
                
        except Exception as e:
            print(f"❌ Firestore 조회 오류: {e}")
            return 3  # 오류 시 기본값
    
    def generate_tile_image(self, x, y, zoom, user_id, fog_level):
        """fog_level에 따라 타일 이미지 생성"""
        size = 256
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # fog_level에 따른 색상 설정
        if fog_level == 1:
            # 완전히 탐색된 지역 - 투명 (지도가 완전히 보임)
            pass  # 투명하게 유지
            debug_color = "투명"
        elif fog_level == 2:
            # 부분적으로 탐색된 지역 - 연한 회색
            draw.rectangle([0, 0, size, size], fill=(128, 128, 128, 80))
            debug_color = "연한회색"
        elif fog_level == 3:
            # 미탐색 지역 - 검은색 (완전히 가림)
            draw.rectangle([0, 0, size, size], fill=(0, 0, 0, 255))
            debug_color = "검은색"
        else:
            # 알 수 없는 level - 기본 검은색
            draw.rectangle([0, 0, size, size], fill=(0, 0, 0, 255))
            debug_color = "기본검은색"
        
        # 디버그 정보 표시 (개발용)
        try:
            draw.text((10, 10), f"Z:{zoom} X:{x} Y:{y}", fill=(255, 255, 255, 255))
            draw.text((10, 30), f"User:{user_id[:8]}...", fill=(255, 255, 255, 255))
            draw.text((10, 50), f"Level:{fog_level} ({debug_color})", fill=(255, 255, 255, 255))
            draw.text((10, 70), f"ADC Auth", fill=(255, 255, 255, 255))
        except:
            pass  # 텍스트 렌더링 실패해도 무시
        
        # PNG 바이트로 변환
        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='PNG')
        return img_byte_arr.getvalue()

def main():
    """서버 시작"""
    print("🚀 ADC 인증 Fog of War 타일 서버 시작")
    
    # Firebase 초기화
    if not initialize_firebase():
        print("❌ Firebase 초기화 실패로 서버를 시작할 수 없습니다")
        print("💡 다음 명령어를 실행하세요: gcloud auth application-default login")
        return
    
    # HTTP 서버 시작
    port = 8080
    server_address = ('', port)
    httpd = HTTPServer(server_address, FogTileHandler)
    
    print(f"✅ 서버가 포트 {port}에서 실행 중입니다")
    print(f"📡 URL 예시: http://localhost:{port}/tiles/USER_ID/15/26910/12667.png")
    print(f"🔑 프로젝트 ID: ppamproto-439623")
    print("🛑 서버 종료: Ctrl+C")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 서버 종료")
        httpd.server_close()

if __name__ == '__main__':
    main()
