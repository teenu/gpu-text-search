#!/usr/bin/env python3

import struct
import sys
import subprocess

def read_binary_positions(filename):
    """Read UInt32 positions from binary file"""
    positions = []
    with open(filename, 'rb') as f:
        while True:
            data = f.read(4)  # Read 4 bytes for UInt32
            if not data:
                break
            position = struct.unpack('<I', data)[0]  # Little-endian UInt32
            positions.append(position)
    return positions

def get_grep_positions(filename, pattern):
    """Get positions using grep for validation"""
    try:
        # Use grep with byte offset
        result = subprocess.run(['grep', '-b', '-o', pattern, filename], 
                              capture_output=True, text=True)
        positions = []
        for line in result.stdout.strip().split('\n'):
            if line:
                pos = int(line.split(':')[0])
                positions.append(pos)
        return sorted(positions)
    except:
        return []

def validate_positions_in_file(filename, pattern, positions):
    """Manually validate positions by reading file content"""
    with open(filename, 'rb') as f:
        content = f.read()
    pattern_bytes = pattern.encode('utf-8')

    valid_positions = []
    for pos in positions:
        if pos + len(pattern_bytes) <= len(content):
            if content[pos:pos+len(pattern_bytes)] == pattern_bytes:
                valid_positions.append(pos)
            else:
                invalid = content[pos:pos+len(pattern_bytes)]
                print(f"❌ Position {pos} is invalid: '{invalid}' != '{pattern_bytes}'")
        else:
            print(f"❌ Position {pos} is out of bounds")
    
    return valid_positions

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 validate_binary.py <binary_file> <text_file> <pattern>")
        sys.exit(1)
    
    binary_file = sys.argv[1]
    text_file = sys.argv[2]
    pattern = sys.argv[3]
    
    print(f"Validating binary export: {binary_file}")
    print(f"Text file: {text_file}")
    print(f"Pattern: '{pattern}'")
    print()
    
    # Read binary positions
    binary_positions = read_binary_positions(binary_file)
    print(f"Binary file contains {len(binary_positions)} positions: {binary_positions}")
    
    # Get grep positions for comparison
    grep_positions = get_grep_positions(text_file, pattern)
    print(f"Grep found {len(grep_positions)} positions: {grep_positions}")
    
    # Manually validate each position
    valid_positions = validate_positions_in_file(text_file, pattern, binary_positions)
    print(f"Manually validated {len(valid_positions)} positions: {valid_positions}")
    
    # Compare results (sort for comparison since order may differ)
    binary_sorted = sorted(binary_positions)
    grep_sorted = sorted(grep_positions)
    valid_sorted = sorted(valid_positions)
    
    print("\n=== VALIDATION RESULTS ===")
    if binary_sorted == grep_sorted == valid_sorted:
        print("✅ PERFECT MATCH: All methods agree!")
        print(f"✅ All {len(binary_positions)} positions are correct")
        print(f"✅ Sorted positions: {binary_sorted}")
    else:
        print("❌ MISMATCH DETECTED:")
        if set(binary_positions) != set(grep_positions):
            print(f"❌ Binary vs Grep: {set(binary_positions) - set(grep_positions)} extra in binary")
            print(f"❌ Grep vs Binary: {set(grep_positions) - set(binary_positions)} extra in grep")
        if set(binary_positions) != set(valid_positions):
            print(f"❌ Binary positions validation failed")
            
    # Check if just ordering differs
    if set(binary_positions) == set(grep_positions) == set(valid_positions):
        print("✅ CONTENT MATCH: Same positions, different order (GPU thread execution order)")
        print(f"✅ Binary order: {binary_positions}")
        print(f"✅ Grep order: {grep_positions}")
    
    print(f"\nFile size validation:")
    expected_size = len(binary_positions) * 4  # 4 bytes per UInt32
    actual_size = len(open(binary_file, 'rb').read())
    if expected_size == actual_size:
        print(f"✅ File size correct: {actual_size} bytes")
    else:
        print(f"❌ File size mismatch: expected {expected_size}, got {actual_size}")
