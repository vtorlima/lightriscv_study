// riscv_multi_struct.sv
// menotti@ufscar.br 13 May 2021
// Multi-cycle implementation of a subset of RISC-V

// Based on:
// David_Harris@hmc.edu and Sarah_Harris@hmc.edu 26 July 2011 
// Multi-cycle implementation of a subset of MIPS
module riscv_multi_struct(
            input  logic        clk, reset,
            output logic [31:0] adr, writedata,
            output logic        memwrite,
            input  logic [31:0] readdata);

  logic        zero, pcen, irwrite, regwrite,
               iord, memtoreg;
  logic [1:0]  alusrca, pcsrc;
  logic [2:0]  alusrcb, alucontrol, funct3;
  logic [6:0]  op, funct7;

  controller c(clk, reset, op, funct7, zero,
               pcen, memwrite, irwrite, regwrite,
               iord, memtoreg, 
               alusrca, pcsrc, alusrcb, alucontrol, funct3);
  datapath dp(clk, reset, 
              pcen, irwrite, regwrite,
              iord, memtoreg,
              alusrca, pcsrc, alusrcb, alucontrol, funct3,
              op, funct7, zero,
              adr, writedata, readdata);
endmodule


module controller(input  logic       clk, reset,
                  input  logic [6:0] op, funct7,
                  input  logic       zero,
                  output logic       pcen, memwrite, irwrite, regwrite,
                  output logic       iord, memtoreg,
                  output logic [1:0] alusrca, pcsrc,
                  output logic [2:0] alusrcb, alucontrol, 
                  input  logic [2:0] funct3);

  logic [1:0] aluop;
  logic       branch, pcwrite;

  // Main Decoder and ALU Decoder subunits.
  maindec md(clk, reset, op,
             pcwrite, memwrite, irwrite, regwrite,
             branch, iord, memtoreg, 
             alusrca, pcsrc, alusrcb, aluop);
  aludec  ad(funct3, aluop, alucontrol);

  assign pcen = pcwrite | branch & zero;
 
endmodule

module maindec(input  logic       clk, reset, 
               input  logic [6:0] op, 
               output logic       pcwrite, memwrite, irwrite, regwrite,
               output logic       branch, iord, memtoreg,
               output logic [1:0] alusrca, pcsrc,
               output logic [2:0] alusrcb, 
               output logic [1:0] aluop);
  import riscv_constants::*;

  logic [3:0] state;
  logic [15:0] controls;

  multicycle_fsm fsm(clk, reset, op, state);

  // output logic
  assign {pcwrite, memwrite, irwrite, regwrite, 
          alusrca, branch, iord, memtoreg,
          pcsrc, alusrcb, aluop} = controls;
//                                          pcsrc
  always_comb//                                alusrcb
    case(state)//                    alusrca       aluop
      STATE_FETCH:   controls = 16'b1010_00_000_00_001_00;
      STATE_DECODE:  controls = 16'b0000_00_000_00_011_00;
      STATE_MEMADR:  controls = 16'b0000_01_000_00_010_00;
      STATE_MEMRD:   controls = 16'b0000_00_010_00_000_00;
      STATE_MEMWB:   controls = 16'b0001_00_001_00_000_00;
      STATE_MEMWR:   controls = 16'b0100_00_010_00_000_00;
      STATE_RTYPEEX: controls = 16'b0000_01_000_00_000_10;
      STATE_RTYPEWB: controls = 16'b0001_00_000_00_000_00;
      STATE_BEQEX:   controls = 16'b0000_01_100_01_000_01;
      STATE_ADDIEX:  controls = 16'b0000_01_000_00_010_00;
      STATE_ADDIWB:  controls = 16'b0001_00_000_00_000_00;
      STATE_JEX:     controls = 16'b1000_10_000_00_100_00;
      default:  controls = 16'bxxxx_xx_xxx_xx_xx_xx; // should never happen
    endcase
endmodule

module aludec(input  logic [2:0] funct3,
              input  logic [1:0] aluop,
              output logic [2:0] alucontrol);

  always_comb
    case(aluop)
      2'b00: alucontrol = 3'b010;  // add (fetch, memaddr, addi, etc.)
      2'b01: alucontrol = 3'b110;  // sub (beq)
      default: case(funct3)         // RTYPE 
           3'b000: alucontrol = 3'b010; // ADD
           3'b111: alucontrol = 3'b000; // AND
           3'b110: alucontrol = 3'b001; // OR
           3'b010: alucontrol = 3'b111; // SLT
          default: alucontrol = 3'bxxx; // ???
        endcase
    endcase

endmodule

module datapath(input  logic        clk, reset,
                input  logic        pcen, irwrite, regwrite,
                input  logic        iord, memtoreg,
                input  logic [1:0]  alusrca, pcsrc, 
                input  logic [2:0]  alusrcb, alucontrol,
                output logic [2:0]  funct3,
                output logic [6:0]  op, funct7,
                output logic        zero,
                output logic [31:0] adr, writedata, 
                input  logic [31:0] readdata);
  import riscv_constants::*;

  // Below are the internal signals of the datapath module.
  logic [4:0]  rd, rs1, rs2;
  logic [31:0] pcnext, pc, pca;
  logic [31:0] instr, data, srca, srcb;
  logic [31:0] a;
  logic [31:0] aluresult, aluout;
  logic [31:0] signimm;   // the sign-extended immediate
  logic [31:0] signimmsh; // the sign-extended immediate shifted left by 2
  logic [31:0] wd3, rd1, rd2;
  logic [31:0] immI, immS, immB, immU, immJ;

  // instruction fields to controller
  assign op     = instr[ 6: 0];
  assign rd     = instr[11: 7];
  assign funct3 = instr[14:12];
  assign rs1    = instr[19:15];
  assign rs2    = instr[24:20];
  assign funct7 = instr[31:25];
  // immediate fields
  assign immI = immediate_i(instr);
  assign immS = immediate_s(instr);
  assign immB = immediate_b(instr);
  assign immU = immediate_u(instr);
  assign immJ = immediate_j(instr);

  // datapath
  flopenr #(32) pcregn(clk, reset, pcen, pcnext, pc);
  flopenr #(32) pcrega(clk, reset, pcen, pc, pca);
  mux2    #(32) adrmux(pc, aluout, iord, adr);
  flopenr #(32) instrreg(clk, reset, irwrite, readdata, instr);
  flopr   #(32) datareg(clk, reset, readdata, data);
  mux2    #(32) wdmux(aluout, data, memtoreg, wd3);
  regfile       rf(clk, regwrite, rs1, rs2, rd, wd3, rd1, rd2);
  flopr   #(32) areg(clk, reset, rd1, a);
  flopr   #(32) breg(clk, reset, rd2, writedata);
  mux3    #(32) srcamux(pc, a, pca, alusrca, srca);
  mux5    #(32) srcbmux(writedata, 32'b100, immI, immI<<2, immJ, alusrcb, srcb);
  alu           alu(srca, srcb, alucontrol, aluresult, zero);
  flopr   #(32) alureg(clk, reset, aluresult, aluout);
  mux2    #(32) pcmux(aluresult, aluout, pcsrc[0], pcnext);
endmodule


// building blocks
module regfile(input  logic        clk, 
               input  logic        we3, 
               input  logic [4:0]  ra1, ra2, wa3, 
               input  logic [31:0] wd3, 
               output logic [31:0] rd1, rd2);

  logic [31:0] rf[31:0];

  // three ported register file
  // read two ports combinationally
  // write third port on rising edge of clk
  // register 0 hardwired to 0
  // note: for pipelined processor, write third port
  // on falling edge of clk

  always_ff @(posedge clk)
    if (we3) 
       rf[wa3] <= wd3;	

  assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
  assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule


/*
module sl2(input  logic [31:0] a,
           output logic [31:0] y);

  // shift left by 2
  assign y = {a[29:0], 2'b00};
endmodule

module signext(input  logic [15:0] a,
               output logic [31:0] y);
              
  assign y = {{16{a[15]}}, a};
endmodule
*/
module alu(input  logic [31:0] a, b,
           input  logic [2:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero);

  logic [31:0] condinvb, sum;

  assign condinvb = alucontrol[2] ? ~b : b;
  assign sum = a + condinvb + alucontrol[2];

  always_comb
    case(alucontrol)
      3'b000, 3'b100: result = a & b;
      3'b001, 3'b101: result = a | b;
      3'b010, 3'b110: result = sum;
      3'b011, 3'b111: result = sum[31];
    endcase

  assign zero = (result == 32'b0);
endmodule

module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic             s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  assign #1 y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule

module mux4 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2, d3,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

   always_comb
      case(s)
         2'b00: y = d0;
         2'b01: y = d1;
         2'b10: y = d2;
         2'b11: y = d3;
      endcase
endmodule

module mux5 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2, d3, d4, 
              input  logic [2:0]       s, 
              output logic [WIDTH-1:0] y);

   always_comb
      casex(s)
         3'b000: y = d0;
         3'b001: y = d1;
         3'b010: y = d2;
         3'b011: y = d3;
         3'b1xx: y = d4;
      endcase
endmodule

module flopr #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

module flopenr #(parameter WIDTH = 8)
              (input  logic             clk, reset, en,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset)   q <= 0;
    else if (en) q <= d;
endmodule
