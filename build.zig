
const std = @import("std");
const assert = std.debug.assert;

fn AddShaderBuildCommand(b: *std.Build, dep_sokol_shdc: *std.Build.Dependency, inputPath: []const u8, outputPath: []const u8) *std.Build.Step.Run
{
	const sokolShdc = b.addSystemCommand(&.{"bin/linux/sokol-shdc", "--input"});
	sokolShdc.setCwd(dep_sokol_shdc.path(""));
	sokolShdc.addFileArg(b.path(inputPath));
	sokolShdc.addArg("--output");
	sokolShdc.addFileArg(b.path(outputPath));
	sokolShdc.addArgs(&.{"--slang", "glsl410:hlsl4:metal_macos", "-b"});
	
	return sokolShdc;
}

pub fn build(b: *std.Build) !void
{
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimise = b.standardOptimizeOption(.{});
    
	_ = try b.default_step.addDirectoryWatchInput(.{.cwd_relative = "code/*"});
    
    const exe = b.addExecutable(.{
        .name = "goldsrctosource",
        .target = target,
        .optimize = optimise,
        .link_libc = true,
	});
	
	if (optimise == .Debug)
	{
		exe.defineCMacro("GC_DEBUG", "");
		const debugGraphics = true;
		if (debugGraphics)
		{
			const imgui = b.addStaticLibrary(.{
				.name = "imgui",
				.target = target,
				.optimize = .ReleaseFast,
				.link_libc = true,
			});
			
			imgui.addCSourceFiles(.{
				.root = b.path("code/imgui"),
				.files = &.{
					"imgui.cpp", "imgui_draw.cpp",
					"imgui_tables.cpp", "imgui_widgets.cpp", "imgui_demo.cpp",
					"cimgui.cpp"
				},
			});
			
			imgui.addIncludePath(b.path("code/imgui/"));
			imgui.addIncludePath(b.path("code/"));
			imgui.linkLibCpp();
			
			
			const dep_sokol_shdc = b.dependency("sokol_shdc", .{});
			
			const worldShader = AddShaderBuildCommand(b, dep_sokol_shdc,
													  "code/shaders/world.glsl",
													  "code/shaders_compiled/world.h");
			const wireShader = AddShaderBuildCommand(b, dep_sokol_shdc,
													  "code/shaders/wire.glsl",
													  "code/shaders_compiled/wire.h");
			b.default_step.dependOn(&worldShader.step);
			b.default_step.dependOn(&wireShader.step);
			
			exe.linkLibrary(imgui);
			// TODO: sokol-shdc!!!!!!
			exe.defineCMacro("DEBUG_GRAPHICS", "");
			if (target.result.os.tag == .windows)
			{
				exe.linkSystemLibrary("gdi32");
			}
			else if (target.result.os.tag == .linux)
			{
				exe.linkSystemLibrary("x11");
				exe.linkSystemLibrary("xi");
				exe.linkSystemLibrary("xcursor");
				exe.linkSystemLibrary("gl");
				exe.linkSystemLibrary("rt");
			}
		}
		if (target.result.os.tag == .linux)
		{
			exe.linkSystemLibrary("ubsan");
		}
	}
	
	exe.linkLibC();
	if (target.result.os.tag == .windows)
	{
		exe.addCSourceFile(.{
			.file = b.path("code/win32_goldsrctosource.c"),
			.flags = &.{"-std=c23"},
		});
    }
	else if (target.result.os.tag == .linux)
	{
		exe.addCSourceFile(.{
			.file = b.path("code/linux_goldsrctosource.c"),
			.flags = &.{"-fno-sanitize-trap=undefined", "-std=c23"}
		});
	}
    b.installArtifact(exe);
}
