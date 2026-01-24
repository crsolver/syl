package syl

Box :: struct {
	using box: Layout_Box,
    style: ^Box_Style_Override,
}

update_box :: proc(box: ^Box) {
    for child in box.children do element_update(child)
}

// Style ______________________________________________________________________
Box_Style:: struct {
    text_color: [4]u8,
    font_size: int,
	background_color: [4]u8,
	border_color: [4][4]u8,
    border_thickness: [4]f32,
	border_radius: [4]f32,
	padding: [4]f32,
	transitions: Box_Transitions,
	gap: f32,
}

Box_Style_Override :: struct {
    text_color: Maybe([4]u8),
    font_size: Maybe(int),
	background_color: Maybe([4]u8),
	border_color: Maybe([4][4]u8),
    border_thickness: Maybe([4]f32),
	border_radius: Maybe([4]f32),
	padding: Maybe([4]f32),
	transitions: Maybe(Box_Transitions),
	gap: Maybe(f32),
}

Box_Transitions:: struct {
	background_color: Transition,
	padding: Transition,
}



box_destroy:: proc(box: ^Box) {
    box_deinit(box)
    free(box)
}

box_deinit:: proc(box: ^Box) {
    if box == nil do return
    layout_box_deinit(&box.box)
}

// Style

box_set_style :: proc(box: ^Box, style: ^Box_Style_Override, use_transitions: bool = true) {
    default := box.style_sheet.box
    fallback := box.style
    layout_box_set_style(box, style, fallback, default, use_transitions)
}

box_apply_style :: proc(box: ^Box, style: Box_Style_Override, use_transitions: bool = true) {
    layout_box_apply_style(box, style, use_transitions)
}
