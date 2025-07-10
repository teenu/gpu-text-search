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
        if (text[gid] == pattern[0]) {
            found = true;
        }
    } else {
        if (text[gid] == pattern[0] && text[gid + patternLen - 1] == pattern[patternLen - 1]) {
            bool middleMatch = true;
            
            if (patternLen == 2) {
                middleMatch = true;
            } else if (patternLen == 3) {
                middleMatch = (text[gid + 1] == pattern[1]);
            } else if (patternLen == 4) {
                middleMatch = (text[gid + 1] == pattern[1]) && 
                             (text[gid + 2] == pattern[2]);
            } else if (patternLen <= 8) {
                for (uint i = 1; i < patternLen - 1; i++) {
                    if (text[gid + i] != pattern[i]) {
                        middleMatch = false;
                        break;
                    }
                }
            } else {
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

    if (found) {
        uint storeIndex = atomic_fetch_add_explicit(matchCount, 1, memory_order_relaxed);

        if (storeIndex < maxPositions) {
            positions[storeIndex] = gid;
        }
    }
}
