package syl

import "base:intrinsics"

transition_manager := Transition_Manager{}

MessageHandler :: struct($T: typeid) {
	handler: proc(rawptr, rawptr),
	destroy: proc(rawptr),
	base: ^T,
	element: rawptr,
}

// ^custom_element, base_type, message_type, update, destroy
make_handler :: proc(element: ^$E, $B:typeid, $M: typeid, update_proc: proc(^E, ^M), destroy_proc: proc(^E)) -> MessageHandler(B) where (intrinsics.type_field_type(E, "base") == B) {
	return {
		element = element,
		base = &element.base,
		handler = auto_cast update_proc,
		destroy = auto_cast destroy_proc,
	}
}

Element_Type :: enum { Box, Text, Button }

Handler :: struct {
	element: rawptr,
	handler: proc(rawptr, rawptr),
	destroy: proc(rawptr)
}

Element :: struct {
	owner: ^Element,
	type: Element_Type,
	parent: ^Element,
	children: [dynamic]^Element,
	position: [2]f32,
	global_position: [2]f32,
	size: [2]f32,
	min_size: [2]f32,
	sizing: Sizing,
	style_sheet: ^Style_Sheet,
	handler: Maybe(Handler),
}

SizingKind :: enum {
	Fit,
	Fixed,
	Expand,
}

Sizing :: [2]SizingKind

element_add_child:: proc(element: ^Element, child: ^Element, use_transitions: bool = false) { 
	if child.parent == element do return
	append_elem(&element.children, child)
	element_set_style_sheet_recursive(child, element.style_sheet, use_transitions)
	child.parent = element
	element_set_owner(child, element.owner)
}

element_remove_child:: proc(element: ^Element, child: ^Element) { 
	if child.parent == element {
		child.style_sheet = nil
		child.parent = nil
		child.owner = nil
		remove_item(&element.children, child)
	}
}

element_remove_children:: proc(element: ^Element) { 
	for child in element.children {
		element_remove_child(element, child)
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

events: [dynamic]any

element_update :: proc(el: ^Element) {
	#partial switch el.type {
	case .Box: update_box(cast(^Box)el)
	case .Button: update_button(cast(^Button)el)
	}
}

element_set_owner :: proc(element: ^Element, owner: ^Element) {
	if element.owner == nil {
		element.owner = owner
		for child in element.children {
			element_set_owner(child, owner)
		}
	}
}

clear_children :: proc(element: ^Element) {
	box := cast(^Box)element
	if box == nil do return
	
	// Free all children elements
	for child in box.children {
		element_destroy(child)
	}
	
	// Clear the dynamic array
	clear(&box.children)
}

element_append :: proc(element: ^Element, child: ^Element) {
	append_elem(&element.children, child)
	child.parent = element // Will be set by the parent later if needed
}

base_element_deinit :: proc(element: ^Element) {
    if element == nil do return
    for child in element.children do element_destroy(child) 
    delete(element.children)
}

element_destroy :: proc(element: ^Element) {
    if element == nil do return

	if h, ok := element.handler.?; ok {
		switch element.type {
			case .Text:   text_deinit(cast(^Text)element)
			case .Box:    box_deinit(cast(^Box)element)
			case .Button: button_deinit(cast(^Button)element)
		}
		h.destroy(h.element)
		return
	}

 	switch element.type {
		case .Text:   text_destroy(cast(^Text)element)
		case .Box:    box_destroy(cast(^Box)element)
		case .Button: button_destroy(cast(^Button)element)
    }
}

Mouse :: enum u32 {
	LEFT,
	RIGHT,
	MIDDLE,
}
Mouse_Set :: distinct bit_set[Mouse; u32]

App :: struct {
	ctx: Context,
	root: ^Element
}

ctx: Context

Context :: struct {
	mouse_pos: [2]f32,
	mouse_down_bits:	 Mouse_Set,
	mouse_pressed_bits:	 Mouse_Set,
	mouse_released_bits: Mouse_Set,
	measure_text: proc(string, int) -> int
}

update :: proc(el: ^Element) {
	calculate_layout(el)
	element_update(el)
	update_transitions()
}

input_mouse_move :: proc(pos: [2]f32) {
	ctx.mouse_pos = pos
}

input_mouse_down :: proc(btn: Mouse) {
	ctx.mouse_down_bits    += {btn}
	ctx.mouse_pressed_bits += {btn}
}

input_mouse_up:: proc(btn: Mouse) {
	ctx.mouse_down_bits -= {btn}
	ctx.mouse_released_bits += {btn}
}

clear_context :: proc() {
	ctx.mouse_down_bits = {} // clear
	ctx.mouse_pressed_bits = {} // clear
	ctx.mouse_released_bits = {} // clear
}