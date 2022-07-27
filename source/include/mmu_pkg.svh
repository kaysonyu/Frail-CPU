`ifndef __MMU_PKG
`define __MMU_PKG

`ifdef VERILATOR
`include "common.svh"
`endif

typedef struct packed {
    logic [18:0] vpn2;
    logic odd_page;
    logic [11:0] page_offset;    
} vaddr_t;

typedef struct packed {
    logic [19:0] pfn;
    logic [11:0] page_offset;    
} paddr_t;

 `define TLB_NUM 16
 `define TLB_INDEX_BIT $clog2(`TLB_NUM)
typedef logic [`TLB_INDEX_BIT-1:0] tlb_index_t;

typedef struct packed {
    logic [18:0] vpn2;
    logic [7:0] asid;
    logic G;
    logic [19:0] pfn0;
    logic [2:0] C0;
    logic D0;
    logic V0;
    logic [19:0] pfn1;
    logic [2:0] C1;
    logic D1;
    logic V1;   
} tlb_entry_t;

typedef tlb_entry_t [`TLB_NUM-1:0] tlb_t;

typedef struct packed {
    logic found;
    tlb_index_t index;
    paddr_t paddr;
    logic [2:0] C;
    logic D;
    logic V;
} tlb_search_t;


typedef struct packed {
	logic is_tlbwi;
    logic is_tlbwr;

	cp0_entryhi_t entryhi;
    cp0_entrylo_t entrylo0;
	cp0_entrylo_t entrylo1;
	cp0_index_t index;
    cp0_random_t random;
} mmu_req_t;
    
typedef struct packed {
	cp0_entryhi_t entryhi;
    cp0_entrylo_t entrylo0;
	cp0_entrylo_t entrylo1;
	cp0_index_t index;
} mmu_resp_t;

typedef struct packed {
    logic refill;
	logic invalid; 
	logic modified; 
} tlb_exc_t;

typedef struct packed {
    tlb_exc_t i_tlb_exc;
    tlb_exc_t d_tlb_exc [1:0];
} mmu_exc_out_t;



`endif
