package syl

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
    content: string,
	wrap: Text_Wrap,
	line_space: f32,
	lines: [dynamic]Text_Line,
	overrides: bit_set[Text_Property],
	is_button_text: bool,
	color: [4]u8,
	font_size: int,
}

text_fit:: proc(text: ^Text) -> (f32, f32) {
	width:f32 = f32(ctx.measure_text(text.content, text.font_size))

	clear(&text.lines)

	if text.wrap == .None {
		append(&text.lines, Text_Line{
			size = {width, f32(text.font_size)},
			width = i32(width),
			content = text.content,
		})
		text.size = {width, f32(text.font_size)}
		text.min_size = {width, f32(text.font_size)}
		width = width
		return width, width
	}

	// Find the width of the largest word in the content
	max_word_width: f32 = 0
	
	words := strings.split(text.content, " ")
	defer delete(words)

	for word in words {
		word_width := f32(ctx.measure_text(word, text.font_size))
		max_word_width = max(max_word_width, word_width)
	}
	font_size := text.font_size	
	if len(text.content) == 0 do font_size = 0
	
	text.size = {width, f32(font_size)}
	text.min_size = {max_word_width, f32(text.font_size)}
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
		
		space_width := f32(ctx.measure_text(" ", text.font_size))
		
		current_line := strings.builder_make()
		defer strings.builder_destroy(&current_line)
		current_width: f32 = 0
		
		for word in words {
			word_width := f32(ctx.measure_text(word, text.font_size))
			
			// Check if word fits on current line
			test_width := word_width
			if strings.builder_len(current_line) > 0 {
				test_width = current_width + (space_width*2) + word_width // Temporal Fix: two spaces
			}
			
			// Start new line if needed
			if test_width > max_width && strings.builder_len(current_line) > 0 {
				add_line(&text.lines, strings.to_string(current_line), current_width, text.font_size)
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
			add_line(&text.lines, strings.to_string(current_line), current_width, text.font_size)
		}
		
		// Update text dimensions
		text.size.y = f32(len(text.lines)) * f32(text.font_size)
		text.size.x = max_width  // Keep container width, don't expand
	} else {
		for child in e.children do text_wrap(child)
	}
}


add_line :: proc(lines: ^[dynamic]Text_Line, content: string, width: f32, font_size: int) {
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

text_set_content :: proc(label: ^Text, format: string, args: ..any) {
    delete(label.content)  // Safe to call on empty strings
    label.content = fmt.aprintf(format, ..args)
}

// Style ______________________________________________________________________

Text_Style :: struct {
	color: [4]u8,
	font_size: int,
}

Text_Style_Override:: struct {
	color: Maybe([4]u8),
	font_size: Maybe(int),
}

text_set_style_from_box_style :: proc(text: ^Text, style: ^Box_Style_Override) {
	if style != nil {
		if t, ok := style.text_color.?; ok {
			text.color = t
		}

		if f, ok := style.font_size.?; ok {
			text.font_size = f
		}
		return
	}
	if text.style_sheet != nil {
		default := text.style_sheet.button.normal
		text.color = default.text_color
		text.font_size = default.font_size
	}
}


text_set_style_from_box_style_override :: proc(text: ^Text, new: Box_Style_Override, delta: Maybe(Box_Style_Override), default: Box_Style) {
	text_color := default.text_color
	size := default.font_size

	if d, ok := delta.?; ok {
		if t, ok := d.text_color.?; ok {
			text_color = t
		}
		if f, ok := d.font_size.?; ok {
			size = f
		}
	}

	if t, ok := new.text_color.?; ok {
		text_color = t
	}
	if f, ok := new.font_size.?; ok {
		size = f
	}

	text.color = text_color
	text.font_size = size
}

text_set_style_override :: proc(text: ^Text, color: [4]u8, font_size: int) {
	text.color = color
	text.font_size = font_size
}

text_appy_style :: proc(text: ^Text, style: Text_Style) {
	text.color = style.color
	text.font_size = style.font_size
}

text_appy_style_override :: proc(text: ^Text, style: Text_Style_Override, default: Text_Style) {
	if val, ok := style.color.?; ok {
		text.color = val
	}
	if val, ok := style.font_size.?; ok {
		text.font_size = val
	}
}

text_deinit :: proc(text: ^Text) {
	base_element_deinit(&text.base)	
	delete(text.lines)
	delete(text.content)
}

text_destroy:: proc(text: ^Text) {
	text_deinit(text)	
	free(text)
}