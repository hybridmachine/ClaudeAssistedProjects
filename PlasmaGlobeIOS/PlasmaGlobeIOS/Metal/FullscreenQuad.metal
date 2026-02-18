#include "PlasmaCommon.h"

vertex VertexOut fullscreenQuadVertex(uint vid [[vertex_id]]) {
    // Two-triangle fullscreen quad
    const float2 positions[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };

    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}
