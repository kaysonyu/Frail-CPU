`ifndef MYCORE_SV
`define MYCORE_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`include "regs/pipereg.sv"
`include "regs/pipereg2.sv"
`include "regs/hilo.sv"
`include "regs/regfile.sv"
`include "fetch/pcselect.sv"
`include "decode/decode.sv"
`include "issue/issue.sv"
`include "execute/execute.sv"
`include "memory/memory.sv"
`include "memory/memory2.sv"
`include "bypass.sv"
`include "hazard.sv"
`include "pvtrans.sv"
`endif 

module MyCore (
    input logic clk, resetn,
    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq[1:0],
    input  dbus_resp_t dresp[1:0],
    input logic[5:0] ext_int
);
    /**
     * TODO (Lab1) your code here :)
     */
    
    // dbus_req_t dreq[1:0],dresp[1:0];
    // assign dresp[0]=dresp1;
    // assign dresp[1]='0;
    // assign dreq1=dreq[0];
    u1 stallF,stallD,flushD,flushE,flushM,stallM,stallE,flushW,stallM2,flushF2,flushI,flush_que,stallF2,flushM2,stallI,overflowI,stallI_de;
    u1 is_eret;
    u1 i_wait,d_wait,e_wait,d_wait2;
    u1 is_INTEXC;
    word_t epc;
    
    typedef logic [31:0] paddr_t;
    typedef logic [31:0] vaddr_t;
    paddr_t paddr; // physical address
    vaddr_t vaddr; // virtual address
    
    pvtrans pvtransi(
        .paddr,
        .vaddr
    );

        u1 req1_finish,req2_finish;
        always_ff @(posedge clk) begin
        if (dreq[1].valid&&dresp[1].addr_ok) begin
            req1_finish<='1;
        end else if (req1_finish&&dreq[0].valid) begin
            req1_finish<='1;
        end else begin
            req1_finish<='0;
        end
    end

    always_ff @(posedge clk) begin
        if (dreq[0].valid&&dresp[0].addr_ok) begin
            req2_finish<='1;
        end else begin
            req2_finish<='0;
        end
    end

    assign i_wait=ireq.valid && ~iresp.addr_ok;
    u1 get_read[1:0];
    assign get_read[1]=dresp[1].addr_ok;
    assign get_read[0]=dresp[0].addr_ok;
    assign d_wait= (dreq[1].valid&& ~dresp[1].addr_ok)||(dreq[0].valid&& ~dresp[0].addr_ok);
    // assign d_wait=(dreq[1].valid && ((|dreq[1].strobe && ~dresp[1].addr_ok) || (~(|dreq[1].strobe) && ~get_read[1] )))
    // ||(dreq[0].valid && ((|dreq[0].strobe && ~dresp[0].addr_ok) || (~(|dreq[0].strobe) && ~get_read[0] ))) ;//写请求
    assign d_wait2=(dreq[1].valid && ( (~(|dreq[1].strobe) && ~get_read[1] && dreq[1].addr[15]==0)))||(dreq[0].valid && ( (~(|dreq[0].strobe) && ~get_read[0] && dreq[0].addr[15]==0))) ;
    // assign flushM2 = d_wait;
    // u1 flushM2_hazard;

    hazard hazard(
		.stallF,.stallD,.flushD,.flushE,.flushM,.flushI,.flush_que,.i_wait,.d_wait,.stallM,.stallM2,.stallE,.branchE(dataE[1].branch_taken),.e_wait,.clk,.flushW,.excpW(is_eret||is_INTEXC),.branch_misalign,.stallF2,.flushF2,.stallI,.flushM2,.overflowI,.stallI_de
	);

    assign vaddr=dataP_pc;
    assign ireq.addr=paddr;
	assign ireq.valid=pc_except ? '0:1'b1;
    assign reset=~resetn;

    fetch_data_t dataF2_nxt [1:0],dataF2 [1:0];
    decode_data_t dataD_nxt [1:0],dataD [1:0];
    issue_data_t dataI_nxt[1:0],dataI[1:0];
    execute_data_t dataE_nxt[1:0],dataE[1:0];
    execute_data_t dataM1_nxt[1:0],dataM1[1:0];
    memory_data_t dataM2_nxt[1:0],dataM2[1:0];
    // creg_addr_t ra1I[1:0],ra2I[1:0];

    writeback_data_t dataW[1:0];
	// u32 raw_instr;
    u1 branch_misalign;
    u1 reset;
    u1 pc_except;
    word_t pc_selected,pc_succ,dataP_pc;
    assign pc_except=dataP_pc[1:0]!=2'b00;

    always_comb begin
        pc_succ=dataP_pc+8;
        if (branch_misalign) begin
            pc_succ=dataD_nxt[0].pc;
        end else if (dataP_pc[2]==1) begin
            pc_succ=dataP_pc+4;
        end
    end
    // assign pc_succ=dataP_pc[2]==1?dataP_pc+4:dataP_pc+8;

    //跳转且i_wait时保存跳转pc，
    word_t jpc_save,ipc_save,pc_nxt,bpc_save;
    u1 jpc_saved,ipc_saved,bpc_saved;
    //填入保存信号时确认没有正常进入的替换信号
    always_ff @(posedge clk) begin
		if ((stallF)&&is_INTEXC) begin
			ipc_save<=pc_selected;
			ipc_saved<='1;
        end else if (stallF && dataE[1].branch_taken) begin
            jpc_save<=pc_selected;
            jpc_saved<='1;
        end else if (stallF&& branch_misalign) begin
            bpc_save<=pc_selected;
            bpc_saved<='1;
        end else if (~stallF) begin
			ipc_save<='0;
			ipc_saved<='0;
            jpc_save<='0;
			jpc_saved<='0;
            bpc_save<='0;
			bpc_saved<='0;
		end
	end

    always_comb begin
        if (ipc_saved) begin
            pc_nxt=ipc_save;
        end else if (jpc_saved) begin
            pc_nxt=jpc_save;
        end else if (bpc_saved&&~dataE[1].branch_taken) begin
            pc_nxt=bpc_save;
        end else begin
            pc_nxt=pc_selected;
        end
    end
    //can be perf
    

    pcselect pcselect_inst (
        .pc_selected,
        .pc_succ,
        .pc_branch(dataE[1].target),
        .branch_taken(dataE[1].branch_taken),
        .epc,
        .entrance(32'hBFC0_0380),
		.is_eret,
		.is_INTEXC,
        .branch_misalign,
        .misaligned_pc(dataD_nxt[0].pc)
    );
    //pipereg between pcselect and fetch1
    fetch1_data_t dataF1_nxt,dataF1;
    assign dataF1_nxt.valid='1;
    assign dataF1_nxt.pc=dataP_pc;
    u1 dataF1_pc;
    always_ff @( posedge clk ) begin
		if (reset) begin
			dataP_pc<=32'hbfc0_0000;//
		end  else if(~stallF) begin
			dataP_pc<=pc_nxt;
		end
	end
    word_t pc_f1;

    pipereg #(.T(fetch1_data_t))F1F2reg(
        .clk,
        .reset,
        .in(dataF1_nxt),
        .out(dataF1),
        .en(~stallF2),
        .flush(flushF2)
    );
    u1 rawinstr_saved;
    u64 raw_instrf2_save;
    u1 delay_flushF2;

    always_ff @(posedge clk) begin
        delay_flushF2 <=flushF2;
        if (stallF2&&~rawinstr_saved) begin
            raw_instrf2_save<=iresp.data;
            rawinstr_saved<='1;
        end else if (~stallF2) begin
            {raw_instrf2_save,rawinstr_saved}<='0;
        end
    end
    //前半部分静止，应当不发起ireq
    always_comb begin
        dataF2_nxt[1].raw_instr= dataF1.pc[2]==1? iresp.data[63:32]:iresp.data[31:0];
        if (rawinstr_saved) begin
            dataF2_nxt[1].raw_instr=dataF1.pc[2]==1? raw_instrf2_save[63:32]:raw_instrf2_save[31:0];
        end else if (delay_flushF2) begin
            dataF2_nxt[1].raw_instr='0;
        end
    end
    always_comb begin
        dataF2_nxt[0].raw_instr=  iresp.data[63:32];
        if (rawinstr_saved) begin
            dataF2_nxt[0].raw_instr=raw_instrf2_save[63:32];
        end else if (delay_flushF2) begin
            dataF2_nxt[0].raw_instr='0;
        end
    end
    assign dataF2_nxt[1].pc=dataF1.pc;
    // assign dataF2_nxt[1].raw_instr=rawinstr_saved? raw_instrf2_save[31:0]:iresp.data[31:0];
    assign dataF2_nxt[1].valid= dataF1.valid;
    assign dataF2_nxt[1].cp0_ctl.valid=pc_except;
    assign dataF2_nxt[1].cp0_ctl.ctype=EXCEPTION;
    assign dataF2_nxt[1].cp0_ctl.etype.badVaddrF='1;
    assign dataF2_nxt[0].pc= dataF1.pc[2]==1? '0: dataF1.pc+4;
    // assign dataF2_nxt[0].raw_instr=rawinstr_saved? raw_instrf2_save[63:32]:iresp.data[63:32];
    assign dataF2_nxt[0].valid=/*~pc_except&&*/~(dataF1.pc[2]==1)&&dataF1.valid;


    pipereg2 #(.T(fetch_data_t))F2Dreg(
        .clk,
        .reset,
        .in(dataF2_nxt),
        .out(dataF2),
        .en(~stallD),
        .flush(flushD)
    );

    decode decode_inst(
        .dataF2(dataF2),
        .dataD(dataD_nxt),
        .branch_misalign
        // .rd1,.rd2,
        // .ra1,.ra2
    );

    pipereg2 #(.T(decode_data_t))DIreg(
        .clk,
        .reset,
        .in(dataD_nxt),
        .out(dataD),
        .en(~stallI),
        .flush(flushI)
    );
    word_t rd1[1:0],rd2[1:0];
    // creg_addr_t ra1[1:0],ra2[1:0];

    regfile regfile_inst(
        .clk,.reset,
        .ra1({issue_bypass_out[1].ra1,issue_bypass_out[0].ra1}),.ra2({issue_bypass_out[1].ra2,issue_bypass_out[0].ra2}),
        .wa({dataW[1].wa,dataW[0].wa}),
        .wvalid({dataW[1].ctl.regwrite,dataW[0].ctl.regwrite}),
        .wd({dataW[1].wd,dataW[0].wd}),
        .rd1({rd1[1],rd1[0]}),
        .rd2({rd2[1],rd2[0]})
    );

    // decode_data_t readed_dataD[1:0];
    // always_comb begin
    //     readed_dataD=dataD;
    //     for (int i=0; i<2; ++i) begin
    //     readed_dataD[i].rd1=rd1[i];
    //     readed_dataD[i].rd2=rd2[i];
    //     end
    // end

    bypass_input_t dataE_in[1:0],dataM1_in[1:0],dataM2_in[1:0];
    bypass_output_t bypass_outra1 [1:0],bypass_outra2 [1:0];

    issue issue_inst(
        .clk,
        .dataD,
        .rd1,.rd2,
        .dataI(dataI_nxt),
        .issue_bypass_out,
        .bypass_inra1(bypass_outra1),
        .bypass_inra2(bypass_outra2),
        .flush_que,
        .stallI,
        .overflow(overflowI),
        .stallI_de
    );

    bypass_issue_t dataI_in[1:0],issue_bypass_out[1:0];
    assign dataI_in=issue_bypass_out;
    bypass_execute_t dataEnxt_in[1:0];

    bypass bypass_inst(
        .dataE_in,
        .dataM1_in,
        .dataM2_in,
        .dataI_in,
        .dataEnxt_in,
        // .rdstE,
        // .ra1I,.ra2I,
        // .cp0ra,.lo,.hi
        .outra1(bypass_outra1),
        .outra2(bypass_outra2)
    );

    for (genvar i=0; i<2 ;++i) begin
        assign dataE_in[i].data=dataE[i].alu_out;
        assign dataE_in[i].rdst=dataE[i].rdst;
        assign dataE_in[i].memtoreg=dataE[i].ctl.memtoreg;
        assign dataE_in[i].lotoreg=dataE[i].ctl.lotoreg;
        assign dataE_in[i].hitoreg=dataE[i].ctl.hitoreg;
        assign dataE_in[i].cp0toreg=dataE[i].ctl.cp0toreg;
        assign dataE_in[i].regwrite=dataE[i].ctl.regwrite;

        assign dataM1_in[i].data=dataM1[i].alu_out;
        assign dataM1_in[i].rdst=dataM1[i].rdst;
        assign dataM1_in[i].memtoreg=dataM1[i].ctl.memtoreg;
        assign dataM1_in[i].lotoreg=dataM1[i].ctl.lotoreg;
        assign dataM1_in[i].hitoreg=dataM1[i].ctl.hitoreg;
        assign dataM1_in[i].cp0toreg=dataM1[i].ctl.cp0toreg;
        assign dataM1_in[i].regwrite=dataM1[i].ctl.regwrite;

        assign dataM2_in[i].data=dataW[i].wd;
        assign dataM2_in[i].rdst=dataM2[i].rdst;
        assign dataM2_in[i].memtoreg=dataM2[i].ctl.memtoreg;
        assign dataM2_in[i].lotoreg=dataM2[i].ctl.lotoreg;
        assign dataM2_in[i].hitoreg=dataM2[i].ctl.hitoreg;
        assign dataM2_in[i].cp0toreg=dataM2[i].ctl.cp0toreg;
        assign dataM2_in[i].regwrite=dataM2[i].ctl.regwrite;

        assign dataEnxt_in[i].rdst=dataI[i].rdst;
        assign dataEnxt_in[i].lowrite=dataI[i].ctl.lowrite;
        assign dataEnxt_in[i].hiwrite=dataI[i].ctl.hiwrite;
        assign dataEnxt_in[i].cp0write=dataI[i].ctl.cp0write;
        assign dataEnxt_in[i].cp0ra=dataI[i].cp0ra;
        assign dataEnxt_in[i].regwrite=dataI[i].ctl.regwrite;
    end

    pipereg2 #(.T(issue_data_t))IXreg(
        .clk,
        .reset,
        .in(dataI_nxt),
        .out(dataI),
        .en(~stallE),
        .flush(flushE)
    );

    execute execute_inst(
        .clk,.resetn,
        .dataI,
        .dataE(dataE_nxt),
        .e_wait
    );

    pipereg2 #(.T(execute_data_t))XM1reg(
        .clk,
        .reset,
        .in(dataE_nxt),
        .out(dataE),
        .en(~stallM),
        .flush(flushM)
    );

    memory memory(
		.dataE(dataE),
		.dataE2(dataM1_nxt),
		.dreq,
        .req_finish({req1_finish,req2_finish})
		// .exception(is_eret||is_INTEXC)
	);

    u1 inter_valid;

    // assign is_eret=(dataM2.cp0_ctl.ctype==RET);
	assign inter_valid=~i_wait;

	pipereg2 #(.T(execute_data_t)) M1M2reg(
		.clk,.reset,
		.in(dataM1_nxt),
		.out(dataM1),
		.en(~stallM2),
		.flush(flushM2)
	);
	
	memory2 memory2(
        .clk,
		.dataE(dataM1),
		.dataM(dataM2_nxt),
		.dresp,
        .dreq
	);

	pipereg2 #(.T(memory_data_t)) M2Wreg(
		.clk,.reset,
		.in(dataM2_nxt),
		.out(dataM2),
		.en(1),
		.flush(flushW)
	);

    // cp0_regs_t regs_out ;

    writeback writeback(
        // .clk,.reset,
        .dataM(dataM2),
        .dataW,
        .lo_rd,.hi_rd,.cp0_rd
        // .valid_i,.valid_j,.valid_k
    );

    // u1 hi_write,lo_write;

    u1 valid_j,valid_k;
    word_t hi_data,lo_data;
    //同时对hilo进行读是允许的
    always_comb begin
        {hi_data,lo_data}='0;
        {valid_j,valid_k}='0;
        for (int i=1; i>=0; --i) begin
            if (dataM2[i].ctl.hiwrite) begin
                hi_data=dataM2[i].ctl.op==MTHI? dataM2[i].srca:dataM2[i].hilo[63:32];
                valid_j=i[0];
            end 
            if (dataM2[i].ctl.lowrite) begin
                lo_data=dataM2[i].ctl.op==MTLO? dataM2[i].srca:dataM2[i].hilo[31:0];
                valid_k=i[0];
            end
        end
    end
    word_t hi_rd,lo_rd;
    hilo hilo(
    .clk,
    .hi(hi_rd), .lo(lo_rd),
    .hi_write(dataM2[1].ctl.hiwrite||dataM2[0].ctl.hiwrite), .lo_write(dataM2[1].ctl.lowrite||dataM2[0].ctl.lowrite),
    .hi_data , .lo_data
    );
    
    u1 valid_i;
    assign valid_i= dataM2[1].cp0_ctl.valid? '1:'0;
    assign is_eret=dataM2[valid_i].cp0_ctl.ctype==ERET;
    word_t cp0_rd;
    cp0 cp0(
        .clk,.reset,
        .ra(dataM2[1].cp0ra),//直接读写的指令一次发射一条
        .wa(dataM2[1].cp0ra),
        .wd(dataM2[1].srcb),
        .rd(cp0_rd),
        .epc,
        .valid(dataM2[1].cp0_ctl.valid? dataM2[1].cp0_ctl.valid:dataM2[1].cp0_ctl.valid||dataM2[0].cp0_ctl.valid),
        .is_eret,
        // .regs_out,
        .ctype(dataM2[valid_i].cp0_ctl.ctype),
        .pc(dataM2[valid_i].pc),
        .etype(dataM2[valid_i].cp0_ctl.etype),
        .ext_int,
        .is_slot(dataM2[valid_i].is_slot),
        .is_INTEXC,
        .inter_valid
    );

endmodule

`endif