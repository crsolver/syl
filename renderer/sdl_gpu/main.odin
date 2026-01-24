package sdl_renderer

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:os/os2"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

import syl "../.."

Rect :: struct #packed {
	position_and_size: [4]f32,
	color:             [4]f32,
	f1:                [4]f32, // uv_x for text, border radius for rects
	f2:                [4]f32, // uv_y for text, border thickness for rects
	border_color:      [4][4]f32,
	flags:             [4]i32,
}

Command_Batch :: struct {
	start, end:   int,
	font_texture: ^sdl.GPUTexture,
}

default_font: ^ttf.Font = nil

Renderer :: struct {
	allocator:     runtime.Allocator,
	gpu:           ^sdl.GPUDevice,
	window:        ^sdl.Window,
	pipeline:      ^sdl.GPUGraphicsPipeline,
	font_engine:   ^ttf.TextEngine,
	font_sampler:  ^sdl.GPUSampler,
	dummy_texture: ^sdl.GPUTexture,
	fonts:         [dynamic]^ttf.Font,
	rects:         [dynamic]Rect,
	batch:         [dynamic]Command_Batch,
	rect_gpu_buf:  Gpu_Dynamic_Buffer,
	clear_color:   [4]f32,
}

Gpu_Dynamic_Buffer :: struct {
	data:           ^sdl.GPUBuffer,
	tansfer:        ^sdl.GPUTransferBuffer,
	byte_size:      int,
	prev_byte_size: int,
}

init :: proc(
	allocator: runtime.Allocator,
	window_title: cstring,
	shader_paths: [sdl.GPUShaderStage]string,
	window_size: [2]c.int = {800, 640},
	window_flags: sdl.WindowFlags = {.RESIZABLE},
	shader_format: sdl.GPUShaderFormat = {.SPIRV},
	shader_debug: bool = false,
) -> Renderer {

	r := Renderer{}

	ok := sdl.Init({.VIDEO}); assert(ok)

	r.window = sdl.CreateWindow(window_title, window_size.x, window_size.y, window_flags)
	r.gpu = sdl.CreateGPUDevice(shader_format, shader_debug, nil)

	assert(r.window != nil)
	assert(r.gpu != nil)

	ok = sdl.ClaimWindowForGPUDevice(r.gpu, r.window); assert(ok)

	vert_shader := load_shader(r.gpu, shader_paths[.VERTEX], .VERTEX, shader_format, 1, 0, 1)
	frag_shader := load_shader(r.gpu, shader_paths[.FRAGMENT], .FRAGMENT, shader_format, 0, 1, 0)

	r.pipeline = sdl.CreateGPUGraphicsPipeline(
		r.gpu,
		{
			fragment_shader = frag_shader,
			vertex_shader = vert_shader,
			target_info = {
				color_target_descriptions = &sdl.GPUColorTargetDescription {
					blend_state = {
						src_alpha_blendfactor = .ONE,
						dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
						alpha_blend_op = .ADD,
						src_color_blendfactor = .SRC_ALPHA,
						dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
						color_blend_op = .ADD,
						enable_blend = true,
						enable_color_write_mask = true,
						color_write_mask = ~{},
					},
					format = sdl.GetGPUSwapchainTextureFormat(r.gpu, r.window),
				},
				num_color_targets = 1,
			},
			primitive_type = .TRIANGLELIST,
		},
	)
	assert(r.pipeline != nil)

	sdl.ReleaseGPUShader(r.gpu, vert_shader)
	sdl.ReleaseGPUShader(r.gpu, frag_shader)

	r.rect_gpu_buf = init_gpu_dynamic_buffer(&r)

	ok = ttf.Init(); assert(ok)

	r.font_engine = ttf.CreateGPUTextEngine(r.gpu)
	assert(r.font_engine != nil)

	r.font_sampler = sdl.CreateGPUSampler(
		r.gpu,
		{
			address_mode_u = .REPEAT,
			address_mode_v = .REPEAT,
			address_mode_w = .REPEAT,
			mag_filter = .LINEAR,
			min_filter = .LINEAR,
			mipmap_mode = .LINEAR,
		},
	)
	assert(r.font_sampler != nil)

	r.dummy_texture = sdl.CreateGPUTexture(
		r.gpu,
		{
			height = 1,
			width = 1,
			format = .R8G8B8A8_UNORM,
			usage = {.SAMPLER},
			layer_count_or_depth = 1,
			num_levels = 1,
		},
	)
	assert(r.dummy_texture != nil)

	r.allocator = allocator

	r.batch = make([dynamic]Command_Batch, r.allocator)
	r.fonts = make([dynamic]^ttf.Font, r.allocator)
	r.rects = make([dynamic]Rect, r.allocator)

	return r
}

add_font :: proc(renderer: ^Renderer, path: cstring, size: f32) -> ^ttf.Font {
	font := ttf.OpenFont(path, size)
	assert(font != nil)
	append(&renderer.fonts, font)
	return font
}

init_gpu_dynamic_buffer :: proc(renderer: ^Renderer) -> Gpu_Dynamic_Buffer {
	data_buffer := sdl.CreateGPUBuffer(renderer.gpu, {size = 64, usage = {.GRAPHICS_STORAGE_READ}})
	transfer_buffer := sdl.CreateGPUTransferBuffer(renderer.gpu, {size = 64, usage = .UPLOAD})

	assert(data_buffer != nil)
	assert(transfer_buffer != nil)

	dyn_buf: Gpu_Dynamic_Buffer
	dyn_buf.byte_size = 64 // can't initialize a buffer with zero size, so reserve 64 bytes in advance
	dyn_buf.prev_byte_size = 64
	dyn_buf.data = data_buffer
	dyn_buf.tansfer = transfer_buffer

	return dyn_buf
}

destroy :: proc(renderer: ^Renderer) {

	destroy_gpu_dynamic_buffer(renderer, &renderer.rect_gpu_buf)

	sdl.ReleaseGPUGraphicsPipeline(renderer.gpu, renderer.pipeline)

	sdl.ReleaseGPUTexture(renderer.gpu, renderer.dummy_texture)
	sdl.ReleaseGPUSampler(renderer.gpu, renderer.font_sampler)

	for f in renderer.fonts {
		ttf.CloseFont(f)
	}

	ttf.DestroyGPUTextEngine(renderer.font_engine)

	sdl.ReleaseWindowFromGPUDevice(renderer.gpu, renderer.window)

	sdl.DestroyWindow(renderer.window)
	sdl.DestroyGPUDevice(renderer.gpu)

	delete(renderer.batch)
	delete(renderer.rects)
	delete(renderer.fonts)
}

destroy_gpu_dynamic_buffer :: proc(renderer: ^Renderer, buffer: ^Gpu_Dynamic_Buffer) {
	sdl.ReleaseGPUBuffer(renderer.gpu, buffer.data)
	sdl.ReleaseGPUTransferBuffer(renderer.gpu, buffer.tansfer)
}

update_dynamic_buffer :: proc(
	renderer: ^Renderer,
	buf: ^Gpu_Dynamic_Buffer,
	command_buffer: ^sdl.GPUCommandBuffer,
	data: rawptr,
) {
	if buf.byte_size > buf.prev_byte_size {
		sdl.ReleaseGPUBuffer(renderer.gpu, buf.data)
		buf.data = sdl.CreateGPUBuffer(
			renderer.gpu,
			{size = u32(buf.byte_size), usage = {.GRAPHICS_STORAGE_READ}},
		)

		sdl.ReleaseGPUTransferBuffer(renderer.gpu, buf.tansfer)
		buf.tansfer = sdl.CreateGPUTransferBuffer(
			renderer.gpu,
			{size = u32(buf.byte_size), usage = .UPLOAD},
		)
	}

	if buf.byte_size > 0 {
		tmem := sdl.MapGPUTransferBuffer(renderer.gpu, buf.tansfer, false)
		mem.copy(tmem, data, buf.byte_size)
		sdl.UnmapGPUTransferBuffer(renderer.gpu, buf.tansfer)

		copy_pass := sdl.BeginGPUCopyPass(command_buffer)
		sdl.UploadToGPUBuffer(
			copy_pass,
			{transfer_buffer = buf.tansfer},
			{size = u32(buf.byte_size), buffer = buf.data},
			false,
		)
		sdl.EndGPUCopyPass(copy_pass)
	}
}

begin :: proc(renderer: ^Renderer) {
	clear(&renderer.rects)
	clear(&renderer.batch)
}

feed_renderer :: proc(
	renderer: ^Renderer,
	elem: ^syl.Element,
	start: int,
	bound_texture: ^sdl.GPUTexture,
) -> (
	int,
	^sdl.GPUTexture,
) {
	start := start
	bound_texture := bound_texture

	switch elem.type {
	case .Box, .Button:
		box := cast(^syl.Box)elem

		r := Rect{}
		r.position_and_size.xy = box.global_position
		r.position_and_size.zw = box.size
		r.f1 = box.border_radius
		r.f2 = box.border_thickness
		r.color = color_syl_to_sdl(box.background_color)
		r.flags = 0
		r.border_color = {
			color_syl_to_sdl(box.border_color.x),
			color_syl_to_sdl(box.border_color.y),
			color_syl_to_sdl(box.border_color.z),
			color_syl_to_sdl(box.border_color.w),
		}
		append(&renderer.rects, r)

	case .Text:
		text := cast(^syl.Text)elem
		font := cast(^ttf.Font)text.font

		if font == nil {
			font = default_font
			if font == nil {
				break
			}
		}

		for line in text.lines {
			ttf.SetFontSize(font, f32(text.font_size))
			font_text := ttf.CreateText(
				renderer.font_engine,
				font,
				cast(cstring)raw_data(line.content),
				len(line.content),
			)
			defer ttf.DestroyText(font_text)
			draw_data := ttf.GetGPUTextDrawData(font_text)

			for seq := draw_data; seq != nil; seq = seq.next {
				for idx: i32 = 0; idx < seq.num_indices; idx += 6 {
					i0 := seq.indices[idx + 0]
					i1 := seq.indices[idx + 1]
					i2 := seq.indices[idx + 2]
					i3 := seq.indices[idx + 5]

					v0 := seq.xy[i0]
					v1 := seq.xy[i1]
					v2 := seq.xy[i2]
					v3 := seq.xy[i3]

					uv0 := seq.uv[i0]
					uv1 := seq.uv[i1]
					uv2 := seq.uv[i2]
					uv3 := seq.uv[i3]

					x_min := min(min(v0.x, v1.x), min(v2.x, v3.x))
					y_min := min(min(v0.y, v1.y), min(v2.y, v3.y))
					x_max := max(max(v0.x, v1.x), max(v2.x, v3.x))
					y_max := max(max(v0.y, v1.y), max(v2.y, v3.y))

					width := x_max - x_min
					height := y_max - y_min

					r := Rect{}
					r.position_and_size.xy = line.global_position + {x_min, 0}
					r.position_and_size.zw = {width, height}
					r.f1 = {uv0.x, uv1.x, uv2.x, uv3.x}
					r.f2 = {uv2.y, uv3.y, uv0.y, uv1.y}
					r.color = color_syl_to_sdl(text.color)
					r.flags = {1, 0, 0, 0}

					index := len(renderer.rects)
					append(&renderer.rects, r)

					if bound_texture == nil {
						bound_texture = draw_data.atlas_texture
					}

					if draw_data.next != nil && draw_data.next.atlas_texture != bound_texture {
						append(
							&renderer.batch,
							Command_Batch {
								start = start,
								end = index,
								font_texture = bound_texture,
							},
						)
						bound_texture = draw_data.atlas_texture
						start = index
					}
				}
			}
		}
	}

	for child in elem.children {
		start, bound_texture = feed_renderer(renderer, child, start, bound_texture)
	}

	return start, bound_texture
}

feed_validate :: proc(renderer: ^Renderer, start: int, bound_texture: ^sdl.GPUTexture) {
	if len(renderer.batch) == 0 ||
	   renderer.batch[len(renderer.batch) - 1].end < len(renderer.rects) {
		append(
			&renderer.batch,
			Command_Batch{start = start, end = len(renderer.rects), font_texture = bound_texture},
		)
	}
}

render :: proc(renderer: ^Renderer) {
	window_w, window_h: i32
	sdl.GetWindowSize(renderer.window, &window_w, &window_h)

	cmd_buf := sdl.AcquireGPUCommandBuffer(renderer.gpu)

	renderer.rect_gpu_buf.prev_byte_size = renderer.rect_gpu_buf.byte_size
	renderer.rect_gpu_buf.byte_size = len(renderer.rects) * size_of(Rect)
	update_dynamic_buffer(renderer, &renderer.rect_gpu_buf, cmd_buf, raw_data(renderer.rects))

	swapchain_tex := &sdl.GPUTexture{}
	ok := sdl.WaitAndAcquireGPUSwapchainTexture(
		cmd_buf,
		renderer.window,
		&swapchain_tex,
		nil,
		nil,
	); assert(ok)

	swapchain_target := sdl.GPUColorTargetInfo {
		clear_color = cast(sdl.FColor)renderer.clear_color,
		load_op     = .CLEAR,
		store_op    = .STORE,
		texture     = swapchain_tex,
	}

	storage_bufs := []^sdl.GPUBuffer{renderer.rect_gpu_buf.data}

	projection_mat := matrix[4, 4]f32{
		2.0 / f32(window_w), 0, 0, -1,
		0, -2.0 / f32(window_h), 0, 1,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}

	render_pass := sdl.BeginGPURenderPass(cmd_buf, &swapchain_target, 1, nil)

	sdl.BindGPUGraphicsPipeline(render_pass, renderer.pipeline)
	sdl.PushGPUVertexUniformData(cmd_buf, 0, &projection_mat, u32(size_of(projection_mat)))
	sdl.BindGPUVertexStorageBuffers(render_pass, 0, raw_data(storage_bufs), u32(len(storage_bufs)))
	sdl.BindGPUFragmentSamplers(
		render_pass,
		0,
		&sdl.GPUTextureSamplerBinding {
			sampler = renderer.font_sampler,
			texture = renderer.dummy_texture,
		},
		1,
	)

	for b in renderer.batch {
		if b.font_texture != nil {
			sdl.BindGPUFragmentSamplers(
				render_pass,
				0,
				&sdl.GPUTextureSamplerBinding {
					sampler = renderer.font_sampler,
					texture = b.font_texture,
				},
				1,
			)
		}
		sdl.DrawGPUPrimitives(render_pass, 6, u32(b.end - b.start), 0, u32(b.start))
	}

	sdl.EndGPURenderPass(render_pass)

	ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok)
}

load_shader :: proc(
	gpu: ^sdl.GPUDevice,
	path: string,
	stage: sdl.GPUShaderStage,
	format: sdl.GPUShaderFormat,
	num_ubo, num_samplers, num_storage_buffers: u32,
) -> ^sdl.GPUShader {
	source, read_err := os2.read_entire_file_from_path(path, context.allocator)
	defer delete(source, context.allocator)
	assert(read_err == nil)
	shader := sdl.CreateGPUShader(
		gpu,
		{
			code_size = len(source),
			entrypoint = "main",
			code = raw_data(source),
			stage = stage,
			format = format,
			num_uniform_buffers = num_ubo,
			num_samplers = num_samplers,
			num_storage_buffers = num_storage_buffers,
		},
	)
	assert(shader != nil)
	return shader
}

measure_text :: proc(s: string, font: rawptr, size: int, spacing: f32) -> int {
	font_ := cast(^ttf.Font)(font)

	if font == nil {
		font_ = default_font
	}

	ttf.SetFontSize(font_, f32(size))
	w, h: i32
	ttf.GetStringSize(font_, cast(cstring)raw_data(s), len(s), &w, &h)

	return int(w)
}

color_syl_to_sdl :: proc(c: [4]u8) -> [4]f32 {
	return {f32(c.r), f32(c.g), f32(c.b), f32(c.a)} / 255.0
}
