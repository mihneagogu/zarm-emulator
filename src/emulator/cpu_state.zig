const std = @import("std");
const Allocator = std.mem.Allocator; 

pub const MEMORY_SIZE = 65536;
const REGISTERS = 17;
const PC = 15;
const CPSR = 16;
const MAX_FLAG = 3;

const OFFSET_STEP = 4;

pub const CpuFlag = enum(u8) { N, Z, C, V };
pub const FlagCode = enum(u8) { EQ = 0, NE = 1, GE = 10, LT = 11, GT = 12, LE = 13, AL = 14 };

pub const CpuState = struct { 
    registers: []u32, 
    memory: []u8,

    pub fn init(alloc: *Allocator) CpuState {
        // Realistically we could accept a size of 65536 bytes in which could be
        // static from the stack for speed, but we don't care about this right now

        var mem = alloc.alloc(u8, MEMORY_SIZE) catch @panic("oom");
        std.mem.set(u8, mem, 0); // Zero everything at the beginning
        var regs = alloc.alloc(u32, REGISTERS) catch @panic("oom");
        std.mem.set(u32, regs, 0); // Zero everything at the beginning
        return CpuState {
            .registers = regs,
            .memory  = mem
        };
    }

    pub fn checkCPSRCond(self: *CpuState, cond: u8) bool {
        switch (cond) {
            @enumToInt(FlagCode.EQ) => return self.getFlag(.Z),
            @enumToInt(FlagCode.NE) => return !self.getFlag(.Z),
            @enumToInt(FlagCode.GE) => return self.getFlag(.N) == self.getFlag(.V),
            @enumToInt(FlagCode.LT) => return self.getFlag(.N) != self.getFlag(.V),
            @enumToInt(FlagCode.GT) => return !self.getFlag(.Z) and ( self.getFlag(.N) == self.getFlag(.V) ),
            @enumToInt(FlagCode.LE) => return self.getFlag(.Z) or ( self.getFlag(.N) != self.getFlag(.V) ),
            else => @panic("Undefined CPSR condition")
        }
        return true;
    }

    pub fn destroy(self: *CpuState, alloc: *Allocator) void {
        alloc.free(self.registers);
        alloc.free(self.memory);
    }

    pub fn setCPSRFlag(self: *CpuState, flag: CpuFlag, set: bool) void {
        const mask: u32 = @as(u32, 1) << (31 - @intCast(u5, @enumToInt(flag)));
        if (set) {
            self.registers[CPSR] = self.registers[CPSR] | mask;
        } else {
            self.registers[CPSR] = self.registers[CPSR] & ~mask;
        }
    }

    pub fn getFlag(self: *CpuState, flag: CpuFlag) bool {
        const mask: u32 = @as(u32, 1) << (31 - @intCast(u5, @enumToInt(flag)));
        return (self.registers[CPSR] & mask) != 0;
    }

    pub fn offsetPC(self: *CpuState, ofs: u32) callconv(.Inline) void {
        var pc = self.getPC();
        pc.* += ofs;
    }

    pub fn getPC(self: *CpuState) callconv(.Inline) *u32 {
        return &self.registers[PC];
    }

    pub fn printNonzeroLEMemory(self: *CpuState, bytes: u32) void {
        std.debug.print("Non-zero memory:\n", .{});
        var i = 0;
        while (i < bytes): (i += 4) {
            // TODO
            // const val = fetch(i, cpustate) 
            // if (val != 0) print it 
        }
    }

    pub fn printRegisters(self: *CpuState) void {
        std.debug.print("Registers:\n", .{});
        var i: u8 = @as(u8, 0);
        while (i < REGISTERS): (i += 1) {
            const val = self.registers[i];
            if (i == 13 or i == 14) {
                // Unused registers
                continue;
            }
            if (i != CPSR and i != PC) {
                if (i < 10) {
                    std.debug.print("${d}  : ", .{i});
                } else {
                    std.debug.print("${d} : ", .{i});
                }
            } else if (i == PC) {
                std.debug.print("PC  : ", .{});
            } else {
                std.debug.print("CPSR: ", .{});
            }
            if (val == 0x80000000) {
                std.debug.print(" ", .{}); // Weird print format condition
            }
            std.debug.print("{d} (0x{x:0>8})\n", .{val, val});
        }
    }

    pub fn incrementPC(self: *CpuState) callconv(.Inline) void {
        self.offsetPC(OFFSET_STEP);
    }

    pub fn fetchAt(self: *CpuState, ptr: u32) u32 {
        const valid = true;
        if (!self.checkValidMemoryAccess(ptr)) {
            return 0;
        }

        return indexLEBytes(self.memory[ptr .. ptr+4]);
    }
    pub fn checkValidMemoryAccess(self: *CpuState, addr: u32) bool {
        return if (addr > MEMORY_SIZE - 4) blk: {
            std.debug.print("Out of bounds memory access at 0x{d:0>8}\n", .{addr});
            break :blk false;
        } else true;
    }
};

pub fn processMask(n: u32, start: u8, end: u8) u32 {
    const mask = ( @as(u32, 1) << @intCast(u5, end - start + 1) ) - 1;
    return (n >> @intCast(u5, start)) & mask;
}

pub fn bitmask(n: u32, pos: u8) u32 {
    return (n >> @intCast(u5, pos)) & 1;
}

fn indexLEBytes(ptr: []u8) u32 {
    return ptr[0] | (@as(u32, ptr[1]) << 8) | (@as(u32, ptr[2]) << 16) | (@as(u32, ptr[3]) << 24);
}
