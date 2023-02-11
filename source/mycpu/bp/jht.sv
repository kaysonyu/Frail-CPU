`ifndef __JHT_SV
`define __JHT_SV

`include "common.svh"
`include "test.svh"
`ifdef VERILATOR
`include "../plru.sv"
`endif 

module jht#(
    parameter int ASSOCIATIVITY = 4,
    parameter int SET_NUM = 8,

    localparam INDEX_BITS = $clog2(SET_NUM),
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY),
    localparam TAG_BITS = 18,
    localparam type tag_t = logic [TAG_BITS-1:0],
    localparam type index_t = logic [INDEX_BITS-1:0],
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0],
    localparam type plru_t = logic [ASSOCIATIVITY-2:0],
    localparam type meta_t = struct packed {
        logic valid;
        logic is_jal;
        tag_t tag;
    },
    localparam type ram_addr_t = struct packed {
        index_t index;
        associativity_t line;
    }
) (
    input logic clk, resetn,
    input logic is_write, is_jal, // if this instr write in to jht (j, jal)
    input addr_t j_pc, executed_j_pc, dest_pc,
    /*
    * j_pc is the pc of the jump to be predicted(from f1)
    * executed_j_pc is the pc of the jump to be executed(from exe)
    * dest_pc is the branch dest of the executed_branch
    */
    output addr_t predict_pc,
    output logic hit, hit_jal
);

    function tag_t get_tag(addr_t addr);
        return addr[2+TAG_BITS-1:2];
    endfunction

    function index_t get_index(addr_t addr);
        
        return addr[2+INDEX_BITS-1+3:2+3];

    endfunction

    meta_t [ASSOCIATIVITY-1:0] r_meta_hit;
    meta_t [ASSOCIATIVITY-1:0] r_meta_in_jht;
    meta_t [ASSOCIATIVITY-1:0] w_meta;
    addr_t r_pc_predict, r_pc_replace, w_pc_replace;
    associativity_t hit_line, replace_line;
    ram_addr_t predict_addr, replace_addr;
    logic in_jht;

    // for predict

    always_comb begin
        hit = 1'b0;
        hit_line = '0;
        hit_jal = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && (r_meta_hit[i].tag == get_tag(j_pc))) begin
                hit  = 1'b1;
                hit_jal = r_meta_hit[i].is_jal;
                hit_line = associativity_t'(i);
            end
        end 
    end

    assign predict_addr.index = get_index(j_pc);
    assign predict_addr.line = hit_line;

    assign predict_pc = hit ? r_pc_predict : '0;


    // for repalce

    always_comb begin
        in_jht = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_in_jht[i].valid && r_meta_in_jht[i].tag == get_tag(executed_j_pc)) begin
                in_jht = 1'b1;
            end
        end 
    end

    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_old, plru_new;

    assign plru_old = hit ? plru_ram[get_index(j_pc)] : plru_ram[get_index(executed_j_pc)];

    assign replace_line[1] = plru_old[2];
    assign replace_line[0] = plru_old[2] ? plru_old[0] : plru_old[1];

    always_comb begin
        plru_new = plru_old;
        
        if(hit) begin
            plru_new[2] = ~hit_line[1];

            if (hit_line[1]) begin
                plru_new[0] = ~hit_line[0];
            end 
            else begin
                plru_new[1] = ~hit_line[0];
            end
        end else if (~in_jht && is_write) begin
            plru_new[2] = ~replace_line[1];

            if (replace_line[1]) begin
                plru_new[0] = ~replace_line[0];
            end 
            else begin
                plru_new[1] = ~replace_line[0];
            end
        end

    end

    always_ff @(posedge clk) begin
        if (hit) begin
            plru_ram[get_index(j_pc)] <= plru_new;
        end else if (~in_jht && is_write) begin
            plru_ram[get_index(executed_j_pc)] <= plru_new;
        end
    end

    assign replace_addr.line = replace_line;
    assign replace_addr.index = get_index(executed_j_pc);

    assign w_pc_replace = (~in_jht && is_write) ? dest_pc : r_pc_replace;

    always_comb begin : w_meta_b
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (~in_jht && is_write && associativity_t'(i) == replace_line) begin
                w_meta[i].valid = 1'b1;
                w_meta[i].is_jal = is_jal;
                w_meta[i].tag = get_tag(executed_j_pc);
            end else begin
                w_meta[i] = r_meta_in_jht[i];
            end
        end 
    end

    ram_addr_t reset_addr;

    always_ff @( posedge clk ) begin : reset
        reset_addr <= reset_addr + 1;
    end



    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk),

        .en_1(1'b1), //port1 for replace
        .addr_1(resetn ? replace_addr.index : reset_addr.index),
        .rdata_1(r_meta_in_jht),
        .strobe(1'b1),  
        .wdata(resetn ? w_meta : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(get_index(j_pc)),
        .rdata_2(r_meta_hit)
    );

    LUTRAM_DualPort #(
        .ADDR_WIDTH($bits(ram_addr_t)),
        .DATA_WIDTH($bits(addr_t)),
        .BYTE_WIDTH($bits(addr_t)),
        .READ_LATENCY(0)
    ) dest_pc_ram(
        .clk(clk),

        .en_1(in_jht | is_write | ~resetn), //port1 for replace
        .addr_1(resetn ? replace_addr : reset_addr),
        .rdata_1(r_pc_replace),
        .strobe(1'b1),  
        .wdata(resetn ? w_pc_replace : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(predict_addr),
        .rdata_2(r_pc_predict)
    );

endmodule


`endif 