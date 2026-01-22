#version 460

struct Rect {
  vec4 radius;
  vec4 position_and_size;
  vec4 color;
  vec4 uv_and_type;
  vec4 thickness;
  vec4 border_color_top;
  vec4 border_color_right;
  vec4 border_color_bottom;
  vec4 border_color_left;
};

layout(set = 0, binding = 0) readonly buffer Rects { Rect rects[]; };
layout(set = 1, binding = 0) uniform mats { mat4 proj; };

layout(location = 0) out vec4 out_color;
layout(location = 1) out vec4 out_radius;
layout(location = 2) out vec4 out_thickness;
layout(location = 3) out vec2 out_size;
layout(location = 4) out vec2 out_uv;
layout(location = 5) out vec2 out_text_uv;
layout(location = 6) out vec4 out_border_color[4];
layout(location = 10) out int out_render_type;

const vec2 positions[6] =
    vec2[](vec2(0.5, 0.5), vec2(-0.5, 0.5), vec2(-0.5, -0.5), vec2(0.5, 0.5),
           vec2(-0.5, -0.5), vec2(0.5, -0.5));

const vec2 uvs[6] = vec2[](vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(0.0, 1.0),
                           vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));

void main() {
  vec2 vert_pos = positions[gl_VertexIndex];

  Rect rect = rects[gl_InstanceIndex];
  vec2 size = rect.position_and_size.zw;
  vec2 pos = rect.position_and_size.xy;

  out_color = rect.color;
  out_radius = rect.radius;
  out_thickness = rect.thickness;
  out_size = size;
  out_uv = uvs[gl_VertexIndex];
  out_text_uv = rect.uv_and_type.xy;
  out_border_color = vec4[](rect.border_color_top, rect.border_color_right,
                            rect.border_color_bottom, rect.border_color_left);

  out_render_type = int(rect.uv_and_type.z);
  gl_Position = proj * vec4(vert_pos * size + pos + size / 2, 1.0, 1.0);
}
