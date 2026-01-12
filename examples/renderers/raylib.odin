package main

import "core:fmt"
import syl "../.."
import renderer "../../renderer/raylib"
import "core:math/ease"
import rl "vendor:raylib"

GREEN :: [4]u8{195,214,44, 255}
YELLOW :: [4]u8{255,255,40, 255}
BLACK :: [4]u8{25,25,25, 255}
BLANK :: [4]u8{0, 0, 0, 0}
RED :: [4]u8{255, 0, 0, 255}

SCREEN_W :: 800
SCREEN_H :: 500

style_sheet := syl.Style_Sheet {
	box = {
		default = {
			background_color = GREEN,
			padding = {10,15,10,15},
			border_radius = 8,
			transitions = {
				background_color = {0.3, .Linear},
				padding = {0.15, .Linear}
			},
		},
		hover = {
			background_color = YELLOW,
			padding = [4]f32{10,15,10,15} * 2,
		}
	},
	text = {
		color = BLACK,
	}
}

new_app :: proc() -> ^syl.Element {
	return syl.box(syl.center(syl.box(style_sheet = &style_sheet, background_color=BLANK, layout_direction=.Left_To_Right, gap=10, padding=10, children = {
		syl.box(syl.text("option 1", wrap = false)),
		syl.box(syl.text("option 2", wrap = false)),
		syl.box(syl.text("option 3", wrap = false)),
		syl.box(syl.text("option 4", wrap = false)),
		syl.box(syl.text("option 5", wrap = false)),
		syl.box(syl.text("option 6", wrap = false)),
	})), size={SCREEN_W, SCREEN_H})
}

main :: proc() {
	//rl.SetConfigFlags({.WINDOW_RESIZABLE} | {.WINDOW_TOPMOST})
	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Syl in Raylib")
	rl.SetTargetFPS(60)

	app := new_app()

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
