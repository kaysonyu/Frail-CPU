`ifndef __MULTI_SV
`define __MULTI_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif
import common::*;
import pipes::*;

module multiplier_multicycle_dsp (
    input logic clk, resetn, valid,
    input i32 a, b,
    output logic done,
    output i64 c // c = a * b
);
    logic [3:0][31:0]p, p_nxt;
    assign p_nxt[0] = a[15:0] * b[15:0];
    assign p_nxt[1] = a[15:0] * b[31:16];
    assign p_nxt[2] = a[31:16] * b[15:0];
    assign p_nxt[3] = a[31:16] * b[31:16];

    always_ff @(posedge clk) begin
        if (~resetn) begin
            p <= '0;
        end else begin
            p <= p_nxt;
        end
    end
    logic [3:0][63:0] q;
    assign q[0] = {p[0]};
    assign q[1] = {p[1], 16'b0};
    assign q[2] = {p[2], 16'b0};
    assign q[3] = {p[3], 32'b0};
    assign c = q[0] + q[1] + q[2] + q[3];

    enum logic {INIT, DOING} state, state_nxt;
    always_ff @(posedge clk) begin
        if (~resetn) begin
            state <= INIT;
        end else begin
            state <= state_nxt;
        end
    end
    always_comb begin
        state_nxt = state;
        if (state == DOING) begin
            state_nxt = INIT;
        end else if (valid) begin
            state_nxt = DOING;
        end
    end
    assign done = state_nxt == INIT;
endmodule

`endif
