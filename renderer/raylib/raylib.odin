package raylib_renderer

import rl "vendor:raylib"
import syl "../.."

draw :: proc(element: syl.Element) {
	switch e in element {
	case ^syl.Box: draw_box(e)
	}

	for e in syl.get_children(element) {
		switch v in e {
		case ^syl.Box: draw_box(v)
		}
	}
}

draw_box :: proc(box: ^syl.Box) {
	pos := box.global_position
	size := box.size
	rl.DrawRectangle(i32(pos.x), i32(pos.y), i32(size.x), i32(size.y), cast(rl.Color)box.style.background_color)
	rl.DrawRectangleLines(i32(pos.x), i32(pos.y), i32(size.x), i32(size.y), rl.BLACK)
}