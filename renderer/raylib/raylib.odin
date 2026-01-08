package raylib_renderer

import rl "vendor:raylib"
import syl "../.."
import "core:strings"

draw :: proc(element: syl.Element) {
	#partial switch e in element {
	case ^syl.Box: box_draw(e)
	case ^syl.Text: text_draw(e)
	}

	for e in syl.get_children(element) do draw(e)
}

box_draw :: proc(box: ^syl.Box) {
	pos := box.global_position
	size := box.size
	if box.style.background_color.a > 0 {
		rl.DrawRectangle(i32(pos.x), i32(pos.y), i32(size.x), i32(size.y), cast(rl.Color)box.style.background_color)
		//rl.DrawRectangleRounded({pos.x, pos.y, size.x, size.y},0.2, 10, cast(rl.Color)box.style.background_color)
	}
	rl.DrawRectangleLines(i32(pos.x), i32(pos.y), i32(size.x), i32(size.y), rl.GRAY)
	//rl.DrawRectangleRoundedLines({pos.x, pos.y, size.x, size.y},0.2, 10, rl.GRAY)
}

stack_draw :: proc(stack: ^syl.Stack) {
	pos := stack.global_position
	size := stack.size
	rl.DrawRectangleLines(i32(pos.x), i32(pos.y), i32(size.x), i32(size.y), rl.BLACK)
	if stack.style.background_color.a > 0 {
		rl.DrawRectangle(i32(pos.x), i32(pos.y), i32(size.x), i32(size.y), cast(rl.Color)stack.style.background_color)
	}
	for child in stack.children do draw(child)
}

text_draw :: proc(text: ^syl.Text) {
    if len(text.lines) == 0 {
        return
    }

    font_size: i32 = 18
    line_height: f32 = f32(font_size)
    
    // Get text color from style or use default
    color := rl.DARKGRAY
    // If you have style system: 
    // if text.base_style != nil && .Color in text.overrides {
    //     color = text.base_style.color
    // }
    
    rl.DrawRectangle(i32(text.global_position.x), i32(text.global_position.y), i32(text.size.x), i32(text.size.y), rl.LIGHTGRAY)
    // Draw each line
    for line, i in text.lines {
        // Draw the line content
        line_cstr := strings.clone_to_cstring(line.content)
        defer delete(line_cstr)

        
        rl.DrawText(
            line_cstr,
            i32(line.global_position.x),
            i32(line.global_position.y),
            font_size,
            color,
        )
    }
}