package syl

Element_Type :: enum { Box, Text }

Element :: struct {
	type: Element_Type,
	parent: ^Element,
	children: [dynamic]^Element,
	position: [2]f32,
	global_position: [2]f32,
	size: [2]f32,
	min_size: [2]f32,
	sizing: Sizing,
	style_sheet: ^Style_Sheet,
}

SizingKind :: enum {
	Fit,
	Fixed,
	Expand,
}

Sizing :: [2]SizingKind


element_add_child:: proc(element: ^Element, children: ..^Element) { 
	for child in children {
		append_elem(&element.children, child)
		child.parent = element
	}
}

element_set_position :: proc(element: ^Element, pos: [2]f32) { 
	element.position = pos
	element.global_position = pos

	if element.parent != nil {
		element.global_position += element.parent.global_position
	}
	for child in element.children {
		child.global_position = child.position + element.global_position
	}
}

element_set_global_position :: proc(element: ^Element, pos: [2]f32) { 
	element.position = pos
	element.global_position = pos

	if element.parent != nil {
		element.position -= element.parent.global_position
	}

	for child in element.children {
		child.global_position = child.position + element.global_position
	}
}

element_update :: proc(el: ^Element) {
	#partial switch el.type {
	case .Box: update_box(cast(^Box)el)
	}
}

val :: proc(val: $T) -> ^T {
	return val
}

transition_manager := Transition_Manager{}