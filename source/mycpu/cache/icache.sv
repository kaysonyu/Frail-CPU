`ifndef __ICACHE_SV
`define __ICACHE_SV

`include "common.svh"
`include "cache_pkg.svh"
`include "cp0_pkg.svh"
`ifdef VERILATOR

`endif 
module icache (
    input logic clk, resetn,

    input  ibus_req_t  ireq_1,
    input  ibus_req_t  ireq_2,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp,

    input icache_inst_t cache_inst,
    input cp0_taglo_t tag_lo
);

    localparam type state_t = enum logic[2:0] {
        IDLE, UNCACHE_1, UNCACHE_2
    };

    state_t state;

    logic en;
    logic data_ok_reg;

    word_t data_1, data_2;

    assign en = state==UNCACHE_2 & icresp.last;
    
    //FSM
    always_ff @(posedge clk) begin
        if (resetn) begin
            unique case (state)
                IDLE: begin
                    if (ireq_1.valid) begin
                        state <= UNCACHE_1;
                    end
                end

                UNCACHE_1: begin
                    state  <= icresp.last ? UNCACHE_2 : UNCACHE_1; 
                end

                UNCACHE_2: begin
                    state  <= icresp.last ? IDLE : UNCACHE_2;
                end

                default: begin   
                end
            endcase  
        end
        else begin
            state <= IDLE;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (state==UNCACHE_1 & icresp.last) begin
                data_1 <= icresp.data;
            end
            if (state==UNCACHE_2 & icresp.last) begin
                data_2 <= icresp.data;
            end   
        end
        else begin
            data_1 <= '0;
            data_2 <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= en;
        end
        else begin
            data_ok_reg <= '0;
        end
    end

    //ibus
    assign iresp.addr_ok = en;
    assign iresp.data_ok = data_ok_reg;
    assign iresp.data = {data_2, data_1};

    //CBus
    assign icreq.valid = state==UNCACHE_1 | state==UNCACHE_2;     
    assign icreq.is_write = 0;  
    assign icreq.size = MSIZE4;      
    assign icreq.addr = state==UNCACHE_1 ? ireq_1.addr : ireq_2.addr;      
    assign icreq.strobe = 0;   
    assign icreq.data = 0;      
    assign icreq.len = MLEN1;  

endmodule

`endif