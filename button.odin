package syl

import rl "vendor:raylib"
import "core:fmt"

Button_State :: enum {
    Default,
    Hover,
	Press,
}

Button :: struct {
	using box: Box,
    text: ^Text,
	button_state: Button_State,
    on_button_state_changed: proc(e: ^Button, to: Button_State),
    on_click: Maybe(any),
}

button_change_state :: proc(button: ^Button, state: Button_State) {
	if button.on_button_state_changed != nil {
		button.on_button_state_changed(button, state)
	}

    button.button_state = state
	if button.style_sheet == nil do return
    
    default := button.style_sheet.button.default
    hover := button.style_sheet.button.hover
    press := button.style_sheet.button.press

    switch state {
    case .Default: 
        box_apply_style_default(button, default)
        if button.text != nil do text_set_style_from_box_style(button.text, default)
    case .Hover:   
        box_apply_style_delta(button, hover, default)
        if button.text != nil do text_set_style_from_box_style_delta(button.text, hover, default)
    case .Press:   
        box_apply_style_delta(button, press, default)
        if button.text != nil do text_set_style_from_box_style_delta(button.text, press, default)
    }
}

test_update_button :: proc(b: ^Button) -> any {
    return b.on_click
}

button_dispatch :: proc(button: ^Button, message: Maybe(any)) {
    if m, ok := message.?; ok {
        if button.owner != nil {
            if h, ok := button.owner.handler_data.?; ok {
                h.handler(h.owner, m.data)
            }
        }
    }
}

update_button :: proc(button: ^Button) {
    mouse_pos := rl.GetMousePosition()
    box_rect := rl.Rectangle{button.global_position.x, button.global_position.y, button.size.x, button.size.y}
    collide := rl.CheckCollisionPointRec(mouse_pos, box_rect)

    if collide && rl.IsMouseButtonPressed(.LEFT) {
        if button.button_state != .Press {
            button_dispatch(button, button.on_click)
            button_change_state(button, .Press)
        }
    } else if collide {
        if button.button_state != .Hover {
            button_change_state(button, .Hover)
        }
    } else {
        if button.button_state != .Default {
            button_change_state(button, .Default)
        }
    }

    for child in button.children do element_update(child)
}

// Style ______________________________________________________________________
Button_State_Styles :: struct {
	default: Box_Style,
	hover: Box_Style_Delta,
	press: Box_Style_Delta
}

EventMessage :: struct {}