package syl

import "core:mem"

@(private="package")
ctx: ^Context

@(private="package")
Context :: struct {
	allocator: mem.Allocator,
	mouse_pos: [2]f32,
	mouse_down_bits:	 Mouse_Set,
	mouse_pressed_bits:	 Mouse_Set,
	mouse_released_bits: Mouse_Set,
	measure_text: proc(string, rawptr, int, f32) -> int,
	transitions: struct {
		color: [dynamic]Color_Transition,
	    float: [dynamic]Float_Transition,
	}
}

Mouse :: enum u32 {
	LEFT,
	RIGHT,
	MIDDLE,
}

Mouse_Set :: distinct bit_set[Mouse; u32]

create_context :: proc(
	measure_text: proc(string, rawptr, int, f32) -> int,
	allocator := context.allocator,
) {
    ctx = new(Context, allocator)
	ctx.allocator = allocator
	ctx.transitions.color= make([dynamic]Color_Transition, allocator)
    ctx.transitions.float = make([dynamic]Float_Transition, allocator)
	ctx.measure_text = measure_text
}

destroy_context :: proc() {
    if ctx == nil do return
    delete(ctx.transitions.color)
    delete(ctx.transitions.float)
    free(ctx, ctx.allocator)
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
	ctx.mouse_down_bits = {}
	ctx.mouse_pressed_bits = {}
	ctx.mouse_released_bits = {}
}
