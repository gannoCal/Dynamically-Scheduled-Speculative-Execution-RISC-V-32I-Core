module writeback(
//input
result_exec,
result_mem,
wb_addr_exec,
wb_addr_mem,
writeback_stage_opcode_latch,

flush,
wb_en,
//output
wb_out,
wb_addr
);

//Parameters
parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;

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

input [31:0] result_exec;
input [31:0] result_mem;
input [31:0] wb_addr_exec;
input [31:0] wb_addr_mem;

input flush;
input wb_en;
input  [6:0]writeback_stage_opcode_latch;
output reg [31:0] wb_out;
output reg [31:0] wb_addr;



always @(*) begin
	wb_out 	= 0;
	wb_addr = 0;
	//Writeback decoder
	if( wb_en) begin
		case(writeback_stage_opcode_latch)

			LB,
			LH,	
			LW,	
			LBU,	
			LHU : begin
				//mem results
				wb_out 	= result_mem;
				wb_addr = wb_addr_mem;
			end

	
					
			LUI,
			AUIPC,	
			JAL,	
			JALR,

			ADDI,
			SLTI,
			SLTIU,
			XORI,
			ORI,
			ANDI,
			SLLI,
			SRLI,
			SRAI,
			ADD,
			SUB,
			SLL,
			SLT,
			SLTU,
			XOR,
			SRL,
			SRA,
			OR,
			AND : begin
				//simple exec results
				wb_out 	= result_exec;
				wb_addr = wb_addr_exec;
			end
			
			FENCE : begin end
			ECALL : begin end
			EBREAK : begin end
		endcase
	end
end

endmodule
