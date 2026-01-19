package syl

Style_Sheet :: struct {
	box: Box_State_Styles,
	text: Text_Style,
	button: Button_Styles,
	boxes: map[string]Box_State_Styles
}

// Set the values of non-overridden properties of Element and its children from the given StyleSheet
element_apply_style :: proc(element: ^Element, style: ^Style_Sheet) {
	element.style_sheet = style

	#partial switch element.type {
	case .Box:
		box_apply_style_default(cast(^Box)element, style.box.default)
	case .Text:
		text := cast(^Text)element
		if text.is_button_text do return
		if !(.Color in text.overrides) {
			text.style.color = style.text.color
		}
		return
	case .Button:
		b := cast(^Button)element
		if b.style != nil {
			box_apply_style_delta(b, b.style.default, nil, style.button.default)
			if b.text != nil do text_set_style_from_box_style_delta(b.text, b.style.default, nil, style.button.default)
		} else {
			box_apply_style_default(b, style.button.default)
			if b.text != nil do text_set_style_from_box_style(b.text, style.button.default)
		}
	}
}

element_apply_style_recursive :: proc(element: ^Element, style: ^Style_Sheet) {
	element_apply_style(element, style)
	for child in element.children do element_apply_style_recursive(child, style)
}
