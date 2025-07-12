#include <metal_stdlib>
using namespace metal;

kernel void searchOptimizedKernel(
    device const uchar* text        [[ buffer(0) ]],
    device const uchar* pattern     [[ buffer(1) ]],
    constant uint&      patternLen  [[ buffer(2) ]],
    device atomic_uint* matchCount  [[ buffer(3) ]],
    constant uint&      textLength  [[ buffer(4) ]],
    device uint*        positions   [[ buffer(5) ]],
    constant uint&      maxPositions[[ buffer(6) ]],
    uint                gid         [[ thread_position_in_grid ]]
)
{
    if (gid + patternLen > textLength) {
        return;
    }

    bool found = false;
    
    if (patternLen == 1) {
        found = (text[gid] == pattern[0]);
    } else {
        // Early termination: check first and last characters
        if (text[gid] == pattern[0] && text[gid + patternLen - 1] == pattern[patternLen - 1]) {
            // Unified loop for all middle characters (handles lengths 2-∞)
            found = true;
            for (uint i = 1; i < patternLen - 1; i++) {
                if (text[gid + i] != pattern[i]) {
                    found = false;
                    break;
                }
            }
        }
    }

    if (found) {
        uint storeIndex = atomic_fetch_add_explicit(matchCount, 1, memory_order_relaxed);
        if (storeIndex < maxPositions) {
            positions[storeIndex] = gid;
        }
    }
}
