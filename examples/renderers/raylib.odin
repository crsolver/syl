package main

import rl "vendor:raylib"
import renderer "../../renderer/raylib"
import syl "../.."

BLUE :: [4]u8{0,0,255,255}
RED :: [4]u8{255,0,0,255}
TRANSPARENT :: [4]u8{0,0,0,0}

style := syl.Style {
	box = {
		layout_direction = .Top_To_Bottom,
		background_color = BLUE,
		padding_top = 10,
		padding_right = 10,
		padding_bottom = 10,
		padding_left = 10,
		gap = 10,
	},
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(800, 400, "Syl in Raylib")
	rl.SetTargetFPS(60)

	app := syl.box(
		background_color = RED,
		size = {220, 400},
		children = {
			syl.box(size={200,50}),
			syl.box(size={200,50}, background_color = RED),
			syl.box(size={200,50}),
			syl.box(size={200,50}),
			syl.box(size={200,50}),
			syl.box(size={200,50}),
		},
	)

	syl.apply_style(&style, app)
	syl.update(app)

    for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK) 
			renderer.draw(app)
		rl.EndDrawing()
    }

    rl.CloseWindow()
}