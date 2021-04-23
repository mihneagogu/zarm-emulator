const std = @import("std");
const Allocator = std.mem.Allocator;


const MEMORY_SIZE = 65536;
const REGISTERS = 17;
const PC = 15;
const CPSR = 16;
const MAX_FLAG = 3;

pub const CpuFlag = enum(u8) { N, Z, C, V };
pub const FlagCode = enum(u8) { EQ = 0, NE = 1, GT = 10, LT = 11, GT = 12, LE = 13, AL = 14 };

pub const CpuState = struct { 
    registers: []u32, 
    memory: []u8,

    pub fn init(alloc: *Allocator) CpuState {
        return CpuState {
            .registers = alloc.alloc(u32, REGISTERS) catch @panic("oom"),
            .memory  = alloc.alloc(u8, MEMORY_SIZE) catch @panic("oom")
        };
    }

    pub fn destroy(self: *CpuState, alloc: *Allocator) void {
        alloc.free(self.registers);
        alloc.free(self.memory);
    }

    pub fn set_flag(self: *CpuState, flag: CpuFlag, set: bool) void {
        const mask: u32 = @as(u32, 1) << (31 - @intCast(u5, @enumToInt(flag)));
        if (set) {
            self.registers[CPSR] = self.registers[CPSR] | mask;
        } else {
            self.registers[CPSR] = self.registers[CPSR] & ~mask;
        }
    }

    pub fn get_flag(self: *CpuState, flag: CpuFlag) bool {
        const mask: u32 = @as(u32, 1) << (31 - @intCast(u5, @enumToInt(flag)));
        return (self.registers[CPSR] & mask) != 0;
    }

};
