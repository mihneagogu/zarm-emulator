const std = @import("std");
const fs = std.fs;
const process = std.process;

const cpu_state = @import("emulator/cpu_state.zig");
const _pip_ex = @import("emulator/pipeline_executor.zig");
const startPipeline = _pip_ex.startPipeline;
const CpuState = cpu_state.CpuState;
const CpuFlag =  cpu_state.CpuFlag;

const pex = @import("emulator/pipeline_executor.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer { _ = gpa.deinit(); }
    const alloc = &gpa.allocator;

    var arg_it = process.args();
    _  = arg_it.skip();

    const file_name = arg_it.next(alloc) orelse @panic("You didn't specify a file name!") catch unreachable;
    defer alloc.free(file_name);
    std.debug.print("Emulating {s}\n", .{file_name});

    var f = fs.cwd().openFile(file_name, fs.File.OpenFlags{ .read = true }) catch @panic("Could not open file");
    defer f.close();
    const len = f.getEndPos() catch @panic("Could not read file");

    if (len > cpu_state.MEMORY_SIZE) {
        std.debug.print("File size is bigger than allowed size: {d} bytes. Aborting", .{cpu_state.MEMORY_SIZE});
        return;
    }
    var cpu = CpuState.init(alloc);
    defer cpu.destroy(alloc);

    _ = f.read(cpu.memory) catch @panic("Could not read file");
    // startPipeline(&cpu);
}

