const std = @import("std");
const process = std.process;

const cpu_state = @import("emulator/cpu_state.zig");
const CpuState = cpu_state.CpuState;
const CpuFlag =  cpu_state.CpuFlag;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer { _ = gpa.deinit(); }
    const alloc = &gpa.allocator;

    var arg_it = process.args();
    _  = arg_it.skip();

    const file_name = arg_it.next(alloc) orelse @panic("You didn't specify a file name!") catch unreachable;
    defer alloc.free(file_name);
    std.debug.print("Emulating {s}\n", .{file_name});
    
    var cpu = CpuState.init(alloc);
    defer cpu.destroy(alloc);
}
