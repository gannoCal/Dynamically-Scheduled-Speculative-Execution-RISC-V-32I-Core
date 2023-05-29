module simple_exec(
//input
reset,
execute_stage_opcode_latch,
execute_stage_opcode_addr,
imm,
execute_stage_rd,
a,
b,
ROB_FULL,
waw_id,

clk,
//output
result,
wb_addr,
idle,
flush,

//CDB
CDB,
CDB_REG_ID,
CDB_FU_ID,
CDB_ISS_ID,
CDB_REQ,
CDB_ACK,
branch_addr,
no_branch
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


parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;

//ports

input reset;
input   [31:0]imm;
input 	[31:0] execute_stage_rd;
input  [6:0]execute_stage_opcode_latch;
input   [ADDR_WIDTH-1:0] execute_stage_opcode_addr;

input ROB_FULL;

output reg flush;
output reg no_branch;
input clk;
reg [31:0] decode_alu_result;
reg stall_i;
input  [31:0] a;
input  [31:0] b;
input  [7:0] waw_id;
output reg [31:0] result;
output reg [31:0] wb_addr;
output reg idle;


output [63:0]CDB;
output [4:0]CDB_REG_ID; 
output [3:0]CDB_FU_ID; 
output [31:0]CDB_ISS_ID;
output CDB_REQ;
input CDB_ACK;
reg [31:0] wb_addr_i;
//artificial delay
always @(posedge clk) if(!stall_i) wb_addr <= wb_addr_i;

reg [31:0] c;
always @(posedge clk) if(!stall_i) result <= c;

reg reset_sync;
always @(posedge clk) reset_sync <= reset;

parameter STAGES=2;
reg [STAGES-1:0] active_stages;
reg new_instruction;
always @(*) begin
	new_instruction = 0;
	case(execute_stage_opcode_latch)				
		

		LUI 	,	
		AUIPC 	,
		JAL 	,
		JALR 	,
		
		BEQ	, 
		BNE	, 
		BLT	, 
		BGE	, 
		BLTU	,
		BGEU	,	
		
		ADDI 	,
		SLTI 	,
		SLTIU 	,
		XORI 	,
		ORI 	,
		ANDI 	,
		SLLI 	,
		SRLI 	,
		SRAI 	,
		ADD 	,
		SUB 	,
		SLL 	,
		SLT 	,
		SLTU 	,
		XOR 	,
		SRL 	,
		SRA 	,
		OR 	,
		AND 	: begin
			new_instruction = 1;
		end

		
	endcase
end


reg CDB_REQ_s01;
always @(posedge clk) CDB_REQ_s01 <= reset ? 'h0 : CDB_REQ;
always @(*) stall_i = (CDB_REQ_s01 && ~CDB_ACK);

always @(posedge clk) begin 
    if(reset) active_stages <= 'h0;
    if(!stall_i) begin
	
	active_stages <= 'h0;
	begin
		
		active_stages <= {1'b0,active_stages[STAGES-1:1]};
		if(new_instruction) begin
			active_stages[STAGES-1] <= 1;
		end
		
	end
    end
end

reg [7:0]waw_id_s01;
reg [7:0]waw_id_s02;

always @(posedge clk) if(!stall_i) waw_id_s01 <= waw_id;
always @(posedge clk) if(!stall_i) waw_id_s02 <= waw_id_s01;

assign CDB = CDB_ACK ? result : 'hz;
assign CDB_REQ = active_stages[1] | stall_i;
assign CDB_REG_ID = CDB_ACK ?  wb_addr : 'hz;
assign CDB_FU_ID =  CDB_ACK ? 0 : 'hz;
assign CDB_ISS_ID = CDB_ACK ? waw_id_s02 : 'hz;

always @(*) begin
    idle = !stall_i; // 2 stage fully pipelined, can always pull an instruction unless stalled
end

output  [ADDR_WIDTH:0] branch_addr;
reg [ADDR_WIDTH:0] branch_addr_r;
assign branch_addr = reset_sync ? 0 : branch_addr_r;
//Branch Control	
always @(*) begin
	//do nothing case (stall)	
	flush                       		= 'h0; //next cc don't perform the instruction  
	branch_addr_r			= 'h0;			
	//logic
	flush = 'h0;
	no_branch = 0;
	
	case(execute_stage_opcode_latch)	
		JAL : begin branch_addr_r = (execute_stage_opcode_addr + {{32{imm[20]}},imm[20:2]});  branch_addr_r[ADDR_WIDTH]=1; end	//note - when using gnu-toolchain, jmp commands will be x4 times larger, due to branch_addr+4 (gnu) vs branch_addr+1 (what we do). hence [20:2]
		JALR : begin branch_addr_r = (a + {{32{imm[11]}},imm[11:2]});  branch_addr_r[ADDR_WIDTH]=1; end	
		BEQ : begin      if($signed(a)==$signed(b) ) begin branch_addr_r = (execute_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) );  branch_addr_r[ADDR_WIDTH]=1; end else no_branch = 1;  end	
		BNE : begin      if($signed(a)!=$signed(b) ) begin branch_addr_r = (execute_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); branch_addr_r[ADDR_WIDTH]=1; end  else no_branch = 1;  end	
		BLT : begin       if($signed(a)<$signed(b) ) begin branch_addr_r = (execute_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); branch_addr_r[ADDR_WIDTH]=1; end  else no_branch = 1;  end	
		BGE : begin	  if($signed(a)>$signed(b) ) begin branch_addr_r = (execute_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); branch_addr_r[ADDR_WIDTH]=1; end else no_branch = 1;  end	
		BLTU : begin  if($unsigned(a)<$unsigned(b) ) begin branch_addr_r = (execute_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); branch_addr_r[ADDR_WIDTH]=1; end else no_branch = 1;  end	
		BGEU : begin  if($unsigned(a)>$unsigned(b) ) begin branch_addr_r = (execute_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); branch_addr_r[ADDR_WIDTH]=1; end else no_branch = 1;  end	
	
		FENCE : begin end
		ECALL : begin end
		EBREAK : begin end
	endcase

		
	
end

always @(*) begin
        decode_alu_result = -1;	
	case(execute_stage_opcode_latch)
		LUI : begin decode_alu_result = {imm,12'b0}; end	
		AUIPC : begin decode_alu_result = {imm,12'b0} + execute_stage_opcode_addr;  end	
		JAL : begin decode_alu_result = execute_stage_opcode_addr + 1; end	
		JALR : begin decode_alu_result = execute_stage_opcode_addr + 1; end
	endcase	
end


//Execute (ALU) + Register Writeback
	always @(posedge clk) if(!stall_i) begin
		//Execute (ALU)
		wb_addr_i <= execute_stage_rd;
		case(execute_stage_opcode_latch)
			LUI : begin c <= decode_alu_result;  end	
			AUIPC : begin c <= decode_alu_result;    end	
			JAL : begin c <= decode_alu_result;   end	
			JALR : begin c <= decode_alu_result;   end	
					
			
			ADDI : begin c <= $signed(a) + {{32{imm[11]}},imm[11:0]};  end
			SLTI : begin  c <= ($signed(a) < {{32{imm[11]}},imm[11:0]});  end
			SLTIU : begin c <= ($unsigned(a) < {{32'b0},imm[11:0]});  end
			XORI : begin c <= $signed(a) ^ {{32{imm[11]}},imm[11:0]};  end
			ORI : begin c <= $signed(a) | {{32{imm[11]}},imm[11:0]};  end
			ANDI : begin c <= $signed(a) & {{32{imm[11]}},imm[11:0]};  end
			SLLI : begin c <= $signed(a) << imm[4:0];   end
			SRLI : begin c <= $signed(a) >> imm[4:0];   end
			SRAI : begin c <= $signed(a) >>> imm[4:0];   end
			ADD : begin c <= $signed(a) + $signed(b);   end
			SUB : begin c <= $signed(a) - $signed(b);   end
			SLL : begin c <= $signed(a) << b[4:0];   end
			SLT : begin c <= ($signed(a) < $signed(b));   end
			SLTU : begin c <= ($unsigned(a) < $unsigned(b));   end
			XOR : begin c <= $signed(a) ^ $signed(b);   end
			SRL : begin c <= $signed(a) >> b[4:0];   end
			SRA : begin c <= $signed(a) >>> b[4:0];   end
			OR : begin c <= $signed(a) | $signed(b);   end
			AND : begin c <= $signed(a) & $signed(b);   end
			
			FENCE : begin end
			ECALL : begin end
			EBREAK : begin end
		endcase
		
	end

endmodule
