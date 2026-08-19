package defines;
  typedef enum bit [2:0] {
      WB_ALU  = 3'd0,
      WB_BOOL = 3'd1,
      WB_MEM  = 3'd2,
      WB_REG  = 3'd3,
      WB_IMM  = 3'd4
  } wb_sel_t;

  typedef enum bit [2:0] {
      CMP_NEVER = 3'd0,
      CMP_GT    = 3'd1,
      CMP_LT    = 3'd2,
      CMP_GE    = 3'd3,
      CMP_LE    = 3'd4,
      CMP_EQ    = 3'd5,
      CMP_NEQ   = 3'd6,
      CMP_ALWAYS = 3'd7
  } cmp_op_t;

typedef enum bit [2:0] {
    DISPLAY_PC = 3'd0,
    DISPLAY_REG = 3'd1,
    DISPLAY_MEM = 3'd2,
    DISPLAY_IMM = 3'd3,
    DISPLAY_FLAGS = 3'd4,
    DISPLAY_INSTRUCTION = 3'd5
} display_mux_t;

typedef enum bit [1:0] {
    TICK_MODE = 2'b00,
    MANUAL_MODE = 2'b10,
    TURBO_MODE = 2'b01,
    FAST_MODE = 2'b11
} enable_mode_t;


typedef enum bit [6:0] {  //{a,b,c,d,e,f,g} ACTIVE LOW!
    ZERO = 7'b0000001,
    ONE = 7'b1001111,
    TWO = 7'b0010010,
    THREE = 7'b0000110,
    FOUR = 7'b1001100,
    FIVE = 7'b0100100,
    SIX = 7'b0100000,
    SEVEN = 7'b0001111,
    EIGHT = 7'b0000000,
    NINE = 7'b0000100,
    MINUS = 7'b1111110,
    OFF = 7'b1111111
} seven_segment_t;
endpackage

