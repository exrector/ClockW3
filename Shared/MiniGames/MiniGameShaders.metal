#include <metal_stdlib>
using namespace metal;

// A stitchable function means SwiftUI can use it for effects.
[[stitchable]] float2 gravitationalLens(float2 position, float2 center, float lensRadius, float strength) {
    float2 to_center = position - center;
    float dist = length(to_center);

    // No distortion beyond the lens radius
    if (dist >= lensRadius) {
        return float2(0.0, 0.0);
    }

    float2 direction = normalize(to_center);
    
    // The amount of pull, strongest at the center, fading to zero at the edge.
    float pull = (lensRadius - dist) / lensRadius;
    pull = pow(pull, 1.5f);

    // The displacement vector
    return direction * pull * strength;
}
