const std = @import("std");
const _cpu = @import("cpu_state.zig");
const _instr_exec = @import("instruction_executions.zig");
const executeBranchInstr = _instr_exec.executeBranchInstr;
const executeMultipltyInstruction = _instr_exec.executeMultipltyInstruction;
const executeDataProcInstruction = _instr_exec.executeDataProcInstruction;
const CpuState = _cpu.CpuState;
const processMask = _cpu.processMask;
const bitmask = _cpu.bitmask;

pub const InstrType = enum { DATA_PROCESS, MULTIPLY, SINGLE_DATA_TRANSFER, BRANCH };
pub const Instruction = struct {
    code: u32,
    ty: InstrType,

    pub fn isBranch(n: u32) bool {
        return processMask(n, 24, 27) == 10; 
    }

    pub fn isMultiplty(n: u32) bool {
        const top_bits_zero = processMask(n, 22, 27) == 0;
        const lower_bits = processMask(n, 4, 7) == 9;
        return top_bits_zero and lower_bits;
    }

    pub fn isSingleDataTransfer(n: u32) bool {
        return processMask(n, 26, 27) == 1; 
    }

    pub fn decode(n: u32) Instruction {
        var ity: InstrType = undefined;
        if (isBranch(n)) {
            ity = .BRANCH; 
        } else if (isMultiplty(n)) {
            ity = .MULTIPLY;
        } else if (isSingleDataTransfer(n)) {
            ity = .SINGLE_DATA_TRANSFER;
        } else {
            ity = .DATA_PROCESS;
        }
        return .{ .code = n, .ty = ity };
    }
};

pub fn startPipeline(cpu: *CpuState) void {
    var pipe = Pipe.init(cpu);
    startPipelineHelper(cpu, &pipe);
}

fn startPipelineHelper(cpu: *CpuState, pipe: *Pipe) void {
    if (pipe.fetching != 0) {
        pipe.executing = pipe.decoding;
        pipe.decoding = Instruction.decode(pipe.fetching);
        var branch_instr_succeeded = false;
        if (pipe.executing) |exec| {
            const succeeded = execute(exec, cpu, pipe);
            // We need to check whether the jump was successful or not
            if (succeeded and exec.ty == .BRANCH) {
                branch_instr_succeeded = true;
            }
        }
        if (!branch_instr_succeeded) {
            // Branch instr didn't succeed, just continue
            pipe.fetching = cpu.fetchAt(cpu.getPC().*);
            cpu.incrementPC();
        }
        startPipelineHelper(cpu, pipe);
    } else {
        const ended = endPipeline(cpu, pipe);
        if (!ended) {
            startPipelineHelper(cpu, pipe);
        }
    }
}

fn endPipeline(cpu: *CpuState, pipe: *Pipe) bool {
    if (pipe.executing) |exec| {
        const succeeded = execute(exec, cpu, pipe);
        if (exec.ty == .BRANCH and succeeded) {
            // The last instruction was a branch instruction which succeeded,
            // so we are no longer aborting
            return false;
        }
        cpu.incrementPC();
        if (pipe.decoding) |_| {
            pipe.decoding = null;
        }
    } else {
        if (pipe.decoding) |decoding| {
            const succeeded = execute(decoding, cpu, pipe);
            if (decoding.ty == .BRANCH and succeeded) {
                // Same as above, we made a successful jump
                return false;
            }
            pipe.decoding = null;
        }
    }
    cpu.incrementPC();
    return true;
}


pub fn execute(instr: Instruction, cpu: *CpuState, pipe: *Pipe) bool {
    if ( !cpu.checkCPSRCond(@intCast(u8, processMask(instr.code, 28, 31))) ) {
        return false;
    }

    switch (instr.ty) {
        .DATA_PROCESS => { executeDataProcInstruction(cpu, &instr); pipe.executing = null; },
        .MULTIPLY => { executeMultipltyInstruction(&instr, cpu); pipe.executing = null; },
        .SINGLE_DATA_TRANSFER => { },
        .BRANCH => { return executeBranchInstr(&instr, cpu, pipe); }, 
    }
    return true;
}

pub const Pipe = struct {
    executing: ?Instruction,
    decoding: ?Instruction,
    fetching: u32,

    pub fn clear(self: *Pipe) void {
        self.executing = null;
        self.decoding = null;
        self.fetching = 0;
    }

    pub fn init(cpu: *CpuState) Pipe {
        cpu.incrementPC();
        return Pipe {
            .executing = null,
            .decoding = null,
            .fetching = cpu.fetchAt(0)
        };
    }

};

