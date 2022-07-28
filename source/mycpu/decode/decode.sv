`ifndef __DECODE_SV
`define __DECODE_SV
`ifdef VERILATOR
`include "common.svh"
`include "decoder.sv"
`else

`endif

module decode(
    input fetch_data_t dataF2 [1:0],
    output decode_data_t dataD [1:0]
    // input word_t rd1[1:0],
    // input word_t rd2[1:0],
    // output creg_addr_t ra1[1:0],ra2[1:0]
);
    // decode_data_t dataD0;
    // assign {dataD0.valid,dataD0.raw_instr,dataD0.cp0ra,dataD0.pc,dataD0.imm,dataD0.is_slot,dataD0.rd1,dataD0.rd2,dataD0.cp0_ctl}='0;
    u1 jump1,jump2;

    decoder decoder_inst1(
        .valid(dataF2[1].valid),
        .instr(dataF2[1].raw_instr),
        .cp0_ctl_old(dataF2[1].cp0_ctl),
        .cp0_ctl(dataD[1].cp0_ctl),
        .ctl(dataD[1].ctl),
        .srcrega(dataD[1].ra1), 
        .srcregb(dataD[1].ra2), 
        .destreg(dataD[1].rdst),
        .jump(jump1)
    );
    //如果0是跳转，需要把这条的valid置0，其余随意。
    decoder decoder_inst2(
        .valid(dataF2[0].valid),
        .instr(dataF2[0].raw_instr),
        .ctl(dataD[0].ctl),
        .cp0_ctl_old(dataF2[0].cp0_ctl),
        .cp0_ctl(dataD[0].cp0_ctl),
        .srcrega(dataD[0].ra1), 
        .srcregb(dataD[0].ra2), 
        .destreg(dataD[0].rdst),
        .jump(jump2)
    );


    // always_comb begin
    //     dataD[0]='0;
    //     if (~dataD0.ctl.jump&&~dataD0.ctl.branch) begin
    //         dataD[0]=dataD0;
    //         dataD[0].raw_instr=dataF2[0].raw_instr;
    //         dataD[0].valid=dataF2[0].valid;
    //         dataD[0].pc=dataF2[0].pc;
    //     end 
    // end
    // assign dataD[0].is_slot=jump1;
    for (genvar i=0; i<2; ++i) begin
        // assign dataD[i].rd1=rd1[i];
        // assign dataD[i].rd2=rd2[i];
        assign dataD[i].imm=dataF2[i].raw_instr[15:0];
        assign dataD[i].raw_instr=dataF2[i].raw_instr;
        assign dataD[i].pc=dataF2[i].pc;
        assign dataD[i].cp0ra={dataF2[i].raw_instr[15:11],dataF2[i].raw_instr[2:0]};
        // assign dataD[i].ra1=ra1[i];
        // assign dataD[i].ra2=ra2[i];
    end
    assign dataD[1].valid=dataF2[1].valid;
    assign dataD[0].valid=dataF2[0].valid;


    
endmodule

`endif