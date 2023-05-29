module fetch(
	//inputs
	clk,
	reset,
	sram_data,
	
	branch_addr,
	PC_init,
        flush,
        no_branch,
        branch_pc,
	//outputs
	instruction,
	sram_addr,
	sram_we,
	sram_sel,
	sram_en,
	decode_stage_opcode_addr,
	stall,
	branch_taken,
	resume_issue,
        prediction_success,
        prediction_failed
	
);

//Parameters
parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;

reg   [ADDR_WIDTH-1:0] 		PC_s01; 
reg   [ADDR_WIDTH-1:0] 		PC_s02;

input 	reset;
input 	clk;
input  [ADDR_WIDTH:0] branch_addr;
input  [ADDR_WIDTH-1:0] PC_init;
input  stall;
input flush;
input no_branch;
input  [ADDR_WIDTH-1:0] branch_pc;

//sram
inout 	[ADDR_WIDTH-1:0]sram_addr;
inout 	[DATA_WIDTH-1:0]sram_data;
inout 	sram_we;
inout 	sram_sel;
inout 	sram_en;

output reg [63:0]		 instruction;
output [ADDR_WIDTH-1:0] decode_stage_opcode_addr;

output prediction_success;
output prediction_failed;

reg    [ADDR_WIDTH-1:0]		PC;
output branch_taken;
output resume_issue;

reg prediction_failed_r;
reg prediction_failed_r_s01;

wire stall_i;
always @(posedge clk) /*if(!stall_i)*/ prediction_failed_r <= prediction_failed;
always @(posedge clk) /*if(!stall_i)*/ prediction_failed_r_s01 <= prediction_failed_r;

assign branch_taken = branch_addr[ADDR_WIDTH];
assign resume_issue = prediction_failed_r_s01;

reg prediction_active;

wire [ADDR_WIDTH-1:0]prediction_pending_resolution;

wire prediction_success_taken;
wire prediction_failed_taken;
assign prediction_success_taken = branch_addr[ADDR_WIDTH] && branch_addr[ADDR_WIDTH-1:0] == prediction_pending_resolution;
assign prediction_failed_taken = (branch_addr[ADDR_WIDTH] && branch_addr[ADDR_WIDTH-1:0] != prediction_pending_resolution) || /*Default prediction case - we predict not taken if no valid BHT entry*/ (!prediction_active && branch_addr[ADDR_WIDTH]);

wire prediction_success_not_taken;
wire prediction_failed_not_taken;
assign prediction_success_not_taken = no_branch && branch_pc+1 == prediction_pending_resolution | (no_branch && $signed(prediction_pending_resolution) == -1);
assign prediction_failed_not_taken = no_branch && (branch_pc+1 != prediction_pending_resolution && $signed(prediction_pending_resolution) != -1);

assign prediction_success = (prediction_success_taken && prediction_active) | prediction_success_not_taken;
assign prediction_failed = prediction_failed_taken | (prediction_failed_not_taken && prediction_active);

wire [ADDR_WIDTH-1:0]prediciton_failed_address;
assign prediciton_failed_address = prediction_failed_taken ? branch_addr[ADDR_WIDTH-1:0] : prediction_failed_not_taken ? branch_pc+1 : -1;

wire prediction_resolved;
assign prediction_resolved = prediction_success | prediction_failed;




//branch prediction
wire prediction;
wire prediction_vector;
wire [ADDR_WIDTH-1:0]predicted_pc;

branch_predictor BP (
    .clk(clk),
    .reset(reset),
    .pc({{(64-ADDR_WIDTH){1'b0}},PC}),
    .branch_taken(branch_taken),
    .branch_not_taken(no_branch),
    .branch_pc(branch_pc),
    .branch_address(branch_addr[ADDR_WIDTH-1:0]),
    .prediction(prediction),
    .prediction_vector(prediction_vector),
    .predicted_pc(predicted_pc),
    .prediction_pending_resolution_o(prediction_pending_resolution)
);

assign stall_i = stall && !branch_taken; 

assign sram_addr 	= reset ? 'hz : (!stall_i) ? 
					(prediction_failed) ? 
						prediciton_failed_address : PC
					: PC_s01;
assign sram_we	 	= reset ? 'hz : 1'h0;
assign sram_sel 	= reset ? 'hz : 1'h1;
assign sram_en 		= reset ? 'hz : 1'h1;


//used to identify the PC associated with the current instruction, due to sram 1cc delay + EX stage 1cc delay.

always @(posedge clk) if(!stall_i) PC_s01 <= (prediction_failed) ? 
								prediciton_failed_address : PC;
always @(posedge clk) if(!stall_i) PC_s02 <= PC_s01;
assign decode_stage_opcode_addr = PC_s02;

reg reset_s01;
always @(posedge clk) reset_s01 <= reset;




//FETCH		
always @(posedge clk) begin
	//do nothing case (stall_i)	
	PC					<= PC;
	instruction				<= instruction;
	//logic
	if(reset) begin
		PC					<= PC_init;
		instruction				<= 'h0;
                prediction_active <= 0;
	end else if(!stall_i) begin
                //next PC
		if(prediction_failed) PC		<= prediciton_failed_address+1;
		else PC					<= predicted_pc;
                //prediction latches
                if(prediction)          prediction_active <= 1;
                if(prediction_resolved) prediction_active <= 0;
                //handle POR
		if(!reset_s01) instruction				<= sram_data;	
	end
end



endmodule
