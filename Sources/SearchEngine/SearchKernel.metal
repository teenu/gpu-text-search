#include <metal_stdlib>
using namespace metal;

// Enhanced GPU-optimized text search kernel with vectorized operations
kernel void searchOptimizedKernel(
    device const uchar* text        [[ buffer(0) ]],
    device const uchar* pattern     [[ buffer(1) ]],
    constant uint&      patternLen  [[ buffer(2) ]],
    device atomic_uint* matchCount  [[ buffer(3) ]], // Provides index & final count
    constant uint&      textLength  [[ buffer(4) ]],
    device uint*        positions   [[ buffer(5) ]], // Stores positions
    constant uint&      maxPositions[[ buffer(6) ]], // Max positions to store
    uint                gid         [[ thread_position_in_grid ]] // Starting position
)
{
    // Boundary check: Ensure the pattern fits within the text starting from gid
    if (gid + patternLen > textLength) {
        return; // Thread has no work to do
    }

    // Cache pattern and text pointers for better memory access
    device const uchar* textPtr = text + gid;
    device const uchar* patternPtr = pattern;
    
    // --- Optimized Pattern Matching ---
    bool found = false;
    
    // Ultra-fast path for single character patterns
    if (patternLen == 1) {
        found = (textPtr[0] == patternPtr[0]);
    } 
    // Vectorized comparison for 2-byte patterns (endianness-safe)
    else if (patternLen == 2) {
        // Check 2-byte alignment before vectorized access
        if (((ulong)textPtr % 2 == 0) && ((ulong)patternPtr % 2 == 0)) {
            // Safe: Both text and pattern use same endianness and memory layout
            const ushort textChars = *reinterpret_cast<device const ushort*>(textPtr);
            const ushort patternChars = *reinterpret_cast<device const ushort*>(patternPtr);
            found = (textChars == patternChars);
        } else {
            // Fallback to byte-by-byte comparison for unaligned access
            found = (textPtr[0] == patternPtr[0]) && (textPtr[1] == patternPtr[1]);
        }
    }
    // Vectorized comparison for 4-byte patterns (endianness-safe)
    else if (patternLen == 4) {
        // Check 4-byte alignment before vectorized access
        if (((ulong)textPtr % 4 == 0) && ((ulong)patternPtr % 4 == 0)) {
            // Safe: Both text and pattern use same endianness and memory layout
            const uint textChars = *reinterpret_cast<device const uint*>(textPtr);
            const uint patternChars = *reinterpret_cast<device const uint*>(patternPtr);
            found = (textChars == patternChars);
        } else {
            // Fallback to byte-by-byte comparison for unaligned access
            found = (textPtr[0] == patternPtr[0]) && 
                    (textPtr[1] == patternPtr[1]) && 
                    (textPtr[2] == patternPtr[2]) && 
                    (textPtr[3] == patternPtr[3]);
        }
    }
    // Optimized unrolled loops for common pattern lengths (3, 5-15 chars)
    else if (patternLen == 3) {
        found = (textPtr[0] == patternPtr[0]) && 
                (textPtr[1] == patternPtr[1]) && 
                (textPtr[2] == patternPtr[2]);
    }
    else if (patternLen == 5) {
        found = (textPtr[0] == patternPtr[0]) && 
                (textPtr[1] == patternPtr[1]) && 
                (textPtr[2] == patternPtr[2]) && 
                (textPtr[3] == patternPtr[3]) && 
                (textPtr[4] == patternPtr[4]);
    }
    else if (patternLen == 6) {
        found = (textPtr[0] == patternPtr[0]) && 
                (textPtr[1] == patternPtr[1]) && 
                (textPtr[2] == patternPtr[2]) && 
                (textPtr[3] == patternPtr[3]) && 
                (textPtr[4] == patternPtr[4]) && 
                (textPtr[5] == patternPtr[5]);
    }
    else if (patternLen == 7) {
        found = (textPtr[0] == patternPtr[0]) && 
                (textPtr[1] == patternPtr[1]) && 
                (textPtr[2] == patternPtr[2]) && 
                (textPtr[3] == patternPtr[3]) && 
                (textPtr[4] == patternPtr[4]) && 
                (textPtr[5] == patternPtr[5]) && 
                (textPtr[6] == patternPtr[6]);
    }
    else if (patternLen == 8) {
        // Use 64-bit comparison for 8-byte patterns (endianness-safe)
        #if __METAL_VERSION__ >= 230
        if (((ulong)textPtr % 8 == 0) && ((ulong)patternPtr % 8 == 0)) {
            // Safe: Both text and pattern use same endianness and memory layout
            const ulong textChars = *reinterpret_cast<device const ulong*>(textPtr);
            const ulong patternChars = *reinterpret_cast<device const ulong*>(patternPtr);
            found = (textChars == patternChars);
        } else {
            // Fallback to unrolled comparison for unaligned access
            found = (textPtr[0] == patternPtr[0]) && 
                    (textPtr[1] == patternPtr[1]) && 
                    (textPtr[2] == patternPtr[2]) && 
                    (textPtr[3] == patternPtr[3]) && 
                    (textPtr[4] == patternPtr[4]) && 
                    (textPtr[5] == patternPtr[5]) && 
                    (textPtr[6] == patternPtr[6]) && 
                    (textPtr[7] == patternPtr[7]);
        }
        #else
        // Fallback to unrolled comparison
        found = (textPtr[0] == patternPtr[0]) && 
                (textPtr[1] == patternPtr[1]) && 
                (textPtr[2] == patternPtr[2]) && 
                (textPtr[3] == patternPtr[3]) && 
                (textPtr[4] == patternPtr[4]) && 
                (textPtr[5] == patternPtr[5]) && 
                (textPtr[6] == patternPtr[6]) && 
                (textPtr[7] == patternPtr[7]);
        #endif
    }
    // Optimized paths for 9-15 byte patterns (hybrid vectorization)
    else if (patternLen == 9) {
        // Use 8-byte + 1-byte comparison
        if (((ulong)textPtr % 8 == 0) && ((ulong)patternPtr % 8 == 0)) {
            const ulong textChars = *reinterpret_cast<device const ulong*>(textPtr);
            const ulong patternChars = *reinterpret_cast<device const ulong*>(patternPtr);
            found = (textChars == patternChars) && (textPtr[8] == patternPtr[8]);
        } else {
            found = true;
            for (uint i = 0; i < 9 && found; i++) {
                found = (textPtr[i] == patternPtr[i]);
            }
        }
    }
    else if (patternLen == 10) {
        // Use 8-byte + 2-byte comparison
        if (((ulong)textPtr % 8 == 0) && ((ulong)patternPtr % 8 == 0)) {
            const ulong textChars1 = *reinterpret_cast<device const ulong*>(textPtr);
            const ulong patternChars1 = *reinterpret_cast<device const ulong*>(patternPtr);
            if (((ulong)(textPtr + 8) % 2 == 0) && ((ulong)(patternPtr + 8) % 2 == 0)) {
                const ushort textChars2 = *reinterpret_cast<device const ushort*>(textPtr + 8);
                const ushort patternChars2 = *reinterpret_cast<device const ushort*>(patternPtr + 8);
                found = (textChars1 == patternChars1) && (textChars2 == patternChars2);
            } else {
                found = (textChars1 == patternChars1) && 
                       (textPtr[8] == patternPtr[8]) && (textPtr[9] == patternPtr[9]);
            }
        } else {
            found = true;
            for (uint i = 0; i < 10 && found; i++) {
                found = (textPtr[i] == patternPtr[i]);
            }
        }
    }
    else if (patternLen == 12) {
        // Use 8-byte + 4-byte comparison
        if (((ulong)textPtr % 8 == 0) && ((ulong)patternPtr % 8 == 0)) {
            const ulong textChars1 = *reinterpret_cast<device const ulong*>(textPtr);
            const ulong patternChars1 = *reinterpret_cast<device const ulong*>(patternPtr);
            if (((ulong)(textPtr + 8) % 4 == 0) && ((ulong)(patternPtr + 8) % 4 == 0)) {
                const uint textChars2 = *reinterpret_cast<device const uint*>(textPtr + 8);
                const uint patternChars2 = *reinterpret_cast<device const uint*>(patternPtr + 8);
                found = (textChars1 == patternChars1) && (textChars2 == patternChars2);
            } else {
                found = (textChars1 == patternChars1) && 
                       (textPtr[8] == patternPtr[8]) && (textPtr[9] == patternPtr[9]) &&
                       (textPtr[10] == patternPtr[10]) && (textPtr[11] == patternPtr[11]);
            }
        } else {
            found = true;
            for (uint i = 0; i < 12 && found; i++) {
                found = (textPtr[i] == patternPtr[i]);
            }
        }
    }
    else if (patternLen >= 13 && patternLen <= 15) {
        // Use 8-byte + remaining bytes for 13-15 byte patterns
        if (((ulong)textPtr % 8 == 0) && ((ulong)patternPtr % 8 == 0)) {
            const ulong textChars = *reinterpret_cast<device const ulong*>(textPtr);
            const ulong patternChars = *reinterpret_cast<device const ulong*>(patternPtr);
            found = (textChars == patternChars);
            
            // Check remaining bytes
            for (uint i = 8; i < patternLen && found; i++) {
                found = (textPtr[i] == patternPtr[i]);
            }
        } else {
            found = true;
            for (uint i = 0; i < patternLen && found; i++) {
                found = (textPtr[i] == patternPtr[i]);
            }
        }
    }
    // Extended SIMD support for 16-byte patterns
    else if (patternLen == 16) {
        // Use 128-bit integer SIMD (endianness-safe)
        #if __METAL_VERSION__ >= 240
        if (((ulong)textPtr % 16 == 0) && ((ulong)patternPtr % 16 == 0)) {
            // Safe: uint4 vectors compare element-wise, preserving byte order
            const uint4 textChars = *reinterpret_cast<device const uint4*>(textPtr);
            const uint4 patternChars = *reinterpret_cast<device const uint4*>(patternPtr);
            found = all(textChars == patternChars);
        } else {
            // Fallback: check in 8-byte chunks
            found = true;
            for (uint i = 0; i < 16 && found; i += 8) {
                if (((ulong)(textPtr + i) % 8 == 0) && ((ulong)(patternPtr + i) % 8 == 0)) {
                    const ulong textChunk = *reinterpret_cast<device const ulong*>(textPtr + i);
                    const ulong patternChunk = *reinterpret_cast<device const ulong*>(patternPtr + i);
                    found = (textChunk == patternChunk);
                } else {
                    // Byte-by-byte for unaligned remainder
                    for (uint j = 0; j < 8 && found; j++) {
                        found = (textPtr[i + j] == patternPtr[i + j]);
                    }
                }
            }
        }
        #else
        // Fallback: unrolled comparison for older Metal versions
        found = true;
        for (uint i = 0; i < 16 && found; i++) {
            found = (textPtr[i] == patternPtr[i]);
        }
        #endif
    }
    // Extended SIMD support for 32-byte patterns
    else if (patternLen == 32) {
        // Use 256-bit integer comparison (endianness-safe)
        #if __METAL_VERSION__ >= 240
        if (((ulong)textPtr % 16 == 0) && ((ulong)patternPtr % 16 == 0)) {
            // Safe: uint4 vectors compare element-wise, preserving byte order
            const uint4 textChars1 = *reinterpret_cast<device const uint4*>(textPtr);
            const uint4 patternChars1 = *reinterpret_cast<device const uint4*>(patternPtr);
            const uint4 textChars2 = *reinterpret_cast<device const uint4*>(textPtr + 16);
            const uint4 patternChars2 = *reinterpret_cast<device const uint4*>(patternPtr + 16);
            
            bool chunk1Match = all(textChars1 == patternChars1);
            bool chunk2Match = all(textChars2 == patternChars2);
            found = chunk1Match && chunk2Match;
        } else {
            // Fallback: check in 8-byte chunks
            found = true;
            for (uint i = 0; i < 32 && found; i += 8) {
                if (((ulong)(textPtr + i) % 8 == 0) && ((ulong)(patternPtr + i) % 8 == 0)) {
                    const ulong textChunk = *reinterpret_cast<device const ulong*>(textPtr + i);
                    const ulong patternChunk = *reinterpret_cast<device const ulong*>(patternPtr + i);
                    found = (textChunk == patternChunk);
                } else {
                    // Byte-by-byte for unaligned remainder
                    for (uint j = 0; j < 8 && found; j++) {
                        found = (textPtr[i + j] == patternPtr[i + j]);
                    }
                }
            }
        }
        #else
        // Fallback: check in 8-byte chunks for older Metal versions
        found = true;
        for (uint i = 0; i < 32 && found; i += 8) {
            const ulong textChunk = *reinterpret_cast<device const ulong*>(textPtr + i);
            const ulong patternChunk = *reinterpret_cast<device const ulong*>(patternPtr + i);
            found = (textChunk == patternChunk);
        }
        #endif
    }
    // Optimized loop with first/last character pre-check for longer patterns
    else {
        // Quick rejection using first and last characters
        if (textPtr[0] == patternPtr[0] && textPtr[patternLen - 1] == patternPtr[patternLen - 1]) {
            found = true;
            
            // Check middle characters with optimized memory access
            // Process 4 bytes at a time where possible for better cache utilization
            uint i = 1;
            uint endCheck = patternLen - 1;
            
            // Process middle section in 4-byte chunks when alignment allows
            if (patternLen > 8) {
                for (; i + 3 < endCheck; i += 4) {
                    if (textPtr[i] != patternPtr[i] || 
                        textPtr[i+1] != patternPtr[i+1] ||
                        textPtr[i+2] != patternPtr[i+2] || 
                        textPtr[i+3] != patternPtr[i+3]) {
                        found = false;
                        break;
                    }
                }
            }
            
            // Handle remaining bytes
            for (; i < endCheck && found; i++) {
                if (textPtr[i] != patternPtr[i]) {
                    found = false;
                }
            }
        }
    }

    // --- Optimized Position Storage ---
    if (found) {
        // Use relaxed memory ordering for maximum performance
        uint storeIndex = atomic_fetch_add_explicit(matchCount, 1, memory_order_relaxed);

        // Conditional store to avoid unnecessary memory writes
        if (storeIndex < maxPositions) {
            positions[storeIndex] = gid;
        }
        // Note: Counter still increments even if we don't store (for truncation detection)
    }
}
