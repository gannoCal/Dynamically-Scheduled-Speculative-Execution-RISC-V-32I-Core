module mem_ctl(
//input
execute_stage_opcode_latch_i,
imm_i,
rd_i,
flush,
clk,
reset,
a_i,
b_i,
waw_id_i,
ROB_FULL,
//output
result,
data_sram_en,
data_sram_sel,
data_sram_we,
data_sram_data,
data_sram_addr,
hazard_addr_mem,
hazard_det_mem,
wb_addr,
pull,

//CDB
CDB,
CDB_REG_ID,
CDB_FU_ID,
CDB_ISS_ID,
CDB_REQ,
CDB_ACK
);

//Parameters
parameter LB = 7'd11;
parameter LH = 7'd12;
parameter LW = 7'd13;
parameter LBU = 7'd14;
parameter LHU = 7'd15;
parameter SB = 7'd16;
parameter SH = 7'd17;
parameter SW = 7'd18;

parameter FENCE = 7'd38;
parameter ECALL = 7'd39;
parameter EBREAK = 7'd40;


parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;

//ports



input ROB_FULL;
input   [4:0]rd_i;
input   [31:0]imm_i;
input  [6:0]execute_stage_opcode_latch_i;

input flush;
input clk;
input reset;

input  [31:0] a_i;
input  [31:0] b_i;

input [7:0] waw_id_i;

//latch inputs in case mem write follows read
reg write_after_read_hazard;
reg write_after_read_hazard_p01;


reg   [4:0]rd;
reg   [31:0]imm;
reg  [6:0]execute_stage_opcode_latch;
reg  [31:0] a;
reg  [31:0] b;
reg [7:0] waw_id;

reg   [4:0]rd_s01;
reg   [31:0]imm_s01;
reg  [6:0]execute_stage_opcode_latch_s01;
reg  [31:0] a_s01;
reg  [31:0] b_s01;
reg [7:0] waw_id_i_s01;

reg stall_i_s01;
reg stall_i;

always @(posedge clk) if(!stall_i) rd_s01                            <= rd_i;
always @(posedge clk) if(!stall_i) imm_s01                           <= imm_i;
always @(posedge clk) if(!stall_i) execute_stage_opcode_latch_s01    <= execute_stage_opcode_latch_i;
always @(posedge clk) if(!stall_i) a_s01                             <= a_i;
always @(posedge clk) if(!stall_i) b_s01                             <= b_i;
always @(posedge clk) if(!stall_i) waw_id_i_s01                      <= waw_id_i;

always @(*) rd                          = write_after_read_hazard /*| stall_i_s01*/ ? rd_s01                              : rd_i;
always @(*) imm                         = write_after_read_hazard /*| stall_i_s01*/ ? imm_s01                             : imm_i;
always @(*) execute_stage_opcode_latch  = write_after_read_hazard /*| stall_i_s01*/ ? execute_stage_opcode_latch_s01      : execute_stage_opcode_latch_i;
always @(*) a                           = write_after_read_hazard /*| stall_i_s01*/ ? a_s01                               : a_i;
always @(*) b                           = write_after_read_hazard /*| stall_i_s01*/ ? b_s01                               : b_i;
always @(*) waw_id                      = write_after_read_hazard /*| stall_i_s01*/ ? waw_id_i_s01                        : waw_id_i;



output [ADDR_WIDTH-1:0] data_sram_en;
output data_sram_sel;
output data_sram_we;	
output [DATA_WIDTH-1:0] data_sram_data;
output [ADDR_WIDTH-1:0]data_sram_addr;

output reg	[31:0] 		hazard_addr_mem; // 32, 32-bit regs
output reg	 		hazard_det_mem;

output reg	[31:0] 		result;

output pull;

output [63:0]CDB;
output [4:0]CDB_REG_ID; 
output [3:0]CDB_FU_ID; 
output [31:0]CDB_ISS_ID;
output CDB_REQ;
input CDB_ACK;

reg   [ADDR_WIDTH-1:0]		data_sram_addr_i;
reg 	[DATA_WIDTH-1:0]	data_sram_data_i;
reg 				data_sram_we_i;
reg 				data_sram_sel_i;
reg 				data_sram_en_i;	

assign		data_sram_addr = !reset ? 	data_sram_addr_i 	: 'h0;
assign		data_sram_data = !reset ? 
                                data_sram_we_i ? 
                                            data_sram_data_i : 'hz  
                                            : 'h0;
assign		data_sram_we   = !reset ? 	data_sram_we_i 		: 'h0;
assign		data_sram_sel  = !reset ? 	data_sram_sel_i 	: 'h0;
assign		data_sram_en   = !reset ? 	data_sram_en_i 		: 'h0;


//writeback stage control registers
reg  [6:0]prev_execute_stage_opcode_latch_s01;
reg  [6:0]prev_execute_stage_opcode_latch_s02;
always @(posedge clk) if(!stall_i) prev_execute_stage_opcode_latch_s01 <= execute_stage_opcode_latch;
always @(posedge clk) if(!stall_i) prev_execute_stage_opcode_latch_s02 <= prev_execute_stage_opcode_latch_s01;

output reg [31:0] wb_addr;
reg [31:0] wb_addr_i;
//artificial delay
always @(posedge clk) if(!stall_i) wb_addr <= hazard_addr_mem;

parameter STAGES=2;
reg [STAGES-1:0] active_stages;
reg new_instruction;
always @(*) begin
	new_instruction = 0;
	case(execute_stage_opcode_latch)				
		//load
		LB, 
		LH, 
		LW,		
		LBU,	
		LHU : begin 
		 new_instruction = 1;
		end
		
		//Store
		SB,
		SH, 
		SW : begin
		 new_instruction = 1;
		end
		
	endcase
end

always @(posedge clk)  begin
	if(reset) begin
		active_stages <= 'h0;
	end else if(!stall_i) begin
		active_stages <= {1'b0,active_stages[STAGES-1:1]};
		if(new_instruction && !write_after_read_hazard_p01) begin
			active_stages[STAGES-1] <= 1;
		end	
	end
end

//detect previous instruction types
reg read_instr;
reg write_instr;
reg read_instr_s01;
reg write_instr_s01;
reg read_instr_s02;
reg write_instr_s02;
always @(*) begin
    read_instr = 0;
    write_instr = 0;
    case(execute_stage_opcode_latch)	
	//load
	LB, 
	LH, 
	LW,		
	LBU,	
	LHU : begin 
	    read_instr = 1;
	end
	
	//Store
	SB, 
	SH,
	SW : begin 
	    write_instr = 1;
	end
	
    endcase

    read_instr_s01 = 0;
    write_instr_s01 = 0;
    case(prev_execute_stage_opcode_latch_s01)	
	//load
	LB, 
	LH, 
	LW,		
	LBU,	
	LHU : begin 
	    read_instr_s01 = 1;
	end
	
	//Store
	SB,
	SH,
	SW : begin 
	    write_instr_s01 = 1;
	end
	
    endcase
    
    read_instr_s02 = 0;
    write_instr_s02 = 0;
    case(prev_execute_stage_opcode_latch_s02)	
	//load
	LB, 
	LH, 
	LW,		
	LBU,	
	LHU : begin 
	    read_instr_s02 = 1;
	end
	
	//Store
	SB,
	SH,
	SW : begin 
	    write_instr_s02 = 1;
	end
	
    endcase
end

always @(*) write_after_read_hazard = (write_instr_s01 && read_instr_s02);
always @(*) write_after_read_hazard_p01 = (write_instr && read_instr_s01);

reg CDB_REQ_s01;
always @(posedge clk) CDB_REQ_s01 <= reset ? 'h0 :CDB_REQ;
always @(*) stall_i = (CDB_REQ_s01 && ~CDB_ACK);

reg [7:0]waw_id_s01;
reg [7:0]waw_id_s02;

always @(posedge clk) if(!stall_i) waw_id_s01 <= waw_id;
always @(posedge clk) if(!stall_i) waw_id_s02 <= waw_id_s01;

assign CDB = CDB_ACK ? result : 'hz;
assign CDB_REQ = active_stages[1] | stall_i;
assign pull = !stall_i && !write_after_read_hazard; // 2 stage fully pipelined, can always pull an instruction unless stalled
assign CDB_REG_ID = CDB_ACK ? wb_addr : 'hz;
assign CDB_FU_ID = CDB_ACK ? 1 : 'hz;
assign CDB_ISS_ID = CDB_ACK ? waw_id_s02 : 'hz;




//Execute (ALU) + Register Writeback
	always @(posedge clk) if(!stall_i) begin
		//Execute (ALU)
		hazard_addr_mem 		<= -1;
		hazard_det_mem 	<= 0;
		
		case(execute_stage_opcode_latch)						
			LB : begin	hazard_addr_mem <= rd; hazard_det_mem <= 1; end	
			LH : begin hazard_addr_mem <= rd; hazard_det_mem <= 1; 	end	
			LW : begin hazard_addr_mem <= rd; hazard_det_mem <= 1; 	end	
			LBU : begin hazard_addr_mem <= rd; hazard_det_mem <= 1; end	
			LHU : begin hazard_addr_mem <= rd; hazard_det_mem <= 1; end	
			
			
			
			FENCE : begin end
			ECALL : begin end
			EBREAK : begin end
		endcase
		

	end


reg[31:0] result_mux;
reg[31:0] result_s01;
always @(posedge clk) stall_i_s01 <= stall_i;
always @(posedge clk) result_s01 <= result;
always @(*) result = stall_i_s01 ? result_s01 : result_mux;
always @(*) begin
//Register Writeback
    result_mux = -1;
	case(prev_execute_stage_opcode_latch_s02)
		//writeback from memory
		LB : begin  result_mux = {{32{data_sram_data[7]}},data_sram_data[7:0]}; end	
		LH : begin  result_mux = {{32{data_sram_data[15]}},data_sram_data[15:0]}; 	end	
		LW : begin  result_mux = data_sram_data; 	end	
		LBU : begin result_mux = {{32'b0},data_sram_data[7:0]}; end	
		LHU : begin result_mux = {{32'b0},data_sram_data[15:0]}; end	
	endcase
end

//Memory Access

//need to latch sel and we on read requests - i.e. can't have sequential read/write (we expect this to be managed at the issue level - Need to implimeent)
// or we can detect this here, as block the "pull" signal
reg read_request;
	always @(posedge clk)  begin
		if(reset) begin
			data_sram_en_i 		<= 'h0;
			data_sram_sel_i 	<= 'h0;
			data_sram_we_i 		<= 'h0;
			data_sram_data_i 	<= 'h0;
			data_sram_addr_i 	<= 'h0;
		end else if(!stall_i) begin
                        if(read_request) begin
                            data_sram_en_i 		<= data_sram_en_i;
			    data_sram_sel_i 	        <= data_sram_sel_i;
			    data_sram_we_i 		<= data_sram_we_i;
                        end else begin
			    data_sram_en_i 		<= 'h0;
			    data_sram_sel_i 	        <= 'h0;
			    data_sram_we_i 		<= 'h0; 
                        end
			data_sram_data_i 	<= 'h0;
			data_sram_addr_i 	<= 'h0;
                        read_request            <= 0;
			case(execute_stage_opcode_latch)
					
				//load
				LB, 
				LH, 
				LW,		
				LBU,	
				LHU : begin 
					data_sram_en_i 		<= 'h1;
					data_sram_sel_i 		<= 'h1;
					data_sram_we_i 		<= 'h0;
					data_sram_data_i 		<= 'h0;
					data_sram_addr_i  	<= a + $signed(imm); 
                                        read_request            <= 1;
				end
				
				//Store
				SB : if(!read_request) begin 
					data_sram_en_i 	<= 'h1;
					data_sram_sel_i 	<= 'h1;
					data_sram_we_i 	<= 'h1;
					data_sram_data_i 	<= b[7:0];
					data_sram_addr_i  <= a + $signed(imm); 
				end
				SH : if(!read_request) begin 
					data_sram_en_i 	<= 'h1;
					data_sram_sel_i 	<= 'h1;
					data_sram_we_i 	<= 'h1;
					data_sram_data_i 	<= b[15:0];
					data_sram_addr_i  <= a + $signed(imm); 
				end
				SW : if(!read_request) begin 
					data_sram_en_i 	<= 'h1;
					data_sram_sel_i 	<= 'h1;
					data_sram_we_i 	<= 'h1;
					data_sram_data_i 	<= b;
					data_sram_addr_i  <= a + $signed(imm); 
				end
				
				FENCE : begin end
				ECALL : begin end
				EBREAK : begin end
			endcase
		end
	end

endmodule
