package main

import syl "../"
import "core:math/ease"

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

Message_Counter :: enum { 
	Increment,
	Decrement
}

Counter :: struct {
	using base: syl.Box,
	count: int,
	counter_label: ^syl.Text,
}

counter_update:: proc(using counter: ^Counter, message: ^Message_Counter) {
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
		handler = syl.make_handler(c, syl.Box, Message_Counter, counter_update, counter_destroy),
		layout_direction = .Left_To_Right,
		gap = 10,
		children = {
			syl.button(text_content = "-", on_click = Message_Counter.Decrement, style=&primary_button),
			syl.box(
				syl.text("0", ref = &c.counter_label),
				sizing=syl.Expand,
			),
			syl.button(text_content = "+", on_click = Message_Counter.Increment),
		}
	)
	return c
}

counter_app :: proc () -> ^syl.Box{
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

	return app 
}

