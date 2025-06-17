#!/usr/bin/env python3

import subprocess
import tempfile
import os
import sys

def run_cli_search(file_path, pattern):
    """Run CLI search and return match count and positions"""
    try:
        result = subprocess.run([
            '.build/debug/search-cli', 'search', file_path, pattern, '--quiet'
        ], capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            print(f"❌ CLI search failed: {result.stderr}")
            return None, []
            
        match_count = int(result.stdout.strip().split('\n')[0])
        
        # Get detailed results for positions
        result_verbose = subprocess.run([
            '.build/debug/search-cli', 'search', file_path, pattern, '--verbose'
        ], capture_output=True, text=True, timeout=30)
        
        positions = []
        for line in result_verbose.stdout.split('\n'):
            if line.startswith('[') and line.endswith(']'):
                # Parse positions from [pos1, pos2, ...]
                pos_str = line.strip()[1:-1]  # Remove brackets
                if pos_str:
                    positions = [int(x.strip()) for x in pos_str.split(',')]
                break
                
        return match_count, positions
    except Exception as e:
        print(f"❌ CLI error: {e}")
        return None, []

def run_grep_search(file_path, pattern):
    """Run grep search and return match count and positions"""
    try:
        result = subprocess.run([
            'grep', '-F', '-b', '-o', pattern, file_path  # -F for fixed strings (literal search)
        ], capture_output=True, text=True)
        
        positions = []
        for line in result.stdout.strip().split('\n'):
            if line and ':' in line:
                pos = int(line.split(':')[0])
                positions.append(pos)
                
        return len(positions), sorted(positions)
    except Exception as e:
        print(f"❌ Grep error: {e}")
        return None, []

def validate_positions_manually(file_path, pattern, positions):
    """Manually validate positions by reading file"""
    try:
        with open(file_path, 'rb') as f:  # Use binary mode for exact byte positions
            content = f.read()
        
        pattern_bytes = pattern.encode('utf-8')
        valid_positions = []
        
        for pos in positions:
            if pos + len(pattern_bytes) <= len(content):
                if content[pos:pos+len(pattern_bytes)] == pattern_bytes:
                    valid_positions.append(pos)
                else:
                    print(f"❌ Position {pos} invalid: got {content[pos:pos+len(pattern_bytes)]}, expected {pattern_bytes}")
                    
        return len(valid_positions), valid_positions
    except Exception as e:
        print(f"❌ Manual validation error: {e}")
        return None, []

def test_pattern(file_path, pattern, description):
    """Test a specific pattern against a file"""
    print(f"\n🔍 Testing: {description}")
    print(f"   File: {file_path}")
    print(f"   Pattern: '{pattern}'")
    
    # Run all three methods
    cli_count, cli_positions = run_cli_search(file_path, pattern)
    grep_count, grep_positions = run_grep_search(file_path, pattern)
    manual_count, manual_positions = validate_positions_manually(file_path, pattern, cli_positions)
    
    if cli_count is None or grep_count is None or manual_count is None:
        print("❌ FAILED - Some methods failed to run")
        return False
    
    # Compare results
    cli_sorted = sorted(cli_positions) if cli_positions else []
    grep_sorted = sorted(grep_positions) if grep_positions else []
    manual_sorted = sorted(manual_positions) if manual_positions else []
    
    print(f"   CLI:    {cli_count} matches at {cli_sorted}")
    print(f"   Grep:   {grep_count} matches at {grep_sorted}")
    print(f"   Manual: {manual_count} matches at {manual_sorted}")
    
    if cli_count == grep_count == manual_count and cli_sorted == grep_sorted == manual_sorted:
        print("✅ PERFECT MATCH")
        return True
    else:
        print("❌ MISMATCH DETECTED")
        if cli_count != grep_count:
            print(f"   Count mismatch: CLI={cli_count}, Grep={grep_count}")
        if cli_sorted != grep_sorted:
            print(f"   Position mismatch: CLI={cli_sorted}, Grep={grep_sorted}")
        if manual_count != cli_count:
            print(f"   Manual validation failed: {manual_count} vs {cli_count}")
        return False

def main():
    print("=== COMPREHENSIVE CLI VALIDATION SUITE ===")
    
    test_cases = [
        # File, Pattern, Description
        ("test_file.txt", "Hello", "Basic multi-match search"),
        ("test_file.txt", "the", "Common word search"),
        ("test_file.txt", ".", "Single character punctuation"),
        ("test_file.txt", "function", "Single word match"),
        ("test_file.txt", "xyz", "No matches"),
        ("test_file.txt", "searchOptimizedKernel", "Long pattern match"),
        ("empty_file.txt", "anything", "Empty file search"),
        ("unicode_test.txt", "Hello", "Unicode file search"),
        ("unicode_test.txt", "世界", "Unicode pattern search"),
        ("unicode_test.txt", "🚀", "Emoji pattern search"),
        ("large_test_file.txt", "ABC", "Large file search"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for file_path, pattern, description in test_cases:
        if os.path.exists(file_path):
            if test_pattern(file_path, pattern, description):
                passed += 1
        else:
            print(f"\n⚠️  Skipping {description} - file {file_path} not found")
            total -= 1
    
    print(f"\n=== FINAL RESULTS ===")
    print(f"Passed: {passed}/{total}")
    print(f"Success Rate: {(passed/total*100):.1f}%" if total > 0 else "No tests run")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED - CLI is fully compliant with reference implementations!")
    else:
        print("❌ Some tests failed - CLI needs fixes")
        sys.exit(1)

if __name__ == "__main__":
    main()\n
