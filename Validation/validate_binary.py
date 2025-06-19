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
    
    print(f"Validating: {binary_file} for pattern '{pattern}'")
    
    # Read and validate positions
    binary_positions = read_binary_positions(binary_file)
    grep_positions = get_grep_positions(text_file, pattern)
    valid_positions = validate_positions_in_file(text_file, pattern, binary_positions)
    
    print(f"Binary: {len(binary_positions)}, Grep: {len(grep_positions)}, Valid: {len(valid_positions)}")
    
    # Compare results (sort for comparison since order may differ)
    binary_sorted = sorted(binary_positions)
    grep_sorted = sorted(grep_positions)
    valid_sorted = sorted(valid_positions)
    
    # Results
    if binary_sorted == grep_sorted == valid_sorted:
        print("✅ Perfect match: All positions correct")
    elif set(binary_positions) == set(grep_positions) == set(valid_positions):
        print("✅ Content match: Same positions, different order (GPU parallelism)")
    else:
        print("❌ Validation failed")
        if set(binary_positions) != set(grep_positions):
            print(f"   Binary-Grep diff: {len(set(binary_positions) ^ set(grep_positions))} positions")
    
    # File size check
    expected_size = len(binary_positions) * 4
    actual_size = len(open(binary_file, 'rb').read())
    print(f"File size: {'✅' if expected_size == actual_size else '❌'} {actual_size} bytes")
