`ifndef __PIPES_SV
`define __PIPES_SV


`ifdef VERILATOR
`include "common.svh"
`include "decode.svh"
`include "cp0_pkg.svh"


`endif 

/* Define instrucion decoding rules here */

// parameter F7_RI = 7'bxxxxxxx;


/* Define pipeline structures here */

parameter F6_J = 6'b000010;
parameter F6_JAL = 6'b000011;

typedef struct packed {
	word_t data;
	creg_addr_t rdst;
	u8 cp0ra;
	u1 lowrite,hiwrite,cp0write;
	u1 memtoreg;
	u1 regwrite;
} bypass_input_t;

typedef struct packed {
	u1 lo_read,hi_read,cp0_read;
	u8 cp0ra;
	creg_addr_t ra1,ra2;
} bypass_issue_t;

typedef struct packed {
	u1 lowrite,hiwrite,cp0write;
	u8 cp0ra;
	u1 regwrite;
	creg_addr_t rdst;
} bypass_execute_t;

typedef struct packed {
	word_t data;
	u1 valid;
	u1 [1:0] bypass;
} bypass_output_t;


// typedef enum u3 { 
// 	NONE,EXCEPTION,INTERUPT,RET,cp0_INSTR
//  } cp0_type_t;
//  typedef enum u2 { 
// 	cp0RW,cp0RC,cp0RS
//  } cp0_op_t;
// typedef struct packed {
// 	u1 trint;
// 	u1 swint;
// 	u1 exint;
// } int_type_t;

typedef struct packed {
	u1 taken;
	u32 pc;
} bp_res_t;

// typedef enum i3 {
//      MSIZE1 = 3'b000,
//      MSIZE2 = 3'b001,
//      MSIZE4 = 3'b010
//  } msize_t;



// typedef enum logic[1:0] { REGB, IMM} alusrcb_t;

typedef struct packed {
	decoded_op_t op;//for ext(imm)
	// alufunc_t alufunc;
	// branch_t branch;
	// u2 memRw;
	// u1 regwrite,pcTarget,extAluOut,mem_unsigned,alu_sign,alu_cut,zeroext,mul_div_r;
	// u2 wbSelect;//left:1,right:2
	// msize_t msize;

	alufunc_t alufunc;
    logic memtoreg, memwrite,memsext;
    logic regwrite;
    alusrcb_t alusrc;
    logic branch;
    branch_t branch_type;
    logic jump;
    logic jr;
    logic shamt_valid;
    logic zeroext;
    logic cp0write;
    logic is_eret;
    logic hiwrite;
    logic lowrite;
    logic is_bp;
    logic is_sys;
    logic hitoreg, lotoreg, cp0toreg;
    logic is_link;
    logic mul_div_r;
	msize_t msize;

} control_t;

// typedef struct packed {
// 	cp0_type_t ctype;
// 	cp0_op_t op;
// 	u4 code;
// 	u1 valid;
// 	u1 imm;
// 	u12 cp0a;
// 	u5 zimm;
// 	u64 rs1rd;
// } cp0_control_t;

typedef struct packed {
	u1 valid;
	u32 raw_instr;
	u32 pc;
	cp0_control_t cp0_ctl;
	// int_type_t int_type;
    } fetch_data_t;//

typedef struct packed {
	// int_type_t int_type;
	u1 valid;
	u32 raw_instr;
	u8 cp0ra;
	control_t ctl;
	creg_addr_t rdst,ra1,ra2;//2^5=32 assign the reg to be written
	word_t pc;
	u16 imm;
	u1 is_slot;
	cp0_control_t cp0_ctl;
	word_t rd1,rd2;
} decode_data_t;

typedef struct packed {
	// int_type_t int_type;
	u1 valid;
	word_t rd1,rd2,lo_rd,hi_rd,cp0_rd;
	control_t ctl;
	u8 cp0ra;
	u16 imm;
	// creg_addr_t rd,ra1,ra2;//2^5=32 assign the reg to be written
	word_t pc;
	u1 is_slot;
	u32 raw_instr;
	creg_addr_t rdst;

	cp0_control_t cp0_ctl;
} issue_data_t;

typedef struct packed {
	// int_type_t int_type;
	
	u1 valid;
	word_t pc;
	control_t ctl;
	creg_addr_t rdst;
	word_t alu_out;
	u8 cp0ra;
	u64 hilo;
	// u64 target;
	// u64 sextimm;
	word_t srcb;
	word_t target;
	u1 branch_taken;
	u1 is_slot;
	word_t lo_rd,hi_rd,cp0_rd;
	// u64 rs1rd;
	cp0_control_t cp0_ctl;
} execute_data_t;

typedef struct packed {
	u1 valid;
	// int_type_t int_type;
	word_t pc;
	word_t alu_out;
	control_t ctl;
	creg_addr_t rdst;
	u8 cp0ra;
	u1 is_slot;
	// word_t lo_rd,hi_rd,cp0_rd;
	cp0_control_t cp0_ctl;
	word_t srcb;

	// u64 target;
	word_t rd;
	// u64 rs1rd;
} memory_data_t;
//写回阶段dataM与dataW混用
typedef struct packed {
	u1 valid;
	creg_addr_t wa;
	word_t wd;
	control_t ctl;
	word_t cp0_rd;
	word_t lo_rd;
	word_t hi_rd;
	u1 regwrite;

} writeback_data_t;

`endif