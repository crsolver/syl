package raylib_renderer

import rl "vendor:raylib"
import syl "../.."
import "core:strings"

mouse_buttons_map := [syl.Mouse]rl.MouseButton{
	.LEFT    = .LEFT,
	.RIGHT   = .RIGHT,
	.MIDDLE  = .MIDDLE,
}

Box_Shader :: struct {
    shader:            rl.Shader,
    loc_position:      i32,
    loc_size:          i32,
    loc_bg_color:      i32,
    loc_border_color:  i32,
    loc_border_thick:  i32,
    loc_border_radius: i32,
    loc_screen_height: i32,
}

box_shader: Box_Shader

init :: proc(allocator := context.allocator) {
	syl.create_context(measure_text, allocator)
	init_layout_box_shader()
}

deinit :: proc() {
	rl.UnloadShader(box_shader.shader)
	syl.destroy_context()
}

init_layout_box_shader :: proc() {
    // Load shaders from renderer/raylib relative to the process working directory
    // Use the alternative fragment shader `alt.fs` (converted for Raylib).
    shader := rl.LoadShader("assets/vertex.vs", "assets/box_sdf.fs")
    box_shader = Box_Shader{
        shader = shader,
        loc_position      = rl.GetShaderLocation(shader, "position"),
        loc_size          = rl.GetShaderLocation(shader, "size"),
        loc_bg_color      = rl.GetShaderLocation(shader, "backgroundColor"),
        loc_border_color  = rl.GetShaderLocation(shader, "borderColor"),
        loc_border_thick  = rl.GetShaderLocation(shader, "borderThickness"),
        loc_border_radius = rl.GetShaderLocation(shader, "borderRadius"),
        loc_screen_height = rl.GetShaderLocation(shader, "screenHeight"),
    }
}

measure_text :: proc(s: string, font: rawptr, font_size: int, spacing: f32) -> int {
	cstr := strings.clone_to_cstring(s)
	defer delete(cstr)
	if font == nil {
		return int(rl.MeasureText(cstr, i32(font_size)))
	} else {
		return int(rl.MeasureTextEx((cast(^rl.Font)font)^, cstr, f32(font_size), spacing).x)
	}
}

update :: proc(root: ^syl.Element) {
	syl.input_mouse_move(rl.GetMousePosition())

	for button_rl, button_mu in mouse_buttons_map {
		switch {
		case rl.IsMouseButtonPressed(button_rl):
			syl.input_mouse_down(button_mu)
		case rl.IsMouseButtonReleased(button_rl):
			syl.input_mouse_up(button_mu)
		}
	}

	syl.update(root)
	syl.clear_context()
}

render :: proc(element: ^syl.Element) {
	#partial switch element.type {
	case .Box, .Button: draw_box(cast(^syl.Layout_Box)element)
	case .Text: text_draw(cast(^syl.Text)element)
	}

	for e in element.children do render(e)
}

draw_box :: proc(box: ^syl.Layout_Box) {
    // Set position and size uniforms
    rl.SetShaderValue(box_shader.shader, box_shader.loc_position, &box.global_position, .VEC2)
    rl.SetShaderValue(box_shader.shader, box_shader.loc_size, &box.size, .VEC2)
    
    // Set background color
    bg_color := color_u8_to_f32(box.background_color)
    rl.SetShaderValue(box_shader.shader, box_shader.loc_bg_color, &bg_color, .VEC4)
    
    // Set border colors (flatten 4 colors into single array)
    border_colors: [16]f32
    for i in 0..<4 {
        c := color_u8_to_f32(box.border_color[i])
        border_colors[i*4 + 0] = c.r
        border_colors[i*4 + 1] = c.g
        border_colors[i*4 + 2] = c.b
        border_colors[i*4 + 3] = c.a
    }
    rl.SetShaderValueV(box_shader.shader, box_shader.loc_border_color, &border_colors, .VEC4, 4)
    
    // Set border thickness (top, right, bottom, left)
    rl.SetShaderValue(box_shader.shader, box_shader.loc_border_thick, &box.border_thickness, .VEC4)
    
    // Set border radius (top-left, top-right, bottom-right, bottom-left)
    rl.SetShaderValue(box_shader.shader, box_shader.loc_border_radius, &box.border_radius, .VEC4)
    
    // provide screen height so shader can convert gl_FragCoord to top-left coords
    screen_h := f32(rl.GetScreenHeight())
    rl.SetShaderValue(box_shader.shader, box_shader.loc_screen_height, &screen_h, .FLOAT)
    
    // Draw rectangle with shader
    rl.BeginShaderMode(box_shader.shader)
        rl.DrawRectangle(
            i32(box.global_position.x),
            i32(box.global_position.y),
            i32(box.size.x),
            i32(box.size.y),
            rl.WHITE, // Color ignored, shader handles it
        )
    rl.EndShaderMode()
}

// Helper to convert u8 color to normalized float
color_u8_to_f32 :: proc(color: [4]u8) -> [4]f32 {
    return {
        f32(color.r) / 255.0,
        f32(color.g) / 255.0,
        f32(color.b) / 255.0,
        f32(color.a) / 255.0,
    }
}

get_roundness :: proc(rect_size: rl.Vector2, radius_pixels: f32) -> f32 {
	min_dimension := min(rect_size.x, rect_size.y)
	if min_dimension <= 0.0 do return 0.0
	roundness := (2 * radius_pixels / min_dimension)
	return clamp(roundness, 0.0, 1.0)
}

text_draw :: proc(text: ^syl.Text) {
    if len(text.lines) == 0 do return

    font_size: i32 = auto_cast text.font_size
    line_height: f32 = f32(font_size)

    //rl.DrawRectangleLines(i32(text.global_position.x), i32(text.global_position.y), i32(text.size.x), i32(text.size.y), rl.GRAY)
    
    for line, i in text.lines {
        line_cstr := strings.clone_to_cstring(line.content)
        defer delete(line_cstr)
		if text.font == nil {
			rl.DrawText(
				line_cstr,
				i32(line.global_position.x),
				i32(line.global_position.y),
				font_size,
				cast(rl.Color)text.color,
			)
		} else {
			rl.DrawTextEx(
				(cast(^rl.Font)text.font)^,
				line_cstr,
				line.global_position,
				f32(text.font_size),
				text.spacing,
				cast(rl.Color)text.color,
			)
		}
    }
}
