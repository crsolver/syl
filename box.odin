package syl

import "core:fmt"
import rl "vendor:raylib"

Box_Styles_Override :: struct {
	default: Box_Style_Delta,
	hover:   Box_Style_Delta,
}

Box :: struct {
	using box: Layout_Box,
    style: ^Box_Styles_Override,
    state: Box_State,
}

Box_State :: enum {
    Default,
    Hover,
}

box_change_state :: proc(box: ^Box, state: Box_State) {
    box.state = state
    if box.style_sheet == nil do return

    default := box.style_sheet.box.default
    delta: Maybe(Box_Style_Delta)
    hover := box.style_sheet.box.hover
    if box.style != nil {
        delta := box.style.default
        hover = box.style.hover
    }

    switch state {
    case .Default: 
        if box.style != nil {
            box_apply_style_delta(box, box.style.default, delta, default)
        } else {
            box_apply_style_default(box, default)
        }
    case .Hover:   
        box_apply_style_delta(box, hover, delta, default) 
    }
}

update_box :: proc(box: ^Box) {
    mouse_pos := rl.GetMousePosition()
    box_rect := rl.Rectangle{box.global_position.x, box.global_position.y, box.size.x, box.size.y}
    collide := rl.CheckCollisionPointRec(mouse_pos, box_rect)

    if box.state == .Default && collide {
        box_change_state(box, .Hover)
    } else if box.state == .Hover && !collide {
        box_change_state(box, .Default)
    }

    for child in box.children do element_update(child)
}


// Style ______________________________________________________________________

Box_State_Styles :: struct {
	default: Box_Style,
	hover: Box_Style_Delta,
}

Box_Style:: struct {
    text_color: [4]u8,
    font_size: i32,
	background_color: [4]u8,
	border_color: [4]u8,
	border_radius: f32,
	padding: [4]f32,
	transitions: Box_Transitions,
	gap: f32,
}

Box_Style_Delta :: struct {
    text_color: Maybe([4]u8),
    font_size: Maybe(i32),
	background_color: Maybe([4]u8),
	border_color: Maybe([4]u8),
	border_radius: Maybe(f32),
	padding: Maybe([4]f32),
	padding_top: Maybe(f32),
	padding_right: Maybe(f32),
	padding_bottom: Maybe(f32),
	padding_left: Maybe(f32),
	transitions: Maybe(Box_Transitions),
	gap: Maybe(f32),
}

Box_Transitions:: struct {
	background_color: Transition,
	padding: Transition,
}

box_apply_style_default :: proc(box: ^Layout_Box, style: Box_Style) {
	if !(.Gap in box.overrides) {
		box.gap = style.gap
	}

	if !(.Background_Color in box.overrides) {
		t := style.transitions.background_color
		if t.duration > 0 {
			animate_color(&box.background_color, style.background_color, t.duration, t.ease)
		} else {
			box.background_color = style.background_color
		}
		box.background_color = style.background_color
	}

	if !(.Border_Color in box.overrides) {
		box.border_color = style.border_color
	}

	if !(.Border_Radius in box.overrides) {
		box.border_radius = style.border_radius
	}

	if !(.Padding in box.overrides) {
		using style.transitions.padding
        animate_float(&box.padding[0], style.padding[0], duration, ease)
        animate_float(&box.padding[1], style.padding[1], duration, ease)
        animate_float(&box.padding[2], style.padding[2], duration, ease)
        animate_float(&box.padding[3], style.padding[3], duration, ease)
	}
}

box_apply_style_delta:: proc(box: ^Layout_Box, new: Box_Style_Delta, delta: Maybe(Box_Style_Delta), fallback: Box_Style) {
	transitions := fallback.transitions
    gap := fallback.gap
    padding := fallback.padding
    background_color := fallback.background_color
    border_radius := fallback.border_radius
    border_color := fallback.border_color

    if d, ok := delta.?; ok {
        if g, ok := d.gap.?; ok do gap = g
        if p, ok := d.padding.?; ok do padding = p
        if bg, ok := d.background_color.?; ok do background_color = bg
        if br, ok := d.border_radius.?; ok do border_radius = br
        if bc, ok := d.border_color.?; ok do border_color = bc
        if val, ok := d.transitions.?; ok {
            transitions = val
        }
    }
    
    if g, ok := new.gap.?; ok do gap = g
    if p, ok := new.padding.?; ok do padding = p
    if bg, ok := new.background_color.?; ok do background_color = bg
    if br, ok := new.border_radius.?; ok do border_radius = br
    if bc, ok := new.border_color.?; ok do border_color = bc
    if val, ok := new.transitions.?; ok {
        transitions = val
    }

	if  !(.Gap in box.overrides) {
		box.gap = gap
	}

	if !(.Background_Color in box.overrides) {
		using transitions.background_color
		animate_color(&box.background_color, background_color, duration, ease)
	}

	if  !(.Border_Color in box.overrides) {
		box.border_color = border_color
	}

	if  !(.Border_Radius in box.overrides) {
        box.border_radius = border_radius
	}

	if !(.Padding in box.overrides) {
		using transitions.padding
        animate_float(&box.padding[0], padding[0], duration, ease)
        animate_float(&box.padding[1], padding[1], duration, ease)
        animate_float(&box.padding[2], padding[2], duration, ease)
        animate_float(&box.padding[3], padding[3], duration, ease)
	}
}

box_destroy:: proc(box: ^Box) {
    box_deinit(box)
    free(box)
}

box_deinit:: proc(box: ^Box) {
    if box == nil do return
    layout_box_deinit(&box.box)
}