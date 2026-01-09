package main

import rl "vendor:raylib"
import renderer "../../renderer/raylib"
import syl "../.."
import "core:fmt"
import "core:math/ease"

BLUE :: [4]u8{0,0,255,255}
RED :: [4]u8{255,0,0,255}
GREEN:: [4]u8{0,255,0,255}
YELLOW :: [4]u8{255,255,0,255}
BLANK :: [4]u8{0,0,0,0}
WHITE :: [4]u8{255,255,255,255}

SCREEN_W :: 800
SCREEN_H :: 500

style_sheet := syl.StyleSheet {
	box = {
		default = {
			background_color = BLUE,
			padding_right = 10,
			padding_left = 10,
			padding_bottom = 10,
			padding_top = 10,
			gap = 10,
			transitions = {
				background_color = { duration = 0.4, ease = .Cubic_In },
			}
		},
		hover = {
			background_color = RED,
		}
	},
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE} | {.WINDOW_TOPMOST})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Syl in Raylib")
	rl.SetTargetFPS(60)
	
	p : ^syl.Box
	app := syl.box(
		style_sheet = &style_sheet,
		layout_direction = .Left_To_Right,
		size = {SCREEN_W, SCREEN_H},
		background_color = BLANK,
		id = "parent",
		ref = &p,
		children = {
			syl.box(id="sidebar", layout_direction = .Top_To_Bottom, gap=0, padding=0, width=150, sizing={.Fixed, .Expand}, background_color = BLANK, children = {
				syl.box(syl.text("option 1"), width_sizing = .Expand, padding = 10),
				syl.box(syl.text("option 2"), width_sizing = .Expand, padding = 10),
				syl.box(syl.text("option 3"), width_sizing = .Expand, padding = 10),
				syl.box(syl.text("option 4"), width_sizing = .Expand, padding = 10),
				syl.box(syl.text("option 5"), width_sizing = .Expand, padding = 10),
				syl.box(syl.text("option 6"), width_sizing = .Expand, padding = 10),
				syl.box(syl.text("option 7"), width_sizing = .Expand, padding = 10),
			}),
			syl.box(id="main", children = {
				syl.text("Odin is a general-purpose programming language with distinct typing built for high performance, modern systems and data-oriented programming. Odin is the C alternative for the Joy of Programming.")
			})	
		}
	)

	syl.calculate_layout(app)

    for !rl.WindowShouldClose() {
		syl.update(app)
		syl.update_transitions()

		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE) 
			renderer.draw(app)
			size := 40
			//for row in 0..<50 do rl.DrawLine(0, i32(row*size), 800, i32(row*size), rl.GRAY)
			//for col in 0..<50 do rl.DrawLine(i32(col*size), 0, i32(col*size), 400, rl.GRAY)
		rl.EndDrawing()
    }

    rl.CloseWindow()
}