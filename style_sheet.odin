package syl

import "core:math/ease"
import "core:fmt"

Style_Sheet :: struct {
	box: Box_State_Style,
	text: Text_Style,
}

Box_State_Style :: struct {
	default: Box_Style,
	hover: Box_Style_Delta,
}

Box_Style:: struct {
	background_color: [4]u8,
	border_color: [4]u8,
	border_radius: f32,
	padding: [4]f32,
	transitions: Box_Transition_Setups,
	gap: f32,
}

Box_Style_Delta :: struct {
	background_color: Maybe([4]u8),
	border_color: Maybe([4]u8),
	border_radius: Maybe(f32),
	padding: Maybe([4]f32),
	padding_top: Maybe(f32),
	padding_right: Maybe(f32),
	padding_bottom: Maybe(f32),
	padding_left: Maybe(f32),
	transitions: Maybe(Box_Transition_Setups),
	gap: Maybe(f32),
}

Transition_Setup:: struct {
	duration: f32,
	ease: ease.Ease,
}

Box_Transition_Setups :: struct {
	background_color: Transition_Setup,
	padding: Transition_Setup,
}

Text_Style :: struct {
	color: [4]u8,
	font_size: i32,
} 

// Set the values of non-overridden properties of Element and its children from the given StyleSheet
element_apply_style :: proc(element: ^Element, style: ^Style_Sheet) {
	element.style_sheet = style

	#partial switch element.type {
	case .Box:
		box_apply_style(cast(^Box)element, style.box.default)
	case .Text:
		text := cast(^Text)element
		if !(.Color in text.overrides) {
			text.style.color = style.text.color
		}
		return
	}
}

element_apply_style_recursive :: proc(element: ^Element, style: ^Style_Sheet) {
	element_apply_style(element, style)
	for child in element.children do element_apply_style_recursive(child, style)
}

box_apply_style_default :: proc(box: ^Box, style: Box_Style) {
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
		t := style.transitions.padding
		if t.duration > 0 {
			animate_float(&box.padding[0], style.padding[0], t.duration, t.ease)
			animate_float(&box.padding[1], style.padding[1], t.duration, t.ease)
			animate_float(&box.padding[2], style.padding[2], t.duration, t.ease)
			animate_float(&box.padding[3], style.padding[3], t.duration, t.ease)
		} else {
			box.padding = style.padding
		}
	}
}

box_apply_style_delta:: proc(box: ^Box, delta: Box_Style_Delta) {
	transitions := box.style_sheet.box.default.transitions
	delta_transitions := transitions

	if val, ok := delta.transitions.?; ok {
		delta_transitions = val
	}

	if val, ok := delta.gap.?; ok && !(.Gap in box.overrides) {
		box.gap = val 
	}

	if val, ok := delta.background_color.?; ok && !(.Background_Color in box.overrides) {
		t := transitions.background_color
		delta_t := delta_transitions.background_color

		if delta_t.duration > 0 {
			animate_color(&box.background_color, val, delta_t.duration, delta_t.ease)
		} else if t.duration > 0 {
			animate_color(&box.background_color, val, t.duration, t.ease)
		} else {
			box.background_color = val
		}
	}

	if val, ok := delta.border_color.?; ok && !(.Border_Color in box.overrides) {
		box.border_color = val
	}

	if val, ok := delta.border_radius.?; ok && !(.Border_Radius in box.overrides) {
		t := transitions.background_color
		delta_t := delta_transitions.background_color
	}

	if val, ok := delta.padding.?; ok && !(.Padding in box.overrides) {
		t := transitions.padding
		delta_t := delta_transitions.padding

		if delta_t.duration > 0 {
			animate_float(&box.padding[0], val[0], delta_t.duration, delta_t.ease)
			animate_float(&box.padding[1], val[1], delta_t.duration, delta_t.ease)
			animate_float(&box.padding[2], val[2], delta_t.duration, delta_t.ease)
			animate_float(&box.padding[3], val[3], delta_t.duration, delta_t.ease)
		} else if t.duration > 0 {
			animate_float(&box.padding[0], val[0], t.duration, t.ease)
			animate_float(&box.padding[1], val[1], t.duration, t.ease)
			animate_float(&box.padding[2], val[2], t.duration, t.ease)
			animate_float(&box.padding[3], val[3], t.duration, t.ease)
		} else {
			box.padding = val
		}
	}
}

box_apply_style :: proc {
	box_apply_style_default,
	box_apply_style_delta,
}