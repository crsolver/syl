package syl

import "core:fmt"
import rl "vendor:raylib"
import "core:math"

Layout_Direction :: enum {
	Top_To_Bottom,
	Left_To_Right,
}

Box_State :: enum {
    Default,
    Hover,
}

Box :: struct {
	using base: Base_Element,
	style: Box_Style,
    state: Box_State,
    layout_direction: Layout_Direction,
}

calculate_layout :: proc(element: Element) {
    fit_sizing(element, 0) // fit widths
    expand_shrink_sizing(element, 0) // expand/shrink widths
    text_wrap(element)
    fit_sizing(element, 1) // fit heights
    expand_shrink_sizing(element, 1) // expand/shrink heights
    update_layout(element)
}

// Step 1: Calculate minimum required sizes bottom-up
fit_sizing:: proc(element: Element, axis: int) -> (f32, f32) {
    #partial switch e in element {
    case ^Box:
        return box_fit_sizing(e, axis)
    case ^Text:
        if axis == 0 {
            return text_fit_sizing(e)
        } else {
            return text_fit_sizing_height(e)
        }
    }
	return 0,0
}

// Returns the prefered size and the minimum size of the element axis
box_fit_sizing :: proc(box: ^Box, axis: int) -> (f32, f32) {
    size: f32
    min_size: f32
    primary_axis := box.layout_direction == .Left_To_Right ? 0 : 1
    cross_axis := 1 - primary_axis

    // Calculate size based on layout direction
    if axis == primary_axis {
        // Primary axis: sum sizes of children
        for child in box.children {
            child_size, child_min_size := fit_sizing(child, axis)
            size += child_size
            min_size += child_min_size
        }
        
        // Add gaps between children
        if len(box.children) > 0 {
            gaps := f32(len(box.children) - 1) * box.style.gap
            size += gaps
            min_size += gaps
        }
    } else {
        // Cross axis: take max size of children
        for child in box.children {
            child_size, child_min_size:= fit_sizing(child, axis)
            size = max(size, child_size)
            min_size = max(min_size, child_min_size)
        }
    }
    
    if axis == 0 { // horizontal axis
        size += box.style.padding_left + box.style.padding_right
        min_size += box.style.padding_left + box.style.padding_right
    } else { // vertical axis
        size += box.style.padding_top + box.style.padding_bottom
        min_size += box.style.padding_top + box.style.padding_bottom
    }

    if box.sizing[axis] == .Fixed {
        box.min_size[axis] = box.size[axis]
    } else {
        box.size[axis] = size
        box.min_size[axis] = min_size
    }
    
    return box.size[axis], box.min_size[axis]
}

// Step 2: Expand children that want to grow
expand_shrink_sizing :: proc(element: Element, axis: int) {
    #partial switch e in element {
    case ^Box:
        box_expand_shrink_sizing(e, axis)
	}
}

box_expand_shrink_sizing :: proc(box: ^Box, axis: int) {
    if len(box.children) == 0 do return
    
    // Determine primary and cross axis based on layout direction
    primary_axis := box.layout_direction == .Left_To_Right ? 0 : 1
    cross_axis := 1 - primary_axis
    
    // Take the whole size for cross axis expansion
    if axis == cross_axis {
        target := box.size[cross_axis]
        if cross_axis == 0 {
            target -= box.style.padding_left + box.style.padding_right
        } else {
            target -= box.style.padding_top + box.style.padding_bottom
        }

        for child in box.children {
            base := get_base(child)

            if base.sizing[cross_axis] == .Expand {
                if base.id == "child" {
                    fmt.println("target", target)
                    fmt.println("grow child", base.size)
                }
                // Clamp child cross-axis size to the available target, but
                // never go below the child's minimum size.
                base.size[cross_axis] = max(base.min_size[cross_axis], target)
                if base.id == "child" {
                    fmt.println("grow child", base.size)
                }
            }
        }

        for child in box.children do expand_shrink_sizing(child, axis)
        return
    }

    remaining := box.size[primary_axis]
    if primary_axis == 0 {
        remaining -= box.style.padding_left + box.style.padding_right
    } else {
        remaining -= box.style.padding_top + box.style.padding_bottom
    }

    // Subtract gaps from primary axis
    if len(box.children) > 0 {
        remaining -= f32(len(box.children) - 1) * box.style.gap
    }

    // Account for space taken by children before deciding to grow or shrink
    for child in box.children {
        base := get_base(child)
        remaining -= base.size[primary_axis]
    }

    if remaining > 0 { // Expand 
        expand_children(box, axis) 
    } else if remaining < 0 { // Shrink
        // First attempt: if there are children that can expand, distribute
        // the available space among them so they share the container before
        // running the generic shrink algorithm.
        remaining := expand_children(box, primary_axis) 
        for child in box.children do remaining -= get_base(child).size[primary_axis]

        shrinkable := [dynamic]^Base_Element{}
        for child in box.children do append_elem(&shrinkable, get_base(child))
        defer delete(shrinkable)

        for remaining < 0 {
            largest := shrinkable[0].size[primary_axis]
            second_largest := f32(0)
            to_add := remaining

            // Find the size of the largest and the second largest element
            for child in shrinkable {
                if child.size[primary_axis] > largest {
                    second_largest = largest
                    largest = child.size[primary_axis]
                }
                if child.size[primary_axis] < largest {
                    second_largest = max(second_largest, child.size[primary_axis])
                    to_add = second_largest - largest
                }
            }

            if len(shrinkable) == 0 do break

            to_add = max(to_add, remaining / f32(len(shrinkable)))

            // Make the largest elements as small as the second largest element
            for c, i in box.children {
                child := get_base(c)
                
                prev := child.size[primary_axis]
                if child.size[primary_axis] == largest {
                    child.size[primary_axis] += to_add
                    if child.size[primary_axis] <= child.min_size[primary_axis] { // ?
                        //ordered_remove(&shrinkable, i) // Fix
                        remove_item(&shrinkable, child)
                    }
                    remaining -= (child.size[primary_axis] - prev)
                }
            }
        }
    }

    for child in box.children do expand_shrink_sizing(child, primary_axis)
}

expand_children :: proc(box: ^Box, primary_axis: int) -> f32 {
    growable := [dynamic]^Base_Element{}
    non_grow_sum := f32(0)
    for child in box.children {
        base := get_base(child)
        if base.sizing[primary_axis] == .Expand {
            append_elem(&growable, base)
        } else {
            non_grow_sum += base.size[primary_axis]
        }
    }

    available := box.size[primary_axis]

    if len(growable) > 0 {
        // Compute available space for children (box size minus paddings and gaps)
        if primary_axis == 0 {
            available -= box.style.padding_left + box.style.padding_right
        } else {
            available -= box.style.padding_top + box.style.padding_bottom
        }
        if len(box.children) > 0 {
            available -= f32(len(box.children) - 1) * box.style.gap
        }

        // Space to distribute among growable children
        space_for_growable := available - non_grow_sum
        if space_for_growable < 0 {
            space_for_growable = 0
        }

        target := space_for_growable / f32(len(growable))
        for child in growable {
            child.size[primary_axis] = max(child.min_size[primary_axis], target)
        }

        // Recompute remaining after distribution
        //remaining = available
        //for child in box.children do remaining -= get_base(child).size[primary_axis]
    }

    return available
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
update_layout :: proc(element: Element) {
    #partial switch e in element {
    case ^Box:
        update_box_layout(e)
    case ^Text:
        text_update_positions(e)
	}
}

update_box_layout :: proc(box: ^Box) {
    padding_top := box.style.padding_top
    padding_left := box.style.padding_left
    gap := box.style.gap
    
    // Determine primary and cross axis based on layout direction
    primary_axis := box.layout_direction == .Left_To_Right ? 0 : 1
    
    cursor := [2]f32{padding_left, padding_top}

    // Position all children
    for child in box.children {
        set_position(child, cursor)
        size := get_size(child)

        // Advance cursor along primary axis
        cursor[primary_axis] += size[primary_axis] + gap
        
        // Recursively layout children
        update_layout(child)
    }
}

box_change_state :: proc(box: ^Box) {
    switch box.state {
    case .Default:
        box.state = .Hover
        animate_color(&box.style.background_color, {0, 0,180,255}, 0.1)
    case .Hover:
        box.state = .Default
        animate_color(&box.style.background_color, {100,100,250,255}, 0.1)
    }
}

box :: proc(
	children:       ..Element, 
    ref:              Maybe(^^Box) = nil,
    style_sheet:      ^StyleSheet= nil,
	layout_direction: Layout_Direction = .Top_To_Bottom, 
	gap:              Maybe(f32) = nil,
	padding:          Maybe(f32) = nil,
	padding_top:      Maybe(f32) = nil,
	padding_right:    Maybe(f32) = nil,
	padding_bottom:   Maybe(f32) = nil,
	padding_left:     Maybe(f32) = nil,
	background_color: Maybe([4]u8) = nil,
	size:             [2]f32 = {0,0}, // use for Fixed sizing, only apply if it's different than {0,0}
	width:            Maybe(f32) = nil,
	height:           Maybe(f32) = nil,
	sizing: 		  Sizing = {.Fit, .Fit},
    width_sizing:    Maybe(SizingKind) = nil,
    height_sizing:    Maybe(SizingKind) = nil,
    id:               string = "",
) -> Element {
	box := new(Box)
    fmt.println("before", id, size)
    box.style_sheet = style_sheet

    if style_sheet != nil {
	    box.base.base_style = &box.style.base
    }
    
    box.id = id
	box.sizing = sizing
    box.layout_direction = layout_direction

    if r, ok := ref.?; ok {
        r^ = box
    }

    // overrides
    if size.x != 0 {
        box.size.x = size.x
        box.overrides += {.Width}
        box.sizing.x = .Fixed
    }

    if size.y != 0 {
        box.size.y = size.y
        box.overrides += {.Height}
        box.sizing.y = .Fixed
    }

	if val, ok := width.?; ok {
        box.size.x = val
        box.overrides += {.Width}
        box.sizing.x = .Fixed
    }

    if val, ok := height.?; ok {
        box.size.y = val
        box.overrides += {.Height}
        box.sizing.y = .Fixed
    }
    
    if val, ok := width_sizing.?; ok {
        box.sizing.x = val
    }

    if val, ok := height_sizing.?; ok {
        box.sizing.y = val
    }

	if val, ok := gap.?; ok {
		box.overrides += { .Gap }
        box.style.gap = val
	}

	if val, ok := padding.?; ok {
		box.style.padding_top    = val
		box.style.padding_right  = val
		box.style.padding_bottom = val
		box.style.padding_left   = val
		box.overrides += { .Padding_All }
	}

	if val, ok := padding_top.?; ok {
		box.style.padding_top = val
		box.overrides += { .Padding_Top }
	}

	if val, ok := padding_right.?; ok {
		box.style.padding_right = val
		box.overrides += { .Padding_Right }
	}
	
	if val, ok := padding_bottom.?; ok {
		box.style.padding_bottom = val
		box.overrides += { .Padding_Bottom }
	}

	if val, ok := padding_left.?; ok {
		box.style.padding_left = val
		box.overrides += { .Padding_Left }
	}

	if val, ok := background_color.?; ok {
		box.style.background_color = val
		box.overrides += { .Background_Color }
	}

	for child in children do set_parent(child, box)
	append_elems(&box.children, ..children)
    if style_sheet != nil {
        apply_style(style_sheet, box)
    }

    if box.id == "parent" {
        fmt.printfln("direction", box.layout_direction)
    }

	return box
}

update_box :: proc(box: ^Box) {
    if !(.Background_Color in box.overrides) {
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

    for child in box.children do update(child)
}

Expand :: Sizing{.Expand,.Expand}
