module decode(
	//inputs
	clk,
	reset,
	decode_stage_opcode_addr,
	instruction,
	hazard_addr_mem,
	hazard_det_mem,
	wb_out,
	wb_addr,
	wb_en,
        stall_i,
        retired_regmap_i, 
        prediction_failed,
	//outputs
	a,
	b,
	flush,
	branch_addr,
	issue_stage_opcode_latch,
        issue_stage_opcode_addr_latch,
	rd_latch,
	rs1_latch,
	rs2_latch,
	imm_latch,
	 fm_latch,
	 pred_latch,
	 succ_latch,
	regmap_o,
	stall	
	
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

input 	reset;
input 	clk;

input   [ADDR_WIDTH-1:0] decode_stage_opcode_addr;
input [63:0]		 		instruction;

//data hazard stall detection
input	[31:0] 				hazard_addr_mem; // 32, 32-bit regs
input	 				hazard_det_mem;
reg  [31:0]hazard_addr_mem_s01;
reg  [31:0]hazard_det_mem_s01;
always @(posedge clk) hazard_addr_mem_s01 				<= hazard_addr_mem;
always @(posedge clk) hazard_det_mem_s01 			<= hazard_det_mem;
input stall_i;
output flush;
output  [ADDR_WIDTH:0] branch_addr;
output reg [ADDR_WIDTH-1:0] issue_stage_opcode_addr_latch;
always @(posedge clk) begin 
    if(!flush && !stall_i) issue_stage_opcode_addr_latch <= decode_stage_opcode_addr;
    else issue_stage_opcode_addr_latch <= issue_stage_opcode_addr_latch;
end

output reg stall;
input wb_en;



output reg [31:0] a;
output reg [31:0] b;
reg [31:0] a_i;
reg [31:0] b_i;
input	[31:0] wb_out;
input	[4:0] wb_addr;

//Decode signals
wire [6:0]opcode;
output reg [6:0]issue_stage_opcode_latch;
reg [6:0]decoded_opcode;
always @(posedge clk) begin 
    if(!flush && !stall_i) issue_stage_opcode_latch <= decoded_opcode;
    else issue_stage_opcode_latch <= issue_stage_opcode_latch;
end
output reg  [4:0]rd_latch;
output reg  [4:0]rs1_latch;
output reg  [4:0]rs2_latch;
output reg  [31:0]imm_latch; 
output reg  [4:0] fm_latch;
output reg  [2:0] pred_latch;
output reg  [3:0] succ_latch;

reg [31:0] decode_alu_result;

input 		[1023:0]retired_regmap_i;
wire [31:0] retired_regmap[31:0];
genvar ii;
generate for(ii=0; ii<32 ; ii=ii+1) begin : regmap_port_in
	assign retired_regmap[ii] = retired_regmap_i[1023 - ii*32 -:32];
end endgenerate
input prediction_failed;

reg  [4:0]rd;
reg  [4:0]rs1;
reg  [4:0]rs2;
reg  [31:0]imm; 
reg  [4:0] fm;
reg  [2:0] pred;
reg  [3:0] succ;

//hazard detection (scoreboard) - moved to issue stage
reg  [4:0]rd_s01;
reg  [4:0]rd_s02;
reg  [4:0]rd_s03;
always @(posedge clk)   if(!stall && !flush) rd_s01 <= rd; else rd_s01 <= -1;
always @(posedge clk)   rd_s02 <= rd_s01;
always @(posedge clk)   rd_s03 <= rd_s02;

always @(*) begin
	stall = 0;
	/*if($signed(rs1) != -1 && !reset && rs1 != 0 && !flush) begin
		if(rs1 == rd_s01) stall = 1;
		if(rs1 == rd_s02) stall = 1;
		if(rs1 == rd_s03) stall = 1; //we expect to have the value from wb
	end

	if($signed(rs2) != -1 && !reset && rs2 != 0 && !flush) begin
		if(rs2 == rd_s01) stall = 1;
		if(rs2 == rd_s02) stall = 1;
		if(rs2 == rd_s03) stall = 1; //we expect to have the value from wb
	end*/
end



always @(posedge clk) begin
	if( !flush && !stall_i) begin
		rd_latch <= rd;
		rs1_latch <= rs1;
		rs2_latch <= rs2;
		imm_latch <= imm; 
		fm_latch <= fm;
		pred_latch <= pred;
		succ_latch <= succ;
	end 
end

// 32, 32-bit regs
output 		[1023:0]regmap_o;
reg 		[31:0]regmap[31:0];
generate for(ii=0; ii<32 ; ii=ii+1) begin : regmap_port_out
	assign regmap_o[1023 - ii*32 -:32] = regmap[ii];
end endgenerate
 

/*reg   flush_r;
reg   flush_r_s01;
reg   flush_r_s02;
reg   flush_r_s03;
reg   flush_r_s04;
always @(posedge clk) flush_r_s01 <= flush_r;
always @(posedge clk) flush_r_s02 <= flush_r_s01;
always @(posedge clk) flush_r_s03 <= flush_r_s02;
always @(posedge clk) flush_r_s04 <= flush_r_s03;
assign flush = flush_r | flush_r_s01;*/

assign flush = 'h0; 
assign branch_addr = 'hz;
//check for read/write conflict
always @(*) begin
        a_i = -1;
        b_i = -1;

            a_i = regmap[rs1];
            if(wb_en && rs1 == wb_addr) a_i = wb_out;
	    
	    b_i = regmap[rs2];
	    if(wb_en && rs2 == wb_addr) b_i = wb_out;
	   
        //end
        

	//return 0 from 0 register always
	if(rs1 == 'h0) a_i = 'h0;
	if(rs2 == 'h0) b_i = 'h0;
end




//Branch Control	
/*always @(posedge clk) begin
	//do nothing case (stall)	
	flush_r                       		<= 'h0; //next cc don't perform the instruction
	branch_addr			<= 'h0;			
	//logic
		
	if(!flush && !stall && !stall_i) begin
		case(decoded_opcode)	
			JAL : begin branch_addr <= (decode_stage_opcode_addr + {{32{imm[20]}},imm[20:2]}); flush_r<=1; branch_addr[ADDR_WIDTH]<=1; end	//note - when using gnu-toolchain, jmp commands will be x4 times larger, due to branch_addr+4 (gnu) vs branch_addr+1 (what we do). hence [20:2]
			JALR : begin branch_addr <= (a_i + {{32{imm[11]}},imm[11:2]}); flush_r<=1; branch_addr[ADDR_WIDTH]<=1; end	
			BEQ : begin      if($signed(a_i)==$signed(b_i) ) begin branch_addr <= (decode_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); flush_r<=1; branch_addr[ADDR_WIDTH]<=1; end   end	
			BNE : begin      if($signed(a_i)!=$signed(b_i) ) begin branch_addr <= (decode_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); flush_r<=1;branch_addr[ADDR_WIDTH]<=1; end    end	
			BLT : begin       if($signed(a_i)<$signed(b_i) ) begin branch_addr <= (decode_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); flush_r<=1;branch_addr[ADDR_WIDTH]<=1; end    end	
			BGE : begin	  if($signed(a_i)>$signed(b_i) ) begin branch_addr <= (decode_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); flush_r<=1;branch_addr[ADDR_WIDTH]<=1; end   end	
			BLTU : begin  if($unsigned(a_i)<$unsigned(b_i) ) begin branch_addr <= (decode_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); flush_r<=1;branch_addr[ADDR_WIDTH]<=1; end   end	
			BGEU : begin  if($unsigned(a_i)>$unsigned(b_i) ) begin branch_addr <= (decode_stage_opcode_addr + ({{32{imm[12]}},imm[12:2]}) ); flush_r<=1;branch_addr[ADDR_WIDTH]<=1; end   end	
		
			FENCE : begin end
			ECALL : begin end
			EBREAK : begin end
		endcase
	end
	
end

always @(*) begin
        decode_alu_result = -1;
	if(!stall && !stall_i) begin
		case(decoded_opcode)
			LUI : begin decode_alu_result = {imm,12'b0}; end	
			AUIPC : begin decode_alu_result = {imm,12'b0} + decode_stage_opcode_addr;  end	
			JAL : begin decode_alu_result = decode_stage_opcode_addr + 1; end	
			JALR : begin decode_alu_result = decode_stage_opcode_addr + 1; end
		endcase
	end
end*/


//read regmap
always @(posedge clk) begin
    if(!flush && !stall_i) begin
	a <= a_i;
	b <= b_i;
    end
    //stall detection logic
    if(stall_i) begin
        if(rs1_latch != 0 && rs1_latch == wb_addr && wb_en) a <= wb_out;
        if(rs2_latch != 0 && rs2_latch == wb_addr && wb_en) b <= wb_out;
    end
end
wire [63:0]reg12_mon;
assign reg12_mon = regmap[10];
wire [63:0]reg12_wb;
assign reg12_wb = regmap[wb_addr];
//write regmap
always @(posedge clk) begin : regmap_assignments
    
	integer i;
    for(i=0;i<32;i=i+1)if(prediction_failed) regmap[i] <= retired_regmap[i];

    if(wb_en) begin
	regmap[wb_addr] <= wb_out;
    end


	//special registers
	//x0 : always 0
	regmap[0] <= 0;
end



//Decode		

    //monitors
    	wire  [31:0]rd_mon;
    assign rd_mon = regmap[rd];
	wire  [31:0]rs1_mon;
    assign rs1_mon = regmap[rs1];
	wire  [31:0]rs2_mon;
    assign rs2_mon = regmap[rs2];

	
assign opcode = instruction[6:0];
always @(*) begin
//default vals: avoid inferred latch
	rd 			= 'h0;
	rs1 			= 'h0;
	rs2 			= 'h0;
	
	
	imm 			= 'h0;	
	decoded_opcode = -1;
	//decode the instruction type
	case(opcode)
		
		
		/*LUI 	*/ 7'b0110111 : begin decoded_opcode=LUI; rd=instruction[11:7]; imm[31:12]=instruction[31:12]; end
		/*AUIPC */  7'b0010111 : begin decoded_opcode=AUIPC; rd=instruction[11:7]; imm[31:12]=instruction[31:12]; end
		/*JAL 	*/ 7'b1101111 : begin decoded_opcode=JAL; rd=instruction[11:7]; imm[20]=instruction[31]; imm[10:1]=instruction[30:21]; imm[11]=instruction[20]; imm[19:12]=instruction[19:12]; end
		/*JALR 	*/ 7'b1100111 : begin decoded_opcode=JALR; imm[11:0]=instruction[31:20]; rs1=instruction[19:15]; rd=instruction[11:7]; end
						7'b1100011 : begin 
							imm[12]=instruction[31]; imm[10:5]=instruction[30:25]; rs2=instruction[24:20]; rs1=instruction[19:15]; imm[4:1]=instruction[11:8]; imm[11]=instruction[7];
							case(instruction[14:12])
		/*BEQ 	*/						3'b000 : begin decoded_opcode=BEQ; end
		/*BNE 	*/						3'b001 : begin decoded_opcode=BNE; end
		/*BLT 	*/ 					3'b100 : begin decoded_opcode=BLT; end
		/*BGE 	*/ 					3'b101 : begin decoded_opcode=BGE; end
		/*BLTU 	*/ 					3'b110 : begin decoded_opcode=BLTU; end
		/*BGEU 	*/ 					3'b111 : begin decoded_opcode=BGEU; end
							endcase 
						end //BEQ family
						7'b0000011 : begin 
							imm[11:0]=instruction[31:20]; rs1=instruction[19:15]; rd=instruction[11:7];
							case(instruction[14:12])
		/*LB 	*/				3'b000 : begin decoded_opcode=LB; end
		/*LH 	*/    		3'b001 : begin decoded_opcode=LH; end
		/*LW 	*/    		3'b010 : begin decoded_opcode=LW; end
		/*LBU 	*/ 		3'b100 : begin decoded_opcode=LBU; end
		/*LHU 	*/ 		3'b101 : begin decoded_opcode=LHU; end
							endcase
						end //LB Family
						7'b0100011 : begin
						imm[11:0]=instruction[31:20]; imm[4:0]=instruction[11:7]; rs2=instruction[24:20]; rs1=instruction[19:15];
						case(instruction[14:12])
		/*SB 	*/			3'b000 : begin decoded_opcode=SB; end
		/*SH 	*/ 		3'b001 : begin decoded_opcode=SH; end
		/*SW 	*/			3'b010 : begin decoded_opcode=SW; end
						endcase
					end // SB family
						7'b0010011 : begin
						imm[11:0]=instruction[31:20]; rs1=instruction[19:15]; rd=instruction[11:7];
						case(instruction[14:12])
		/*ADDI 	*/		3'b000 : begin decoded_opcode=ADDI; end
		/*SLTI 	*/ 	3'b010 : begin decoded_opcode=SLTI; end
		/*SLTIU */ 		3'b011 : begin decoded_opcode=SLTIU; end
		/*XORI 	*/ 	3'b100 : begin decoded_opcode=XORI; end
		/*ORI 	*/ 	3'b110 : begin decoded_opcode=ORI; end
		/*ANDI 	*/ 	3'b111 : begin decoded_opcode=ANDI; end
		/*SLLI 	*/ 	3'b001 : begin decoded_opcode=SLLI; end
							3'b101 : begin 
								case(instruction[31:25])
		/*SRLI 	*/				7'b0000000 : begin decoded_opcode=SRLI; end
		/*SRAI 	*/				7'b0100000 : begin decoded_opcode=SRAI; end
								endcase
							end
		  	
							endcase
						end//ADDI family
						7'b0110011: begin
							rs2=instruction[24:20]; rs1=instruction[19:15]; rd=instruction[11:7];
							case(instruction[14:12])
								3'b000 : begin 
									case(instruction[31:25])
		/*ADD 	*/					7'b0000000 : begin decoded_opcode=ADD; end		
		/*SUB 	*/					7'b0100000 : begin decoded_opcode=SUB; end	
									endcase
								end
		/*SLL 	*/			3'b001 : begin decoded_opcode=SLL; end
		/*SLT 	*/ 		3'b010 : begin decoded_opcode=SLT; end
		/*SLTU 	*/			3'b011 : begin decoded_opcode=SLTU; end
		/*XOR 	*/ 		3'b100 : begin decoded_opcode=XOR; end
								3'b101 : begin 
									case(instruction[31:25])
		/*SRL 	*/					7'b0000000 : begin decoded_opcode=SRL; end		
		/*SRA 	*/					7'b0100000 : begin decoded_opcode=SRA; end	
									endcase
								end
		/*OR 	*/				3'b110 : begin decoded_opcode=OR; end
		/*AND 	*/			3'b111 : begin decoded_opcode=AND; end
							endcase
						end // ADD Family
		/*FENCE */ 	7'b0001111 : begin decoded_opcode=FENCE; fm=instruction[31:27]; pred=instruction[26:24]; succ=instruction[23:20]; rs1=instruction[19:15]; rd=instruction[11:7]; end
						7'b1110011: begin 
						
							case(instruction[31:20])
		/*ECALL */				12'd0 : begin decoded_opcode=ECALL; end
		/*EBREAK*/				12'd1 : begin decoded_opcode=EBREAK; end	
							endcase
						end //ECALL Family
		

		//unknown opcode
		default : begin
			rd 			= -1;
			rs1 			= -1;
			rs2 			= -1;
			imm 			= -1;
		end
	endcase
	
end

endmodule
