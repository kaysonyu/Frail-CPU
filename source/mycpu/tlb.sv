`ifndef __TLB_SV
`define __TLB_SV

`include "common.svh"

module tlb (
    input logic clk,
    input logic resetn,

    //i_search
    input logic [18:0] i_vpn2,
    input logic i_odd_page,
    input logic [7:0] i_asid,

    output tlb_search_t i_search_result;

    //d_search
    input logic [18:0] d_vpn2,
    input logic d_odd_page,
    input logic [7:0] d_asid,

    output tlb_search_t d_search_result;

    //read
    input tlb_index_t r_index,
    output tlb_entry_t r_entry,

    //write
    input logic we,
    input tlb_index_t w_index,
    input tlb_entry_t w_entry
);

    tlb_entry_t tlb_ram [`TLB_NUM-1:0];

    //inst_search
    logic [`TLB_NUM-1:0] i_search_match;
    tlb_entry_t i_choose_entry;
    tlb_index_t i_choose_index;

    for (genvar i = 0; i < `TLB_NUM; i++) begin
        assign i_search_match[i] = (i_vpn2==tlb_ram[i].vpn2) & (i_asid==tlb_ram[i].asid | tlb_ram[i].g);
    end
    assign i_search_result.found = |i_search_match;
    always_comb begin
        i_choose_index = 0;
        for (int i = 0; i < `TLB_NUM; i++) begin
            i_choose_index |= i_search_match[i] ? tlb_index_t'(i) : 0;
        end
    end
    assign i_search_result.index = i_choose_index;
    
    assign i_choose_entry = tlb_ram[i_choose_index];

    assign i_search_result.pfn = i_odd_page ? i_choose_entry.pfn1 : i_choose_entry.pfn0;
    assign i_search_result.c = i_odd_page ? i_choose_entry.c1 : i_choose_entry.c0;
    assign i_search_result.d = i_odd_page ? i_choose_entry.d1 : i_choose_entry.d0;
    assign i_search_result.v = i_odd_page ? i_choose_entry.v1 : i_choose_entry.v0;

    //data_search
    logic [`TLB_NUM-1:0] d_search_match;
    tlb_entry_t d_choose_entry;
    tlb_index_t d_choose_index;

    for (genvar i = 0; i < `TLB_NUM; i++) begin
        assign d_search_match[i] = (d_vpn2==tlb_ram[i].vpn2) & (d_asid==tlb_ram[i].asid | tlb_ram[i].g);
    end
    assign d_search_result.found = |d_search_match;
    always_comb begin
        d_choose_index = 0;
        for (int i = 0; i < `TLB_NUM; i++) begin
            d_choose_index |= d_search_match[i] ? tlb_index_t'(i) : 0;
        end
    end
    assign d_search_result.index = d_choose_index;
    
    assign d_choose_entry = tlb_ram[d_choose_index];

    assign d_search_result.pfn = d_odd_page ? d_choose_entry.pfn1 : d_choose_entry.pfn0;
    assign d_search_result.c = d_odd_page ? d_choose_entry.c1 : d_choose_entry.c0;
    assign d_search_result.d = d_odd_page ? d_choose_entry.d1 : d_choose_entry.d0;
    assign d_search_result.v = d_odd_page ? d_choose_entry.v1 : d_choose_entry.v0;

    //write && read
    always_ff @(posedge clk) begin
        if(resetn) begin
            if(we) begin
                tlb_ram[w_index] <= w_entry;
            end      
        end 
        else begin
            tlb_ram <= '0;
        end
    end
    assign r_entry = tlb_ram[r_index];



endmodule

`endif
