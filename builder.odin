package syl

box :: proc(
	children:       ..^Element, 
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
	on_state_changed: 	  proc(e: ^Element, to: Box_State) = nil,
) -> ^Element {
	box := new(Box)
	box.type = .Box
	box.style_sheet = style_sheet
	box.sizing = sizing
    box.layout_direction = layout_direction

    if r, ok := ref.?; ok {
        r^ = box
    }

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

	for child in children do child.parent = box
	append_elems(&box.children, ..children)

    if style_sheet != nil {
        element_apply_style_recursive(box, style_sheet)
    }

	return box
}