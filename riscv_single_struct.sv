// Single-cycle RV32I subset with separate controller and datapath.
module riscv_single_struct(
  input  logic        Clk, Reset,
  output logic [31:0] PC,
  input  logic [31:0] Instr,
  output logic [31:0] DataAddress, WriteData,
  output logic        MemWrite,
  input  logic [31:0] ReadData
);
  logic        RegWrite, ALUSrcB, ImmSrc, ALUSubtract, ArithmeticShift;
  logic [2:0]  ResultSrc, PCSrc;
  logic [2:0]  Funct3;
  logic        LessThan, LessThanUnsigned, Equal;

  single_controller c(
    .Opcode(Instr[6:0]),
    .Funct3(Instr[14:12]),
    .Funct7(Instr[31:25]),
    .LessThan(LessThan),
    .LessThanUnsigned(LessThanUnsigned),
    .Equal(Equal),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .ALUSrcB(ALUSrcB),
    .ImmSrc(ImmSrc),
    .ALUSubtract(ALUSubtract),
    .ArithmeticShift(ArithmeticShift),
    .ResultSrc(ResultSrc),
    .PCSrc(PCSrc),
    .ALUFunct3(Funct3)
  );

  single_datapath dp(
    .Clk(Clk),
    .Reset(Reset),
    .Instr(Instr),
    .ReadData(ReadData),
    .RegWrite(RegWrite),
    .ALUSrcB(ALUSrcB),
    .ImmSrc(ImmSrc),
    .ALUSubtract(ALUSubtract),
    .ArithmeticShift(ArithmeticShift),
    .ResultSrc(ResultSrc),
    .PCSrc(PCSrc),
    .ALUFunct3(Funct3),
    .LessThan(LessThan),
    .LessThanUnsigned(LessThanUnsigned),
    .Equal(Equal),
    .PC(PC),
    .DataAddress(DataAddress),
    .WriteData(WriteData)
  );
endmodule

module single_controller(
  input  logic [6:0] Opcode,
  input  logic [2:0] Funct3,
  input  logic [6:0] Funct7,
  input  logic       LessThan, LessThanUnsigned, Equal,
  output logic       RegWrite, MemWrite, ALUSrcB, ImmSrc,
  output logic       ALUSubtract, ArithmeticShift,
  output logic [2:0] ResultSrc, PCSrc, ALUFunct3
);
  import riscv_constants::*;

  localparam [2:0] RESULT_ALU  = 3'b000;
  localparam [2:0] RESULT_MEM  = 3'b001;
  localparam [2:0] RESULT_PC4  = 3'b010;
  localparam [2:0] RESULT_AUIPC = 3'b011;
  localparam [2:0] RESULT_LUI  = 3'b100;

  localparam [2:0] PC_SEQUENTIAL = 3'b000;
  localparam [2:0] PC_BRANCH     = 3'b001;
  localparam [2:0] PC_JAL        = 3'b010;
  localparam [2:0] PC_JALR       = 3'b011;

  always_comb begin
    RegWrite = 1'b0;
    MemWrite = 1'b0;
    ALUSrcB = 1'b0;
    ImmSrc = 1'b0;
    ALUSubtract = 1'b0;
    ArithmeticShift = Funct3 == 3'b101 && Funct7[5];
    ResultSrc = RESULT_ALU;
    PCSrc = PC_SEQUENTIAL;
    ALUFunct3 = Funct3;

    case (Opcode)
      OPCODE_LOAD: begin
        RegWrite = 1'b1;
        ALUSrcB = 1'b1;
        ResultSrc = RESULT_MEM;
      end
      OPCODE_IMM: begin
        RegWrite = 1'b1;
        ALUSrcB = 1'b1;
      end
      OPCODE_AUIPC: begin
        RegWrite = 1'b1;
        ResultSrc = RESULT_AUIPC;
      end
      OPCODE_STORE: begin
        MemWrite = 1'b1;
        ALUSrcB = 1'b1;
        ImmSrc = 1'b1;
      end
      OPCODE_REG: begin
        RegWrite = 1'b1;
        ALUSubtract = (Funct3 == 3'b000) & Funct7[5];
      end
      OPCODE_LUI: begin
        RegWrite = 1'b1;
        ResultSrc = RESULT_LUI;
      end
      OPCODE_BRANCH: begin
        case (Funct3)
          3'b000: if (Equal) PCSrc = PC_BRANCH;
          3'b001: if (!Equal) PCSrc = PC_BRANCH;
          3'b100: if (LessThan) PCSrc = PC_BRANCH;
          3'b101: if (!LessThan) PCSrc = PC_BRANCH;
          3'b110: if (LessThanUnsigned) PCSrc = PC_BRANCH;
          3'b111: if (!LessThanUnsigned) PCSrc = PC_BRANCH;
          default: PCSrc = PC_SEQUENTIAL;
        endcase
      end
      OPCODE_JALR: begin
        RegWrite = 1'b1;
        ALUSrcB = 1'b1;
        ResultSrc = RESULT_PC4;
        PCSrc = PC_JALR;
      end
      OPCODE_JAL: begin
        RegWrite = 1'b1;
        ResultSrc = RESULT_PC4;
        PCSrc = PC_JAL;
      end
      default: begin
      end
    endcase
  end
endmodule

module single_datapath(
  input  logic        Clk, Reset,
  input  logic [31:0] Instr, ReadData,
  input  logic        RegWrite, ALUSrcB, ImmSrc,
  input  logic        ALUSubtract, ArithmeticShift,
  input  logic [2:0]  ResultSrc, PCSrc, ALUFunct3,
  output logic        LessThan, LessThanUnsigned, Equal,
  output logic [31:0] PC, DataAddress, WriteData
);
  import riscv_constants::*;

  localparam [2:0] RESULT_ALU   = 3'b000;
  localparam [2:0] RESULT_MEM   = 3'b001;
  localparam [2:0] RESULT_PC4   = 3'b010;
  localparam [2:0] RESULT_AUIPC = 3'b011;
  localparam [2:0] RESULT_LUI   = 3'b100;

  localparam [2:0] PC_BRANCH = 3'b001;
  localparam [2:0] PC_JAL    = 3'b010;
  localparam [2:0] PC_JALR   = 3'b011;

  wire [4:0] rs1Id = Instr[19:15];
  wire [4:0] rs2Id = Instr[24:20];
  wire [4:0] rdId = Instr[11:7];

  wire [31:0] Iimm = immediate_i(Instr);
  wire [31:0] Simm = immediate_s(Instr);
  wire [31:0] Bimm = immediate_b(Instr);
  wire [31:0] Uimm = immediate_u(Instr);
  wire [31:0] Jimm = immediate_j(Instr);

  wire [31:0] rs1, rs2, SrcA, SrcBImmediate, SrcB;
  wire [31:0] ALUResult, ALUWriteback, Result;
  wire [31:0] PCplus4, BranchTarget, JALTarget, JALRTarget, PCTarget, PCNext;
  wire [31:0] AUIPCResult;

  single_struct_regfile rf(
    .Clk(Clk),
    .WriteEnable(RegWrite),
    .ReadAddress1(rs1Id),
    .ReadAddress2(rs2Id),
    .WriteAddress(rdId),
    .WriteData(Result),
    .ReadData1(rs1),
    .ReadData2(rs2)
  );

  single_struct_mux2 #(32) immediate_mux(
    Iimm, Simm, ImmSrc, SrcBImmediate
  );
  single_struct_mux2 #(32) alu_source_mux(rs2, SrcBImmediate, ALUSrcB, SrcB);
  assign SrcA = rs1;
  single_struct_alu alu(
    .A(SrcA),
    .B(SrcB),
    .Funct3(ALUFunct3),
    .Subtract(ALUSubtract),
    .ArithmeticShift(ArithmeticShift),
    .Result(ALUResult),
    .LessThan(LessThan),
    .LessThanUnsigned(LessThanUnsigned),
    .Equal(Equal)
  );

  assign DataAddress = rs1 + SrcB;
  assign WriteData = rs2;
  assign PCplus4 = PC + 32'd4;
  assign BranchTarget = PC + Bimm;
  assign JALTarget = PC + Jimm;
  assign JALRTarget = {DataAddress[31:1], 1'b0};

  assign PCTarget = (PCSrc == PC_JALR) ? JALRTarget :
                    (PCSrc == PC_JAL)  ? JALTarget :
                                         BranchTarget;
  assign PCNext = (PCSrc == PC_BRANCH || PCSrc == PC_JAL ||
                   PCSrc == PC_JALR) ? PCTarget : PCplus4;
  single_struct_flopr #(32) pc_register(Clk, Reset, PCNext, PC);

  assign AUIPCResult = PC + Uimm;
  assign ALUWriteback = (ResultSrc == RESULT_MEM)   ? ReadData :
                        (ResultSrc == RESULT_PC4)   ? PCplus4 :
                        (ResultSrc == RESULT_AUIPC) ? AUIPCResult :
                        (ResultSrc == RESULT_LUI)   ? Uimm :
                                                     ALUResult;
  assign Result = ALUWriteback;
endmodule

module single_struct_regfile(
  input  logic        Clk,
  input  logic        WriteEnable,
  input  logic [4:0]  ReadAddress1, ReadAddress2, WriteAddress,
  input  logic [31:0] WriteData,
  output logic [31:0] ReadData1, ReadData2
);
  logic [31:0] RegisterFile [0:31];

  always_ff @(posedge Clk)
    if (WriteEnable && (WriteAddress != 5'b0))
      RegisterFile[WriteAddress] <= WriteData;

  assign ReadData1 = (ReadAddress1 == 5'b0) ? 32'b0 :
                     RegisterFile[ReadAddress1];
  assign ReadData2 = (ReadAddress2 == 5'b0) ? 32'b0 :
                     RegisterFile[ReadAddress2];
endmodule

module single_struct_alu(
  input  logic [31:0] A, B,
  input  logic [2:0]  Funct3,
  input  logic        Subtract, ArithmeticShift,
  output logic [31:0] Result,
  output logic        LessThan, LessThanUnsigned, Equal
);
  wire [32:0] Difference =
    {1'b0, A} + {1'b0, ~B} + 33'd1;
  wire [31:0] ShiftRight = ArithmeticShift
                         ? $signed(A) >>> B[4:0]
                         : A >> B[4:0];

  assign LessThan = (A[31] ^ B[31]) ? A[31] : ~Difference[32];
  assign LessThanUnsigned = ~Difference[32];
  assign Equal = (A == B);

  always @* begin
    case (Funct3)
      3'b000: Result = Subtract ? A - B : A + B;
      3'b001: Result = A << B[4:0];
      3'b010: Result = {31'b0, LessThan};
      3'b011: Result = {31'b0, LessThanUnsigned};
      3'b100: Result = A ^ B;
      3'b101: Result = ShiftRight;
      3'b110: Result = A | B;
      3'b111: Result = A & B;
      default: Result = 32'b0;
    endcase
  end
endmodule

module single_struct_mux2 #(
  parameter WIDTH = 32
)(
  input  logic [WIDTH-1:0] D0, D1,
  input  logic             Select,
  output logic [WIDTH-1:0] Y
);
  assign Y = Select ? D1 : D0;
endmodule

module single_struct_flopr #(
  parameter WIDTH = 32
)(
  input  logic             Clk, Reset,
  input  logic [WIDTH-1:0] D,
  output logic [WIDTH-1:0] Q
);
  always_ff @(posedge Clk)
    Q <= Reset ? '0 : D;
endmodule
