package syl

Layout_Direction :: enum {
	Top_To_Bottom,
	Left_To_Right,
}

Sizing :: union {}

Box :: struct {
	using base: Base_Element,
	style: Box_Style,
}

update_box_layout :: proc(box: ^Box) {
	for child in box.children do update_layout(child)

	padding_top := box.style.padding_top
	padding_left := box.style.padding_left

	gap := box.style.gap

	cursor_x := padding_left
	cursor_y := padding_top

	for child in box.children {
		set_position(child, {cursor_x, cursor_y})

		size := get_size(child)
        switch box.style.layout_direction {
        case .Left_To_Right: cursor_x += size.x + gap
        case .Top_To_Bottom: cursor_y += size.y + gap
        }
    }
}

box :: proc(
	children:       ..Element, 
	layout_direction: Maybe(Layout_Direction) = nil,
	gap:              Maybe(f32) = nil,
	padding:          Maybe(f32) = nil,
	padding_top:      Maybe(f32) = nil,
	padding_right:    Maybe(f32) = nil,
	padding_bottom:   Maybe(f32) = nil,
	padding_left:     Maybe(f32) = nil,
	background_color: Maybe([4]u8) = nil,
	size:             [2]f32 = {0,0},
	width:            Maybe(f32) = nil,
	height:           Maybe(f32) = nil,
) -> Element {
	box := new(Box)
	box.base.base_style = &box.style.base
	box.size = size

	// style overrides
	if val, ok := layout_direction.?; ok {
		box.style.layout_direction = val
		box.overrides += { .Layout_Direction }
	}

	if val, ok := gap.?; ok {
		box.style.gap = val
		box.overrides += { .Gap }
	}
	
	if val, ok := padding.?; ok {
		box.style.padding_top    = val
		box.style.padding_right  = val
		box.style.padding_bottom = val
		box.style.padding_left   = val
		box.overrides += { .Padding_All }
	}

	if val, ok := padding_top.?; ok {
		box.style.padding_top = val
		box.overrides += { .Padding_Top }
	}

	if val, ok := padding_right.?; ok {
		box.style.padding_right = val
		box.overrides += { .Padding_Right }
	}
	
	if val, ok := padding_bottom.?; ok {
		box.style.padding_bottom = val
		box.overrides += { .Padding_Bottom }
	}

	if val, ok := padding_left.?; ok {
		box.style.padding_left = val
		box.overrides += { .Padding_Left }
	}

	if val, ok := background_color.?; ok {
		box.style.background_color = val
		box.overrides += { .Background_Color }
	}

	for child in children do set_parent(child, box)
	append_elems(&box.children, ..children)
	return box
}
