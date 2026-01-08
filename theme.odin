package syl

import "core:fmt"
import "core:math/ease"

Style_Property :: enum {
	Gap,
	Layout_Direction,
	Min_Width,
	Min_Height,
	Padding_All,
	Padding_Top,
	Padding_Right,
	Padding_Bottom,
	Padding_Left,
	Background_Color,
	Sizing,
}

Style :: struct {
	box: Box_Style_Class,
	box_classes: map[string]Box_Style_Class
}

Base_Style :: struct {
	background_color: [4]u8,
	padding_top: f32,
	padding_right: f32,
	padding_bottom: f32,
	padding_left: f32,
	min_width: f32,
	min_height: f32,
	sizing: Sizing,
}

Base_Style_Delta :: struct {
	background_color: Maybe([4]u8),
	padding_top: Maybe(f32),
	padding_right: Maybe(f32),
	padding_bottom: Maybe(f32),
	padding_left: Maybe(f32),
	min_width: Maybe(f32),
	min_height: Maybe(f32),
}

Transition_Setup:: struct {
	duration: f32,
	ease: ease.Ease,
}

Transition_Setups :: struct {
	background_color: Transition_Setup,
}

Box_Style_Setup :: struct {
	using base: Base_Style,
	layout_direction: Layout_Direction,
	transitions: Transition_Setups,
	gap: f32,
}

Box_Style :: struct {
	using base: Base_Style,
	layout_direction: Layout_Direction,
	transitions: map[Animatable_Property]Transition_Setup,
	gap: f32,
}

Box_Style_Delta :: struct {
	using base: Base_Style_Delta,
	layout_direction: Maybe(Layout_Direction),
	transitions: Maybe(Transition_Setups),
	gap: Maybe(f32),
}

Box_Style_Class :: struct {
	default: Box_Style_Setup,
	hover: Box_Style_Delta,
}

apply_style :: proc(style: ^Style, element: Element) {
	base := get_base(element)
	base.theme = style

	if base.base_style == nil { 
		for child in get_children(element) do apply_style(style, child)
		return
	}

	if !(Style_Property.Sizing in base.overrides) {
		base.base_style.sizing = style.box.default.sizing
	}

	if !(Style_Property.Background_Color in base.overrides) {
		base.base_style.background_color = style.box.default.background_color
	}

	if !(Style_Property.Padding_All in base.overrides) {
		if !(Style_Property.Padding_Top in base.overrides) {
			base.base_style.padding_top = style.box.default.padding_top
		}

		if !(Style_Property.Padding_Right in base.overrides) {
			base.base_style.padding_right = style.box.default.padding_right
		}

		if !(Style_Property.Padding_Bottom in base.overrides) {
			base.base_style.padding_bottom = style.box.default.padding_bottom
		}

		if !(Style_Property.Padding_Left in base.overrides) {
			base.base_style.padding_left = style.box.default.padding_left
		}
	}

	#partial switch e in element {
	case ^Box:
		if !(Style_Property.Gap in base.overrides) {
			e.style.gap = style.box.default.gap
		}
		/*
		if style.box.transitions.background_color.duration > 0 {
			e.style.transitions[.Background_Color] = style.box.transitions.background_color
		}*/
	}

	for child in get_children(element) do apply_style(style, child)
}

/*
TestStyle :: struct {
	classes: map[int]Box_Styles
}

TVariant :: enum {
	default,
}

theme := TestStyle() {
	classes = []Box_Styles {
		.default = {},
	}
}

TestBox :: struct {
	padding: f32,
	variant: int,
}

newbox :: proc(padding: Maybe(f32) = nil, variant: $T = TVariant.default) -> ^TestBox {
	b := new(TestBox)
	b.variant = int(variant)
	return b
}

m :: proc() {
	t := theme
	b := newbox(padding = 4)
}*/