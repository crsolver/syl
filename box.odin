// Retained mode Layout implementation based on https://github.com/nicbarker/clay
// How Clay's UI Layout Algorithm Works: https://www.youtube.com/watch?v=by9lQvpvMIc&t=1273s

package syl

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

Box_Property :: enum {
	Gap,
	Padding,
	Background_Color,
	Border_Color,
	Border_Radius,
}

Box :: struct {
	using element: Element,
    background_color: [4]u8,
	border_color: [4]u8,
	border_radius: f32,
	padding: [4]f32, // top, right, bottom, left
	transitions: map[Animatable_Property]Transition,
	gap: f32,padding_left: f32,
    state: Box_State,
    layout_direction: Layout_Direction,
    on_state_changed: proc(e: ^Element, to: Box_State),
	overrides: bit_set[Box_Property],
    box_handler: Maybe(MessageHandler(Box))
}

Layout_Direction :: enum {
	Top_To_Bottom,
	Left_To_Right,
}

Box_State :: enum {
    Default,
    Hover,
}

calculate_layout :: proc(element: ^Element) {
    element_fit(element, 0) // fit widths
    element_expand_collapse(element, 0) // widths
    text_wrap(element)
    element_fit(element, 1) // fit heights
    element_expand_collapse(element, 1) // heights
    update_positions(element)
}

// Calculate minimum required sizes bottom-up
element_fit:: proc(element: ^Element, axis: int) -> (f32, f32) {
    switch element.type {
    case .Box, .Button:
        return box_fit(cast(^Box)element, axis)
    case .Text:
        if axis == 0 do return text_fit(cast(^Text)element)
        else do return text_fit_height(cast(^Text)element)
    }
	return 0,0
}

get_axis :: proc(direction: Layout_Direction) -> (int, int) {
    if direction == .Left_To_Right do return 0, 1
    return 1, 0
}

// Returns the prefered size and the minimum size of the element axis
box_fit:: proc(box: ^Box, axis: int) -> (f32, f32) {
    primary_axis, cross_axis := get_axis(box.layout_direction)

    size: f32
    min_size: f32

    // Calculate size based on layout direction
    if axis == primary_axis {
        // Primary axis: sum sizes of children
        for child in box.children {
            child_size, child_min_size := element_fit(child, axis)
            size += child_size
            min_size += child_min_size
        }
        
        // Add gaps between children
        gaps := calculate_gaps(box)
        size += gaps
        min_size += gaps
    } else {
        // Cross axis: take max size of children
        for child in box.children {
            child_size, child_min_size:= element_fit(child, axis)
            size = max(size, child_size)
            min_size = max(min_size, child_min_size)
        }
    }

    padding := calculate_padding(box, axis)
    size += padding
    min_size += padding

    if box.sizing[axis] == .Fixed {
        box.min_size[axis] = box.size[axis]
    } else {
        box.size[axis] = size
        box.min_size[axis] = min_size
    }
    
    return box.size[axis], box.min_size[axis]
}

calculate_available_space :: proc(box: ^Box, axis: int) -> f32 {
    return box.size[axis] - calculate_padding(box, axis)
}

calculate_padding :: proc(box: ^Box, axis: int) -> f32 {
    //  0    1        2     3
    // top, right, bottom, left
    if axis == 0 { 
        return box.padding[1] + box.padding[3] // right, left: 1, 3
    } else { 
        return box.padding[0] + box.padding[2] // top, bottom: 0, 2
    }
}

element_expand_collapse :: proc(element: ^Element, axis: int) {
    #partial switch element.type {
    case .Box, .Button:
        box_expand_collapse(cast(^Box)element, axis)
	}
}

remove_item :: proc(array: ^[dynamic]$T, item: T) {
    for it, i in array {
        if it == item {
            ordered_remove(array, i)
            return
        }
    }
}

update_positions :: proc(element: ^Element) {
    #partial switch element.type {
    case .Box, .Button:
        box_update_positions(cast(^Box)element)
    case .Text:
        text_update_positions(cast(^Text)element)
	}
}

box_update_positions:: proc(box: ^Box) {
    padding_top := box.padding[0]
    padding_left := box.padding[3]
    gap := box.gap
    
    // Determine primary and cross axis based on layout direction
    primary_axis := box.layout_direction == .Left_To_Right ? 0 : 1
    
    cursor := [2]f32{padding_left, padding_top}

    // Position all children
    for child in box.children {
        element_set_position(child, cursor)

        // Advance cursor along primary axis
        cursor[primary_axis] += child.size[primary_axis] + gap
        
        // Recursively layout children
        update_positions(child)
    }
}

box_change_state :: proc(box: ^Box, state: Box_State) {
    if box.on_state_changed != nil {
        box.on_state_changed(box, state)
    }

    box.state = state
    if box.style_sheet == nil do return

    switch state {
    case .Default: box_apply_style_default(box, box.style_sheet.box.default)
    case .Hover:   box_apply_style_delta(box, box.style_sheet.box.hover, box.style_sheet.box.default)
    }
}

update_box :: proc(box: ^Box) {
    mouse_pos := rl.GetMousePosition()
    box_rect := rl.Rectangle{box.global_position.x, box.global_position.y, box.size.x, box.size.y}
    collide := rl.CheckCollisionPointRec(mouse_pos, box_rect)

    if box.state == .Default && collide {
        box_change_state(box, .Hover)
    } else if box.state == .Hover && !collide {
        box_change_state(box, .Default)
    }

    for child in box.children do element_update(child)
}

Expand :: Sizing{.Expand,.Expand}

box_expand_collapse:: proc(box: ^Box, axis: int) {
    if len(box.children) == 0 do return
    
    primary_axis := box.layout_direction == .Left_To_Right ? 0 : 1
    cross_axis := 1 - primary_axis
    
    if axis == cross_axis do handle_cross_axis_expansion(box, cross_axis)
    else do handle_primary_axis_sizing(box, primary_axis)
    
    for child in box.children do element_expand_collapse(child, axis)
}

handle_cross_axis_expansion :: proc(box: ^Box, cross_axis: int) {
    target := calculate_available_space(box, cross_axis)
    
    for child in box.children {
        if child.sizing[cross_axis] == .Expand {
            child.size[cross_axis] = max(child.min_size[cross_axis], target)
        }
    }
}

handle_primary_axis_sizing :: proc(box: ^Box, primary_axis: int) {
    remaining := calculate_available_space(box, primary_axis)
    remaining -= calculate_gaps(box)
    remaining -= sum_child_sizes(box, primary_axis)
    
    if remaining > 0 {
        progressive_expand(box, primary_axis, remaining)
    } else if remaining < 0 {
        handle_collapsing(box, primary_axis, remaining)
    }
}



calculate_gaps :: proc(box: ^Box) -> f32 {
    if len(box.children) == 0 do return 0
    return f32(len(box.children) - 1) * box.gap
}

sum_child_sizes :: proc(box: ^Box, axis: int) -> f32 {
    sum := f32(0)
    for child in box.children {
        sum += child.size[axis]
    }
    return sum
}

progressive_expand :: proc(box: ^Box, axis: int, remaining: f32) {
    expandable := collect_expandable_children(box, axis)
    defer delete(expandable)
    
    if len(expandable) == 0 do return
    
    remaining := remaining
    prev_remaining := f32(0)
    
    for remaining > 1e-6 {
        smallest, second_smallest := find_smallest_and_second(expandable, axis)
        
        // If all elements are equal, distribute remaining evenly
        if second_smallest == math.INF_F32 || abs(second_smallest - smallest) < 1e-6 {
            per_child := remaining / f32(len(expandable))
            for child in expandable {
                child.size[axis] += per_child
            }
            break
        }
        
        // Calculate how much to add to bring smallest up to second smallest
        to_add := second_smallest - smallest
        
        // But don't exceed the fair share of remaining space
        to_add = min(to_add, remaining / f32(len(expandable)))
        
        // Safety check: if we're not making progress, distribute and exit
        if to_add < 1e-6 || abs(remaining - prev_remaining) < 1e-6 {
            per_child := remaining / f32(len(expandable))
            for child in expandable {
                child.size[axis] += per_child
            }
            break
        }
        
        prev_remaining = remaining
        
        // Grow all elements at the smallest size
        count := 0
        for child in expandable {
            if abs(child.size[axis] - smallest) < 1e-6 {
                child.size[axis] += to_add
                remaining -= to_add
                count += 1
            }
        }

        // prevent infinite loop
        if count == 0 do break 
    }
}

handle_collapsing:: proc(box: ^Box, axis: int, remaining: f32) {
    // First, try to redistribute space among expandable children
    remaining := redistribute_expandable(box, axis)
    
    // If still overflowing, shrink progressively
    if remaining < 0 {
        progressive_collapse(box, axis, remaining)
    }
}

redistribute_expandable :: proc(box: ^Box, axis: int) -> f32 {
    expandable := collect_expandable_children(box, axis)
    defer delete(expandable)

     // Calculate space to distribute among growable children
    available := calculate_available_space(box, axis)
    available -= calculate_gaps(box)
    
    if len(expandable) == 0 {
        // Return current remaining (still negative)
        return available - sum_child_sizes(box, axis)
    }
   
    non_expand_sum := f32(0)
    for child in box.children {
        if child.sizing[axis] != .Expand {
            non_expand_sum += child.size[axis]
        }
    }
    
    space_for_expandable := max(0, available - non_expand_sum)
    target := space_for_expandable / f32(len(expandable))
    
    for child in expandable {
        child.size[axis] = max(child.min_size[axis], target)
    }
    
    // Recalculate remaining after redistribution
    return available - sum_child_sizes(box, axis)
}

progressive_collapse:: proc(box: ^Box, axis: int, remaining: f32) {
    collapsible := [dynamic]^Element{}
    defer delete(collapsible)

    for child in box.children {
        append_elem(&collapsible, child)
    }
    
    remaining := remaining
    for remaining < 0 && len(collapsible) > 0 {
        largest, second_largest := find_largest_and_second(collapsible, axis)
        
        // Calculate how much to remove to bring largest down to second largest
        to_subtract := largest - second_largest
        
        // But don't exceed the fair share of deficit
        to_subtract = min(to_subtract, -remaining / f32(len(collapsible)))
        
        // Shrink all elements at the largest size
        for child, i in collapsible {
            child := collapsible[i]
            if child.size[axis] == largest {
                prev := child.size[axis]
                child.size[axis] -= to_subtract
                
                // Remove if hit minimum size
                if child.size[axis] <= child.min_size[axis] {
                    child.size[axis] = child.min_size[axis]
                    ordered_remove(&collapsible, i)
                    continue
                }
                
                remaining += (child.size[axis] - prev)
            }
        }
    }
}

collect_expandable_children :: proc(box: ^Box, axis: int) -> [dynamic]^Element {
    expandable := [dynamic]^Element{}
    for child in box.children {
        if child.sizing[axis] == .Expand {
            append_elem(&expandable, child)
        }
    }
    return expandable
}

find_smallest_and_second :: proc(elements: [dynamic]^Element, axis: int) -> (f32, f32) {
    if len(elements) == 0 do return 0, 0
    
    smallest := elements[0].size[axis]
    second_smallest := math.INF_F32
    
    for child in elements {
        size := child.size[axis]
        if size < smallest {
            second_smallest = smallest
            smallest = size
        } else if size > smallest {
            second_smallest = min(second_smallest, size)
        }
    }
    
    return smallest, second_smallest
}

find_largest_and_second :: proc(elements: [dynamic]^Element, axis: int) -> (f32, f32) {
    if len(elements) == 0 do return 0, 0
    
    largest := elements[0].size[axis]
    second_largest := f32(0)
    
    for child in elements {
        size := child.size[axis]
        if size > largest {
            second_largest = largest
            largest = size
        } else if size < largest {
            second_largest = max(second_largest, size)
        }
    }
    
    return largest, second_largest
}


// Style ______________________________________________________________________

Box_State_Styles :: struct {
	default: Box_Style,
	hover: Box_Style_Delta,
}

Box_Style:: struct {
    text_color: [4]u8,
    font_size: i32,
	background_color: [4]u8,
	border_color: [4]u8,
	border_radius: f32,
	padding: [4]f32,
	transitions: Box_Transitions,
	gap: f32,
}

Box_Style_Delta :: struct {
    text_color: Maybe([4]u8),
    font_size: Maybe(i32),
	background_color: Maybe([4]u8),
	border_color: Maybe([4]u8),
	border_radius: Maybe(f32),
	padding: Maybe([4]f32),
	padding_top: Maybe(f32),
	padding_right: Maybe(f32),
	padding_bottom: Maybe(f32),
	padding_left: Maybe(f32),
	transitions: Maybe(Box_Transitions),
	gap: Maybe(f32),
}

Box_Transitions:: struct {
	background_color: Transition,
	padding: Transition,
}

box_apply_style_default :: proc(box: ^Box, style: Box_Style) {
	if !(.Gap in box.overrides) {
		box.gap = style.gap
	}

	if !(.Background_Color in box.overrides) {
		t := style.transitions.background_color
		if t.duration > 0 {
			animate_color(&box.background_color, style.background_color, t.duration, t.ease)
		} else {
			box.background_color = style.background_color
		}
		box.background_color = style.background_color
	}

	if !(.Border_Color in box.overrides) {
		box.border_color = style.border_color
	}

	if !(.Border_Radius in box.overrides) {
		box.border_radius = style.border_radius
	}

	if !(.Padding in box.overrides) {
		using style.transitions.padding
        animate_float(&box.padding[0], style.padding[0], duration, ease)
        animate_float(&box.padding[1], style.padding[1], duration, ease)
        animate_float(&box.padding[2], style.padding[2], duration, ease)
        animate_float(&box.padding[3], style.padding[3], duration, ease)
	}
}

box_apply_style_delta:: proc(box: ^Box, delta: Box_Style_Delta, default: Box_Style) {
	transitions := default.transitions

	if val, ok := delta.transitions.?; ok {
		transitions = val
	}

	if val, ok := delta.gap.?; ok && !(.Gap in box.overrides) {
		box.gap = val 
	}

	if val, ok := delta.background_color.?; ok && !(.Background_Color in box.overrides) {
		using transitions.background_color
		animate_color(&box.background_color, val, duration, ease)
	}

	if val, ok := delta.border_color.?; ok && !(.Border_Color in box.overrides) {
		box.border_color = val
	}

	if val, ok := delta.border_radius.?; ok && !(.Border_Radius in box.overrides) {
        box.border_radius = val
	}

	if val, ok := delta.padding.?; ok && !(.Padding in box.overrides) {
		using transitions.padding
        animate_float(&box.padding[0], val[0], duration, ease)
        animate_float(&box.padding[1], val[1], duration, ease)
        animate_float(&box.padding[2], val[2], duration, ease)
        animate_float(&box.padding[3], val[3], duration, ease)
	}
}
