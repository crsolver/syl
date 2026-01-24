package main

import syl "../"
import "core:math/ease"

SCREEN_W :: 800
SCREEN_H :: 500

BACKGROUND_COLOR :: [4]u8{17, 45, 58, 255}
BLACK :: [4]u8{0, 0, 0, 255}
WHITE :: [4]u8{255, 255, 255, 255}
PRIMARY_COLOR :: [4]u8{236, 155, 92, 255} // orange
SECONDARY_COLOR :: [4]u8{160, 223, 227, 255}
PRIMARY_TEXT_COLOR :: [4]u8{25, 16, 0, 255} // black
MUTED :: [4]u8{46, 79, 90, 255}

GREEN :: [4]u8{175, 194, 30, 255}
BLUE :: [4]u8{0, 0, 255, 255}
YELLOW :: [4]u8{255, 255, 40, 255}
BLANK :: [4]u8{0, 0, 0, 0}
RED :: [4]u8{255, 0, 0, 255}
DARK :: [4]u8{31, 31, 33, 255}
CELESTE :: [4]u8{80, 99, 132, 255}

style_sheet := syl.Style_Sheet {
	box = {padding = {0, 0, 0, 10}, transitions = {padding = {0.15, .Linear}}},
	button = {
		normal = {
			text_color = SECONDARY_COLOR,
			font_size = 18,
			background_color = BACKGROUND_COLOR,
			padding = {10, 30, 10, 30},
			// border with different colors
			border_color = {
				PRIMARY_COLOR, // top
				MUTED, // right
				MUTED, // bottom
				PRIMARY_COLOR, // left
			},
			border_thickness = {2, 2, 2, 12},
			border_radius = {20, 20, 20, 20},
			transitions = {background_color = {0.2, .Cubic_Out}, padding = {0.1, .Cubic_Out}},
		},
		hover = {
			background_color = PRIMARY_COLOR,
			text_color = PRIMARY_TEXT_COLOR,
			border_color = PRIMARY_COLOR,
		},
		press = {
			background_color = WHITE,
			border_color = WHITE,
			padding = [4]f32{13, 30, 7, 30},
			transitions = syl.Box_Transitions{background_color = {0, .Linear}},
		},
	},
	text = {color = SECONDARY_COLOR, font_size = 18},
}

Game_UI :: struct {
	count:      int,
	using base: syl.Box,
	container:  ^syl.Box,
	sub_menus:  struct {
		start:    ^syl.Box,
		settings: ^syl.Box,
		network:  ^syl.Box,
		credits:  ^syl.Box,
		exit:     ^syl.Box,
	},
	current:    ^syl.Box,
}

Message :: enum {
	Start,
	Settings,
	Network,
	Credits,
	Exit,
}

game_ui_update :: proc(using game_ui: ^Game_UI, msg: ^Message) {
	if current != nil {
		syl.element_remove_child(container, current)
		current.padding = 0
	}

	switch msg^ {
	case .Start:
		current = sub_menus.start
	case .Network:
		current = sub_menus.network
	case .Settings:
		current = sub_menus.settings
	case .Credits:
		current = sub_menus.credits
	case .Exit:
		current = sub_menus.exit
	}

	syl.element_add_child(container, current, use_transitions = true)
}

game_menu_ui :: proc() -> ^Game_UI {
	game_ui := new(Game_UI)
	// This allows the box to receive messages
	handler := syl.make_handler(game_ui, syl.Box, Message, game_ui_update, game_ui_destroy)
	game_ui.sub_menus.start = start()
	game_ui.sub_menus.settings = settings()
	game_ui.sub_menus.network = network()
	game_ui.sub_menus.credits = credits()
	game_ui.sub_menus.exit = exit()

	// With a handler syl.box will initialize Game_UI instead creating a new Box
	syl.box(
		size = {SCREEN_H, SCREEN_H},
		style_sheet = &style_sheet,
		handler = handler,
		children = {
			syl.center(
				syl.box(
					syl.box(
						gap = 10,
						children = {
							syl.button(
								text_content = "START",
								size = {200, 40},
								on_mouse_over = Message.Start,
							),
							syl.button(
								text_content = "SETTINGS",
								size = {200, 40},
								on_mouse_over = Message.Settings,
							),
							syl.button(
								text_content = "NETWORK",
								size = {200, 40},
								on_mouse_over = Message.Network,
							),
							syl.button(
								text_content = "CREDITS",
								size = {200, 40},
								on_mouse_over = Message.Credits,
							),
							syl.button(
								text_content = "EXIT",
								size = {200, 40},
								on_mouse_over = Message.Exit,
							),
						},
					),
					syl.box(ref = &game_ui.container, width = 200, height_sizing = .Expand),
					layout_direction = .Left_To_Right,
				),
			),
		},
	)

	return game_ui
}

start :: proc() -> ^syl.Box {
	return syl.box(
		gap = 10,
		children = {
			syl.button(text_content = "CONTINUE", size = {200, 40}),
			syl.button(text_content = "NEW GAME", size = {200, 40}),
		},
	)
}

settings :: proc() -> ^syl.Box {
	return syl.box(
		gap = 10,
		children = {
			syl.button(text_content = "AUDIO", size = {200, 40}),
			syl.button(text_content = "VIDEO", size = {200, 40}),
			syl.button(text_content = "CONTROLS", size = {200, 40}),
			syl.button(text_content = "GAMEPLAY", size = {200, 40}),
		},
	)
}

network :: proc() -> ^syl.Box {
	return syl.box(
		gap = 10,
		children = {
			syl.button(text_content = "CONNECT TO SERVER", size = {240, 40}),
			syl.button(text_content = "HOST GAME", size = {240, 40}),
			syl.button(text_content = "DISCONNECT", size = {240, 40}),
		},
	)
}

credits :: proc() -> ^syl.Box {
	return syl.box(
		gap = 10,
		sizing = syl.Expand,
		children = {syl.center(syl.text("Programmer: CRSOLVER", wrap = false))},
	)
}

exit :: proc() -> ^syl.Box {
	return syl.box(
		sizing = syl.Expand,
		children = {
			syl.center(
				syl.box(
					syl.text("ARE YOU SURE?", wrap = false),
					syl.box(
						syl.button(text_content = "YES", size = {100, 40}),
						syl.button(text_content = "NO", size = {100, 40}),
						layout_direction = .Left_To_Right,
						padding = 0,
						gap = 10,
					),
					gap = 10,
					padding = 0,
				),
			),
		},
	)
}

game_ui_destroy :: proc(game_ui: ^Game_UI) {
	syl.element_destroy(game_ui.sub_menus.start)
	syl.element_destroy(game_ui.sub_menus.network)
	syl.element_destroy(game_ui.sub_menus.settings)
	syl.element_destroy(game_ui.sub_menus.credits)
	syl.element_destroy(game_ui.sub_menus.exit)
	free(game_ui)
}
