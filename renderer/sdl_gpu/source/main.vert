#version 460

struct Rect {
  vec4 position_and_size;
  vec4 color;
  vec4 f1;
  vec4 f2;
  vec4 border_color[4];
  ivec4 flags;
};

layout(set = 0, binding = 0) readonly buffer Rects { Rect rects[]; };
layout(set = 1, binding = 0) uniform mats { mat4 proj; };

layout(location = 0) out vec4 out_color;
layout(location = 1) out vec4 out_radius;
layout(location = 2) out vec4 out_thickness;
layout(location = 3) out vec2 out_size;
layout(location = 4) out vec2 out_uv;
layout(location = 5) out vec4 out_border_color[4];
layout(location = 9) out ivec4 out_flags;

const vec2 positions[6] =
    vec2[](vec2(0.5, 0.5), vec2(-0.5, 0.5), vec2(-0.5, -0.5), vec2(0.5, 0.5),
           vec2(-0.5, -0.5), vec2(0.5, -0.5));

const vec2 uvs[6] = vec2[](vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(0.0, 1.0),
                           vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(1.0, 1.0));

const int uv_map[6] = int[](1, 0, 3, 1, 3, 2);

void main() {
  vec2 vert_pos = positions[gl_VertexIndex];

  Rect rect = rects[gl_InstanceIndex];
  vec2 size = rect.position_and_size.zw;
  vec2 pos = rect.position_and_size.xy;

  out_color = rect.color;
  out_radius = rect.f1;
  out_thickness = rect.f2;
  out_size = size;
  out_border_color = rect.border_color; 
  out_flags = rect.flags;

  if (rect.flags.x == 1) {
	  out_uv = vec2(rect.f1[uv_map[gl_VertexIndex]], rect.f2[uv_map[gl_VertexIndex]]);
  } else {
	  out_uv = uvs[gl_VertexIndex];
  }

  gl_Position = proj * vec4(vert_pos * size + pos + size / 2, 1.0, 1.0);
}
