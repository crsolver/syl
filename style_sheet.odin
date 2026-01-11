package syl

import "core:math/ease"

StyleSheet :: struct {
	box: Box_Style_Class,
	text: Text_Style,
}

Style_Property :: enum {
	Gap,
	Padding_All,
	Padding_Top,
	Padding_Right,
	Padding_Bottom,
	Padding_Left,
	Background_Color,
	Border_Color,
	Border_Radius,
	Width,
	Height,
	Text_Color,
}

Element_Base_Style :: struct {
	background_color: [4]u8,
	border_color: [4]u8,
	border_radius: f32,
	padding_top: f32,
	padding_right: f32,
	padding_bottom: f32,
	padding_left: f32,
	width: f32,
	height: f32,
}

Transition_Setup:: struct {
	duration: f32,
	ease: ease.Ease,
}

Transition_Setups :: struct {
	background_color: Transition_Setup,
}

Box_Style_Class :: struct {
	default: Box_Style_Setup,
	hover: Box_Style_Delta,
}

Box_Style_Setup :: struct {
	using base: Element_Base_Style,
	layout_direction: Layout_Direction,
	transitions: Transition_Setups,
	gap: f32,
}

Box_Style :: struct {
	using base: Element_Base_Style,
	transitions: map[Animatable_Property]Transition_Setup,
	gap: f32,
}

// Used to override Default Element_Base_Style
Element_Base_Style_Delta :: struct {
	background_color: Maybe([4]u8),
	padding_top: Maybe(f32),
	padding_right: Maybe(f32),
	padding_bottom: Maybe(f32),
	padding_left: Maybe(f32),
}

Box_Style_Delta :: struct {
	using element: Element_Base_Style_Delta,
	layout_direction: Maybe(Layout_Direction),
	transitions: Maybe(Transition_Setups),
	gap: Maybe(f32),
}

Text_Style :: struct {
	color: [4]u8,
	font_size: i32,
} 

// Set the values of non-overridden properties of Element and its children from the given StyleSheet
element_apply_style :: proc(element: ^Element, style: ^StyleSheet) {
	element.style_sheet = style

	#partial switch element.type {
	case .Box:
		box := cast(^Box)element
		if !(.Gap in element.overrides) {
			box.style.gap = style.box.default.gap
		}
		/*
		if style.box.transitions.background_color.duration > 0 {
			e.style.transitions[.Background_Color] = style.box.transitions.background_color
		}*/
	case .Text:
		text := cast(^Text)element
		if !(.Text_Color in text.overrides) {
			text.style.color = style.text.color
		}
		return
	}

	if element.base_style == nil { 
		return
	}

	if !(.Background_Color in element.overrides) {
		element.base_style.background_color = style.box.default.background_color
	}

	if !(.Border_Color in element.overrides) {
		element.base_style.border_color = style.box.default.border_color
	}

	if !(.Border_Radius in element.overrides) {
		element.base_style.border_radius = style.box.default.border_radius
	}

	if !(.Padding_All in element.overrides) {
		if !(.Padding_Top in element.overrides) {
			element.base_style.padding_top = style.box.default.padding_top
		}

		if !(.Padding_Right in element.overrides) {
			element.base_style.padding_right = style.box.default.padding_right
		}

		if !(.Padding_Bottom in element.overrides) {
			element.base_style.padding_bottom = style.box.default.padding_bottom
		}

		if !(.Padding_Left in element.overrides) {
			element.base_style.padding_left = style.box.default.padding_left 
		}
	}
}

element_apply_style_recursive :: proc(element: ^Element, style: ^StyleSheet) {
	element_apply_style(element, style)
	for child in element.children do element_apply_style_recursive(child, style)
}