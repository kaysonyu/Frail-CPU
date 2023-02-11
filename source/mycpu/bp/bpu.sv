`ifndef __BPU_SV
`define __BPU_SV

`include "common.svh"

`ifdef VERILATOR
`include "bht.sv"
`include "jht.sv"
`include "jht2.sv"
`include "rpct.sv"
`include "ras.sv"
`endif 

module bpu #(
    parameter int COUNTER_BITS = 2
) (
    input logic clk, resetn, ras_push_f1, ras_pop_f1,

    input addr_t f1_pc, f1_pc_push,// f1
    output logic f1_taken, hit, hit_jal, hit_jrra,
    output addr_t pre_pc,

    // input logic is_jr_ra_decode,// decode (jump do not need pre)
    // output logic jr_ra_fail,
    // output addr_t decode_ret_pc,

    input addr_t exe_pc, dest_pc, ret_pc,// exe
    // ret_pc for jal, jalr
    input logic is_branch, is_j, is_jal, is_jalr, is_jr_ra_exe, is_jr_not_ra,
    input logic flush,
    input logic is_taken, stall
    // stall for ras
    // to avoid this case: stall and keep pushing or keep popping
);

    logic bht_hit, jht_hit, ras_hit, ras_fail;
    addr_t bht_pre_pc, ras_pre_pc, jht_pre_pc;
    logic prediction_outcome;

    assign hit_jrra = ras_hit;

    always_comb begin : pre_pc_block
        pre_pc = '0;
        if(bht_hit) begin
            pre_pc = bht_pre_pc;
        end else if(jht_hit) begin
            pre_pc = jht_pre_pc;
        end else if(ras_hit) begin
            pre_pc = ras_pre_pc;
        end
    end

    always_comb begin : f1_taken_block
        f1_taken = 1'b0;
        if((ras_hit) || jht_hit) begin
            f1_taken = 1'b1;
        end else if (bht_hit) begin
            f1_taken = prediction_outcome;
        end
    end

    // logic bht_hit_pc, bht_hit_pcp4, jht_hit_pc, jht_hit_pcp4, rpct_hit_pc, rpce_hit_pcp4;
    assign hit = bht_hit | (ras_hit && ~ras_fail) | jht_hit;
    // assign jr_ra_fail = '0;

    bht bht (
        .clk, .resetn,
        .is_write(is_branch),
        .branch_pc(f1_pc),
        .executed_branch_pc(exe_pc),
        .dest_pc,
        .is_taken,
        .predict_pc(bht_pre_pc),
        .hit(bht_hit),
        .dpre(prediction_outcome)
    );

    jht jht (
        .clk, .resetn,
        .is_write(is_j | is_jal | is_jr_not_ra),
        .is_jal,
        .j_pc(f1_pc),
        .executed_j_pc(exe_pc),
        .dest_pc,
        .predict_pc(jht_pre_pc),
        .hit(jht_hit),
        .hit_jal
    );

    ras ras (
        .clk, .resetn,
        .push(ras_push_f1),
        .pop(ras_pop_f1),
        .bk_push(is_jal & (~stall)),
        .bk_pop(is_jr_ra_exe & (~stall)),
        .flush,
        .f1_pc(f1_pc),
        .ret_pc_push(f1_pc_push),
        .bk_ret_pc_push(ret_pc),
        .jrra_pc(exe_pc),
        .ret_pc_top(ras_pre_pc),
        .fail(ras_fail),
        .hit(ras_hit)
    );

    // jht2 rpct (
    //     .clk, .resetn,
    //     .is_write(is_j | is_jal | is_jr_ra_exe),
    //     .j_pc(f1_pc),
    //     .executed_j_pc(exe_pc),
    //     .dest_pc,
    //     .predict_pc(rpct_pre_pc),
    //     .hit(rpct_hit)
    // );

    // rpct rpct (
    //     .clk, .resetn,
    //     .is_call(is_jal),
    //     .is_ret(is_jr_ra_exe),
    //     .pc_f1(f1_pc),
    //     .jrra_pc(exe_pc),
    //     .call_pc(dest_pc),
    //     .ret_pc(is_jr_ra_exe ? dest_pc : ret_pc),
    //     .hit(rpct_hit),
    //     .pre_pc(rpct_pre_pc)
    // );

endmodule


`endif 