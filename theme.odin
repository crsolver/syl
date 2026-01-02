package syl


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
}

Style :: struct {
	box: Box_Style,
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
}

Base_Style_Delta :: struct {
	background_color: Maybe([4]f32),
	padding_top: Maybe(f32),
	padding_right: Maybe(f32),
	padding_bottom: Maybe(f32),
	padding_left: Maybe(f32),
	min_width: Maybe(f32),
	min_height: Maybe(f32),
}

Box_Style :: struct {
	using base: Base_Style,
	layout_direction: Layout_Direction,
	gap: f32,
}

Box_Style_Delta :: struct {
	using base: Base_Style_Delta,
	layout_direction: Maybe(Layout_Direction),
	gap: Maybe(f32),
}

Box_Style_Class :: struct {
	default: Box_Style_Delta,
	//hover: Box_Style_Delta,
}


apply_style :: proc(style: ^Style, element: Element) {
	base := get_base(element)

	if !(Style_Property.Background_Color in base.overrides) {
		base.base_style.background_color = style.box.background_color
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