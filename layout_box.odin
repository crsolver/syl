// Retained mode layout system implementation based on https://github.com/nicbarker/clay
// How Clay's UI Layout Algorithm Works: https://www.youtube.com/watch?v=by9lQvpvMIc&t=1273s
package syl

import "core:math"

Layout_layout_box_Property :: enum {
	Gap,
	Background_Color,
	Border_Color,
	Border_Radius,
    Border_Thickness,
	Padding,
}

Layout_Box :: struct {
	using element:    Element,
    background_color: [4]u8,
	border_color:     [4][4]u8,
    border_thickness: [4]f32,
	border_radius:    [4]f32,
	padding:          [4]f32,
	gap:              f32,
    layout_direction: Layout_Direction,
	overrides:        bit_set[Layout_layout_box_Property],
}

Layout_Direction :: enum {
	Top_To_Bottom,
	Left_To_Right,
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
    case .Box, .Button:
        return layout_box_fit(cast(^Layout_Box)element, axis)
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
layout_box_fit:: proc(box: ^Layout_Box, axis: int) -> (f32, f32) {
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
        box.size[axis] = max(size, box.min_size[axis])
    }
    
    return box.size[axis], min_size
}

calculate_available_space :: proc(box: ^Layout_Box, axis: int) -> f32 {
    return box.size[axis] - calculate_padding(box, axis)
}

calculate_padding :: proc(box: ^Layout_Box, axis: int) -> f32 {
    //  0    1        2     3
    // top, right, bottom, left
    if axis == 0 { 
        p1 := box.padding[1]
        p3 := box.padding[3]
        if math.is_nan(p1) || math.is_inf(p1) do p1 = 0
        if math.is_nan(p3) || math.is_inf(p3) do p3 = 0
        return p1 + p3 // right, left: 1, 3
    } else { 
        p0 := box.padding[0]
        p2 := box.padding[2]
        if math.is_nan(p0) || math.is_inf(p0) do p0 = 0
        if math.is_nan(p2) || math.is_inf(p2) do p2 = 0
        return p0 + p2 // top, bottom: 0, 2
    }
}

element_expand_collapse :: proc(element: ^Element, axis: int) {
    #partial switch element.type {
    case .Box, .Button:
        layout_box_expand_collapse(cast(^Layout_Box)element, axis)
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
        layout_box_update_positions(cast(^Layout_Box)element)
    case .Text:
        text_update_positions(cast(^Text)element)
	}
}

layout_box_update_positions:: proc(box: ^Layout_Box) {
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

Expand :: Sizing{.Expand,.Expand}

layout_box_expand_collapse:: proc(box: ^Layout_Box, axis: int) {
    if len(box.children) == 0 do return
    
    primary_axis := box.layout_direction == .Left_To_Right ? 0 : 1
    cross_axis := 1 - primary_axis
    
    if axis == cross_axis do handle_cross_axis_expansion(box, cross_axis)
    else do handle_primary_axis_sizing(box, primary_axis)
    
    for child in box.children do element_expand_collapse(child, axis)
}

handle_cross_axis_expansion :: proc(box: ^Layout_Box, cross_axis: int) {
    target := calculate_available_space(box, cross_axis)
    
    for child in box.children {
        if child.sizing[cross_axis] == .Expand {
            child.size[cross_axis] = max(child.min_size[cross_axis], target)
        }
    }
}

handle_primary_axis_sizing :: proc(box: ^Layout_Box, primary_axis: int) {
    remaining := calculate_available_space(box, primary_axis)
    remaining -= calculate_gaps(box)
    remaining -= sum_child_sizes(box, primary_axis)
    
    if remaining > 0 {
        progressive_expand(box, primary_axis, remaining)
    } else if remaining < 0 {
        handle_collapsing(box, primary_axis, remaining)
    }
}



calculate_gaps :: proc(box: ^Layout_Box) -> f32 {
    if len(box.children) == 0 do return 0
    return f32(len(box.children) - 1) * box.gap
}

sum_child_sizes :: proc(box: ^Layout_Box, axis: int) -> f32 {
    sum := f32(0)
    for child in box.children {
        sum += child.size[axis]
    }
    return sum
}

progressive_expand :: proc(box: ^Layout_Box, axis: int, remaining: f32) {
    expandable := collect_expandable_children(box, axis)
    defer delete(expandable)
    
    if len(expandable) == 0 do return
    
    remaining := remaining
    prev_remaining := f32(0)
    iter := 0
    max_iters := 1000

    for remaining > 1e-6 && iter < max_iters {
        if math.is_nan(remaining) || math.is_inf(remaining) {
            break
        }
        iter += 1
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
    if iter >= max_iters {
        // fallback: distribute remaining evenly to avoid lock
        if len(expandable) > 0 {
            per_child := remaining / f32(len(expandable))
            for child in expandable {
                child.size[axis] += per_child
            }
        }
    }
}

handle_collapsing:: proc(box: ^Layout_Box, axis: int, remaining: f32) {
    // First, try to redistribute space among expandable children
    remaining := redistribute_expandable(box, axis)
    
    // If still overflowing, shrink progressively
    if remaining < 0 {
        progressive_collapse(box, axis, remaining)
    }
}

redistribute_expandable :: proc(box: ^Layout_Box, axis: int) -> f32 {
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

progressive_collapse:: proc(box: ^Layout_Box, axis: int, remaining: f32) {
    collapsible := [dynamic]^Element{}
    defer delete(collapsible)

    for child in box.children {
        append_elem(&collapsible, child)
    }
    
    remaining := remaining
    iter := 0
    max_iters := 1000
    for remaining < 0 && len(collapsible) > 0 && iter < max_iters {
        /*if math.is_nan(remaining) || math.is_inf(remaining) {
            break
        }*/
        iter += 1
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
    if iter >= max_iters {
        // If we've hit the iteration cap, ensure sizes are within min bounds
        for child in box.children {
            child.size[axis] = max(child.size[axis], child.min_size[axis])
        }
    }
}

collect_expandable_children :: proc(box: ^Layout_Box, axis: int) -> [dynamic]^Element {
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

layout_box_destroy:: proc(box: ^Layout_Box) {
    layout_box_deinit(box)
    free(box)
}

layout_box_deinit:: proc(box: ^Layout_Box) {
    if box == nil do return
    base_element_deinit(&box.element)
}

// STYLE

// Sets the style of the layout box, applying overrides on top of default style
layout_box_set_style:: proc(box: ^Layout_Box, new: ^Box_Style_Override, style: ^Box_Style_Override, default: Box_Style, use_transitions: bool = true) {
	transitions := default.transitions
    gap := default.gap
    padding := default.padding
    background_color := default.background_color
    border_radius := default.border_radius
    border_color := default.border_color
    border_thickness := default.border_thickness

    if style != nil {
        if g, ok := style.gap.?; ok do gap = g
        if p, ok := style.padding.?; ok do padding = p
        if bg, ok := style.background_color.?; ok do background_color = bg
        if br, ok := style.border_radius.?; ok do border_radius = br
        if bc, ok := style.border_color.?; ok do border_color = bc
        if bt, ok := style.border_thickness.?; ok do border_thickness = bt
        if val, ok := style.transitions.?; ok {
            transitions = val
        }
    }
    
    if new != nil {
        if g, ok := new.gap.?; ok do gap = g
        if p, ok := new.padding.?; ok do padding = p
        if bg, ok := new.background_color.?; ok do background_color = bg
        if br, ok := new.border_radius.?; ok do border_radius = br
        if bc, ok := new.border_color.?; ok do border_color = bc
        if bt, ok := new.border_thickness.?; ok do border_thickness = bt
        if val, ok := new.transitions.?; ok {
            transitions = val
        }
    }

	if  !(.Gap in box.overrides) {
		box.gap = gap
	}

	if !(.Background_Color in box.overrides) {
        if use_transitions {
            using transitions.background_color
            animate_color(&box.background_color, background_color, duration, ease)
        } else {
            box.background_color = background_color
        }
	}

	if  !(.Border_Color in box.overrides) {
		box.border_color = border_color
	}

    if  !(.Border_Thickness in box.overrides) {
        box.border_thickness = border_thickness
	}

	if  !(.Border_Radius in box.overrides) {
        box.border_radius = border_radius
	}

	if !(.Padding in box.overrides) {
        if use_transitions {
            using transitions.padding
            animate_float(&box.padding[0], padding[0], duration, ease)
            animate_float(&box.padding[1], padding[1], duration, ease)
            animate_float(&box.padding[2], padding[2], duration, ease)
            animate_float(&box.padding[3], padding[3], duration, ease)
        } else {
            box.padding = padding
        }
	}
}

// Applies style overrides on top of current style
layout_box_apply_style:: proc(box: ^Layout_Box, new: Box_Style_Override, use_transitions: bool = true) {
    if gap, ok := new.gap.?; ok && !(.Gap in box.overrides) {
		box.gap = gap
	}

    if padding, ok := new.padding.?; ok && !(.Padding in box.overrides) {
        if t, ok := new.transitions.?; ok && use_transitions  {
            using t.padding
            animate_float(&box.padding[0], padding[0], duration, ease)
            animate_float(&box.padding[1], padding[1], duration, ease)
            animate_float(&box.padding[2], padding[2], duration, ease)
            animate_float(&box.padding[3], padding[3], duration, ease)
        } else {
            box.padding = padding
        }
    }

    if bg, ok := new.background_color.?; ok && !(.Background_Color in box.overrides) {
        if t, ok := new.transitions.?; ok && use_transitions {
            using t.background_color
            animate_color(&box.background_color, bg, duration, ease)
        } else {
            box.background_color = bg
        }
    }
    
    if br, ok := new.border_radius.?; ok && !(.Border_Radius in box.overrides) {
        box.border_radius = br
    }

    if bt, ok := new.border_thickness.?; ok && !(.Border_Thickness in box.overrides) {
        box.border_thickness = bt
    }

    if bc, ok := new.border_color.?; ok && !(.Border_Color in box.overrides) {
        box.border_color = bc
    }
}
