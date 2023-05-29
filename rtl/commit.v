module commit(
clk,
reset,
push_en,
push_reg,
push_branch_unresolved,
push_iss_id,
CDB_REG_ID,
CDB_ISS_ID,
CDB_EN,
regmap_i,
prediction_failed,
prediction_success,
//output
retired_regmap_o,
FULL

);
input clk;
input reset;

input push_en;
input push_branch_unresolved;
input [4:0]push_reg;
input [7:0] push_iss_id;

input [4:0]CDB_REG_ID; 
input [31:0]CDB_ISS_ID;
input CDB_EN;
genvar ij;
input	 		[1023:0]regmap_i;
wire [31:0] 		regmap[31:0];
generate for(ij=0; ij<32 ; ij=ij+1) begin : regmap_port_in
assign regmap[ij] = regmap_i[1023 - ij*32 -:32];
end endgenerate

output  	 		[1023:0]retired_regmap_o;
reg [31:0] 		retired_regmap[31:0];
generate for(ij=0; ij<32 ; ij=ij+1) begin : regmap_port_out
	assign retired_regmap_o[1023 - ij*32 -:32] = retired_regmap[ij];
end endgenerate

reg	[31:0] 		retired_regmap_r[31:0];


output FULL;


//reorder buffer
//Buffer
parameter SLOT_WIDTH = 16;
parameter DEPTH = 15;
parameter COUNTER = 4; //clog2(DEPTH)

//1 bits valid entry
`define VALID_ENTRY (SLOT_WIDTH-1)-:1
// 1 bit pending flag 
`define PENDING_FU (SLOT_WIDTH-1)-1-:1
// 1 bit speculative branch
`define SPECULATIVE (SLOT_WIDTH-1)-2-:1
//5 bits destination
`define DEST_SLOT (SLOT_WIDTH-1)-3-:5
//8 bits issue id
`define ISS_ID (SLOT_WIDTH-1)-8-:8
//Total 16 bits per slot

reg [SLOT_WIDTH-1:0] rob[DEPTH-1:0];
reg [4:0] entry_address[DEPTH-1:0];
reg [4:0] head_address;
input prediction_failed;
input prediction_success;
reg [COUNTER-1:0] back_ptr;
wire push_en_i[DEPTH-1:0];
wire push_en_rot[DEPTH-1:0];
//monitors
wire speculative[DEPTH-1:0];
wire valid[DEPTH-1:0];
wire pending[DEPTH-1:0];

reg push_en_i_any;
reg push_en_rot_any;
integer j;
always @(*) begin
    push_en_i_any       = 0;
    push_en_rot_any     = 0;
    for (j = 0; j < DEPTH ; j=j+1) begin
        if(push_en_i[j]) push_en_i_any = 1;
        if(push_en_rot[j]) push_en_rot_any = 1;
    end
end

always @(*) begin : regmap_mappings
    integer ii;
    for(ii = 0 ; ii < 32 ; ii = ii+1) retired_regmap[ii] = 32'h0;
    
    if(prediction_failed) begin : more_regmap_mappings
        //clear the buffer
        integer k;
        for(k=0;k<32;k=k+1) retired_regmap[k] = retired_regmap_r[k];
        for (j = 0; j < DEPTH ; j=j+1) begin
            if(rob[j][`VALID_ENTRY] && !rob[j][`PENDING_FU]) retired_regmap[rob[j][`DEST_SLOT]] = regmap[rob[j][`DEST_SLOT]];
        end
    end
end

assign FULL = back_ptr >= DEPTH;

//monitors
genvar ii;
generate
for (ii = 0; ii < DEPTH ; ii=ii+1) begin : assign_monitor
    wire [SLOT_WIDTH-1:0] tmp;
    wire [1-1:0] VALID_ENTRY_val;
    wire [1-1:0] PENDING_FU_val;
    wire [1-1:0] SPECULATIVE_val;
    wire [5-1:0] DEST_SLOT_val;
    wire [8-1:0] ISS_ID_val;
    assign tmp = rob[ii];
    assign VALID_ENTRY_val = rob[ii][`VALID_ENTRY];
    assign PENDING_FU_val = rob[ii][`PENDING_FU];
    assign SPECULATIVE_val = rob[ii][`SPECULATIVE];
    assign DEST_SLOT_val = rob[ii][`DEST_SLOT];
    assign ISS_ID_val = rob[ii][`ISS_ID];
end endgenerate




//generate push location detectors


    genvar iii;
    generate for(iii=0 ; iii < DEPTH ; iii=iii+1) begin : push_en_gen
        assign push_en_i[iii] = push_en && back_ptr < DEPTH && iii == back_ptr && $signed(push_reg) != -1 && $signed(push_reg) != 0;
        assign push_en_rot[iii] = push_en && back_ptr <= DEPTH && iii == back_ptr && $signed(push_reg) != -1 && $signed(push_reg) != 0;
    end endgenerate

    
reg [1:0] type_i;
integer i;
     always @(*) for (i = 0; i < DEPTH ; i=i+1) entry_address[i] = rob[i][`DEST_SLOT];
    
always @(posedge clk) begin : rs_pop
    for (i = 0; i < DEPTH ; i=i+1) begin : rs_entry
        if(reset) begin : regmap_values
            integer ii;
            rob[i] <= {SLOT_WIDTH{1'h0}};
            back_ptr <= {COUNTER{1'h0}};
            
            for(ii = 0 ; ii < 32 ; ii = ii+1) retired_regmap_r[ii] <= 'h0;
        end else begin
            
            
            type_i <= 3;
            if(rob[0][`PENDING_FU] == 0 && rob[0][`VALID_ENTRY] == 1 /*&& rob[0][`SPECULATIVE] == 0*/ && back_ptr != 0) begin
                //if head is not pending, copy frontend regmap to retired regmap
                type_i <= 0;
                retired_regmap_r[entry_address[0]] <= regmap[entry_address[0]];
                
                if(!push_en_rot_any) back_ptr <= back_ptr-1;
                if(i < DEPTH - 1) rob[i] <= rob[i+1];
                else  rob[i] <= 'h0;
                
                //if branch resolved, invalidate speculative instructions
                if(prediction_failed && rob[i][`SPECULATIVE] && i > 0) rob[i-1][`VALID_ENTRY] <= 0;
                if(prediction_success && rob[i][`SPECULATIVE] && i > 0) rob[i-1][`SPECULATIVE] <= 0;
                if(push_en_rot[i]) begin
                        rob[back_ptr-1][`VALID_ENTRY] <= 1;
                        rob[back_ptr-1][`PENDING_FU] <= 1;
                        rob[back_ptr-1][`SPECULATIVE] <= push_branch_unresolved;
                        rob[back_ptr-1][`DEST_SLOT] <= push_reg;
                        rob[back_ptr-1][`ISS_ID] <= push_iss_id;    
                end
                if(i != 0 && i < back_ptr && CDB_REG_ID == rob[i][`DEST_SLOT] && CDB_ISS_ID == rob[i][`ISS_ID]) begin rob[i-1][`PENDING_FU] <= 0; end//set the pending flag in the updated WB slot -- notice it moved
                
            end else if(rob[0][`VALID_ENTRY] == 0 && back_ptr != 0) begin
                //if head is not valid, discard
                type_i <= 1;
                if(!push_en_rot_any) back_ptr <= back_ptr-1;
                if(i < DEPTH - 1) rob[i] <= rob[i+1];
                else  rob[i] <= 'h0;
                
                //if branch resolved, invalidate speculative instructions
                if(prediction_failed && rob[i][`SPECULATIVE] && i > 0) rob[i-1][`VALID_ENTRY] <= 0;
                if(prediction_success && rob[i][`SPECULATIVE] && i > 0) rob[i-1][`SPECULATIVE] <= 0;
                if(push_en_rot[i]) begin
                    rob[back_ptr-1][`VALID_ENTRY] <= 1;
                    rob[back_ptr-1][`PENDING_FU] <= 1;
                    rob[back_ptr-1][`SPECULATIVE] <= push_branch_unresolved;
                    rob[back_ptr-1][`DEST_SLOT] <= push_reg;
                    rob[back_ptr-1][`ISS_ID] <= push_iss_id;  
                end
                if(i != 0 && i < back_ptr && CDB_REG_ID == rob[i][`DEST_SLOT] && CDB_ISS_ID == rob[i][`ISS_ID]) rob[i-1][`PENDING_FU] <= 0; //set the pending flag in the updated WB slot -- notice it moved
            end else begin
                type_i <= 2;
                
                //if branch resolved, invalidate speculative instructions
                if(prediction_failed && rob[i][`SPECULATIVE]) rob[i][`VALID_ENTRY] <= 0;
                if(prediction_success && rob[i][`SPECULATIVE]) rob[i][`SPECULATIVE] <= 0;
                if(push_en_i[i]) begin
                    rob[back_ptr][`VALID_ENTRY] <= 1;
                    rob[back_ptr][`PENDING_FU] <= 1;
                    rob[back_ptr][`SPECULATIVE] <= push_branch_unresolved;
                    rob[back_ptr][`DEST_SLOT] <= push_reg;
                    rob[back_ptr][`ISS_ID] <= push_iss_id;
                    back_ptr <= back_ptr+1;
                end
                if(i < back_ptr && CDB_REG_ID == rob[i][`DEST_SLOT] && CDB_ISS_ID == rob[i][`ISS_ID]) rob[i][`PENDING_FU] <= 0;//set the pending flag in the static WB slot
            end
            
        
            
            
        end
    end
end
//endgenerate // match generate

endmodule
