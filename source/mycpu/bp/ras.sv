`ifndef __RAS_SV
`define __RAS_SV

`include "common.svh"

module ras #(
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
        tag_t tag;
    },
    localparam type ram_addr_t = struct packed {
        index_t index;
        associativity_t line;
    },

    parameter int RAS_SIZE = 16,

    localparam RAS_ADDR_BITS = $clog2(RAS_SIZE),
    localparam type ras_addr_t = logic [RAS_ADDR_BITS-1:0]
) (
    input logic clk, resetn,
    // push means jal in exe
    // pop means jrra in exe
    input logic push, pop, bk_push, bk_pop, flush,
    // f1_pc is the pc from f1
    // ret_pc_push is jal_pc + 8 from exe
    // jrra_pc is the pc of jrra from exe
    input addr_t f1_pc, ret_pc_push, bk_ret_pc_push, jrra_pc,
    output addr_t ret_pc_top,
    // when hit && (~fail), the ret_pc_top is valid
    output u1 fail, hit
);

    function tag_t get_tag(addr_t addr);
        return addr[2+TAG_BITS-1:2];
    endfunction

    function index_t get_index(addr_t addr);
        return addr[2+INDEX_BITS-1+3:2+3];
    endfunction


    ras_addr_t top, top_nxt, ras_addr;// top == '0 when stack_num == 1 or stack_num == 0
    ras_addr_t bk_top, bk_top_nxt, bk_ras_addr;
    logic empty, empty_nxt, overflow, overflow_nxt, full;
    logic bk_empty, bk_empty_nxt , bk_overflow, bk_overflow_nxt, bk_full;
    logic fuck_high, fuck_high_nxt, fuck_low, fuck_low_nxt;// hope you won't see fuck == 1
    logic [RAS_SIZE-1:0] overflow_counter;
    logic [RAS_SIZE-1:0] overflow_counter_nxt;
    logic [RAS_SIZE-1:0] bk_overflow_counter;
    logic [RAS_SIZE-1:0] bk_overflow_counter_nxt;
    addr_t w_ret_pc, r_ret_pc;
    addr_t bk_w_ret_pc, bk_r_ret_pc;

    logic in_ras;
    associativity_t replace_line, hit_line;
    meta_t [ASSOCIATIVITY-1:0] r_meta_hit;
    meta_t [ASSOCIATIVITY-1:0] r_meta_in_ras;
    meta_t [ASSOCIATIVITY-1:0] w_meta;

    // f1 stack for restoring ret_pc

    assign ret_pc_top = (empty | overflow) ? bk_r_ret_pc : r_ret_pc;
    assign fail = (empty | overflow) && (bk_empty | bk_overflow);

    assign full = &top;

    always_comb begin
        if(~flush) begin
            empty_nxt = empty;
            if(push) empty_nxt = 1'b0;
            else if(top == '0 && pop) empty_nxt = 1'b1;
        end else begin
            empty_nxt = 1'b1;
            // empty_nxt = bk_empty;
            // if(push) empty_nxt = 1'b0;
            // else if(bk_top == '0 && pop) empty_nxt = 1'b1;
        end

    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            empty <= 1'b1;
        end else begin
            empty <= empty_nxt;
        end
    end

    always_comb begin
        if(~flush) begin
            overflow_nxt = overflow;
            if(push && full) overflow_nxt = 1'b1;
            // overflow_counter == 1 and pop
            else if(~(|overflow_counter[RAS_SIZE-1:1]) && overflow_counter[0] && pop) overflow_nxt = 1'b0;
        end else begin
            overflow_nxt = 1'b0;
            // overflow_nxt = bk_overflow;
            // if(push && bk_full) overflow_nxt = 1'b1;
            // else if(~(|bk_overflow_counter[RAS_SIZE-1:1]) && bk_overflow_counter[0] && pop) overflow_nxt = 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            overflow <= 1'b0;
        end else begin
            overflow <= overflow_nxt;
        end
    end

    always_comb begin
        if(~flush) begin
            top_nxt = top;
            if(push && ~full && ~empty) begin // push && top is not '1 && stack is not empty (when stack_num == 0 or stack_num == 1 top = 0)
                top_nxt = top + 1;
            end else if(pop && (|top) && ~overflow) begin // pop && top is not '0
                top_nxt = top - 1;
            end
        end else begin
            top_nxt = '0;
            // top_nxt = bk_top;
            // if(push && ~bk_full && ~bk_empty) begin // push && top is not '1 && stack is not empty (when stack_num == 0 or stack_num == 1 top = 0)
            //     top_nxt = bk_top + 1;
            // end else if(pop && (|bk_top) && ~bk_overflow) begin // pop && top is not '0
            //     top_nxt = bk_top - 1;
            // end
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            top <= '0;
        end else begin
            top <= top_nxt;
        end
    end

    always_comb begin
        if(~flush) begin
            overflow_counter_nxt = overflow_counter;
            if(full && push) begin
                overflow_counter_nxt = overflow_counter + 1;
            end else if((|overflow_counter) && pop) begin
                overflow_counter_nxt = overflow_counter - 1;
            end
        end else begin
            overflow_counter_nxt = '0;
            // overflow_counter_nxt = bk_overflow_counter;
            // if(bk_full && push) begin
            //     overflow_counter_nxt = bk_overflow_counter + 1;
            // end else if((|bk_overflow_counter) && pop) begin
            //     overflow_counter_nxt = bk_overflow_counter - 1;
            // end
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            overflow_counter <= '0;
        end else begin
            overflow_counter <= overflow_counter_nxt;
        end
    end

    always_comb begin
        fuck_high_nxt = fuck_high;
        if((&overflow_counter) && push) begin
            fuck_high_nxt = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            fuck_high <= '0;
        end else begin
            fuck_high <= fuck_high_nxt;
        end
    end

    always_comb begin
        fuck_low_nxt = fuck_low;
        if(empty && pop) begin
            fuck_low_nxt = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            fuck_low <= '0;
        end else begin
            fuck_low <= fuck_low_nxt;
        end
    end

    assign ras_addr = push ? top_nxt : top;

    assign w_ret_pc = flush ? r_ret_pc
                            : ((push && ~full) ? ret_pc_push : r_ret_pc);

    // assign w_ret_pc = recover ? ((push && ~bk_full) ? ret_pc_push : r_ret_pc) 
                            //   : ((push && ~full) ? ret_pc_push : r_ret_pc);

    RAM_SinglePort #(
		.ADDR_WIDTH(RAS_ADDR_BITS),//8 cache sets
		.DATA_WIDTH(32),
		.BYTE_WIDTH(32),
		.READ_LATENCY(0)
    ) ret_pc_ram (
        .clk(clk), .en(1'b1),
        .addr(ras_addr),//get meta from cache set[index]
        .strobe(1'b1),
        .wdata(w_ret_pc),
        .rdata(r_ret_pc)
    );


    // bk stack


    assign bk_full = &bk_top;

    always_comb begin
        bk_empty_nxt = bk_empty;
        if(bk_push) bk_empty_nxt = 1'b0;
        else if(bk_top == '0 && bk_pop) bk_empty_nxt = 1'b1;

    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            bk_empty <= 1'b1;
        end else begin
            bk_empty <= bk_empty_nxt;
        end
    end

    always_comb begin
        bk_overflow_nxt = bk_overflow;
        if(bk_push && bk_full) bk_overflow_nxt = 1'b1;
        // bk_overflow_counter == 1 and bk_pop
        else if(~(|bk_overflow_counter[RAS_SIZE-1:1]) && bk_overflow_counter[0] && bk_pop) bk_overflow_nxt = 1'b0;
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            bk_overflow <= 1'b0;
        end else begin
            bk_overflow <= bk_overflow_nxt;
        end
    end

    always_comb begin
        bk_top_nxt = bk_top;
        if(bk_push && ~bk_full && ~bk_empty) begin // push && top is not '1 && stack is not empty (when stack_num == 0 or stack_num == 1 top = 0)
            bk_top_nxt = bk_top + 1;
        end else if(bk_pop && (|bk_top) && ~bk_overflow) begin // pop && top is not '0
            bk_top_nxt = bk_top - 1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            bk_top <= '0;
        end else begin
            bk_top <= bk_top_nxt;
        end
    end

    always_comb begin
        bk_overflow_counter_nxt = bk_overflow_counter;
        if(bk_full && bk_push) begin
            bk_overflow_counter_nxt = bk_overflow_counter + 1;
        end else if((|bk_overflow_counter) && bk_pop) begin
            bk_overflow_counter_nxt = bk_overflow_counter - 1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            bk_overflow_counter <= '0;
        end else begin
            bk_overflow_counter <= bk_overflow_counter_nxt;
        end
    end

    assign bk_ras_addr = bk_push ? bk_top_nxt : bk_top;

    assign bk_w_ret_pc = (bk_push && ~bk_full) ? bk_ret_pc_push : bk_r_ret_pc;

    RAM_SinglePort #(
		.ADDR_WIDTH(RAS_ADDR_BITS),//8 cache sets
		.DATA_WIDTH(32),
		.BYTE_WIDTH(32),
		.READ_LATENCY(0)
    ) bk_ret_pc_ram (
        .clk(clk), .en(1'b1),
        .addr(bk_ras_addr),//get meta from cache set[index]
        .strobe(1'b1),
        .wdata(bk_w_ret_pc),
        .rdata(bk_r_ret_pc)
    );

    // ram for noting jrra_pc

    // for predict

    always_comb begin
        hit = 1'b0;
        hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && (r_meta_hit[i].tag == get_tag(f1_pc))) begin
                hit  = 1'b1;
                hit_line = associativity_t'(i);
            end
        end 
    end

    // for repalce

    always_comb begin
        in_ras = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_in_ras[i].valid && r_meta_in_ras[i].tag == get_tag(jrra_pc)) begin
                in_ras = 1'b1;
            end
        end 
    end

    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_old, plru_new;

    assign plru_old = plru_ram[get_index(f1_pc)];

    assign replace_line[1] = plru_old[2];
    assign replace_line[0] = plru_old[2] ? plru_old[0] : plru_old[1];

    always_comb begin
        plru_new = plru_old;

        plru_new[2] = ~hit_line[1];

        if (hit_line[1]) begin
            plru_new[0] = ~hit_line[0];
        end 
        else begin
            plru_new[1] = ~hit_line[0];
        end

    end

    always_ff @(posedge clk) begin
        if (hit) begin
            plru_ram[get_index(f1_pc)] <= plru_new;
        end
    end

    always_comb begin : w_meta_b
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (~in_ras && bk_pop && associativity_t'(i) == replace_line) begin
                w_meta[i].valid = 1'b1;
                w_meta[i].tag = get_tag(jrra_pc);
            end else begin
                w_meta[i] = r_meta_in_ras[i];
            end
        end 
    end

    index_t reset_addr;

    always_ff @( posedge clk ) begin : reset
        reset_addr <= reset_addr + 1;
    end

    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) meta_ram (
        .clk(clk),

        .en_1(1'b1), //port1 for replace
        .addr_1(resetn ? get_index(jrra_pc) : reset_addr),
        .rdata_1(r_meta_in_ras),
        .strobe(1'b1),  
        .wdata(resetn ? w_meta : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(get_index(f1_pc)),
        .rdata_2(r_meta_hit)
    );

endmodule


`endif 