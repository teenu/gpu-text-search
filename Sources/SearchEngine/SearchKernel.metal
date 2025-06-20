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
    // Simple, fast loop for longer patterns
    else {
        // Quick rejection using first and last characters
        if (textPtr[0] == patternPtr[0] && textPtr[patternLen - 1] == patternPtr[patternLen - 1]) {
            found = true;
            
            // Simple byte-by-byte comparison for middle characters
            // Eliminates all branching and chunking complexity
            for (uint i = 1; i < patternLen - 1 && found; i++) {
                found = (textPtr[i] == patternPtr[i]);
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
