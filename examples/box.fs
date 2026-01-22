#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

// Element properties
uniform vec2 position;      // Top-left position
uniform vec2 size;          // Width and height

// Box properties
uniform vec4 backgroundColor;  // RGBA normalized (0-1)
uniform vec4 borderColor[4];   // Top, Right, Bottom, Left
uniform vec4 borderThickness;  // Top, Right, Bottom, Left
uniform vec4 borderRadius;     // Top-left, Top-right, Bottom-right, Bottom-left
uniform vec4 padding;          // Top, Right, Bottom, Left

// Screen properties
uniform float screenHeight;

float roundedBoxSDF(vec2 p, vec2 b, vec4 r) {
    // Select the correct corner radius
    r.xy = (p.x > 0.0) ? r.xy : r.zw;
    r.x  = (p.y > 0.0) ? r.x  : r.y;
    
    vec2 q = abs(p) - b + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

void main() {
    // 1. Setup Coordinates
    vec2 pixelPos = vec2(gl_FragCoord.x, screenHeight - gl_FragCoord.y) - position;
    vec2 halfSize = size * 0.5;
    vec2 p = pixelPos - halfSize;

    // 2. Outer Box (SDF)
    float outerDist = roundedBoxSDF(p, halfSize, borderRadius);
    
    // 3. Calculate Inner Box Bounds
    // thickness: x=top, y=right, z=bottom, w=left
    float leftT   = borderThickness.w;
    float rightT  = borderThickness.y;
    float topT    = borderThickness.x;
    float bottomT = borderThickness.z;

    // The inner box size is the outer size minus the thickness of opposite sides
    vec2 innerSize = vec2(size.x - (leftT + rightT), size.y - (topT + bottomT));
    vec2 innerHalfSize = innerSize * 0.5;

    // The inner box center shifts if the thicknesses are asymmetrical
    // Shift = (LeftOffset - RightOffset) / 2, etc.
    vec2 innerCenterShift = vec2((leftT - rightT) * 0.5, (topT - bottomT) * 0.5);
    vec2 pInner = p - innerCenterShift;

    // 4. Calculate Inner Radii (Concentric)
    // borderRadius: TL, TR, BR, BL
    vec4 innerRadius = max(borderRadius - vec4(topT, topT, bottomT, bottomT), 0.0); 
    // Note: For perfect precision, match the radius to the specific side thickness
    
    float innerDist = roundedBoxSDF(pInner, innerHalfSize, innerRadius);

    // 5. Coloring Logic
    if (outerDist > 0.0) {
        discard; 
    }

    if (innerDist <= 0.0) {
        finalColor = backgroundColor;
    } else {
        // Border Side Selection logic
        // We use the normalized pixel position to decide which border color to show
        vec2 normPos = pixelPos / size;
        
        // Diagonal split logic for corners
        if (normPos.x < normPos.y && normPos.x < (1.0 - normPos.y)) {
            finalColor = borderColor[3]; // Left
        } else if (normPos.x > normPos.y && normPos.x > (1.0 - normPos.y)) {
            finalColor = borderColor[1]; // Right
        } else if (normPos.y < normPos.x && normPos.y < (1.0 - normPos.x)) {
            finalColor = borderColor[0]; // Top
        } else {
            finalColor = borderColor[2]; // Bottom
        }
    }

    // Smooth AA on both outer and inner edges for a crisp look
    float edgeAA = smoothstep(1.0, 0.0, outerDist + 0.5);
    finalColor.a *= edgeAA;
}
