const std = @import("std");
const _pip_ex = @import("pipeline_executor.zig");
const _cpu_state = @import("cpu_state.zig");
const Instruction = _pip_ex.Instruction;
const CpuState = _cpu_state.CpuState;
const CpuFlag = _cpu_state.CpuFlag;
const processMask = _cpu_state.processMask;
const bitmask = _cpu_state.bitmask;
const Pipe = _pip_ex.Pipe;


pub fn executeBranchInstr(instr: *const Instruction, cpu: *CpuState, pipe: *Pipe) bool {
    const condition_bits = processMask(instr.code, 28, 31);
    if ( !cpu.checkCPSRCond(@intCast(u8, condition_bits)) ) {
        pipe.executing = null;
        return false;
    }
    var offset: i32 = @intCast(i32, processMask(instr.code, 0, 23) << 2);

    
    if (bitmask(@bitCast(u32, offset), 25) != 0) {
        // Must be a negative number, we need to sign extend it
        const mask = @as(u32, 1 << 26);
        offset |= -@intCast(i32, mask);
    }
    cpu.offsetPC(@bitCast(u32, offset));
    pipe.clear();
    pipe.fetching = cpu.fetchAt(cpu.getPC().*);
    cpu.incrementPC();
    return true;
}

pub fn executeMultipltyInstruction(instr: *const Instruction, cpu: *CpuState) void {
    const set = bitmask(instr.code, 20) != 0;
    const reg_m_bits = processMask(instr.code, 0, 3);
    const reg_s_bits = processMask(instr.code, 8, 11);
    var res: u32 = cpu.registers[reg_m_bits] * cpu.registers[reg_s_bits];
    const accumulate_bits = bitmask(instr.code, 21);
    const reg_d_bits = processMask(instr.code, 16, 19);
    if (accumulate_bits != 0) {
        const reg_n_bits = processMask(instr.code, 12 ,15);
        res += cpu.registers[reg_n_bits];
    }

    if (set) {
        cpu.setCPSRFlag(CpuFlag.N, bitmask(res, 31) != 0);
        if (res == 0) {
            cpu.setCPSRFlag(.Z, true);
        }
    }
    cpu.registers[reg_d_bits] = res;
}

const ShiftOp = enum(u8) { LSL, LSR, ASR, ROR };
pub fn executeShift(operand: u32, shift_amount: u32, shift_opcode: ShiftOp, c_bit: *u8) u32 {

}
