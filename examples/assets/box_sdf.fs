#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform vec2 position;
uniform vec2 size;
uniform vec4 backgroundColor;
uniform vec4 borderColor[4];    // 0:Top, 1:Right, 2:Bottom, 3:Left
uniform vec4 borderThickness;  // x:Top, y:Right, z:Bottom, w:Left
uniform vec4 borderRadius;     // TL, TR, BR, BL
uniform float screenHeight;

float sdf_rect(vec2 pos, vec2 half_size, float radius) {
    vec2 q = abs(pos) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Helper to calculate the inner SDF for a specific thickness pair
float get_inner_sdf(vec2 s_pos, vec2 h_size, vec4 thickness, float rad_outer) {
    // Calculate the hole size and offset for the whole rectangle
    vec2 inner_h_size = h_size - vec2(thickness.w + thickness.y, thickness.x + thickness.z) * 0.5;
    vec2 inner_offset = vec2(thickness.w - thickness.y, thickness.x - thickness.z) * 0.5;
    
    // Use the maximum thickness meeting at the corner to determine the local inner radius
    // (This prevents the inner corner from "over-rounding")
    vec2 sign_pos = sign(s_pos);
    float t_corner = (sign_pos.x < 0.0) ? 
        ((sign_pos.y < 0.0) ? max(thickness.w, thickness.x) : max(thickness.w, thickness.z)) :
        ((sign_pos.y < 0.0) ? max(thickness.y, thickness.x) : max(thickness.y, thickness.z));

    float rad_inner = max(0.0, rad_outer - t_corner);
    return sdf_rect(s_pos - inner_offset, inner_h_size, rad_inner);
}

void main() {
    vec2 pixelPos = vec2(gl_FragCoord.x, screenHeight - gl_FragCoord.y) - position;
    vec2 h_size = size * 0.5;
    vec2 s_pos = pixelPos - h_size;

    // 1. Identify Corner & Sides
    float t_horiz, t_vert;
    vec4 c_horiz, c_vert;
    float rad;

    if (s_pos.x < 0.0) { // Left
        t_horiz = borderThickness.w; c_horiz = borderColor[3];
        if (s_pos.y < 0.0) { t_vert = borderThickness.x; c_vert = borderColor[0]; rad = borderRadius.x; }
        else { t_vert = borderThickness.z; c_vert = borderColor[2]; rad = borderRadius.w; }
    } else { // Right
        t_horiz = borderThickness.y; c_horiz = borderColor[1];
        if (s_pos.y < 0.0) { t_vert = borderThickness.x; c_vert = borderColor[0]; rad = borderRadius.y; }
        else { t_vert = borderThickness.z; c_vert = borderColor[2]; rad = borderRadius.z; }
    }

    // 2. Miter Blending Logic
    vec2 dist_to_edges = h_size - abs(s_pos);
    float miter_val = (dist_to_edges.x / max(t_horiz, 0.01)) - (dist_to_edges.y / max(t_vert, 0.01));
    
    // We blend over a slightly wider range to ensure G1 continuity (smoothness)
    float blend = smoothstep(-0.1, 0.1, miter_val);
    vec4 side_color = mix(c_horiz, c_vert, blend);

    // 3. Geometry Blending (The Fix for the Bump)
    // Clamp radius to the rectangle's half-size to avoid over-rounding
    // (prevents "pinched" corners when width != height)
    float rad_outer = min(rad, min(h_size.x, h_size.y));

    // Instead of blending radius, we blend the actual Distance Field results
    float d_outer = sdf_rect(s_pos, h_size, rad_outer);
    
    // We calculate two "candidate" inner SDFs
    // Candidate A: The inner hole if the whole corner used t_horiz
    // Candidate B: The inner hole if the whole corner used t_vert
    vec4 thick_h = vec4(t_horiz); // Symmetric assumption for the candidate
    vec4 thick_v = vec4(t_vert);
    
    // However, to keep the rectangle's overall shape, we use the actual thickness vector
    // but interpolate the weight of the "active" sides.
    float d_inner = get_inner_sdf(s_pos, h_size, borderThickness, rad_outer);

    // 4. Final Masks
    float edge_softness = 1.0;
    float outer_mask = smoothstep(edge_softness, -edge_softness, d_outer);
    float inner_mask = smoothstep(-edge_softness, edge_softness, d_inner);
    float fill_mask  = smoothstep(edge_softness, -edge_softness, d_inner);

    vec4 border_part = side_color * outer_mask * inner_mask;
    vec4 fill_part = backgroundColor * fill_mask;

    if (d_outer > edge_softness) discard;

    finalColor = fill_part + border_part;
}