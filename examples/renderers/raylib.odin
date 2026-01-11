package main

import syl "../.."
import renderer "../../renderer/raylib"
import "core:math/ease"
import rl "vendor:raylib"

GREEN :: [4]u8{195,214,44, 255}
DARK_GREEN :: [4]u8{110,210,40, 255}
BLACK :: [4]u8{25,25,25, 255}
BLANK :: [4]u8{0, 0, 0, 0}
RED :: [4]u8{255, 0, 0, 255}

SCREEN_W :: 800
SCREEN_H :: 500

style_sheet := syl.StyleSheet {
	box = {
		default = {
			border_color = GREEN,
			transitions = {
				background_color = {duration = 0.4, ease = .Cubic_In}
			},
		},
	},
	text = {
		color = GREEN,
	}
}

item :: proc(title, active: string) -> ^syl.Element {
	return syl.box(width_sizing=.Expand, children={
	syl.box(syl.text(title, wrap=false), padding=14, border_color=BLANK),
		syl.box(
			syl.box(id="anim",width_sizing=.Expand, padding=10, background_color=GREEN, border_color=BLACK, children={
				syl.text(active, color=BLACK),
			}),
			syl.box(
				syl.text("SEMI-AUTO"),
				syl.text("MAN-OVERRIDE"),
				padding=14,
				width_sizing=.Expand,
			),
			padding=1,
			gap=4,
			width_sizing=.Expand
		)
	})
}

make_app :: proc() -> ^syl.Element {
	// You can pass a reference to a pointer to get a reference of an Element...
	title: ^syl.Text 
	return syl.box(size = {SCREEN_W, SCREEN_H}, padding = 10, style_sheet = &style_sheet, children = {
		syl.box(sizing=syl.Expand, padding = 20, children = {
			syl.box(sizing = syl.Expand, gap = 0, padding = 0, children = {
				syl.box(width_sizing =.Expand, padding = 14, layout_direction = .Left_To_Right, children = {
					syl.box(sizing = syl.Expand, border_color = BLANK),
					syl.text("REMOTE SENTRY WEAPON SYSTEM", wrap = false),
					syl.box(sizing = syl.Expand, border_color = BLANK),
				}),
				syl.box(width_sizing = .Expand, padding = 0, layout_direction = .Left_To_Right, children = {
					item("System mode", "AUTO-REMOTE"),	
					item("Weapon status", "SAFE"),	
					item("Neural link", "STANDBY"),	
					item("Hull integrity", "91.3%"),	
				}),
				syl.box(sizing = syl.Expand, padding = 20, children = {
					syl.text("Hull schematic floats center-screen, a wireframe...")
				}),
			})
		})
	})
}

main :: proc() {
	//rl.SetConfigFlags({.WINDOW_RESIZABLE} | {.WINDOW_TOPMOST})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Syl in Raylib")
	rl.SetTargetFPS(60)

	app := make_app()	
	syl.calculate_layout(app)

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
