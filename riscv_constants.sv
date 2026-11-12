package riscv_constants;
  localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
  localparam logic [6:0] OPCODE_IMM    = 7'b0010011;
  localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;
  localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
  localparam logic [6:0] OPCODE_REG    = 7'b0110011;
  localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
  localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
  localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
  localparam logic [6:0] OPCODE_JAL    = 7'b1101111;

  localparam logic [3:0] STATE_FETCH   = 4'b0000;
  localparam logic [3:0] STATE_DECODE  = 4'b0001;
  localparam logic [3:0] STATE_MEMADR  = 4'b0010;
  localparam logic [3:0] STATE_MEMRD   = 4'b0011;
  localparam logic [3:0] STATE_MEMWB   = 4'b0100;
  localparam logic [3:0] STATE_MEMWR   = 4'b0101;
  localparam logic [3:0] STATE_RTYPEEX = 4'b0110;
  localparam logic [3:0] STATE_RTYPEWB = 4'b0111;
  localparam logic [3:0] STATE_BEQEX   = 4'b1000;
  localparam logic [3:0] STATE_ADDIEX  = 4'b1001;
  localparam logic [3:0] STATE_ADDIWB  = 4'b1010;
  localparam logic [3:0] STATE_JEX     = 4'b1011;

  function automatic logic [31:0] immediate_i(input logic [31:0] instr);
    immediate_i = {{20{instr[31]}}, instr[31:20]};
  endfunction

  function automatic logic [31:0] immediate_s(input logic [31:0] instr);
    immediate_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  endfunction

  function automatic logic [31:0] immediate_b(input logic [31:0] instr);
    immediate_b = {{19{instr[31]}}, instr[31], instr[7],
                   instr[30:25], instr[11:8], 1'b0};
  endfunction

  function automatic logic [31:0] immediate_u(input logic [31:0] instr);
    immediate_u = {instr[31:12], 12'b0};
  endfunction

  function automatic logic [31:0] immediate_j(input logic [31:0] instr);
    immediate_j = {{11{instr[31]}}, instr[31], instr[19:12],
                   instr[20], instr[30:21], 1'b0};
  endfunction
endpackage
