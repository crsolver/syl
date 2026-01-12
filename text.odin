package syl

import rl "vendor:raylib"
import "core:strings"
import "core:fmt"

Text_Wrap :: enum {
    None,
    Word,
}

Text_Line :: struct {
	size: [2]f32,
	global_position: [2]f32,
	content: string,
    width: i32,
    min_width: i32,
}

Text_Property :: enum {
	Color
}

Text :: struct {
    using base: Element,
	style: Text_Style,
    content: string,
	wrap: Text_Wrap,
	line_space: f32,
	lines: [dynamic]Text_Line,
	overrides: bit_set[Text_Property]
}

text :: proc(
	content: string = "",
    ref:              Maybe(^^Text) = nil,
	font_size: i32 = 18,
	color: Maybe([4]u8) = nil,
	wrap: bool = true,
) -> ^Element {
	text := new(Text)
    if r, ok := ref.?; ok {
        r^ = text
    }
	text.type = .Text
	text.sizing = {.Expand, .Expand}
	if wrap {
		text.wrap = .Word
	}
	text.style.font_size = font_size
	text.content = content
	if val, ok := color.?; ok {
		text.style.color = val
		text.overrides += {.Color}
	}
	return text
}

text_fit:: proc(text: ^Text) -> (f32, f32) {
	cstr := strings.clone_to_cstring(text.content)
	defer delete(cstr)
	width:f32 = f32(rl.MeasureText(cstr, text.style.font_size))

	clear(&text.lines)

	if text.wrap == .None {
		append(&text.lines, Text_Line{
			size = {width, f32(text.style.font_size)},
			width = i32(width),
			content = text.content,
		})
		text.size = {width, f32(text.style.font_size)}
		text.min_size = {width, f32(text.style.font_size)}
		width = width
		return width, width
	}

	// Find the width of the largest word in the content
	max_word_width: f32 = 0
	
	words := strings.split(text.content, " ")
	defer delete(words)

	for word in words {
		cstr := strings.clone_to_cstring(word)
		word_width := f32(rl.MeasureText(cstr, i32(text.style.font_size)))
		delete(cstr)
		max_word_width = max(max_word_width, word_width)
	}
	font_size := text.style.font_size	
	if len(text.content) == 0 do font_size = 0
	
	text.size = {width, f32(font_size)}
	text.min_size = {max_word_width, f32(text.style.font_size)}
	return width, max_word_width
}

text_wrap :: proc(e: ^Element) {
	// TODO: Fix text overflow
	if e.type == .Text {
		text := cast(^Text)e
		if text.wrap != .Word {
			return
		}
		
		clear(&text.lines)
		
		if len(text.content) == 0 {
			return
		}
		
		max_width := text.size.x
		
		words := strings.split(text.content, " ")
		defer delete(words)
		
		if len(words) == 0 {
			return
		}
		
		space_width := measure_text(" ", text.style.font_size)
		
		current_line := strings.builder_make()
		defer strings.builder_destroy(&current_line)
		current_width: f32 = 0
		
		for word in words {
			word_width := measure_text(word, text.style.font_size)
			
			// Check if word fits on current line
			test_width := word_width
			if strings.builder_len(current_line) > 0 {
				test_width = current_width + (space_width*2) + word_width // Temporal Fix: two spaces
			}
			
			// Start new line if needed
			if test_width > max_width && strings.builder_len(current_line) > 0 {
				add_line(&text.lines, strings.to_string(current_line), current_width, text.style.font_size)
				strings.builder_reset(&current_line)
				strings.write_string(&current_line, word)
				current_width = word_width
			} else {
				if strings.builder_len(current_line) > 0 {
					strings.write_string(&current_line, " ")
				}
				strings.write_string(&current_line, word)
				current_width = test_width
			}
		}
		
		// Add final line
		if strings.builder_len(current_line) > 0 {
			add_line(&text.lines, strings.to_string(current_line), current_width, text.style.font_size)
		}
		
		// Update text dimensions
		text.size.y = f32(len(text.lines)) * f32(text.style.font_size)
		text.size.x = max_width  // Keep container width, don't expand
	} else {
		for child in e.children do text_wrap(child)
	}
}

measure_text :: proc(s: string, font_size: i32) -> f32 {
	cstr := strings.clone_to_cstring(s)
	defer delete(cstr)
	return f32(rl.MeasureText(cstr, font_size))
}

add_line :: proc(lines: ^[dynamic]Text_Line, content: string, width: f32, font_size: i32) {
	append(lines, Text_Line{
		content = strings.clone(content),
		size = {width, f32(font_size)},
		width = i32(width),
	})
}

text_fit_height :: proc(text: ^Text) -> (f32,f32) {
	return text.size.y, text.min_size.y
}

text_update_positions :: proc(text: ^Text) {
	cursor := text.base.global_position
	for &line in text.lines {
		line.global_position = cursor
        cursor.y += line.size.y + text.line_space
    }
}