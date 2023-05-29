module reservation_station(
//input
clk,
reset,
push,
bypass,
//slot input
decoded_opcode, op1v, op1, op2v, op2, dest, imm, res_id, execute_stage_opcode_addr,

push_branch_unresolved,
prediction_failed,
prediction_success,

//CDB input
CDB,
CDB_REG_ID,
CDB_FU_ID,
CDB_ISS_ID,

pull,
pull_non_load,


//output
//slot output
decoded_opcode_o, op1_o, op2_o, dest_o, imm_o, res_id_o, execute_stage_opcode_addr_o,

rdy,
rs_full,
rs_empty
);

parameter ADDR_WIDTH = 15; //32k ram

parameter JAL = 7'd3;
parameter JALR = 7'd4;
parameter BEQ = 7'd5;
parameter BNE = 7'd6;
parameter BLT = 7'd7;
parameter BGE = 7'd8;
parameter BLTU = 7'd9;
parameter BGEU = 7'd10;

//ports
input clk;
input reset;
input push;
input pull;
input bypass;
//slot input
input [6:0] decoded_opcode;
input op1v;
input [63:0]op1;
input op2v;
input [63:0]op2;
input [4:0]dest;
input [31:0]imm;
input [31:0]res_id;
input   [ADDR_WIDTH-1:0] execute_stage_opcode_addr;

input [63:0]CDB;
input [4:0]CDB_REG_ID; 
input [3:0]CDB_FU_ID; 
input [31:0]CDB_ISS_ID;
input push_branch_unresolved;

input prediction_failed;
input prediction_success;

input pull_non_load;


output reg rdy;
output rs_full; 
output rs_empty;

//slot output
 reg [6:0] decoded_opcode_r;
 reg [63:0]op1_r;
 reg [63:0]op2_r;
 reg [4:0]dest_r;
reg [31:0]imm_r;
reg [31:0]res_id_r;
reg   [ADDR_WIDTH-1:0] execute_stage_opcode_addr_r;

output  [6:0] decoded_opcode_o;
output  [63:0]op1_o;
output  [63:0]op2_o;
output  [4:0]dest_o;
output  [31:0]imm_o;
output [31:0]res_id_o;
output   [ADDR_WIDTH-1:0] execute_stage_opcode_addr_o;

assign decoded_opcode_o = bypass ? decoded_opcode : decoded_opcode_r;
assign op1_o = bypass ? op1 : op1_r;
assign op2_o = bypass ? op2 : op2_r;
assign dest_o = bypass ? dest : dest_r;
assign imm_o = bypass ? imm : imm_r;
assign res_id_o = bypass ? res_id : res_id_r;
assign execute_stage_opcode_addr_o = bypass ? execute_stage_opcode_addr : execute_stage_opcode_addr_r;


//Buffer
parameter SLOT_WIDTH = 223;
parameter DEPTH = 15;
parameter COUNTER = 4; //clog2(DEPTH)


//7 bits decoded opcode
`define OPCODE (SLOT_WIDTH-1)-:7
// 1 bit flag operand 1 is tag or data
`define OP1V (SLOT_WIDTH-1)-7-:1
//64 bits operand 1 (tag or data)
`define OP1 (SLOT_WIDTH-1)-8-:64
// 1 bit flag operand 2 is tag or data
`define OP2V (SLOT_WIDTH-1)-72-:1
//64 bits operand 2 (tag or data)
`define OP2 (SLOT_WIDTH-1)-73-:64
//5 bits destination
`define DEST (SLOT_WIDTH-1)-137-:5
//32 bits imm field
`define IMM (SLOT_WIDTH-1)-142-:32
//32 bit reservation id field
`define RES_ID (SLOT_WIDTH-1)-174-:32
//15 bit PC address field
`define PC_VAL (SLOT_WIDTH-1)-206-:15
//1 bit branch speculation
`define SPECULATE_B  (SLOT_WIDTH-1)-221-:1
//1 bit valid flag
`define RS_VALID  (SLOT_WIDTH-1)-222-:1
//Total 222 bits per slot

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

//monitors
reg [TAG_WIDTH-1:0]tag0_1;
reg [4:0]tag_dest0_1;
reg [31:0]tag_iss0_1;
reg [3:0] tag_fu0_1;
reg [TAG_WIDTH-1:0]tag0_2;
reg [4:0]tag_dest0_2;
reg [31:0]tag_iss0_2;
reg [3:0] tag_fu0_2;

reg [SLOT_WIDTH-1:0] rs[DEPTH-1:0];
reg [COUNTER-1:0] back_ptr;
reg [COUNTER-1:0] found_ptr;

always @(*) tag0_1 = rs[0][`OP1];
always @(*) tag_dest0_1 = tag0_1[`TAG_DEST];
always @(*) tag_iss0_1 = tag0_1[`TAG_ISS_ID];
always @(*) tag_fu0_1 = tag0_1[`TAG_FU_ID];
always @(*) tag0_2 = rs[0][`OP2];
always @(*) tag_dest0_2 = tag0_2[`TAG_DEST];
always @(*) tag_iss0_2 = tag0_2[`TAG_ISS_ID];
always @(*) tag_fu0_2 = tag0_2[`TAG_FU_ID];

wire [0:0]rs0_OP1V;
wire [63:0]rs0_OP1;
wire [0:0]rs0_OP2V;
wire [63:0]rs0_OP2;
wire [4:0]rs0_DEST;
wire [31:0]rs0_IMM;
wire [31:0]rs0_RES_ID;
wire [0:0]rs0_SPECULATE_B;
wire [0:0]rs0_RS_VALID;
wire [6:0]rs0_OPCODE;

assign rs0_OP1V = rs[0][`OP1V];
assign rs0_OP1 = rs[0][`OP1];
assign rs0_OP2V = rs[0][`OP2V];
assign rs0_OP2 = rs[0][`OP2];
assign rs0_DEST = rs[0][`DEST];
assign rs0_IMM = rs[0][`IMM];
assign rs0_RES_ID = rs[0][`RES_ID];
assign rs0_SPECULATE_B = rs[0][`SPECULATE_B];
assign rs0_RS_VALID = rs[0][`RS_VALID];
assign rs0_OPCODE = rs[0][`OPCODE];





reg [DEPTH:0]rs_match_found1;
reg [DEPTH:0]rs_match_found2;


reg [TAG_WIDTH-1:0] tag1;
reg [TAG_WIDTH-1:0] tag2;
reg [2:0] match_type;

reg [DEPTH:0]load_instruction;
parameter LB = 7'd11;
parameter LH = 7'd12;
parameter LW = 7'd13;
parameter LBU = 7'd14;
parameter LHU = 7'd15;

//detect a ready insruction
always @(*) begin : tag_detection
    integer i;
    found_ptr = -1;
    tag1 = -1;
    tag2 = -1;
    match_type = -1;
    rs_match_found1 = 0;
    rs_match_found2 = 0;
    //check tag completion, and remove element if possible
    for( i=(DEPTH-1); i>=0; i = i - 1 ) if(i < back_ptr) begin
        tag1 = -1;
        tag2 = -1;

        //detect if instruction is a load
        load_instruction[i] = 0;
        case(rs[i][`OPCODE])   
            //Load
            LB, 
            LH, 
            LW,		
            LBU,	
            LHU : begin 
           	load_instruction[i] = 1;
            end
        endcase

        if(rs[i][`OP1V] == 1 && rs[i][`OP2V] == 0) begin
        //src1 ready
            tag2 = rs[i][`OP2];
        end

        if(rs[i][`OP1V] == 0 && rs[i][`OP2V] == 1) begin
        //src2 ready
            tag1 = rs[i][`OP1];
        end

        if(rs[i][`OP1V] == 0 && rs[i][`OP2V] == 0) begin
        //no sources ready
            tag1 = rs[i][`OP1];
            tag2 = rs[i][`OP2];
        end
        
        if(CDB_REG_ID != 0)  begin  
            //match on src2
            if(tag2[`TAG_DEST]==CDB_REG_ID && tag2[`TAG_FU_ID]==CDB_FU_ID && (tag2[`TAG_ISS_ID]==CDB_ISS_ID)) begin
                match_type = 2;
                if(!(pull_non_load && load_instruction[i])) if(rs[i][`OP1V] == 1) found_ptr = i; //only clear entry if other op is ready
                rs_match_found2[i]=1;
            end
                    
                    
            //match on src1
            if(tag1[`TAG_DEST]==CDB_REG_ID && tag1[`TAG_FU_ID]==CDB_FU_ID && (tag1[`TAG_ISS_ID]==CDB_ISS_ID)) begin
                match_type = 1;
                if(!(pull_non_load && load_instruction[i])) if(rs[i][`OP2V] == 1) found_ptr = i; //only clear entry if other op is ready
                rs_match_found1[i]=1;
            end

            //match on src1 and src2
            if(tag2[`TAG_DEST]==CDB_REG_ID && tag2[`TAG_FU_ID]==CDB_FU_ID && (tag2[`TAG_ISS_ID]==CDB_ISS_ID))
                if(tag1[`TAG_DEST]==CDB_REG_ID && tag1[`TAG_FU_ID]==CDB_FU_ID && (tag1[`TAG_ISS_ID]==CDB_ISS_ID)) begin
                    match_type = 3;
                    if(!(pull_non_load && load_instruction[i])) found_ptr = i;
                    rs_match_found2[i]=1;
                    rs_match_found1[i]=1;
                end
        end
        

        if(rs[i][`OP1V] == 1 && rs[i][`OP2V] == 1) begin
        //No tags
            if(!(pull_non_load && load_instruction[i])) found_ptr = i;
            match_type = 0;
        end
    end
end




assign rs_full = back_ptr >= DEPTH;
assign rs_empty = back_ptr == 0;

always @(*) begin
//check tag completion, and remove element if possible
    rdy = 0;
    
    decoded_opcode_r      = 0; 
    op1_r                 = 0;
    op2_r                 = 0;
    dest_r                = 0;
    imm_r                 = 0;
    res_id_r              = 0;
    if(!bypass && pull) begin
        if($signed(found_ptr) != -1) begin
            rdy = 1;
            //remove the extracted instruction
            case(match_type)
                0 : begin
                    decoded_opcode_r      = rs[found_ptr][`OPCODE];
                    op1_r                 = rs[found_ptr][`OP1];
                    op2_r                 = rs[found_ptr][`OP2];
                    dest_r                = rs[found_ptr][`DEST];
                    imm_r                 = rs[found_ptr][`IMM];
                    res_id_r              = rs[found_ptr][`RES_ID];
                    execute_stage_opcode_addr_r = rs[found_ptr][`PC_VAL];
                end
                1 : begin
                    decoded_opcode_r      = rs[found_ptr][`OPCODE];
                    op1_r                 = CDB;
                    op2_r                 = rs[found_ptr][`OP2];
                    dest_r                = rs[found_ptr][`DEST];
                    imm_r                 = rs[found_ptr][`IMM];
                    res_id_r              = rs[found_ptr][`RES_ID];
                    execute_stage_opcode_addr_r = rs[found_ptr][`PC_VAL];
                end
                2 : begin
                    decoded_opcode_r      = rs[found_ptr][`OPCODE];
                    op1_r                 = rs[found_ptr][`OP1];
                    op2_r                 = CDB;
                    dest_r                = rs[found_ptr][`DEST];
                    imm_r                 = rs[found_ptr][`IMM];
                    res_id_r              = rs[found_ptr][`RES_ID];
                    execute_stage_opcode_addr_r = rs[found_ptr][`PC_VAL];
                end
                3 : begin
                    decoded_opcode_r      = rs[found_ptr][`OPCODE];
                    op1_r                 = CDB;
                    op2_r                 = CDB;
                    dest_r                = rs[found_ptr][`DEST];
                    imm_r                 = rs[found_ptr][`IMM];
                    res_id_r              = rs[found_ptr][`RES_ID];
                    execute_stage_opcode_addr_r = rs[found_ptr][`PC_VAL];
                end
                default : ;
            endcase
            //handle speculative case
            case(rs[found_ptr][`OPCODE])
            JAL, 
            JALR,
            BEQ,
            BNE,
            BLT,
            BGE,
            BLTU,
            BGEU : if(!rs[found_ptr][`RS_VALID]) decoded_opcode_r = 0; //avoid combinational loop - branch instruction can drive prediction_failed
            default : if(!rs[found_ptr][`RS_VALID] || (prediction_failed && rs[found_ptr][`SPECULATE_B])) decoded_opcode_r = 0;
            endcase
        end
    end //bypass
    
end


reg [63:0] new_tag;
integer i;
//generate

always @(posedge clk) begin
    for (i = 0; i < DEPTH ; i = i + 1) begin : rs_entry
        if(reset) begin
            rs[i] <= {SLOT_WIDTH{1'h0}};
            back_ptr <= {COUNTER{1'h0}};
        end else begin
            if(!bypass) begin
                
                //shift all instructions, after removing the extracted one
                if($signed(found_ptr) != -1 && pull && back_ptr > 0) begin
                    if(i>=found_ptr && i<back_ptr && i < DEPTH-1) begin
                        rs[i] <= rs[i+1];
                    end
                    if(push) rs[back_ptr-1] <= {decoded_opcode, op1v, op1, op2v, op2, dest, imm, res_id, execute_stage_opcode_addr, push_branch_unresolved, 1'b1 /*start valid*/};
                    if(prediction_failed && rs[i][`SPECULATE_B] && i > 0)  rs[i-1][`RS_VALID] <= 0;
                    if(prediction_success && rs[i][`SPECULATE_B] && i > 0)  rs[i-1][`SPECULATE_B] <= 0;
                    //check common data bus for completed tags, and overwrite tags
                    //shifting case
                    if(i>=found_ptr && i<back_ptr) begin
                        if(rs_match_found1[i] && i > 0) begin
                            rs[i-1][`OP1]  <= CDB;
                            rs[i-1][`OP1V] <= 1;
                        end
                        if(rs_match_found2[i] && i > 0) begin
                            rs[i-1][`OP2]  <= CDB;
                            rs[i-1][`OP2V] <= 1;
                        end
                    end else if(i<back_ptr) begin
                        //instructions that don't rotate
                        if(rs_match_found1[i]) begin
                            rs[i][`OP1]  <= CDB;
                            rs[i][`OP1V] <= 1;
                        end
                        if(rs_match_found2[i]) begin
                            rs[i][`OP2]  <= CDB;
                            rs[i][`OP2V] <= 1;
                        end
                    end
                    
                    if(!push)back_ptr <= back_ptr-1;
                end else begin
                    //check common data bus for completed tags, and overwrite tags
                    //non-shifting case
                    if(prediction_failed && rs[i][`SPECULATE_B])  rs[i][`RS_VALID] <= 0;
                    if(prediction_success && rs[i][`SPECULATE_B])  rs[i][`SPECULATE_B] <= 0;
                    if(i<back_ptr) begin
                        if(rs_match_found1[i]) begin
                            rs[i][`OP1]  <= CDB;
                            rs[i][`OP1V] <= 1;
                        end
                        if(rs_match_found2[i]) begin
                            rs[i][`OP2]  <= CDB;
                            rs[i][`OP2V] <= 1;
                        end
                    end
                    case(push)
                    1'b1 : begin
                        //PUSH
                        if(back_ptr < DEPTH && i == back_ptr) begin
                            rs[back_ptr] <= {decoded_opcode, op1v, op1, op2v, op2, dest, imm, res_id, execute_stage_opcode_addr, push_branch_unresolved, 1'b1 /*start valid*/};
                            new_tag <= op1;
                            back_ptr <= back_ptr+1;
                        end
                    end
                    default:;
                    endcase
                end
            end //end bypass
            
        end
    end
end
//endgenerate // match generate


endmodule
