package main

import "core:fmt"
import "core:mem"

import syl "../"

import sdl_renderer "../renderer/sdl_gpu/"
import sdl "vendor:sdl3"

import rl_renderer "../renderer/raylib/"
import rl "vendor:raylib"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	run_sdl_backend()
}

run_raylib_backend :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "Game Settings")
	ui := game_menu_ui()

	rl_renderer.init()
	defer rl_renderer.deinit()

	for !rl.WindowShouldClose() {
		rl_renderer.update(ui)

		rl.BeginDrawing()
		rl.ClearBackground(cast(rl.Color)BACKGROUND_COLOR)
		rl_renderer.render(ui)
		rl.EndDrawing()
	}

	rl.CloseWindow()

}

run_sdl_backend :: proc() {
	r := sdl_renderer.init(
		context.allocator,
		"Game Menu",
		{
			.VERTEX = "../renderer/sdl_gpu/compiled/main.vert.sprv",
			.FRAGMENT = "../renderer/sdl_gpu/compiled/main.frag.sprv",
		},
	)

	defer sdl_renderer.destroy(&r)

	f := sdl_renderer.add_font(&r, "./assets/Lora.ttf", 16)

	sdl_renderer.default_font = f
	r.clear_color = sdl_renderer.color_syl_to_sdl(BACKGROUND_COLOR)

	syl.create_context(sdl_renderer.measure_text)

	ui := game_menu_ui()
	
	defer syl.destroy_context()

	run: for {

		event := sdl.Event{}

		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				break run
			case .KEY_DOWN:
				if event.key.scancode == .ESCAPE {
					break run
				}
			}
		}

		x, y: f32
		_ = sdl.GetMouseState(&x, &y)

		syl.input_mouse_move({x, y})

		syl.update(ui)
		syl.clear_context()

		sdl_renderer.begin(&r)
		sdl_renderer.feed_validate(&r, sdl_renderer.feed_renderer(&r, ui, 0, nil))
		sdl_renderer.render(&r)
	}
}
