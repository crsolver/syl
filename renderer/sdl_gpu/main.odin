package sdl_renderer

import "core:fmt"
import "core:c"
import "core:mem"
import "core:os/os2"
import sdl "vendor:sdl3"

import syl "../.."

Rect :: struct #packed {
	radius:            [4]f32,
	position_and_size: [4]f32,
	color:             [4]f32,
	uv_and_type:       [4]f32, // .z component as type, 0 for rect, 1 for text
	border_thickness:  [4]f32,
	border_color:      [4][4]f32,
}

Command_Batch :: struct {
	start, end: int,
}

Renderer :: struct {
	gpu:          ^sdl.GPUDevice,
	window:       ^sdl.Window,
	pipeline:     ^sdl.GPUGraphicsPipeline,
	rects:        [dynamic]Rect,
	rect_gpu_buf: Gpu_Dynamic_Buffer,
	clear_color:  [4]f32,
}

Gpu_Dynamic_Buffer :: struct {
	data:           ^sdl.GPUBuffer,
	tansfer:        ^sdl.GPUTransferBuffer,
	byte_size:      int,
	prev_byte_size: int,
}

init_renderer :: proc(
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
	frag_shader := load_shader(r.gpu, shader_paths[.FRAGMENT], .FRAGMENT, shader_format, 0, 0, 0)

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

	return r
}

init_ui :: proc() {
	syl.ctx.measure_text = measure_text
}

init_gpu_dynamic_buffer :: proc(renderer: ^Renderer) -> Gpu_Dynamic_Buffer {
	data_buffer := sdl.CreateGPUBuffer(renderer.gpu, {size = 64, usage = {.GRAPHICS_STORAGE_READ}})
	transfer_buffer := sdl.CreateGPUTransferBuffer(renderer.gpu, {size = 64, usage = .UPLOAD})

	dyn_buf: Gpu_Dynamic_Buffer
	dyn_buf.byte_size = 64
	dyn_buf.prev_byte_size = 64
	dyn_buf.data = data_buffer
	dyn_buf.tansfer = transfer_buffer

	return dyn_buf
}

destroy_renderer :: proc() {

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
}

feed_renderer :: proc(
	renderer: ^Renderer,
	elem: ^syl.Element,
	start: int,
	bound_texture: ^sdl.GPUTexture,
) {
	start := start
	bound_texture := bound_texture

	r := Rect{}

	switch elem.type {
	case .Box, .Button:
		box := cast(^syl.Box)elem

		r.position_and_size.xy = box.global_position
		r.position_and_size.zw = box.size
		r.border_thickness = 1
		r.radius = 5
		r.color = color_syl_sdl(box.background_color)
		r.border_color = color_syl_sdl(box.border_color)

	case .Text:
		text := cast(^syl.Text)elem

		r.position_and_size.xy = text.global_position
		r.position_and_size.zw = text.size
		r.border_thickness = 1
	}

	append(&renderer.rects, r)

	for child in elem.children {
		feed_renderer(renderer, child, start, nil)
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
	sdl.DrawGPUPrimitives(render_pass, 6, u32(len(renderer.rects)), 0, 0)

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

measure_text :: proc(s: string, size: int) -> int {
	return 15
}

color_syl_sdl :: proc(c: [4]u8) -> [4]f32 {
	return {f32(c.r), f32(c.g), f32(c.b), f32(c.a)} / 255.0
}
