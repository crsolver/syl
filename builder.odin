package syl

import "core:mem"
import "base:runtime"
import "core:fmt"

layout_box_init :: proc(
	box: 			  ^Layout_Box,
	children:         Maybe([]^Element), 
	style_sheet:      ^Style_Sheet, 
	layout_direction: Layout_Direction, 
	gap:              Maybe(f32),
	padding:          Maybe([4]f32),
	background_color: Maybe([4]u8),
	border_radius:    Maybe(f32),
	border_color:     Maybe([4]u8),
	size:             [2]f32, // use for Fixed sizing, only apply if it's different than {0,0}
	width:            Maybe(f32),
	height:           Maybe(f32),
	sizing: 		  Sizing,
    width_sizing:     Maybe(SizingKind),
    height_sizing:    Maybe(SizingKind),
) {
	box.style_sheet = style_sheet
	box.sizing = sizing
    box.layout_direction = layout_direction

    // overrides
    if size.x != 0 {
        box.size.x = size.x
        box.sizing.x = .Fixed
    }

    if size.y != 0 {
        box.size.y = size.y
        box.sizing.y = .Fixed
    }
    
    if val, ok := border_radius.?; ok {
        box.border_radius = val
		box.overrides += {.Border_Radius}
	}

	if val, ok := width.?; ok {
        box.size.x = val
        box.sizing.x = .Fixed
    }

    if val, ok := height.?; ok {
        box.size.y = val
        box.sizing.y = .Fixed
    }
    
    if val, ok := width_sizing.?; ok {
        box.sizing.x = val
    }

    if val, ok := height_sizing.?; ok {
        box.sizing.y = val
    }

	if val, ok := gap.?; ok {
		box.overrides += { .Gap }
        box.gap = val
	}

	if val, ok := padding.?; ok {
		box.padding = val
		box.overrides += { .Padding }
	}

	if val, ok := background_color.?; ok {
		box.background_color = val
		box.overrides += { .Background_Color }
	}

    if val, ok := border_color.?; ok {
		box.border_color = val
		box.overrides += { .Border_Color }
	}

	if chldn, ok := children.?; ok {
		append_elems(&box.children, ..chldn)
	}

	for child in box.children do child.parent = box
	
	if style_sheet != nil {
		element_apply_style_recursive(box, style_sheet)
	}

}

box :: proc(
	children:       ..^Element, 
	handler:		  Maybe(MessageHandler(Box)) = nil,
    ref:              Maybe(^^Box) = nil,
    style_sheet:      ^Style_Sheet= nil,
	layout_direction: Layout_Direction = .Top_To_Bottom, 
	gap:              Maybe(f32) = nil,
	padding:          Maybe([4]f32) = nil,
	background_color: Maybe([4]u8) = nil,
	border_radius:    Maybe(f32) = nil,
	border_color:     Maybe([4]u8) = nil,
	size:             [2]f32 = {0,0}, // use for Fixed sizing, only apply if it's different than {0,0}
	width:            Maybe(f32) = nil,
	height:           Maybe(f32) = nil,
	sizing: 		  Sizing = {.Fit, .Fit},
    width_sizing:     Maybe(SizingKind) = nil,
    height_sizing:    Maybe(SizingKind) = nil,
    id: Maybe(string) = nil,
	on_state_changed: 	  proc(e: ^Element, to: Box_State) = nil,
	style:  		  ^Box_Styles_Override = nil,
) -> ^Box {
	box := new(Box)
	is_owner := false
	if h, ok := handler.?; ok {
		box = h.base
		box.handler = Handler{
			element = h.element,
			handler = h.handler,
			destroy = h.destroy,
		}
		is_owner = true
	} else {
		box = new(Box)
	}

	box.type = .Box
	if r, ok := ref.?; ok {
		r^ = box
	}

	box.style = style

	layout_box_init(box, children, style_sheet, layout_direction, gap, padding, background_color, border_radius, border_color, size, width, height, sizing, width_sizing, height_sizing)
	if is_owner {
		element_set_owner(box, box)
	}
	return box
}

text :: proc(
	content: string = "",
    ref:              Maybe(^^Text) = nil,
	font_size: i32 = 18,
	color: Maybe([4]u8) = nil,
	wrap: bool = true,
) -> ^Text {
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

copy_any_to_heap :: proc(val: any, allocator := context.allocator) -> any {
	// 1. If the any is nil, return a nil any
	if val.id == nil do return nil

	// 2. Get the type information (size and alignment)
	info := runtime.type_info_base(type_info_of(val.id))
	
	// 3. Allocate memory on the heap
	new_data, err := mem.alloc(info.size, info.align, allocator)
	if err != nil {
		return nil
	}

	// 4. Copy the data from the original pointer to the new heap pointer
	runtime.mem_copy(new_data, val.data, info.size)

	// 5. Return a new 'any' pointing to the heap memory
	return any{new_data, val.id}
}

button:: proc(
	children:      ..^Element, 
	handler:		  Maybe(MessageHandler(Button)) = nil,
    ref:              Maybe(^^Button) = nil,
    style_sheet:     ^Style_Sheet= nil,
	layout_direction: Layout_Direction = .Top_To_Bottom, 
	gap:              Maybe(f32) = nil,
	text_content:     Maybe(string) = nil,
	padding:          Maybe([4]f32) = nil,
	background_color: Maybe([4]u8) = nil,
	border_radius:    Maybe(f32) = nil,
	border_color:     Maybe([4]u8) = nil,
	size:             [2]f32 = {0,0}, // use for Fixed sizing, only apply if it's different than {0,0}
	width:            Maybe(f32) = nil,
	height:           Maybe(f32) = nil,
	sizing: 		  Sizing = {.Fit, .Fit},
    width_sizing:     Maybe(SizingKind) = nil,
    height_sizing:    Maybe(SizingKind) = nil,
    style:    		 ^Button_Styles_Override = nil,
	on_click: 		  Maybe(any) = nil,
) -> ^Button {
	button: ^Button
	is_owner := false
	if h, ok := handler.?; ok {
		button = h.base
		button.handler = Handler{
			element = h.element,
			handler = h.handler,
			destroy = h.destroy,
		}
		is_owner = true
	} else {
		button = new(Button)
	}

	button.type = .Button
	if r, ok := ref.?; ok {
		r^ = button
	}

	children_list := make([dynamic]^Element)
	defer delete(children_list)

	for child in children {
		append(&children_list, child)
	}

	button.style = style

	if val, ok := on_click.?; ok {
		button.on_click = copy_any_to_heap(val)
	}

	if val, ok := text_content.?; ok {
		str := fmt.aprintf("%s", val)
		button.text = text(str, wrap = false, font_size=18) 
		button.text.is_button_text = true
		append_elem(&children_list, button.text)
	}

	layout_box_init(button, children_list[:], style_sheet, layout_direction, gap, padding, background_color, border_radius, border_color, size, width, height, sizing, width_sizing, height_sizing)
	if is_owner {
		element_set_owner(button, button)
	}
	return button
}

center :: proc(content: ^Element) -> ^Element {
    return box(sizing=Expand, background_color=[4]u8{0,0,0,0}, children = {
        box(sizing=Expand, background_color=[4]u8{0,0,0,0}),
        box(sizing=Expand, layout_direction = .Left_To_Right, background_color=[4]u8{0,0,0,0}, children = {
            box(sizing=Expand, background_color=[4]u8{0,0,0,0}),
            content,
            box(sizing=Expand, background_color=[4]u8{0,0,0,0}),
        }),
        box(sizing=Expand, background_color=[4]u8{0,0,0,0}),
    })
}
