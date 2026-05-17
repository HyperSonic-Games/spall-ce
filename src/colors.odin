package main

import "core:hash"
import "core:math/rand"
import "core:math/linalg/glsl"

bg_color        := BVec4{}
bg_color2       := BVec4{}
text_color      := BVec4{}
text_color2     := BVec4{}
text_color3     := BVec4{}
subtext_color   := BVec4{}
hint_text_color := BVec4{}
line_color      := BVec4{}
division_color    := BVec4{}
subdivision_color := BVec4{}
outline_color := BVec4{}
xbar_color    := BVec4{}
error_color   := BVec4{}

subbar_color := BVec4{}
subbar_split_color := BVec4{}
toolbar_color := BVec4{}
toolbar_button_color  := BVec4{}
toolbar_text_color := BVec4{}
loading_block_color := BVec4{}
tabbar_color := BVec4{}

graph_color   := BVec4{}
highlight_color := BVec4{}
shadow_color := BVec4{}
wide_rect_color := BVec4{}
wide_bg_color := BVec4{}
rect_tooltip_stats_color := BVec4{}
test_color := BVec4{}
grip_color := BVec4{}

ColorMode :: enum {
	Dark,
	Light,
	Auto,
}

default_colors :: proc "contextless" (is_dark: bool) {
	loading_block_color  = BVec4{100, 194, 236, 255}
	error_color          = hex_to_bvec(0xFFe92f42)
	test_color           = BVec4{255, 10, 10, 255}
	toolbar_color        = hex_to_bvec(0xFF0077b6)
	wide_rect_color      = BVec4{0x9b, 0xe9, 0x28, 0}

	// dark mode
	if is_dark {
		bg_color         = BVec4{15,   15,  15, 255}
		bg_color2        = BVec4{0,     0,   0, 255}
		text_color       = BVec4{255, 255, 255, 255}
		text_color2      = BVec4{180, 180, 180, 255}
		text_color3      = BVec4{0,     0,   0, 255}
		subtext_color    = BVec4{120, 120, 120, 255}
		hint_text_color  = BVec4{60,   60,  60, 255}
		line_color       = BVec4{0,     0,   0, 255}
		outline_color    = BVec4{80,   80,  80, 255}

		subbar_color         = BVec4{0x33, 0x33, 0x33, 255}
		subbar_split_color   = BVec4{0x50, 0x50, 0x50, 255}
		toolbar_button_color = BVec4{40, 40, 40, 255}
		toolbar_text_color   = BVec4{0xF5, 0xF5, 0xF5, 255}
		tabbar_color         = BVec4{0x3A, 0x3A, 0x3A, 255}

		graph_color      = BVec4{180, 180, 180, 255}
		highlight_color  = BVec4{ 64,  64, 255,   7}
		wide_bg_color    = BVec4{  0,   0,   0, 255}
		shadow_color     = BVec4{  0,   0,   0, 120}

		subdivision_color = BVec4{ 30,  30, 30, 255}
		division_color    = BVec4{100, 100, 100, 255}
		xbar_color        = BVec4{180, 180, 180, 255}
		grip_color        = BVec4{40, 40, 40, 255}

		rect_tooltip_stats_color = BVec4{80, 255, 80, 255}

	// light mode
	} else {
		bg_color         = BVec4{254, 252, 248, 255}
		bg_color2        = BVec4{255, 255, 255, 255}
		text_color       = BVec4{20,   20,  20, 255}
		text_color2      = BVec4{80,   80,  80, 255}
		text_color3      = BVec4{0,     0,   0, 255}
		subtext_color    = BVec4{40,   40,  40, 255}
		hint_text_color  = BVec4{60,   60,  60, 255}
		line_color       = BVec4{200, 200, 200, 255}
		outline_color    = BVec4{219, 211, 205, 255}

		subbar_color         = BVec4{235, 230, 225, 255}
		subbar_split_color   = BVec4{150, 150, 150, 255}
		tabbar_color         = BVec4{220, 215, 210, 255}
		toolbar_button_color = BVec4{40, 40, 40, 255}
		toolbar_text_color   = BVec4{0xF5, 0xF5, 0xF5, 255}

		graph_color      = BVec4{69,   49,  34, 255}
		highlight_color  = BVec4{255, 255,   0,  64}
		wide_bg_color    = BVec4{  0,  0,    0, 255}
		shadow_color     = BVec4{  0,   0,   0,  30}

		subdivision_color = BVec4{230, 230, 230, 255}
		division_color    = BVec4{180, 180, 180, 255}
		xbar_color        = BVec4{ 80,  80,  80, 255}
		grip_color        = BVec4{180, 175, 170, 255}

		rect_tooltip_stats_color = BVec4{20, 60, 20, 255}
	}
}

set_color_mode :: proc(auto: bool, is_dark: bool) {
	default_colors(is_dark)

	if auto {
		colormode = ColorMode.Auto
	} else {
		colormode = is_dark ? ColorMode.Dark : ColorMode.Light
	}
}

// color_choices must be power of 2
name_color_idx :: proc(name: string) -> u64 {
	name_bytes := transmute([]u8)name
	ret := #force_inline hash.murmur32(name_bytes)
	return u64(ret) & u64(COLOR_CHOICES - 1)
}


generate_color_choices :: proc(trace: ^Trace, use_random: bool) {
/*
	trace.color_choices = [COLOR_CHOICES]FVec3{
		FVec3{168,0,0}, FVec3{140,54,0}, FVec3{99,75,0},
		FVec3{74,82,0}, FVec3{0,89,33}, FVec3{0,85,92},
		FVec3{0,77,144}, FVec3{79,0,231}, FVec3{109,0,205},
		FVec3{130,0,175}, FVec3{146,0,140}, FVec3{161,0,88},
		FVec3{111,0,0}, FVec3{93,36,0}, FVec3{66,50,0},
		FVec3{49,54,0}, FVec3{0,59,22}, FVec3{0,56,61},
		FVec3{0,51,95}, FVec3{52,0,153}, FVec3{72,0,135},
		FVec3{86,0,115}, FVec3{96,0,92}, FVec3{106,0,58},
		FVec3{117,42,42}, FVec3{100,53,42}, FVec3{76,63,42},
		FVec3{62,67,42}, FVec3{42,70,46}, FVec3{42,68,72},
		FVec3{42,64,102}, FVec3{65,42,157}, FVec3{81,42,139},
		FVec3{93,42,121}, FVec3{103,42,99}, FVec3{112,42,69},
		FVec3{176,62,62}, FVec3{150,79,62}, FVec3{114,94,62},
		FVec3{94,100,62}, FVec3{62,105,68}, FVec3{62,102,108},
		FVec3{62,96,154}, FVec3{98,62,237}, FVec3{122,62,211},
		FVec3{141,62,182}, FVec3{156,62,150}, FVec3{169,62,104},
		FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{},
		FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{}, FVec3{},
	}

	presets := 48
	for i := presets; i < COLOR_CHOICES; i += 1 {
		trace.color_choices[i] = trace.color_choices[i - presets]
	}
*/

	if !use_random {
		trace.color_choices[0] = hex_to_fvec(0x6faadc)
		trace.color_choices[1] = hex_to_fvec(0xF1B212)
		trace.color_choices[2] = hex_to_fvec(0x8bd124)
		trace.color_choices[3] = hex_to_fvec(0xae74da)
		trace.color_choices[4] = hex_to_fvec(0xf07481)
		presets := 5
		for i := presets; i < COLOR_CHOICES; i += 1 {
			trace.color_choices[i] = trace.color_choices[i - presets]
		}
	} else {
		for i := 0; i < COLOR_CHOICES; i += 1 {
			h := rand.float32() * 0.5 + 0.5
			h *= h
			h *= h
			h *= h
			s := 0.5 + rand.float32() * 0.1
			v : f32 = 0.85

			trace.color_choices[i] = hsv2rgb(FVec3{h, s, v}) * 255
		}
	}
}

hsv2rgb :: proc(c: FVec3) -> FVec3 {
	K := glsl.vec3{1.0, 2.0 / 3.0, 1.0 / 3.0}
	sum := glsl.vec3{c.x, c.x, c.x} + K.xyz
	p := glsl.abs_vec3(glsl.fract(sum) * 6.0 - glsl.vec3{3,3,3})
	result := glsl.vec3{c.z, c.z, c.z} * glsl.mix(K.xxx, glsl.clamp(p - K.xxx, 0.0, 1.0), glsl.vec3{c.y, c.y, c.y})
	return FVec3{result.x, result.y, result.z}
}

hex_to_bvec :: proc "contextless" (v: u32) -> BVec4 {
	a := u8(v >> 24)
	r := u8(v >> 16)
	g := u8(v >> 8)
	b := u8(v >> 0)

	return BVec4{r, g, b, a}
}

hex_to_fvec :: proc "contextless" (v: u32) -> FVec3 {
	r := u8(v >> 16)
	g := u8(v >> 8)
	b := u8(v >> 0)

	return FVec3{f32(r), f32(g), f32(b)}
}

bvec_to_fvec :: proc "contextless" (c: BVec4) -> FVec3 {
	return FVec3{f32(c.r), f32(c.g), f32(c.b)}
}

greyscale :: proc "contextless" (c: FVec3) -> FVec3 {
	return (c.x * 0.299) + (c.y * 0.587) + (c.z * 0.114)
}

adjust :: proc(c: FVec3, by: f32) -> FVec3 {
	r := max(min(255, c.r + by), 0)
	g := max(min(255, c.g + by), 0)
	b := max(min(255, c.b + by), 0)
	return FVec3{r, g, b}
}

get_node_color :: proc(trace: ^Trace, node: ^ChunkNode) -> FVec3 {
	avg_color := FVec3{}
	collected_weight : i64 = 0
	for wi, idx in node.p {
		avg_color += trace.color_choices[wi.idx] * f32(wi.weight)
		collected_weight += wi.weight
	}
	avg_color /= f32(collected_weight)

	return avg_color
}
