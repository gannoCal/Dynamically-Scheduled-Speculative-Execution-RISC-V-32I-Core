module branch_predictor (
    clk,
    reset,
    pc,
    branch_taken,
    branch_not_taken,
    branch_address,
    branch_pc,
    prediction,
    prediction_vector,
    predicted_pc,
    prediction_pending_resolution_o
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

parameter SATURATING_COUNTER_BITS = 2;   // number of bits in saturating counter
parameter PC_WIDTH = 64;                 // or 'ADDRESS_SIZE'

parameter ADDR_WIDTH = 10; //32k ram
parameter DATA_WIDTH = 32;

//ports
input clk;
    

input [PC_WIDTH-1:0] pc;
input reset;
input branch_taken; // evaluated in EX stage by branch unit
input branch_not_taken;
input [PC_WIDTH-1:0] branch_address; // evaluated in EX stage by branch unit
input [PC_WIDTH-1:0] branch_pc; // evaluated in EX stage by branch unit
output prediction;
output prediction_vector;
output [PC_WIDTH-1:0] predicted_pc;
output [PC_WIDTH-1:0]prediction_pending_resolution_o;
reg [PC_WIDTH-1:0]prediction_pending_resolution;
assign prediction_pending_resolution_o = prediction_pending_resolution;


//BTB

//TODO:
//  To fix aliasing, we must store a "tag" to confirm that the BTB entry is intended for the current address
parameter SLOT_WIDTH = ADDR_WIDTH + 1;
localparam DEPTH 		= 2**ADDR_WIDTH;
reg [ADDR_WIDTH:0] btb [DEPTH:0];

//1 bits valid flag
`define VALID (SLOT_WIDTH-1)-:1
// 'ADDR_WIDTH' bits target address
`define ADDRESS (SLOT_WIDTH-1)-1-:ADDR_WIDTH

//update BTB with branch resolution data
integer i;
always @(posedge clk) begin
    if(reset) begin 
        
        for(i=0;i<DEPTH;i=i+1) begin
            btb[i][`VALID] <= 'h0;
        end
    end else begin
        if(branch_taken) begin
            btb[branch_pc][`ADDRESS] <= branch_address;
            btb[branch_pc][`VALID]   <= 1'h1;
        end
    end
end


//BHT
parameter BHT_SIZE = 512; 
parameter BHT_INDEX = 9; //clog2(BHT_SIZE)
reg [1:0] bht [BHT_SIZE-1:0]; // 2-bit
wire [BHT_INDEX-1:0]branch_tag;
assign branch_tag = branch_pc[BHT_INDEX-1:0];

//update BHT with branch resolution data
integer i2;
always @(posedge clk) begin
    if(reset) begin
        
        for(i2=0;i2<BHT_SIZE;i2=i2+1) begin 
            bht[i2] <= 2'b10; // initialize weak-not taken
        end
    end else begin
        if(branch_taken && bht[branch_tag] != 2'b11)        bht[branch_tag] <= bht[branch_tag] + 1;
        if(branch_not_taken && bht[branch_tag] != 2'b00)    bht[branch_tag] <= bht[branch_tag] - 1;
    end
end


//use BTB + BHT to predict next PC
wire [BHT_INDEX-1:0]tag;
assign tag = pc[BHT_INDEX-1:0];
assign predicted_pc = btb[pc][`VALID] && bht[tag] >= 2'b10 ? btb[pc][`ADDRESS] : pc + 1;
assign prediction = btb[pc][`VALID];
assign prediction_vector = bht[tag] >= 2'b10;

//make no further predictions until previous has been resolved
reg prediction_latch;

always @(posedge clk) begin
    if(reset) begin
        prediction_pending_resolution <= 'hFFFFFFFFFFFFFFF;
    end else begin
        if(branch_taken || branch_not_taken) prediction_pending_resolution <= 'hFFFFFFFFFFFFFFF;
        if(btb[pc][`VALID] /*&& bht[tag] >= 2'b10*/) prediction_pending_resolution <= predicted_pc;
    end
end
always @(posedge clk) prediction_latch <= btb[pc][`VALID] && bht[tag] >= 2'b10;

//need to detect branch instructions that will not be issued - 

wire [ADDR_WIDTH:0]btb_mon;
assign btb_mon = btb[11];

wire [1:0]bht_mon;
assign bht_mon = bht[11];
















endmodule
