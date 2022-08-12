// `ifndef __ICACHE_SV
// `define __ICACHE_SV

// `include "common.svh"
// `include "cache_pkg.svh"
// `include "cp0_pkg.svh"
// `ifdef VERILATOR

// `endif 
// module icache (
//     input logic clk, resetn,

//     input  dbus_req_t  dreq_1,
//     input  dbus_req_t  dreq_2,
//     output dbus_resp_t dresp,
//     output cbus_req_t  dcreq,
//     input  cbus_resp_t dcresp,

//     input icache_inst_t cache_inst,
//     input cp0_taglo_t tag_lo
// );

//     localparam type state_t = enum logic[2:0] {
//         IDLE, UNCACHE_1, UNCACHE_2
//     };

//     state_t state;

//     logic en;
//     logic data_ok_reg;

//     word_t data_1, data_2;

//     assign en = dreq_2.valid ? (state==UNCACHE_2 & dcresp.last)
//                 : dreq_1.valid ? (state==UNCACHE_1 & dcresp.last)
//                 : 1'b1;
    
//     //FSM
//     always_ff @(posedge clk) begin
//         if (resetn) begin
//             unique case (state)
//                 IDLE: begin
//                     if (dreq_1.valid) begin
//                         state <= UNCACHE_1;
//                     end
//                 end

//                 UNCACHE_1: begin
//                     state  <= dcresp.last ? IDLE : UNCACHE_1; 
//                 end

//                 UNCACHE_2: begin
//                     state  <= dcresp.last ? IDLE : UNCACHE_2;
//                 end

//                 default: begin   
//                 end
//             endcase  
//         end
//         else begin
//             state <= IDLE;
//         end
//     end

//     always_ff @(posedge clk) begin
//         if (resetn) begin
//             if (state==UNCACHE_1 & dcresp.last) begin
//                 data_1 <= dcresp.data;
//             end
//             if (state==UNCACHE_2 & dcresp.last) begin
//                 data_2 <= dcresp.data;
//             end   
//         end
//         else begin
//             data_1 <= '0;
//             data_2 <= '0;
//         end
//     end

//     always_ff @(posedge clk) begin
//         if (resetn) begin
//             data_ok_reg <= en;
//         end
//         else begin
//             data_ok_reg <= '0;
//         end
//     end

//     //dbus
//     assign dresp.addr_ok = en;
//     assign dresp.data_ok = data_ok_reg;
//     assign dresp.data = {data_2, data_1};

//     //CBus
//     assign dcreq.valid = state==UNCACHE_1 | state==UNCACHE_2;     
//     assign dcreq.is_write = state==UNCACHE_1 ? |dreq_1.strobe : |dreq_2.strobe;  
//     assign dcreq.size = state==UNCACHE_1 ? dreq_1.size : dreq_2.size;      
//     assign dcreq.addr = state==UNCACHE_1 ? dreq_1.addr : dreq_2.addr;      
//     assign dcreq.strobe = state==UNCACHE_1 ? dreq_1.strobe : dreq_2.strobe;        
//     assign dcreq.data = state==UNCACHE_1 ? dreq_1.data : dreq_2.data;             
//     assign dcreq.len = MLEN1;  

// endmodule

// `endif