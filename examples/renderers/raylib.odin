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

style := syl.Style {
	box = {
		default = {
			layout_direction = .Top_To_Bottom,
			background_color = WHITE,
			padding_right = 10,
			padding_left = 10,
			padding_bottom = 10,
			padding_top = 10,
			gap = 10,
			sizing = .Expand,
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
	rl.SetTargetFPS(100)
	/*
	app := syl.box(
		id = "parent",
		sizing = .Fixed, 
		layout_direction = .Left_To_Right,
		size = {SCREEN_W, SCREEN_H},
		background_color = BLANK,
		children = {
			syl.box(
				syl.box(),
				syl.box(),
				syl.box(),
				syl.box(),
				syl.box(),
				syl.box(),
				background_color = BLANK,
			),
			syl.box(
				layout_direction = .Left_To_Right,
				children = {
					syl.box(),
					syl.box(),
					syl.box(),
					syl.box(),
					syl.box(),
					syl.box(),
				},
				background_color = BLANK,
			),
		}
	)*/
	t: ^syl.Text
	app := syl.box(
		size = {400, 400},
		layout_direction = .Top_To_Bottom,
		sizing = .Fixed,
		id = "parent",
		background_color = BLANK,
		children = {
			syl.box(),
			syl.box(
				syl.text("This is an example of a text element inside a box. It should wrap properly and adjust the box size accordingly.", ref = &t),
			),
		}
	)

	syl.apply_style(&style, app)
	syl.calculate_layout(app)

	fmt.printfln("Text min size: %v", syl.get_min_size(t))
	fmt.printfln("Text size: %v", t.size)
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