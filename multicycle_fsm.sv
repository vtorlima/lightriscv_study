module multicycle_fsm(
  input  logic       Clk, Reset,
  input  logic [6:0] Opcode,
  output logic [3:0] State
);
  import riscv_constants::*;

  logic [3:0] NextState;

  always_ff @(posedge Clk or posedge Reset)
    if (Reset)
      State <= STATE_FETCH;
    else
      State <= NextState;

  always_comb begin
    case (State)
      STATE_FETCH:
        NextState = STATE_DECODE;
      STATE_DECODE:
        case (Opcode)
          OPCODE_LOAD, OPCODE_STORE: NextState = STATE_MEMADR;
          OPCODE_REG:                NextState = STATE_RTYPEEX;
          OPCODE_BRANCH:             NextState = STATE_BEQEX;
          OPCODE_IMM:                NextState = STATE_ADDIEX;
          OPCODE_JAL:                NextState = STATE_JEX;
          default:                   NextState = 4'bxxxx;
        endcase
      STATE_MEMADR:
        case (Opcode)
          OPCODE_LOAD:  NextState = STATE_MEMRD;
          OPCODE_STORE: NextState = STATE_MEMWR;
          default:      NextState = 4'bxxxx;
        endcase
      STATE_MEMRD:   NextState = STATE_MEMWB;
      STATE_MEMWB:   NextState = STATE_FETCH;
      STATE_MEMWR:   NextState = STATE_FETCH;
      STATE_RTYPEEX: NextState = STATE_RTYPEWB;
      STATE_RTYPEWB: NextState = STATE_FETCH;
      STATE_BEQEX:   NextState = STATE_FETCH;
      STATE_ADDIEX:  NextState = STATE_ADDIWB;
      STATE_ADDIWB:  NextState = STATE_FETCH;
      STATE_JEX:     NextState = STATE_FETCH;
      default:       NextState = 4'bxxxx;
    endcase
  end
endmodule
