package main

import syl "../"
import renderer "../renderer/raylib"
import "core:math/ease"
import "core:fmt"
import rl "vendor:raylib"

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
		padding = 0
	},
	button = {
		normal = { 
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

primary_button := syl.Button_Styles_Override {
	normal = {
		text_color = WHITE,
		font_size = 18,
		background_color = BLUE,
		//padding = [4]f32{10,15,10,15},
		border_radius = 8,
		transitions = syl.Box_Transitions {
			background_color = {0.05, .Linear},
		},
	},
	hover = {
		background_color = RED,
	},
	press = {
		background_color = GREEN,
		transitions = syl.Box_Transitions{
			background_color = {0, .Linear}
		}
	}
}

Message :: enum { 
	Increment,
	Decrement
}

Counter :: struct {
	using base: syl.Box,
	count: int,
	counter_label: ^syl.Text,
}

counter_update:: proc(using counter: ^Counter, message: ^Message) {
	switch message^ {
		case .Increment: count += 1
		case .Decrement: count -= 1 
	}

	syl.text_set_content(counter_label, "%d", count)
}

counter_destroy :: proc(counter: ^Counter) {
	free(counter)
}

counter :: proc() -> ^Counter {
	c := new(Counter)
	syl.box(
		handler = syl.make_handler(c, syl.Box, Message, counter_update, counter_destroy),
		layout_direction = .Left_To_Right,
		gap = 10,
		children = {
			syl.button(text_content = "-", on_click = Message.Decrement, style=&primary_button),
			syl.box(
				syl.text("0", ref = &c.counter_label),
				sizing=syl.Expand,
			),
			syl.button(text_content = "+", on_click = Message.Increment),
		}
	)
	return c
}

main :: proc() {
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
		style_sheet = &style_sheet,
		padding = 40,
		gap=4,
	)

	renderer.init()
	for !rl.WindowShouldClose() {
		renderer.update(app)

		rl.BeginDrawing()
			rl.ClearBackground(cast(rl.Color)BLACK)
			renderer.render(app)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
