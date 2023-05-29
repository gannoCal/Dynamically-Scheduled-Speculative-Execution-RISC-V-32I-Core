module issue(
//input
clk,
reset,
decoded_opcode,
src1,
src2,
src1_id,
src2_id,
dest,
imm,
issue_stage_opcode_addr,
flush,
prediction_failed,
prediction_success,
resume_issue,
RS_FULL,
ROB_FULL,

//CDB input
CDB,
CDB_REG_ID,
CDB_FU_ID,
CDB_ISS_ID,
wb_en,

//output
RS_SEL,

//slot output
decoded_opcode_o, op1v_o, op1_o, op2v_o, op2_o, dest_o, imm_o, res_id_o, execute_stage_opcode_addr_o,

stall,

push_en,
push_reg,
push_branch_unresolved,

push_store,
push_store_addr,
push_store_data,
push_store_data_tag,
push_store_addr_tag,
push_store_imm


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

parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;

parameter SIMPLE_EXEC = 0;
parameter MEM = 1;


//ports
output                  push_store;
output reg [64-1:0]         push_store_addr;
output reg [64-1:0]         push_store_data;
output reg                  push_store_data_tag;
output reg                  push_store_addr_tag;
output reg [11:0]                 push_store_imm;

input clk;
input reset;
input [6:0] decoded_opcode;
input [63:0] src1;
input [63:0] src2;
input [4:0]  dest;
input [4:0]  src1_id;
input [4:0]  src2_id;
input [31:0]  imm;
input flush;
input   [ADDR_WIDTH-1:0] issue_stage_opcode_addr;

input resume_issue;
reg flush_issue;

input [63:0]CDB;
input [4:0]CDB_REG_ID; 
input [3:0]CDB_FU_ID; 
input [31:0]CDB_ISS_ID;
input wb_en;
input RS_FULL;
input ROB_FULL;

output reg [3:0] RS_SEL;
reg [3:0] RS_SEL_i;

//slot output
output reg [6:0] decoded_opcode_o;
output  op1v_o;
output  [63:0] op1_o;
output  op2v_o;
output  [63:0] op2_o;
output reg [4:0] dest_o;
output reg [31:0] imm_o;
output reg [31:0] res_id_o;
output reg   [ADDR_WIDTH-1:0] execute_stage_opcode_addr_o;

output reg push_en;
output reg [4:0] push_reg;
output reg push_branch_unresolved;

reg branch_unresolved;
input prediction_failed;
input prediction_success;
wire branch_resolved;
assign branch_resolved = prediction_failed | prediction_success;

output stall;
reg [4:0]stall_i;
assign stall = |stall_i;
reg stall_s01;

always @(posedge clk) stall_s01 <= stall;

//scoreboard
parameter DEPTH = 32; //register count
parameter SLOT_WIDTH = 14;
reg [SLOT_WIDTH-1:0] register_sb[DEPTH-1:0];

//1 bits register pending flag
`define PENDING (SLOT_WIDTH-1)-:1
// 4 bits functional unit ID
`define FUNC_ID (SLOT_WIDTH-1)-1-:4
//8 bits ISS_ID slot
`define ISS_ID (SLOT_WIDTH-1)-5-:8
//1 bit speculative flag
`define SB_SPECULATIVE (SLOT_WIDTH-1)-13-:1
//Total 12 bits per slot

reg new_branch;
reg new_branch_s01;
always @(posedge clk) new_branch_s01 <= new_branch;
//scoreboard (generate tags)
integer j;
always @(*) begin
    stall_i = 'h0;
    for (j = 1; j < DEPTH ; j=j+1) begin
        if(j == src1_id || j == src2_id) if(register_sb[j][`PENDING]) stall_i = j; //multi-bit stall code - set to the register number that we're stalling for? help with debug
    end 
    stall_i = RS_FULL | ROB_FULL | (new_branch && branch_unresolved && !branch_resolved);
end

always @(posedge clk) if(1==1) begin
    if(reset) flush_issue <= 0;
    if(prediction_failed) flush_issue <= 1;
    if(resume_issue) flush_issue <= 0;
end



reg [7:0] issue_order_counter; 


//store detection and logic

//detect store operation
reg store_instruction_out;
always @(*) begin
    store_instruction_out = 0;
    case(decoded_opcode_o)   
        //Store
        SB : begin 
            store_instruction_out = 1;	 
        end
        SH : begin 
            store_instruction_out = 1;	 
        end
        SW : begin 
            store_instruction_out = 1;	 
        end
    endcase
end

assign push_store = store_instruction_out;

//preemptively calculate store address + data
always @(*) begin
    push_store_addr             = op1_o;
    push_store_data             = op2_o;
    push_store_data_tag         = !op2v_o;
    push_store_addr_tag         = !op1v_o;
    push_store_imm              = imm_o;

    if(op1v_o) push_store_addr = op1_o + $signed(imm_o);
end

//scoreboard logic
always @(posedge clk) begin : sb_assign
    integer jj;
    for (jj = 0; jj < DEPTH; jj=jj+1) begin : sb_entry
        if(reset) begin
             register_sb[jj] <= 0;
        end else begin
           
            //clear using CDB write
            if(jj==CDB_REG_ID && register_sb[jj][`FUNC_ID]==CDB_FU_ID && register_sb[jj][`ISS_ID]==CDB_ISS_ID && wb_en) begin
                register_sb[jj][`PENDING]               <= 0;
                register_sb[jj][`FUNC_ID]               <= -1;
            end
 
            //create new entry
            if((jj == dest) && $signed(RS_SEL_i) != -1 && !(stall || stall_s01 || flush_issue || prediction_failed)) begin  
                register_sb[jj][`PENDING]    <= 1;
                register_sb[jj][`FUNC_ID]    <= RS_SEL_i;
                register_sb[jj][`ISS_ID]     <= issue_order_counter;
                register_sb[jj][`SB_SPECULATIVE]        <= branch_unresolved && ~branch_resolved;
            end 

            //clear speculative results if prediction fails
            if(register_sb[jj][`SB_SPECULATIVE] && prediction_failed) begin
                register_sb[jj][`PENDING]               <= 0;
                register_sb[jj][`FUNC_ID]               <= -1;
                register_sb[jj][`SB_SPECULATIVE]        <= 0;
            end
            
            

        end
            
        if(jj == 0) register_sb[jj] <= 0;
    end
end

//sb monitors
wire PENDING_mon;
wire [3:0]FUNC_ID_mon;
wire [7:0]ISS_ID_mon;
wire SB_SPECULATIVE_mon;

assign PENDING_mon              = register_sb[8][`PENDING];
assign FUNC_ID_mon              = register_sb[8][`FUNC_ID];
assign ISS_ID_mon               = register_sb[8][`ISS_ID];
assign SB_SPECULATIVE_mon       = register_sb[8][`SB_SPECULATIVE];




//TAG definition
parameter TAG_WIDTH = 64;
//64 bits total
//5 bit destination register
`define TAG_DEST (TAG_WIDTH-1)-:5
//32 bit issueID - used to maintain logcal flow.
`define TAG_ISS_ID (TAG_WIDTH-1)-5-:32
//4 bit functional unit ID
`define TAG_FU_ID (TAG_WIDTH-1)-37-:4
//23 bit undefined

reg [TAG_WIDTH-1:0] tag1;
reg [TAG_WIDTH-1:0] tag2;

//issue next instruction 
always @(*) begin
    tag2 = 0;
    tag1 = 0;
    tag1[`TAG_FU_ID]    = register_sb[src1_id][`FUNC_ID];
    tag1[`TAG_DEST]     = src1_id;
    tag1[`TAG_ISS_ID]   = register_sb[src1_id][`ISS_ID];
    tag2[`TAG_FU_ID]    = register_sb[src2_id][`FUNC_ID];
    tag2[`TAG_DEST]     = src2_id;
    tag2[`TAG_ISS_ID]   = register_sb[src2_id][`ISS_ID];
end

//handle CDB bypassing
wire CDB_bypass_src1_i;
wire CDB_bypass_src2_i;
assign CDB_bypass_src1_i = wb_en && CDB_REG_ID != 0 && CDB_REG_ID == src1_id && register_sb[src1_id][`ISS_ID]==CDB_ISS_ID;
assign CDB_bypass_src2_i = wb_en && CDB_REG_ID != 0 && CDB_REG_ID == src2_id && register_sb[src2_id][`ISS_ID]==CDB_ISS_ID;


reg op1v_r;
reg [63:0]op1_r;
reg op2v_r;
reg [63:0]op2_r;

reg [4:0]src1_id_r;
reg [4:0]src2_id_r;
always @(posedge clk) if( !stall) src1_id_r <= src1_id;
always @(posedge clk) if( !stall) src2_id_r <= src2_id;
wire CDB_bypass_src1_o;
wire CDB_bypass_src2_o;
assign CDB_bypass_src1_o = wb_en && CDB_REG_ID != 0 && CDB_REG_ID == src1_id_r && op1_r[`TAG_ISS_ID]==CDB_ISS_ID;
assign CDB_bypass_src2_o = wb_en && CDB_REG_ID != 0 && CDB_REG_ID == src2_id_r && op2_r[`TAG_ISS_ID]==CDB_ISS_ID;



assign op1v_o = CDB_bypass_src1_o ? 1 : op1v_r;
assign op1_o  = CDB_bypass_src1_o ? CDB : op1_r;
assign op2v_o = CDB_bypass_src2_o ? 1 : op2v_r;
assign op2_o  = CDB_bypass_src2_o ? CDB : op2_r;

reg push_en_r;
always @(*) push_en =  (prediction_failed && push_branch_unresolved || flush_issue) && !(stall || stall_s01)  ? 0 : push_en_r;



always @(*) begin
        new_branch = 0;
        case(decoded_opcode)
            JAL :   begin new_branch = 1; end 
            JALR :  begin new_branch = 1; end 

            BEQ	:   begin new_branch = 1; end       
            BNE	:   begin new_branch = 1; end
            BLT	:   begin new_branch = 1; end
            BGE	:   begin new_branch = 1; end
            BLTU:   begin new_branch = 1; end	
            BGEU:   begin new_branch = 1; end
        endcase
end



reg issuing_monitor;
//main issue loop
always @(posedge clk) begin
    issuing_monitor <= 0;
    if(reset) branch_unresolved <= 0;
    if(reset) issue_order_counter <= 0;

    if(branch_resolved) branch_unresolved <= 0;
    //CDB while stalled detection
    if(stall) begin
         if(CDB_REG_ID != 0 && CDB_REG_ID == src1_id_r) begin
             op1_r <= CDB;
             op1v_r <= 1;
         end
         if(CDB_REG_ID != 0 && CDB_REG_ID == src2_id_r) begin
             op2_r <= CDB;
             op2v_r <= 1;
         end
     end 
    if( !stall) begin
        
        //if((stall && stall_s01)) push_en          <= 0;
        if(!ROB_FULL) push_en_r          <= 0;
        decoded_opcode_o <= 0;
        if(!(stall && stall_s01)) if(!new_branch) push_branch_unresolved <= 0;
        if(!(stall && stall_s01) /*when a stall is detected, issue the stalling instruction. It will wait in the RS*/ && !(flush_issue || prediction_failed)) begin
            issue_order_counter <= issue_order_counter + 'h1;
            issuing_monitor <= 1;
            decoded_opcode_o <= decoded_opcode;
            dest_o           <= dest;
            if(CDB_bypass_src1_i) begin
                op1_r            <= CDB;
                op1v_r           <= 1;
            end else begin
                op1_r            <= ~register_sb[src1_id][`PENDING] ? src1 : tag1;
                op1v_r           <= ~register_sb[src1_id][`PENDING];
            end
            if(CDB_bypass_src2_i) begin
                op2_r            <= CDB;
                op2v_r           <= 1;
            end else begin
                op2_r            <= ~register_sb[src2_id][`PENDING] ? src2 : tag2;
                op2v_r           <= ~register_sb[src2_id][`PENDING];
            end
            
            imm_o            <= imm;
            res_id_o         <= issue_order_counter;
            execute_stage_opcode_addr_o <= issue_stage_opcode_addr;
        
            push_en_r          <= 1;
            push_reg         <= dest;
    
            
            if(new_branch) branch_unresolved <= 1;
            
            if(branch_unresolved && ~branch_resolved) push_branch_unresolved <= 1;
        end
        //if (stall_s01 && !ROB_FULL) push_en_r          <= 0;
    end
end






//take a decoded opcode, generate tags (if needed), and place in a reservation station.

always @(*) begin
    RS_SEL_i = -1;
    if(!reset) begin
        case(decoded_opcode)
            LUI :   begin RS_SEL_i = SIMPLE_EXEC; end	
            AUIPC : begin RS_SEL_i = SIMPLE_EXEC; end 
            JAL :   begin RS_SEL_i = SIMPLE_EXEC; end 
            JALR :  begin RS_SEL_i = SIMPLE_EXEC; end 

            BEQ	:   begin RS_SEL_i = SIMPLE_EXEC; end       
            BNE	:   begin RS_SEL_i = SIMPLE_EXEC; end
            BLT	:   begin RS_SEL_i = SIMPLE_EXEC; end
            BGE	:   begin RS_SEL_i = SIMPLE_EXEC; end
            BLTU:   begin RS_SEL_i = SIMPLE_EXEC; end	
            BGEU:   begin RS_SEL_i = SIMPLE_EXEC; end		       
            
            ADDI :  begin RS_SEL_i = SIMPLE_EXEC; end
            SLTI :  begin RS_SEL_i = SIMPLE_EXEC; end
            SLTIU : begin RS_SEL_i = SIMPLE_EXEC; end
            XORI :  begin RS_SEL_i = SIMPLE_EXEC; end
            ORI :   begin RS_SEL_i = SIMPLE_EXEC; end
            ANDI :  begin RS_SEL_i = SIMPLE_EXEC; end
            SLLI :  begin RS_SEL_i = SIMPLE_EXEC; end
            SRLI :  begin RS_SEL_i = SIMPLE_EXEC; end
            SRAI :  begin RS_SEL_i = SIMPLE_EXEC; end
            ADD :   begin RS_SEL_i = SIMPLE_EXEC; end
            SUB :   begin RS_SEL_i = SIMPLE_EXEC; end
            SLL :   begin RS_SEL_i = SIMPLE_EXEC; end
            SLT :   begin RS_SEL_i = SIMPLE_EXEC; end
            SLTU :  begin RS_SEL_i = SIMPLE_EXEC; end
            XOR :   begin RS_SEL_i = SIMPLE_EXEC; end
            SRL :   begin RS_SEL_i = SIMPLE_EXEC; end
            SRA :   begin RS_SEL_i = SIMPLE_EXEC; end
            OR :    begin RS_SEL_i = SIMPLE_EXEC; end
            AND :   begin RS_SEL_i = SIMPLE_EXEC; end

            LB, 
            LH, 
            LW,		
            LBU,	
            LHU : begin 
                RS_SEL_i = MEM;	 
            end
            
            //Store
            SB : begin 
                RS_SEL_i = MEM;	 
            end
            SH : begin 
                RS_SEL_i = MEM;	 
            end
            SW : begin 
                RS_SEL_i = MEM;	 
            end
            
            FENCE : begin end
            ECALL : begin end
            EBREAK :begin end
        endcase
    end
end

reg [3:0]RS_SEL_r;
always @(*) RS_SEL = /*prediction_failed |*/ !issuing_monitor ? -1 : RS_SEL_r;
always @(posedge clk) RS_SEL_r <= (/*stall && stall_s01 ||*/ (flush_issue || prediction_failed))  ? -1 : RS_SEL_i;

endmodule
