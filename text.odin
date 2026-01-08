package syl

import rl "vendor:raylib"
import "core:strings"
import "core:fmt"
import "core:math"

/* in other file:
Base_Element :: struct {
	id: string,
	base_parent: ^Base_Element,
	parent: Element,
	base_style: ^Base_Style,
	children: [dynamic]Element,
	position: [2]f32,
	global_position: [2]f32,
	size: [2]f32,
	overrides: bit_set[Style_Property],
	theme: ^Style,
}*/
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

Text :: struct {
    using base: Base_Element,
    content: string,
	wrap: Text_Wrap,
	line_space: f32,
	lines: [dynamic]Text_Line
}

text :: proc(
	content: string = "",
    ref:              Maybe(^^Text) = nil,
) -> Element {
	text := new(Text)
    if r, ok := ref.?; ok {
        r^ = text
    }
	st := new(Base_Style) // TODO: temp
	text.base.base_style = st
	text.base_style.sizing = .Expand
	text.wrap = .Word
	text.content = content
	text.id = "text"
	return text
}

text_fit_sizing:: proc(text: ^Text) -> (f32, f32) {
	cstr := strings.clone_to_cstring(text.content)
	defer delete(cstr)
	width:f32 = f32(rl.MeasureText(cstr, 18))

	clear(&text.lines)

	if text.wrap == .None {
		append(&text.lines, Text_Line{
			size = {width, 18},
			width = i32(width),
			content = text.content,
		})
		text.size = {width, 18}
		text.min_size = {width, 18}
		width = width
		return width, width
	}

	// Find the width of the largest word in the content
	max_word_width: f32 = 0
	
	words := strings.split(text.content, " ")
	defer delete(words)

	for word in words {
		cstr := strings.clone_to_cstring(word)
		word_width := f32(rl.MeasureText(cstr, 18))
		delete(cstr)
		max_word_width = max(max_word_width, word_width)
	}
	
	font_size: f32 = 18
	if len(text.content) == 0 do font_size = 0
	
	text.size = {width, font_size}
	text.min_size = {max_word_width, font_size}
	return width, max_word_width
}

text_wrap :: proc(el: Element) {
	if text, ok := el.(^Text); ok {
		if text.wrap != .Word {
			return
		}

		fmt.println("text width:", text.size.x)
		fmt.println("text min_width:", text.min_size.x)
		
		// Clear existing lines
		clear(&text.lines)
		
		if len(text.content) == 0 {
			return
		}
		
		font_size: i32 = 18
		line_height: f32 = f32(font_size)
		max_width := text.size.x
		
		// Split content into words
		words := strings.split(text.content, " ")
		defer delete(words)
		
		if len(words) == 0 {
			return
		}
		
		// Build lines word by word
		current_line := strings.builder_make()
		defer strings.builder_destroy(&current_line)
		
		current_width: f32 = 0
		// Measure space using a C-string (consistent with other MeasureText calls)
		space_cstr := strings.clone_to_cstring(" ")
		defer delete(space_cstr)
		space_width := f32(rl.MeasureText(space_cstr, font_size))
		
		for word, i in words {
			word_cstr := strings.clone_to_cstring(word)
			defer delete(word_cstr)
			
			word_width := f32(rl.MeasureText(word_cstr, font_size))
			
			// Check if adding this word would overflow
			test_width := current_width
			if strings.builder_len(current_line) > 0 {
				test_width += space_width + word_width
			} else {
				test_width = word_width
			}
			
			// If word doesn't fit and we have content, start new line
			if test_width > max_width && strings.builder_len(current_line) > 0 {
				// Finalize current line
				line_content := strings.clone(strings.to_string(current_line))
				line := Text_Line{
					content = line_content,
					width = i32(math.ceil(current_width)),
					size = {current_width, f32(font_size)},
				}
				append(&text.lines, line)
				
				// Start new line with current word
				strings.builder_reset(&current_line)
				strings.write_string(&current_line, word)
				current_width = word_width
			} else {
				// Add word to current line
				if strings.builder_len(current_line) > 0 {
					strings.write_string(&current_line, " ")
				}
				strings.write_string(&current_line, word)
				current_width = test_width
			}
		}
		
		// Add final line if there's content
		if strings.builder_len(current_line) > 0 {
			line_content := strings.clone(strings.to_string(current_line))
			line := Text_Line{
				content = line_content,
				width = i32(math.ceil(current_width)),
				size = {current_width, f32(font_size)},
			}
			append(&text.lines, line)
		}
		text.size.y = f32(len(text.lines)) * line_height
	} else {
		for child in get_base(el).children do text_wrap(child)
	}
}

text_fit_sizing_height :: proc(text: ^Text) -> (f32,f32) {
	return text.size.y, text.min_size.y
}

text_update_positions :: proc(text: ^Text) {
	cursor := text.global_position
	for &line in text.lines {
		line.global_position = cursor
        cursor.y += line.size.y + text.line_space
    }
}