package syl

import "core:time"
import "core:math/ease"

Transition :: struct {
    duration: f32,
    easing: ease.Ease,
}

Animatable_Property :: enum {
    Padding,
    Width,
    Height,
    Opacity,
}

Transition_Registry :: struct {
    float_anims: map[Transition_Key]Float_Transition,
    color_anims: map[Transition_Key]Color_Transition,
}

// 2. A unique key to look up an animation
Transition_Key :: struct {
    id:   u32,           // The Element's unique ID
    prop: Animatable_Property,
}

Float_Transition :: struct {
    start_val: f32,
    end_val:   f32,
    start_t:   time.Tick,
    duration:  f32,
    easing:    ease.Ease,
}

Color_Transition :: struct {
    start_val: [4]f32,
    end_val:   [4]f32,
    start_t:   time.Tick,
    duration:  f32,
    easing:    ease.Ease,
}

get_animated_float :: proc(reg: ^Transition_Registry, id: u32, prop: Animatable_Property, fallback: f32) -> f32 {
    key := Transition_Key{id, prop}
    
    if anim, found := reg.float_anims[key]; found {
        elapsed := f32(time.duration_seconds(time.tick_since(anim.start_t)))
        progress := clamp(elapsed / anim.duration, f32(0.0), f32(1.0))
        
        t := ease.ease(anim.easing, progress)
        return anim.start_val + (anim.end_val - anim.start_val) * t
    }

    return fallback
}