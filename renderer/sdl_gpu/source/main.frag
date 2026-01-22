#version 460

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec4 in_radius;
layout(location = 2) in vec4 in_border_thickness;
layout(location = 3) in vec2 in_size;
layout(location = 4) in vec2 in_uv;
layout(location = 5) in vec2 in_text_uv;
layout(location = 6) in vec4 in_border_color[4];
layout(location = 10) flat in int in_render_type;

layout(location = 0) out vec4 out_color;

// layout(set = 2, binding = 0) uniform sampler2D font_sampler;

float rect_select_side(vec2 pos, vec4 s) {
	s.xy = pos.x < 0 ? s.xw : s.yz;
	s.x = pos.y > 0 ? s.x : s.y;
	return s.x;
}

vec4 rect_get_blended_border_color(vec2 p, vec2 half_size) {
  float d_left = abs(p.x + half_size.x);
  float d_right = abs(p.x - half_size.x);
  float d_top = abs(p.y + half_size.y);
  float d_bottom = abs(p.y - half_size.y);

  float wl = 1.0 / (d_left + 1e-9);
  float wr = 1.0 / (d_right + 1e-9);
  float wt = 1.0 / (d_top + 1e-9);
  float wb = 1.0 / (d_bottom + 1e-9);

  vec4 color = (in_border_color[3] * wl + in_border_color[0] * wt +
                in_border_color[1] * wr + in_border_color[2] * wb) /
               (wl + wt + wr + wb);

  return color;
}

float rect_get_blended_thickness(vec2 pos, vec2 half_size, vec4 thickness) {
  float d_left = abs(pos.x + half_size.x);
  float d_right = abs(pos.x - half_size.x);
  float d_top = abs(pos.y + half_size.y);
  float d_bottom = abs(pos.y - half_size.y);

  float wl = 1.0 / (d_left + 1e-2);
  float wr = 1.0 / (d_right + 1e-2);
  float wt = 1.0 / (d_top + 1e-2);
  float wb = 1.0 / (d_bottom + 1e-2);

  return (thickness[3] * wl + thickness[0] * wt + thickness[1] * wr +
          thickness[2] * wb) /
         (wl + wt + wr + wb);
}

float sdf_rect(vec2 pos, vec2 half_size, float radius) {
  vec2 q = abs(pos) - half_size + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) -
         radius; // NEGATIVE inside, POSITIVE outside
}


void main() {
 
	vec2 h_size = in_size * 0.5;
	vec2 s_pos = in_uv * in_size - h_size;

	float rad = rect_select_side(s_pos, in_radius);

	float thickness_blended = rect_get_blended_thickness(s_pos, h_size, in_border_thickness);
	vec4 border_color_blended = rect_get_blended_border_color(s_pos, h_size);

	float sdf = sdf_rect(s_pos, h_size, rad);

	float stroke = smoothstep(-1, 1, thickness_blended / 2 - abs(sdf + thickness_blended / 2));

	float fill = smoothstep(-1, 1, -sdf - thickness_blended);

	vec4 stroke_color = vec4(border_color_blended) * stroke;
	vec4 fill_color = vec4(in_color) * fill;
	out_color = fill_color + stroke_color;
}
