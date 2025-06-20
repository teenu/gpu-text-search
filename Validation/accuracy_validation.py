#!/usr/bin/env python3
"""
Comprehensive accuracy validation for GPU Text Search
Tests all optimization paths against grep baseline for 100% accuracy guarantee
"""

import subprocess
import tempfile
import os
import sys
import random
import string

def run_gpu_search(file_path, pattern):
    """Run GPU search and return match count and positions"""
    try:
        result = subprocess.run([
            '.build/release/search-cli', 'search', file_path, pattern, '--verbose'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            return None, [], f"GPU search failed: {result.stderr}"
            
        lines = result.stdout.strip().split('\n')
        match_count = 0
        positions = []
        
        for line in lines:
            if line.startswith('Matches found:'):
                match_count = int(line.split(':')[1].strip())
            elif line.startswith('[') and line.endswith(']'):
                pos_str = line.strip()[1:-1]
                if pos_str:
                    positions = [int(x.strip()) for x in pos_str.split(',')]
                    
        return match_count, positions, None
    except Exception as e:
        return None, [], f"GPU error: {e}"

def run_grep_search(file_path, pattern):
    """Run grep search and return match count and positions"""
    try:
        result = subprocess.run([
            'grep', '-F', '-b', '-o', pattern, file_path
        ], capture_output=True, text=True)
        
        positions = []
        for line in result.stdout.strip().split('\n'):
            if line and ':' in line:
                pos = int(line.split(':')[0])
                positions.append(pos)
                
        return len(positions), sorted(positions), None
    except Exception as e:
        return None, [], f"Grep error: {e}"

def generate_test_content(base_content, pattern, positions):
    """Generate test content with pattern at specific positions (non-overlapping)"""
    content = list(base_content)
    
    # Sort positions and ensure they don't overlap
    valid_positions = []
    sorted_positions = sorted(positions)
    
    for pos in sorted_positions:
        # Check if this position would overlap with any already placed pattern
        overlaps = False
        for valid_pos in valid_positions:
            if abs(pos - valid_pos) < len(pattern):
                overlaps = True
                break
        
        if not overlaps and pos + len(pattern) <= len(content):
            valid_positions.append(pos)
            for i, char in enumerate(pattern):
                content[pos + i] = char
    
    return ''.join(content)

def test_pattern_size(pattern_len, test_name):
    """Test specific pattern length with various alignments and positions"""
    print(f"Testing {test_name} (length {pattern_len})...")
    
    # Generate test pattern (unique and unlikely to occur randomly)
    if pattern_len == 1:
        pattern = 'X'
    elif pattern_len <= 26:
        pattern = string.ascii_uppercase[:pattern_len]
    else:
        # Create a pattern that won't occur randomly in base content
        pattern = 'TESTPATTERN' + 'X' * (pattern_len - 11)
    
    # Test cases: different alignments and content sizes
    test_cases = [
        # (content_size, pattern_positions, description)
        (1000, [0], "start of file"),
        (1000, [999 - pattern_len], "end of file"),
        (1000, [500], "middle of file"),
        (1000, [1, 3, 7], "unaligned positions"),
        (1000, [0, 16, 32, 48], "16-byte aligned"),
        (1000, [4, 20, 36, 52], "4-byte aligned"),
        (1000, [2, 18, 34, 50], "2-byte aligned"),
        (5000, [i * 100 for i in range(10)], "multiple matches"),
        (1000, [], "no matches"),
    ]
    
    failures = 0
    
    for content_size, pattern_positions, description in test_cases:
        # Generate base content that won't accidentally contain our pattern
        base_chars = string.ascii_lowercase + string.digits
        base_content = ''.join(random.choices(base_chars, k=content_size))
        
        # Insert pattern at specified positions
        test_content = generate_test_content(base_content, pattern, pattern_positions)
        
        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            f.write(test_content)
            temp_file = f.name
        
        try:
            # Run both searches
            gpu_count, gpu_positions, gpu_error = run_gpu_search(temp_file, pattern)
            grep_count, grep_positions, grep_error = run_grep_search(temp_file, pattern)
            
            # Check for errors
            if gpu_error:
                print(f"  ❌ {description}: {gpu_error}")
                failures += 1
                continue
                
            if grep_error:
                print(f"  ❌ {description}: {grep_error}")
                failures += 1
                continue
            
            # Compare results
            if gpu_count != grep_count:
                print(f"  ❌ {description}: Count mismatch - GPU: {gpu_count}, Grep: {grep_count}")
                failures += 1
                continue
                
            if sorted(gpu_positions) != sorted(grep_positions):
                print(f"  ❌ {description}: Position mismatch")
                print(f"     GPU:  {sorted(gpu_positions)}")
                print(f"     Grep: {sorted(grep_positions)}")
                failures += 1
                continue
                
            print(f"  ✅ {description}: {gpu_count} matches")
            
        finally:
            os.unlink(temp_file)
    
    return failures

def main():
    print("🔍 GPU Text Search - Comprehensive Accuracy Validation")
    print("=" * 60)
    
    # Build release version for testing
    print("Building release version...")
    build_result = subprocess.run(['swift', 'build', '-c', 'release'], 
                                 capture_output=True, text=True)
    if build_result.returncode != 0:
        print(f"❌ Build failed: {build_result.stderr}")
        return 1
    
    print("✅ Build successful\n")
    
    total_failures = 0
    
    # Test all optimization paths
    test_cases = [
        (1, "Single character (ultra-fast path)"),
        (2, "2-byte vectorized comparison"),
        (3, "3-byte unrolled comparison"),
        (4, "4-byte vectorized comparison"),
        (5, "5-byte unrolled comparison"),
        (6, "6-byte unrolled comparison"),
        (7, "7-byte unrolled comparison"),
        (8, "8-byte vectorized comparison"),
        (9, "9-byte generic loop"),
        (10, "10-byte generic loop"),
        (12, "12-byte generic loop"),
        (15, "15-byte generic loop"),
        (16, "16-byte SIMD comparison"),
        (20, "20-byte generic loop"),
        (32, "32-byte SIMD comparison"),
        (50, "50-byte generic loop"),
        (100, "100-byte generic loop"),
        (256, "256-byte large pattern"),
        (1000, "1KB large pattern"),
    ]
    
    for pattern_len, test_name in test_cases:
        failures = test_pattern_size(pattern_len, test_name)
        total_failures += failures
        if failures == 0:
            print("✅ All tests passed\n")
        else:
            print(f"❌ {failures} test(s) failed\n")
    
    print("=" * 60)
    if total_failures == 0:
        print("🎉 ALL ACCURACY TESTS PASSED!")
        print("GPU Text Search maintains 100% accuracy across all optimization paths.")
        return 0
    else:
        print(f"❌ ACCURACY VALIDATION FAILED: {total_failures} total failures")
        print("Critical accuracy issues detected - fix required before deployment.")
        return 1

if __name__ == "__main__":
    sys.exit(main())