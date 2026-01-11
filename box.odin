// Retained mode Layout implementation based on https://github.com/nicbarker/clay
// How Clay's UI Layout Algorithm Works: https://www.youtube.com/watch?v=by9lQvpvMIc&t=1273s

package syl

import rl "vendor:raylib"
import "core:math"


Box :: struct {
	using element: Element,
	style: Box_Style,
    state: Box_State,
    layout_direction: Layout_Direction,
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
    #partial switch element.type {
    case .Box:
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

calculate_padding :: proc(box: ^Box, axis: int) -> f32 {
    if axis == 0 { 
        return box.style.padding_left + box.style.padding_right
    } else { 
        return box.style.padding_top + box.style.padding_bottom
    }
}

element_expand_collapse :: proc(element: ^Element, axis: int) {
    #partial switch element.type {
    case .Box:
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

// Step 3: Position all children
update_positions :: proc(element: ^Element) {
    #partial switch element.type {
    case .Box:
        box_update_positions(cast(^Box)element)
    case .Text:
        text_update_positions(cast(^Text)element)
	}
}

box_update_positions:: proc(box: ^Box) {
    padding_top := box.style.padding_top
    padding_left := box.style.padding_left
    gap := box.style.gap
    
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

GREEN :: [4]u8{195,214,44, 255}
DARK_GREEN :: [4]u8{255, 255, 34, 255}

box_change_state :: proc(box: ^Box) {
    // TODO: remove temporal hard-coded example animations
    switch box.state {
    case .Default:
        box.state = .Hover
        animate_color(&box.style.background_color, DARK_GREEN, 0.3)
        animate_float(&box.style.padding_bottom, 34, 0.2)
    case .Hover:
        box.state = .Default
        animate_color(&box.style.background_color, GREEN, 0.3)
        animate_float(&box.style.padding_bottom, 10, 0.2)
    }
}

update_box :: proc(box: ^Box) {
    if (box.id == "anim") { // TODO: Fix. Note: temporally hard-coded for the example
        mouse_pos := rl.GetMousePosition()
        box_rect := rl.Rectangle{box.global_position.x, box.global_position.y, box.size.x, box.size.y}
        collide := rl.CheckCollisionPointRec(mouse_pos, box_rect)
        if box.state == .Default && collide {
            box_change_state(box)
        }
        if box.state == .Hover && !collide {
            box_change_state(box)
        }
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

calculate_available_space :: proc(box: ^Box, axis: int) -> f32 {
    space := box.size[axis]
    if axis == 0 {
        space -= box.style.padding_left + box.style.padding_right
    } else {
        space -= box.style.padding_top + box.style.padding_bottom
    }
    return space
}

calculate_gaps :: proc(box: ^Box) -> f32 {
    if len(box.children) == 0 do return 0
    return f32(len(box.children) - 1) * box.style.gap
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

center :: proc(content: ^Element) -> ^Element {
    return box(sizing=Expand, children = {
        box(sizing=Expand),
        box(sizing=Expand, layout_direction = .Left_To_Right, children = {
            box(sizing=Expand),
            content,
            box(sizing=Expand),
        }),
        box(sizing=Expand),
    })
}