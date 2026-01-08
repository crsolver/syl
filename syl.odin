package syl

import "vendor:raylib"

Element:: union {
	^Box,
	^Stack,
	^Text,
}

Sizing :: enum {
	Fit,
	Fixed,
	Expand,
	Expand_Horizontal,
	Expand_Vertical,
}

Base_Element :: struct {
	id: string,
	base_parent: ^Base_Element,
	parent: Element,
	base_style: ^Base_Style,
	children: [dynamic]Element,
	position: [2]f32,
	global_position: [2]f32,
	size: [2]f32,
	min_size: [2]f32,
	overrides: bit_set[Style_Property],
	theme: ^Style,
}

get_min_size :: proc(element: Element) -> [2]f32 {
	base := get_base(element)
	return base.min_size
}

get_base :: proc(element: Element) -> ^Base_Element { 
	#partial switch e in element {
	case ^Box: return &e.base
	case ^Text: return &e.base
	}
	return nil
}

get_parent :: proc(element: Element) -> Element { 
	return get_base(element).parent
}

get_children :: proc(element: Element) -> []Element { 
	return get_base(element).children[:]
}

set_parent :: proc(element: Element, parent: Element)  { 
	base := get_base(element)
	base_parent := get_base(parent)
	base.parent = parent
	base.base_parent = base_parent
}

get_size :: proc(element: Element) -> [2]f32 { 
	return get_base(element).size
}

set_size :: proc(element: Element, size: [2]f32) { 
	get_base(element).size = size
}

get_position :: proc(element: Element) -> [2]f32 { 
	return get_base(element).position
}

get_global_position :: proc(element: Element) -> [2]f32 { 
	base := get_base(element)
	return base.global_position
}

set_position :: proc(element: Element, pos: [2]f32) { 
	base := get_base(element)

	base.position = pos
	base.global_position = pos

	if base.base_parent != nil {
		base.global_position += base.base_parent.global_position
	}
	for child in base.children {
		child_base := get_base(child)
		child_base.global_position = child_base.position + base.global_position
	}
}

set_global_position :: proc(element: Element, pos: [2]f32) { 
	base := get_base(element)

	base.position = pos
	base.global_position = pos

	if base.base_parent != nil {
		base.position -= base.base_parent.global_position
	}

	for child in base.children {
		child_base := get_base(child)
		child_base.global_position = child_base.position + base.global_position
	}
}

update :: proc(el: Element) {
	#partial switch v in el {
	case ^Box: update_box(v)
	}
}

val :: proc(val: $T) -> ^T {
	return val
}

transition_manager := Transition_Manager{}