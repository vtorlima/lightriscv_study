module riscv_single_dataflow(
  input  logic Clk, Reset,
  // Instruction memory interface
  output logic [31:0] PC, 
  input  logic [31:0] Instr,
  // data memory interface
  output logic [31:0] DataAddress, WriteData,
  output logic        MemWrite,
  input  logic [31:0] ReadData);
  
  import riscv_constants::*;

  // The RISC-V instructions supported by this processor.
  wire isALUreg = (Instr[6:0] == OPCODE_REG);
  wire isALUimm = (Instr[6:0] == OPCODE_IMM);
  wire isBranch = (Instr[6:0] == OPCODE_BRANCH);
  wire isJALR   = (Instr[6:0] == OPCODE_JALR);
  wire isJAL    = (Instr[6:0] == OPCODE_JAL);
  wire isAUIPC  = (Instr[6:0] == OPCODE_AUIPC);
  wire isLUI    = (Instr[6:0] == OPCODE_LUI);
  wire isLoad   = (Instr[6:0] == OPCODE_LOAD);
  wire isStore  = (Instr[6:0] == OPCODE_STORE);

  // Immediate formats and instruction fields.
  wire [31:0] Uimm = immediate_u(Instr);
  wire [31:0] Iimm = immediate_i(Instr);
  wire [31:0] Simm = immediate_s(Instr);
  wire [31:0] Bimm = immediate_b(Instr);
  wire [31:0] Jimm = immediate_j(Instr);
  wire [4:0] rs1Id_A1 = Instr[19:15];
  wire [4:0] rs2Id_A2 = Instr[24:20];
  wire [4:0] rdId_A3 = Instr[11:7];
  wire [2:0] funct3 = Instr[14:12];
  wire [6:0] funct7 = Instr[31:25];

  wire [31:0] rs1, rs2;
  wire [31:0] SrcA = rs1;
  wire [31:0] SrcB = isALUreg | isBranch ? rs2 :
                     isStore ? Simm : Iimm;
  wire [31:0] aluPlus = SrcA + SrcB;
  wire [32:0] aluMinus = {1'b1, ~SrcB} + {1'b0, SrcA} + 33'b1;
  wire LT = (SrcA[31] ^ SrcB[31]) ? SrcA[31] : aluMinus[32];
  wire LTU = aluMinus[32];
  wire EQ = (aluMinus[31:0] == 0);

  wire [4:0] shamt = isALUreg ? rs2[4:0] : Instr[24:20];
  wire [31:0] shifter_in = (funct3 == 3'b001) ? flip32(SrcA) : SrcA;
  wire [31:0] shifter = $signed({Instr[30] & SrcA[31], shifter_in}) >>> SrcB[4:0];
  wire [31:0] leftshift = flip32(shifter);

  reg [31:0] ALUResult;
  wire ResultSrc = isLoad;
  wire [31:0] Result = ResultSrc ? ReadData : ALUResult;
  wire RegWrite = isALUimm | isALUreg | isLoad;
  wire PCSrc = isJAL | isJALR;
  wire [31:0] PCplus4 = PC + 32'd4;
  wire [31:0] PCTarget = PC + Jimm;
  wire [31:0] PCNext = PCSrc ? PCTarget : PCplus4;

  // The registers bank
  reg [31:0] RegisterFile [0:31];
  assign rs1 = rs1Id_A1 ? RegisterFile[rs1Id_A1] : 32'b0;
  assign rs2 = rs2Id_A2 ? RegisterFile[rs2Id_A2] : 32'b0;

  assign MemWrite = isStore;
  assign DataAddress = aluPlus;
  assign WriteData = rs2;

  always @(posedge Clk)
    if (RegWrite)
      RegisterFile[rdId_A3] <= Result;

  always @(posedge Clk)
    PC <= Reset ? 32'b0 : PCNext;

  always @(*) begin
    case (funct3)
      3'b000: ALUResult = (funct7[5] & Instr[5]) ? aluMinus[31:0] : aluPlus;
      3'b001: ALUResult = leftshift;
      3'b010: ALUResult = {31'b0, LT};
      3'b011: ALUResult = {31'b0, LTU};
      3'b100: ALUResult = SrcA ^ SrcB;
      3'b101: ALUResult = shifter;
      3'b110: ALUResult = SrcA | SrcB;
      3'b111: ALUResult = SrcA & SrcB;
    endcase
  end

  function [31:0] flip32;
    input [31:0] x;
    flip32 = {x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7],
              x[8], x[9], x[10], x[11], x[12], x[13], x[14], x[15],
              x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
              x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
  endfunction
endmodule
