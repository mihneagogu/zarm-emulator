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

const DataProcOpcode = enum(u8) { 
    AND = 0, EOR = 1,
    SUB = 2,
    RSB = 3,
    ADD = 4,
    TST = 8,
    TEQ = 9,
    CMP = 10,
    ORR = 12,
    MOV = 13
};

pub fn executeDataProcInstruction(cpu: *CpuState, instr: *const Instruction) void {
    const operand1_reg_bits = processMask(instr.code, 16, 19);
    var res: u32 = @as(u32, 0); // Written in dest_register
    
    const operand1 = cpu.registers[operand1_reg_bits];
    var operand2 = processMask(instr.code, 0, 11);
    // If write result is 0 then we do NOT write the result into dest_register
    var write_result = true;
    var c_bit = @as(u8, 0); // Do we write to C bit of CPSR?

    const immediate_enable = bitmask(instr.code, 25) != 0;

    if (immediate_enable) {
        operand2 = processMask(instr.code, 0, 7);
        // operand2 = rotateRight(operand2, processMask(instr.code, 8, 11) * 2);
        c_bit = @intCast(u8, ( operand2 >> @intCast(u5, (processMask(instr.code, 8, 11) * 2)) )) & 1;
    } else {
        // operand2 = regOffsetShit(cpu, instr, &c_bit);
    }

    const opcode = processMask(instr.code, 21, 24);
    switch (opcode) {
        @enumToInt(DataProcOpcode.AND) => { res = operand1 & operand2; },
        @enumToInt(DataProcOpcode.EOR) => { res = operand1 ^ operand2; },
        @enumToInt(DataProcOpcode.SUB) => { res = operand1 -% operand2; c_bit = if (operand2 > operand1) 1 else 0; },
        @enumToInt(DataProcOpcode.RSB) => { res = operand2 -% operand1; c_bit = if (operand1 > operand2) 1 else 0; },
        @enumToInt(DataProcOpcode.ADD) => { 
            if(@addWithOverflow(u32, operand1, operand2, &res)) {
                c_bit = 1;
            }
        },
        @enumToInt(DataProcOpcode.TST) => { res = operand1 & operand2; write_result = false;},
        @enumToInt(DataProcOpcode.TEQ) => { res = operand1 ^ operand2; write_result = false;},
        @enumToInt(DataProcOpcode.CMP) => { res = operand1 - operand2; write_result = false; c_bit = if (operand2 > operand1) 1 else 0; },
        @enumToInt(DataProcOpcode.ORR) => { res = operand1 | operand2; },
        @enumToInt(DataProcOpcode.MOV) => { res = operand2; },
        else => @panic("Unrecognized data processing instruction opcode. Aborting"),
    }
    if (write_result) {
        const dest_register = processMask(instr.code, 12, 15);
        cpu.registers[dest_register] = res;
    }
    const cpsr_enable_bit = bitmask(instr.code, 20) != 0;
    if (cpsr_enable_bit) {
        cpu.setCPSRFlag(.C, c_bit != 0);
        const set_z = res == 0;
        cpu.setCPSRFlag(.Z, set_z);
        cpu.setCPSRFlag(.N, bitmask(res, 31) != 0);
    }
}
