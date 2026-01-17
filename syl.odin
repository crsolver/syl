package syl

import "base:intrinsics"
import "core:fmt"

transition_manager := Transition_Manager{}

MessageHandler :: struct($T: typeid) {
	handler: proc(rawptr, rawptr),
	base: ^T,
	element: rawptr,
	message_type: typeid,
}

make_handler :: proc(owner: ^$E, $B:typeid, $M: typeid, update_proc: proc(^E, M)) -> MessageHandler(B) where (intrinsics.type_field_type(E, "base") == B) {
	return {
		element = owner,
		base = &owner.base,
		handler = (proc(rawptr, rawptr))(update_proc),
		message_type = M,
	}
}

Element_Type :: enum { Box, Text, Button }

HandlerData :: struct {
	owner: rawptr,
	handler: proc(rawptr, rawptr)
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
	handler: proc(rawptr, rawptr),
	handler_data: Maybe(HandlerData),
}

SizingKind :: enum {
	Fit,
	Fixed,
	Expand,
}

Sizing :: [2]SizingKind

element_add_child:: proc(element: ^Element, child: ^Element) { 
	append_elem(&element.children, child)
	child.parent = element
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