package raylib_renderer

import rl "vendor:raylib"
import syl "../.."
import "core:strings"

mouse_buttons_map := [syl.Mouse]rl.MouseButton{
	.LEFT    = .LEFT,
	.RIGHT   = .RIGHT,
	.MIDDLE  = .MIDDLE,
}

init :: proc() {
	syl.ctx.measure_text = measure_text
}

measure_text :: proc(s: string, font_size: int) -> int {
	cstr := strings.clone_to_cstring(s)
	defer delete(cstr)
	return int(rl.MeasureText(cstr, i32(font_size)))
}

update :: proc(root: ^syl.Element) {
	assert(syl.ctx.measure_text != nil)
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
	case .Box, .Button: box_draw(cast(^syl.Box)element)
	case .Text: text_draw(cast(^syl.Text)element)
	}

	for e in element.children do render(e)
}

box_draw :: proc(box: ^syl.Box) {
	pos := box.global_position
	size := box.size
	border_width: f32 = 1
	if size.x <= 0.0 || size.y <= 0.0 do return
	
	// Draw background at original size
	if box.background_color.a > 0 {
		bg_roundness := get_roundness(size, box.border_radius)
		rl.DrawRectangleRounded({pos.x, pos.y, size.x, size.y}, bg_roundness, 20, cast(rl.Color)box.background_color)
	}
	
	// Draw border expanded outward
	if box.border_color.a > 0 && border_width > 0 {
		border_pos := pos - {border_width, border_width}
		border_size := size + {border_width * 2, border_width * 2}
		border_roundness: f32 = 0
		if box.border_radius > 0 do border_roundness = get_roundness(border_size, box.border_radius + border_width)
		rl.DrawRectangleRoundedLinesEx({pos.x, pos.y, size.x, size.y}, border_roundness, 20, border_width, cast(rl.Color)box.border_color)
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
        
        rl.DrawText(
            line_cstr,
            i32(line.global_position.x),
            i32(line.global_position.y),
            font_size,
            cast(rl.Color)text.color,
        )
    }
}