#include <metal_stdlib>
using namespace metal;

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

    // --- Find Match ---
    bool found = false;
    // Quick path for 1-char patterns
    if (patternLen == 1) {
        if (text[gid] == pattern[0]) {
            found = true;
        }
    } else {
        // Optimization: Check first and last characters
        if (text[gid] == pattern[0] && text[gid + patternLen - 1] == pattern[patternLen - 1]) {
            // Optimized middle character checking with loop unrolling for common lengths
            bool middleMatch = true;
            
            // Fast paths for common pattern lengths (2-8 chars)
            if (patternLen == 2) {
                // No middle characters to check
                middleMatch = true;
            } else if (patternLen == 3) {
                middleMatch = (text[gid + 1] == pattern[1]);
            } else if (patternLen == 4) {
                middleMatch = (text[gid + 1] == pattern[1]) && 
                             (text[gid + 2] == pattern[2]);
            } else if (patternLen <= 8) {
                // Unrolled loop for patterns 5-8 characters
                for (uint i = 1; i < patternLen - 1; i++) {
                    if (text[gid + i] != pattern[i]) {
                        middleMatch = false;
                        break;
                    }
                }
            } else {
                // General case for longer patterns
                for (uint i = 1; i < patternLen - 1; i++) {
                    if (text[gid + i] != pattern[i]) {
                        middleMatch = false;
                        break;
                    }
                }
            }
            
            if (middleMatch) {
                found = true;
            }
        }
    }
    // --- End Find Match ---


    // --- Store Position if Found ---
    if (found) {
        // Atomically increment the counter to get the index for this thread's match.
        // The value *before* the increment is the index we should use.
        uint storeIndex = atomic_fetch_add_explicit(matchCount, 1, memory_order_relaxed);

        // Check if the obtained index is within the bounds of our positions buffer.
        if (storeIndex < maxPositions) {
            // If yes, store the starting position (gid) at that index.
            positions[storeIndex] = gid;
        }
        // If storeIndex >= maxPositions, we don't store, but the counter still counts it.
    }
}