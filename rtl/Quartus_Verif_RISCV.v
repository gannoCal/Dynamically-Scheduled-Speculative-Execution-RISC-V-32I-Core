module Quartus_Verif_RISCV(
	reset,
	clk,
	PC_init,
	sram_addr,
	sram_data,
	sram_we,
	sram_sel,
	sram_en

);
	

	//Parameters
	parameter LUI = 7'd1;
	parameter AUIPC = 7'd2;
	parameter JAL = 7'd3;
	parameter JALR = 7'd4;
	parameter BEQ = 7'd5;
	parameter BNE = 7'd6;
	parameter BLT = 7'd7;
	parameter BGE = 7'd8;
	parameter BLTU = 7'd9;
	parameter BGEU = 7'd10;
	parameter LB = 7'd11;
	parameter LH = 7'd12;
	parameter LW = 7'd13;
	parameter LBU = 7'd14;
	parameter LHU = 7'd15;
	parameter SB = 7'd16;
	parameter SH = 7'd17;
	parameter SW = 7'd18;
	parameter ADDI = 7'd19;
	parameter SLTI = 7'd20;
	parameter SLTIU = 7'd21;
	parameter XORI = 7'd22;
	parameter ORI = 7'd23;
	parameter ANDI = 7'd24;
	parameter SLLI = 7'd25;
	parameter SRLI = 7'd26;
	parameter SRAI = 7'd27;
	parameter ADD = 7'd28;
	parameter SUB = 7'd29;
	parameter SLL = 7'd30;
	parameter SLT = 7'd31;
	parameter SLTU = 7'd32;
	parameter XOR = 7'd33;
	parameter SRL = 7'd34;
	parameter SRA = 7'd35;
	parameter OR = 7'd36;
	parameter AND = 7'd37;
	parameter FENCE = 7'd38;
	parameter ECALL = 7'd39;
	parameter EBREAK = 7'd40;

	parameter SIMPLE_EXEC = 0;
	parameter MEM = 1;


	parameter ADDR_WIDTH = 15; //32k ram
	parameter DATA_WIDTH = 32;
	localparam DEPTH 		= 2**ADDR_WIDTH;
	
	//ports
		//control
	input 	wire reset;
	input 	wire clk;
	input  [ADDR_WIDTH-1:0] PC_init;
		//sram
	inout 	wire [ADDR_WIDTH-1:0]sram_addr;
	inout 	wire 	[DATA_WIDTH-1:0]sram_data;
	inout 	wire sram_we;
	inout 	wire sram_sel;
	inout 	wire sram_en;

	
	
	
	//Registers
	reg			[31:0] 		regmap_val; 
	wire	[31:0] 				hazard_addr_mem;
	 
	wire	 						hazard_det_mem; 
	wire [63:0]		 		instruction;
	
	
	
	
	
	
	
	//SRAM	
	
	wire   [ADDR_WIDTH-1:0]		data_sram_addr;
	wire 	[DATA_WIDTH-1:0]	data_sram_data;
	wire 				data_sram_we;
	wire 				data_sram_sel;
	wire 				data_sram_en;
	
	//sram flags
	wire				sram_instr_fetch_mode;
	
	//attach srams
	single_port_sync_sram sram(
		.clk(clk),
		.addr(sram_addr),
		.data(sram_data),
		.sel(sram_sel),
		.we(sram_we),
		.en(sram_en)
	);
	
	single_port_sync_sram data_sram(
		.clk(clk),
		.addr(data_sram_addr),
		.data(data_sram_data),
		.sel(data_sram_sel),
		.we(data_sram_we),
		.en(data_sram_en)
	);

	
		
	//Decode registers
	wire [6:0]issue_stage_opcode_latch;	
	reg [6:0]execute_stage_opcode_latch_s01;
	reg [6:0]writeback_stage_opcode_latch;	
	wire   [4:0]decode_exit_rd;
	wire   [4:0]decode_exit_rs1;
	wire   [4:0]decode_exit_rs2;
	wire   [31:0]decode_exit_imm; 
	wire   [4:0] decode_exit_fm;
	wire   [2:0] decode_exit_pred;
	wire   [3:0] decode_exit_succ;
	reg [31:0] wb_out;
 	reg [31:0] wb_addr;
	

	always @(posedge clk)  execute_stage_opcode_latch_s01 <= issue_stage_opcode_latch; //*
	always @(posedge clk)  writeback_stage_opcode_latch <= execute_stage_opcode_latch_s01;
	
	///////
	// Logical Units
	///////

	
	//CDB
	wire [63:0]CDB;
	wire [4:0]CDB_REG_ID; 
        wire [3:0]CDB_FU_ID; 
	wire [31:0]CDB_ISS_ID;
	wire CDB_REQ_MEM;
	wire CDB_REQ_SE;
	reg CDB_ACK_MEM;
	reg CDB_ACK_SE;

    	wire flush;
	wire stall_d;
	wire stall_i;
	wire [ADDR_WIDTH-1:0] decode_stage_opcode_addr;
	wire [ADDR_WIDTH-1:0] issue_stage_opcode_addr;
	wire [ADDR_WIDTH:0]   branch_addr;
	wire		[1023:0]regmap 	;
	wire branch_taken;
	wire resume_issue;
        wire no_branch;

        wire prediction_success;
        wire prediction_failed;

	wire [ADDR_WIDTH-1:0] execute_stage_opcode_addr_SE_next;
	
	fetch Fetch (
		//inputs
		.clk(clk),
		.reset(reset),
		.sram_data(sram_data),	
		.branch_addr(branch_addr),
		.PC_init(PC_init),
		.flush(flush),
                .no_branch(no_branch),
                .branch_pc(execute_stage_opcode_addr_SE_next),
		//outputs
		.instruction(instruction),
		.sram_addr(sram_addr),
		.sram_we(sram_we),
		.sram_sel(sram_sel),
		.sram_en(sram_en),
		.decode_stage_opcode_addr(decode_stage_opcode_addr),
		.stall(stall_i),
		.branch_taken(branch_taken),
		.resume_issue(resume_issue),
                .prediction_success(prediction_success),
                .prediction_failed(prediction_failed)
	);

	wire [31:0] a;
	wire [31:0] b;

	wire CDB_ACTIVE;
	assign CDB_ACTIVE = CDB_ACK_MEM || CDB_ACK_SE;

	wire 	[1023:0] retired_regmap	;

	decode Decode (
		//inputs
		.clk(clk),
		.reset(reset),
		.decode_stage_opcode_addr(decode_stage_opcode_addr),
		.hazard_det_mem(hazard_det_mem),
		.hazard_addr_mem(hazard_addr_mem),
		.instruction(instruction),
		.wb_addr(CDB_REG_ID),
		.wb_out(CDB),
		.wb_en(CDB_ACTIVE),
		.stall_i(stall_i),
		.retired_regmap_i(retired_regmap),
		.prediction_failed(prediction_failed),
		//outputs
		.a(a),
		.b(b),
		.flush(flush),
		.branch_addr(branch_addr),
		.issue_stage_opcode_latch(issue_stage_opcode_latch),
		.issue_stage_opcode_addr_latch(issue_stage_opcode_addr),
		.rd_latch(decode_exit_rd),
		.rs1_latch(decode_exit_rs1),
		.rs2_latch(decode_exit_rs2),
		.imm_latch(decode_exit_imm),
		 .fm_latch(decode_exit_fm),
		 .pred_latch(decode_exit_pred),
		 .succ_latch(decode_exit_succ),	
		.regmap_o(regmap),
		.stall(stall_d)
	);

	
	//issue regs
	wire [6:0]execute_stage_opcode_latch;
	wire [3:0] RS_SEL;	
	wire op1v;
	wire [63:0] op1;
	wire op2v;
	wire [63:0] op2;
	wire [4:0] dest;
	wire [31:0] imm;
	wire [31:0] res_id;
	wire [ADDR_WIDTH-1:0] execute_stage_opcode_addr;
	wire push_en;
	wire [4:0] push_reg;
	wire SE_RS_FULL;
	wire MEM_RS_FULL;
	wire push_branch_unresolved;
        reg RS_FULL;
        wire ROB_FULL;
        always @(*) RS_FULL = SE_RS_FULL | MEM_RS_FULL;
        reg CDB_HAZARD;


        wire push_store;
        wire [63:0]push_store_addr;
        wire [63:0]push_store_data;
        wire push_store_data_tag;
        wire push_store_addr_tag;
        wire [11:0]push_store_imm;
	
	issue Issue (
		//input
		.clk(clk),
		.reset(reset),
		.decoded_opcode(issue_stage_opcode_latch),
		.src1(a),
		.src2(b),
		.src1_id(decode_exit_rs1),
		.src2_id(decode_exit_rs2),
		.dest(decode_exit_rd),
		.imm(decode_exit_imm),
		.issue_stage_opcode_addr(issue_stage_opcode_addr),
		.flush(flush),
		.prediction_success(prediction_success),
                .prediction_failed(prediction_failed),
		.resume_issue(resume_issue),
                .RS_FULL(RS_FULL),
                .ROB_FULL(ROB_FULL),
		
		//CDB input
		.CDB(CDB),
		.CDB_REG_ID(CDB_REG_ID),
		.CDB_FU_ID(CDB_FU_ID),
		.CDB_ISS_ID(CDB_ISS_ID),
		.wb_en(CDB_ACTIVE),


		//output
		.RS_SEL(RS_SEL),

		//slot output
		.decoded_opcode_o(execute_stage_opcode_latch), .op1v_o(op1v), .op1_o(op1), .op2v_o(op2v), .op2_o(op2), .dest_o(dest), .imm_o(imm), .res_id_o(res_id), .execute_stage_opcode_addr_o(execute_stage_opcode_addr),

		.stall(stall_i),

		.push_en(push_en),
		.push_reg(push_reg),
		.push_branch_unresolved(push_branch_unresolved),

                .push_store(push_store),
                .push_store_addr(push_store_addr),
                .push_store_data(push_store_data),
                .push_store_data_tag(push_store_data_tag),
                .push_store_addr_tag(push_store_addr_tag),
                .push_store_imm(push_store_imm)
	);


	
	//push to exec RS logic
	reg push_SE_RS;
	wire pull_SE_RS;
	reg bypass_SE_RS;
	wire SE_RS_RDY;
        reg[3:0] case_det;
	
	wire SE_RS_EMPTY;
	always @(*) begin
		push_SE_RS = 0;
		bypass_SE_RS = 0;
                case_det = 0;
		if(RS_SEL == SIMPLE_EXEC) begin
                    case_det = 1;
			if(!op1v || !op2v || !pull_SE_RS || !SE_RS_EMPTY) begin
				if(!prediction_failed) push_SE_RS = 1;
                                case_det = 2;
			end else begin
				bypass_SE_RS = 1;
                                case_det = 3;
			end
		end
	end
	
	//CDB access control
        //TODO: use combinational logic to send an ACK as soon as a REQ is made if the CDB is not active
        //thinking either a new signal CDB_ACK_BYPASS, or a mux that uses the ACK register value vs combinational logic
        // always @(*) CDB_ACK_MEM = CDB_REQ_MEM && !CDB_ACTIVE ? 1 : CDB_ACK_MEM_r;
        //the above solution may cause combinational loops in the exec units, if their CDB_REQ is combinationally dependant on the value of CDB_ACK
	always @(posedge clk) begin
		CDB_ACK_MEM <= 0;
		CDB_ACK_SE <= 0;
                CDB_HAZARD <= 0;
		case({CDB_REQ_MEM, CDB_REQ_SE})
			2'b11 : begin 
                                    CDB_HAZARD <= 1;
                                    
									case({CDB_ACK_MEM, CDB_ACK_SE})
										2'b10 : CDB_ACK_SE <= 1;
										2'b01 : CDB_ACK_MEM <= 1;
										2'b00 : CDB_ACK_SE <= 1;
									endcase
                                end
			2'b10 : CDB_ACK_MEM <= 1;
			2'b01 : CDB_ACK_SE <= 1;
		default : ;
		endcase
	end

	

	//RS regs
	wire [6:0]decoded_opcode_SE_next;	
	wire [63:0] op1_SE_next;
	wire [63:0] op2_SE_next;
	wire [4:0] dest_SE_next;
	wire [31:0] imm_SE_next;
	wire [31:0] res_id_SE_next;
	
	reservation_station Simple_exec_RS(
		//input
		.clk(clk),
		.reset(reset),
		.push(push_SE_RS),
		.pull(pull_SE_RS),
		.bypass(bypass_SE_RS),
		//slot input
		.decoded_opcode(execute_stage_opcode_latch), .op1v(op1v), .op1(op1), .op2v(op2v), .op2(op2), .dest(dest), .imm(imm), .res_id(res_id), .execute_stage_opcode_addr(execute_stage_opcode_addr),
                .prediction_failed(prediction_failed),
                .prediction_success(prediction_success),
		.push_branch_unresolved(push_branch_unresolved),

                .pull_non_load('h0),

		//CDB input
		.CDB(CDB),
		.CDB_REG_ID(CDB_REG_ID),
		.CDB_FU_ID(CDB_FU_ID),
		.CDB_ISS_ID(CDB_ISS_ID),


		//output
		//slot output
		.decoded_opcode_o(decoded_opcode_SE_next), .op1_o(op1_SE_next), .op2_o(op2_SE_next), .dest_o(dest_SE_next), .imm_o(imm_SE_next), .res_id_o(res_id_SE_next), .execute_stage_opcode_addr_o(execute_stage_opcode_addr_SE_next),

		.rdy(SE_RS_RDY),
		.rs_full(SE_RS_FULL),
		.rs_empty(SE_RS_EMPTY)
	);

	wire [31:0] result_exec;
	wire [31:0] wb_addr_exec;

	simple_exec Simple_exec(
	//input
		.reset(reset),
		.execute_stage_opcode_latch(decoded_opcode_SE_next),
		.execute_stage_opcode_addr(execute_stage_opcode_addr_SE_next),
		.imm(imm_SE_next),
		.execute_stage_rd(dest_SE_next),
		.a(op1_SE_next),
		.b(op2_SE_next),	
		.flush(flush),
		.clk(clk),
                .ROB_FULL(ROB_FULL),
                .waw_id(res_id_SE_next),
	//output
		.wb_addr(wb_addr_exec),
		.result(result_exec),
		.idle(pull_SE_RS),
		.CDB(CDB),
		.CDB_REG_ID(CDB_REG_ID),
		.CDB_FU_ID(CDB_FU_ID),
		.CDB_ISS_ID(CDB_ISS_ID),
		.CDB_REQ(CDB_REQ_SE),
		.CDB_ACK(CDB_ACK_SE),
		.branch_addr(branch_addr),
                .no_branch(no_branch)
	);
	
	wire [31:0] result_mem;
	wire [31:0] wb_addr_mem;

	//push to exec RS logic
	reg push_MEM_RS;
	wire pull_MEM_RS;
	reg bypass_MEM_RS;
	wire MEM_RS_RDY;
	
	wire MEM_RS_EMPTY;
	always @(*) begin
		push_MEM_RS = 0;
		bypass_MEM_RS = 0;
		if(RS_SEL == MEM) begin
			if(!op1v || !op2v || !pull_MEM_RS || !MEM_RS_EMPTY) begin
				if(!prediction_failed) push_MEM_RS = 1;
			end else begin
				bypass_MEM_RS = 1;
			end
		end
	end
	//RS regs
	wire [6:0]decoded_opcode_MEM_next;	
	wire [63:0] op1_MEM_next;
	wire [63:0] op2_MEM_next;
	wire [4:0] dest_MEM_next;
	wire [31:0] imm_MEM_next;
	wire [31:0] res_id_MEM_next;
	wire [ADDR_WIDTH-1:0] execute_stage_opcode_addr_MEM_next;
        wire pull_non_load_MEM;

	reservation_station Mem_ctl_RS(
		//input
		.clk(clk),
		.reset(reset),
		.push(push_MEM_RS),
		.pull(pull_MEM_RS),
		.bypass(bypass_MEM_RS),
		//slot input
		.decoded_opcode(execute_stage_opcode_latch), .op1v(op1v), .op1(op1), .op2v(op2v), .op2(op2), .dest(dest), .imm(imm), .res_id(res_id), .execute_stage_opcode_addr(execute_stage_opcode_addr),
                .prediction_failed(prediction_failed),
                .prediction_success(prediction_success),
		.push_branch_unresolved(push_branch_unresolved),

                .pull_non_load(pull_non_load_MEM),

		//CDB input
		.CDB(CDB),
		.CDB_REG_ID(CDB_REG_ID),
		.CDB_FU_ID(CDB_FU_ID),
		.CDB_ISS_ID(CDB_ISS_ID),


		//output
		//slot output
		.decoded_opcode_o(decoded_opcode_MEM_next), .op1_o(op1_MEM_next), .op2_o(op2_MEM_next), .dest_o(dest_MEM_next),.imm_o(imm_MEM_next), .res_id_o(res_id_MEM_next),.execute_stage_opcode_addr_o(execute_stage_opcode_addr_MEM_next),

		.rdy(MEM_RS_RDY),
		.rs_full(MEM_RS_FULL),
		.rs_empty(MEM_RS_EMPTY)
	);
        

        //LOAD instructions sit here while a store is pending
        wire [ADDR_WIDTH-1:0] computed_addr;
        wire search_store_buffer;
        wire store_buffer_match;
        wire [6:0]decoded_opcode_MEM_next_load_queue_o;	
        wire [63:0] op1_MEM_next_load_queue_o;
        wire [63:0] op2_MEM_next_load_queue_o;
        wire [4:0] dest_MEM_next_load_queue_o;
        wire [31:0] imm_MEM_next_load_queue_o;
        wire [31:0] res_id_MEM_next_load_queue_o;
        wire [ADDR_WIDTH-1:0] execute_stage_opcode_addr_MEM_next_load_queue_o;
        wire pull_MEM_RS_raw;
         
        load_buffer LBUFF(
            //input
            .clk(clk),
            .reset(reset),
            .store_buffer_match(store_buffer_match),
            .pull_MEM_RS_raw(pull_MEM_RS_raw),
            .decoded_opcode_MEM_next(decoded_opcode_MEM_next),	
            .op1_MEM_next(op1_MEM_next),
            .op2_MEM_next(op2_MEM_next),
            .dest_MEM_next(dest_MEM_next),
            .imm_MEM_next(imm_MEM_next),
            .res_id_MEM_next(res_id_MEM_next),
            .execute_stage_opcode_addr_MEM_next(execute_stage_opcode_addr_MEM_next),
            .speculative(push_branch_unresolved),
            .prediction_success(prediction_success),
            .prediction_failed(prediction_failed),
            //output
            .computed_addr(computed_addr),
            .search_store_buffer(search_store_buffer),
            .decoded_opcode_MEM_next_load_queue_o(decoded_opcode_MEM_next_load_queue_o),
            .op1_MEM_next_load_queue_o(op1_MEM_next_load_queue_o),
            .op2_MEM_next_load_queue_o(op2_MEM_next_load_queue_o),
            .dest_MEM_next_load_queue_o(dest_MEM_next_load_queue_o),
            .imm_MEM_next_load_queue_o(imm_MEM_next_load_queue_o),
            .res_id_MEM_next_load_queue_o(res_id_MEM_next_load_queue_o),
            .execute_stage_opcode_addr_MEM_next_load_queue_o(execute_stage_opcode_addr_MEM_next_load_queue_o), 
            .pull_non_load_MEM(pull_non_load_MEM),
            .pull_MEM_RS(pull_MEM_RS)
        ); 
        

	mem_ctl Mem_ctl(
	//input
		.execute_stage_opcode_latch_i(decoded_opcode_MEM_next_load_queue_o),//*
		.imm_i(imm_MEM_next_load_queue_o),
		.rd_i(dest_MEM_next_load_queue_o),
		.flush(flush),
		.clk(clk),
		.reset(reset),
		.a_i(op1_MEM_next_load_queue_o),
		.b_i(op2_MEM_next_load_queue_o),
                .ROB_FULL(ROB_FULL),
                .waw_id_i(res_id_MEM_next_load_queue_o),
	//output
		.data_sram_en(data_sram_en),
		.data_sram_sel(data_sram_sel),
		.data_sram_we(data_sram_we),
		.data_sram_data(data_sram_data),
		.data_sram_addr(data_sram_addr),
		.hazard_addr_mem(hazard_addr_mem),
		.hazard_det_mem(hazard_det_mem),
		.wb_addr(wb_addr_mem),
		.result(result_mem),
		.CDB(CDB),
		.CDB_REG_ID(CDB_REG_ID),
		.CDB_FU_ID(CDB_FU_ID),
		.CDB_ISS_ID(CDB_ISS_ID),
		.CDB_REQ(CDB_REQ_MEM),
		.CDB_ACK(CDB_ACK_MEM),
		.pull(pull_MEM_RS_raw)
	);

        wire [ADDR_WIDTH-1:0] store_addr_active;
        wire [DATA_WIDTH-1:0] store_data_active;

        assign store_addr_active = (data_sram_we && data_sram_sel && data_sram_en) ? data_sram_addr : -1;
        assign store_data_active = (data_sram_we && data_sram_sel && data_sram_en) ? data_sram_data : -1;

        wire SBUFF_FULL;
        //TODO: need to wire this up to stall the issue stage
        store_buffer SBUFF(
              //input
              .clk(clk),
              .reset(reset),
            
              .store_addr_i(push_store_addr),
              .store_data_i(push_store_data),
              .store_speculative_i(push_branch_unresolved),
              .store_addr_tag_i(push_store_addr_tag),
              .store_data_tag_i(push_store_data_tag),
              .store_imm_i(push_store_imm),
              .push(push_store),

                .search_store_buffer(search_store_buffer),
                .computed_addr(computed_addr),

                //CDB input
		.CDB(CDB),
		.CDB_REG_ID(CDB_REG_ID),
		.CDB_FU_ID(CDB_FU_ID),
		.CDB_ISS_ID(CDB_ISS_ID),
            
              .store_addr_active(store_addr_active),
              .store_data_active(store_data_active),
              .prediction_success(prediction_success),
              .prediction_failed(prediction_failed),
              //output
              .SBUFF_FULL(SBUFF_FULL),
              .store_buffer_match(store_buffer_match)
            );

	commit Commit(
		//input
		.clk(clk),
		.reset(reset),
		.push_en(push_en),
		.push_reg(push_reg),
                .push_iss_id(res_id),
		.push_branch_unresolved(push_branch_unresolved),
                .CDB_ISS_ID(CDB_ISS_ID),
		.CDB_REG_ID(CDB_REG_ID),
		.CDB_EN(CDB_ACTIVE),
		.regmap_i(regmap),
		.prediction_success(prediction_success),
                .prediction_failed(prediction_failed),
                //output
		.retired_regmap_o(retired_regmap),
                .FULL(ROB_FULL)

	);	

	
		
	
	 
	 /*initial begin
      if ($test$plusargs("trace") != 0) begin
         $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
         $dumpfile("logs/vlt_dump.vcd");
         $dumpvars();
        

         
         

      end
      $display("[%0t] Model running...\n", $time);
   end*/

	
	
endmodule
