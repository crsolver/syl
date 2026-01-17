package main

import "core:strconv"
import "core:fmt"
import syl "../"
import renderer "../renderer/raylib"
import "core:math/ease"
import rl "vendor:raylib"
import "core:strings"

GREEN :: [4]u8{175,194,30, 255}
BLUE :: [4]u8{0, 0, 255, 255}
YELLOW :: [4]u8{255,255,40, 255}
WHITE :: [4]u8{255,255,255, 255}
BLACK :: [4]u8{0,0,0, 255}
BLANK :: [4]u8{0, 0, 0, 0}
RED :: [4]u8{255, 0, 0, 255}
DARK :: [4]u8{31,31,33, 255}
CELESTE :: [4]u8{80,99,132, 255}

SCREEN_W :: 800
SCREEN_H :: 500

style_sheet := syl.Style_Sheet {
	box = {
		default = {
			padding = 10
		},
	},
	button = {
		default = {
			text_color = BLACK,
			font_size = 18,
			background_color = GREEN,
			padding = {10,15,10,15},
			border_radius = 8,
			transitions = {
				background_color = {0.05, .Linear},
			},
		},
		hover = {
			background_color = YELLOW,
		},
		press = {
			background_color = GREEN,
			transitions = syl.Box_Transitions{
				background_color = {0, .Linear}
			}
		}
	},
	text = {
		color = WHITE,
		font_size = 18
	}
}

MessageKind :: enum {
	Increment,
	Decrement
}

Message :: struct {
	kind: MessageKind,
	amount: int,
}

Counter :: struct {
	using base: syl.Box,
	count: int,
	counter_label: ^syl.Text,
}

counter_update:: proc(counter: ^Counter, message: Message) {
	switch message.kind {
		case .Increment: counter.count += message.amount
		case .Decrement: counter.count -= message.amount
	}
	syl.text_set_content(counter.counter_label, "%d", counter.count)
}

counter :: proc() -> ^syl.Box {
	c := new(Counter)
	return syl.box(
		padding=0,
		handler = syl.make_handler(c, syl.Box, Message, counter_update),
		layout_direction = .Left_To_Right,
		gap = 10,
		width = 130,
		children = {
			syl.button(text_content = "-", on_click = Message{.Decrement, 1}),
			syl.box(
				syl.text("0", ref = &c.counter_label),
				sizing=syl.Expand,
			),
			syl.button(text_content = "+", on_click = Message{.Increment, 1}),
		}
	)
}

main :: proc() {
	//rl.SetConfigFlags({.WINDOW_RESIZABLE} | {.WINDOW_TOPMOST})
	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Syl in Raylib")
	rl.SetTargetFPS(60)

	app := syl.box(
		counter(), 
		counter(), 
		counter(), 
		counter(), 
		counter(), 
		counter(), 
		counter(),
		counter(),
		counter(),
		style_sheet = &style_sheet,
		gap=4,
	)

	for !rl.WindowShouldClose() {
		syl.calculate_layout(app)
		syl.element_update(app)
		syl.update_transitions()

		rl.BeginDrawing()
		rl.ClearBackground(cast(rl.Color)BLACK)
		renderer.draw(app)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}

