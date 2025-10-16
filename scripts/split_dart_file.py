#!/usr/bin/env python3
"""
Dart 파일을 Part 파일로 자동 분할하는 스크립트

사용법:
  python split_dart_file.py lib/features/map_system/screens/map_screen.dart
"""

import re
import sys
from pathlib import Path

def extract_methods(content):
    """메서드들을 추출"""
    # Dart 메서드 패턴: void|Future|Widget 등으로 시작
    pattern = r'((?:Future<[^>]+>|void|Widget|bool|String|int|double|List<[^>]+>)\s+_\w+\([^)]*\)(?:\s+async)?\s*\{)'
    
    methods = []
    for match in re.finditer(pattern, content, re.MULTILINE):
        start = match.start()
        method_name = match.group(1)
        
        # 메서드 끝 찾기 (중괄호 매칭)
        brace_count = 0
        end = start
        in_method = False
        
        for i in range(start, len(content)):
            char = content[i]
            if char == '{':
                brace_count += 1
                in_method = True
            elif char == '}':
                brace_count -= 1
                if in_method and brace_count == 0:
                    end = i + 1
                    break
        
        method_code = content[start:end]
        methods.append({
            'name': method_name,
            'code': method_code,
            'start': start,
            'end': end
        })
    
    return methods

def classify_methods(methods):
    """메서드를 카테고리별로 분류"""
    categories = {
        'init': [],
        'fog': [],
        'marker': [],
        'post': [],
        'location': [],
        'ui': [],
        'other': []
    }
    
    for method in methods:
        name = method['name'].lower()
        code = method['code'].lower()
        
        # 분류 로직
        if any(k in name for k in ['init', 'setup', 'load']):
            categories['init'].append(method)
        elif any(k in name for k in ['fog', 'gray', 'visit', 'tile']):
            categories['fog'].append(method)
        elif any(k in name for k in ['marker', 'cluster']):
            categories['marker'].append(method)
        elif any(k in name for k in ['post', 'collect', 'receive']):
            categories['post'].append(method)
        elif any(k in name for k in ['location', 'address', 'position']):
            categories['location'].append(method)
        elif any(k in name for k in ['build', 'show', 'widget']):
            categories['ui'].append(method)
        else:
            categories['other'].append(method)
    
    return categories

def create_part_files(file_path, categories):
    """Part 파일들 생성"""
    base_path = Path(file_path).parent / 'parts'
    base_path.mkdir(exist_ok=True)
    
    file_name = Path(file_path).stem
    
    for category, methods in categories.items():
        if not methods:
            continue
        
        part_file = base_path / f'{file_name}_{category}.dart'
        
        with open(part_file, 'w', encoding='utf-8') as f:
            f.write(f"part of '../{Path(file_path).name}';\n\n")
            f.write(f"// ==================== {category.upper()} ====================\n\n")
            
            for method in methods:
                f.write(method['code'])
                f.write('\n\n')
        
        print(f"✅ Created: {part_file} ({len(methods)} methods)")

def main():
    if len(sys.argv) < 2:
        print("Usage: python split_dart_file.py <dart_file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    if not Path(file_path).exists():
        print(f"❌ File not found: {file_path}")
        sys.exit(1)
    
    print(f"📖 Reading: {file_path}")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print(f"📊 File size: {len(content)} characters")
    
    # 메서드 추출
    methods = extract_methods(content)
    print(f"🔍 Found {len(methods)} methods")
    
    # 분류
    categories = classify_methods(methods)
    for category, method_list in categories.items():
        print(f"  - {category}: {len(method_list)} methods")
    
    # Part 파일 생성
    create_part_files(file_path, categories)
    
    print("\n✅ Part 파일 생성 완료!")
    print("\n📝 다음 단계:")
    print("1. 원본 파일에 part 선언 추가")
    print("2. 원본 파일에서 이동된 메서드 삭제")
    print("3. 빌드 테스트")

if __name__ == '__main__':
    main()

