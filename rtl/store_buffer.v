module store_buffer(
  //input
  clk,
  reset,

  store_addr_i,
  store_data_i,
  store_speculative_i,
  store_addr_tag_i,
  store_data_tag_i,
  store_imm_i,
  push,

    search_store_buffer,
    computed_addr,

  store_addr_active,
  store_data_active,
  prediction_success,
  prediction_failed,

//CDB input
CDB,
CDB_REG_ID,
CDB_FU_ID,
CDB_ISS_ID,



  //output
  SBUFF_FULL,
    store_buffer_match
);

//Parameters
parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;

input clk;
input reset;

input [64-1:0]          store_addr_i; // 64 bits to account for tags
input [64-1:0]          store_data_i;
input                   store_speculative_i;
input                   store_addr_tag_i;
input                   store_data_tag_i;
input [11:0]            store_imm_i;
input                   push;

input [ADDR_WIDTH-1:0]  store_addr_active;
input [DATA_WIDTH-1:0]  store_data_active;
input                   prediction_success;
input                   prediction_failed;

output                  SBUFF_FULL;

input [63:0]CDB;
input [4:0]CDB_REG_ID; 
input [3:0]CDB_FU_ID; 
input [31:0]CDB_ISS_ID;

input [ADDR_WIDTH-1:0] computed_addr;
input search_store_buffer;
output reg store_buffer_match;

//slot width
parameter SB_SLOT_WIDTH = 64 + 64 + 16;
parameter DEPTH = 15;
parameter COUNTER = 4; //clog2(DEPTH)

//1 bits valid entry
`define VALID_ENTRY (SB_SLOT_WIDTH-1)-:1
// 1 bit speculative branch
`define SPECULATIVE (SB_SLOT_WIDTH-1)-1-:1
//X bits DATA
`define DATA_SLOT (SB_SLOT_WIDTH-1)-2-:64
//X bits ADDR
`define ADDR_SLOT (SB_SLOT_WIDTH-1)-(2+64)-:64
// 1 bit tag flag
`define ADDR_TAG (SB_SLOT_WIDTH-1)-(2+64 + 64)-:1
// 1 bit tag flag
`define DATA_TAG (SB_SLOT_WIDTH-1)-(3+64 + 64)-:1
// 12 bit imm storage
`define IMM (SB_SLOT_WIDTH-1)-(4+64 + 64)-:12
//Total 64 + 64 + 16 bits per slot

reg [SB_SLOT_WIDTH-1:0] sbuff[DEPTH-1:0];
reg [COUNTER-1:0] back_ptr;
reg [COUNTER:0] found_ptr;

assign SBUFF_FULL = back_ptr == DEPTH;

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

//search the store buffer for LOAD conflicts
integer j;
always @(*) begin
    store_buffer_match = 0;
    if(search_store_buffer) begin
        for (j = DEPTH - 1; j >= 0 ; j=j-1) begin : sbuff_detect_load_conflict
            if(!sbuff[j][`ADDR_TAG] && sbuff[j][`ADDR_SLOT] == computed_addr && sbuff[j][`VALID_ENTRY] && found_ptr != j) store_buffer_match = 1;
        end
    end
end

//monitors
genvar ii;
generate
for (ii = 0; ii < DEPTH ; ii=ii+1) begin : assign_monitor_sbuff
    wire [SB_SLOT_WIDTH-1:0] tmp;
    wire [1-1:0] VALID_ENTRY_val;
    wire [1-1:0] SPECULATIVE_val;
    wire [64-1:0] ADDR_SLOT_val;
    wire [64-1:0] DATA_SLOT_val;
    wire [1-1:0] ADDR_TAG_val;
    wire [1-1:0] DATA_TAG_val;
    wire [12-1:0] IMM_val;
    assign tmp = sbuff[ii];
    assign VALID_ENTRY_val = sbuff[ii][`VALID_ENTRY];
    assign SPECULATIVE_val = sbuff[ii][`SPECULATIVE];
    assign ADDR_SLOT_val = sbuff[ii][`ADDR_SLOT];
    assign DATA_SLOT_val = sbuff[ii][`DATA_SLOT];
    assign ADDR_TAG_val = sbuff[ii][`ADDR_TAG];
    assign DATA_TAG_val = sbuff[ii][`DATA_TAG];
    assign IMM_val = sbuff[ii][`IMM];

    wire [4:0] DATA_TAG_TAG_DEST_val;
    wire [31:0] DATA_TAG_TAG_ISS_ID_val;
    wire [3:0] DATA_TAG_TAG_FU_ID_val;

    wire [4:0] ADDR_TAG_TAG_DEST_val;
    wire [31:0] ADDR_TAG_TAG_ISS_ID_val;
    wire [3:0] ADDR_TAG_TAG_FU_ID_val;

    assign DATA_TAG_TAG_DEST_val = !DATA_TAG_val ? 0 : DATA_SLOT_val[`TAG_DEST];
    assign DATA_TAG_TAG_ISS_ID_val = !DATA_TAG_val ? 0 : DATA_SLOT_val[`TAG_ISS_ID];
    assign DATA_TAG_TAG_FU_ID_val = !DATA_TAG_val ? 0 : DATA_SLOT_val[`TAG_FU_ID];

    assign ADDR_TAG_TAG_DEST_val = !ADDR_TAG_val ? 0 : ADDR_SLOT_val[`TAG_DEST];
    assign ADDR_TAG_TAG_ISS_ID_val = !ADDR_TAG_val ? 0 : ADDR_SLOT_val[`TAG_ISS_ID];
    assign ADDR_TAG_TAG_FU_ID_val = !ADDR_TAG_val ? 0 : ADDR_SLOT_val[`TAG_FU_ID];

    
end endgenerate

//capture tag values
wire [64-1:0] data_tags[DEPTH-1:0];
wire [64-1:0] addr_tags[DEPTH-1:0];

genvar iii;
generate
for (iii = 0; iii < DEPTH ; iii=iii+1) begin : capture_tags_sbuff
    wire [64-1:0] ADDR_SLOT_val;
    wire [64-1:0] DATA_SLOT_val;
    wire [1-1:0] ADDR_TAG_val;
    wire [1-1:0] DATA_TAG_val;
    assign ADDR_SLOT_val = sbuff[iii][`ADDR_SLOT];
    assign DATA_SLOT_val = sbuff[iii][`DATA_SLOT];
    assign ADDR_TAG_val = sbuff[iii][`ADDR_TAG];
    assign DATA_TAG_val = sbuff[iii][`DATA_TAG];

    assign data_tags[iii][`TAG_DEST] = !DATA_TAG_val ? -1 : DATA_SLOT_val[`TAG_DEST];
    assign data_tags[iii][`TAG_ISS_ID] = !DATA_TAG_val ? -1 : DATA_SLOT_val[`TAG_ISS_ID];
    assign data_tags[iii][`TAG_FU_ID] = !DATA_TAG_val ? -1 : DATA_SLOT_val[`TAG_FU_ID];

    assign addr_tags[iii][`TAG_DEST] = !ADDR_TAG_val ? -1 : ADDR_SLOT_val[`TAG_DEST];
    assign addr_tags[iii][`TAG_ISS_ID] = !ADDR_TAG_val ? -1 : ADDR_SLOT_val[`TAG_ISS_ID];
    assign addr_tags[iii][`TAG_FU_ID] = !ADDR_TAG_val ? -1 : ADDR_SLOT_val[`TAG_FU_ID];

    
end endgenerate


//detect store buffer clearances
integer j2;
always @(*) begin
    
    found_ptr = -1;
    for (j2 = DEPTH - 1; j2 >= 0 ; j2=j2-1) begin : sbuff_detect
        if(sbuff[j2][`ADDR_SLOT] == store_addr_active && sbuff[j2][`DATA_SLOT] == store_data_active) found_ptr = j2;
        if(!sbuff[j2][`VALID_ENTRY] && j2 < back_ptr) found_ptr = j2;
    end
end

//sequential store buffer operations
integer i;
always @(posedge clk) begin
    
    for (i = 0; i < DEPTH ; i=i+1) begin : sbuff_entry
        if(reset) begin
            sbuff[i] <= {SB_SLOT_WIDTH{1'h0}};
            back_ptr <= {COUNTER{1'h0}};
        end else begin
            
            if(sbuff[i][`SPECULATIVE] && prediction_failed) sbuff[i][`VALID_ENTRY] <= 0;
            if(sbuff[i][`SPECULATIVE] && prediction_success) sbuff[i][`SPECULATIVE] <= 0;
            if(sbuff[i][`ADDR_SLOT] == store_addr_active && sbuff[i][`DATA_SLOT] == store_data_active) sbuff[i][`VALID_ENTRY] <= 0;
            
            //Push / Clear Handler
            case({push, $signed(found_ptr) != -1})
                //no push, no clear
                2'b00 : begin
                    
                end

                //no push, clear
                2'b01 : begin
                    //shift entries younger than match
                    if(i>=found_ptr && i<back_ptr && i < DEPTH-1) begin
                        sbuff[i] <= sbuff[i+1];
                        if(sbuff[i+1][`SPECULATIVE] && prediction_failed) sbuff[i][`VALID_ENTRY] <= 0;
                        if(sbuff[i+1][`SPECULATIVE] && prediction_success) sbuff[i][`SPECULATIVE] <= 0;
                        if(sbuff[i+1][`ADDR_SLOT] == store_addr_active && sbuff[i+1][`DATA_SLOT] == store_data_active) sbuff[i][`VALID_ENTRY] <= 0;
                        back_ptr <= back_ptr - 1;
                    end
                end
                
                //push, no clear
                2'b10 : begin
                    //add new entry to buffer
                     if(back_ptr < DEPTH) begin
                         sbuff[back_ptr][`VALID_ENTRY]   <= 1;
                         sbuff[back_ptr][`SPECULATIVE]   <= store_speculative_i;
                         sbuff[back_ptr][`ADDR_SLOT]     <= store_addr_i;
                         sbuff[back_ptr][`DATA_SLOT]     <= store_data_i;
                         sbuff[back_ptr][`ADDR_TAG]      <= store_addr_tag_i;
                         sbuff[back_ptr][`DATA_TAG]      <= store_data_tag_i;
                         sbuff[back_ptr][`IMM]           <= store_imm_i;
                         back_ptr <= back_ptr + 1;
                     end
                end

                //push, clear
                2'b11 : begin
                    //add new entry to buffer 
                    sbuff[back_ptr-1][`VALID_ENTRY]   <= 1;
                    sbuff[back_ptr-1][`SPECULATIVE]   <= store_speculative_i;
                    sbuff[back_ptr-1][`ADDR_SLOT]     <= store_addr_i;
                    sbuff[back_ptr-1][`DATA_SLOT]     <= store_data_i;
                    sbuff[back_ptr-1][`ADDR_TAG]      <= store_addr_tag_i;
                    sbuff[back_ptr-1][`DATA_TAG]      <= store_data_tag_i;
                    sbuff[back_ptr-1][`IMM]           <= store_imm_i;
                     

                    //shift entries younger than match
                    if(i>=found_ptr && i<back_ptr && i < DEPTH-1) begin
                        sbuff[i] <= sbuff[i+1];
                        if(sbuff[i+1][`SPECULATIVE] && prediction_failed) sbuff[i][`VALID_ENTRY] <= 0;
                        if(sbuff[i+1][`SPECULATIVE] && prediction_success) sbuff[i][`SPECULATIVE] <= 0;
                        if(sbuff[i+1][`ADDR_SLOT] == store_addr_active && sbuff[i+1][`DATA_SLOT] == store_data_active) sbuff[i][`VALID_ENTRY] <= 0;
                    end
                
                end
            endcase

            //TAG Handler
            case( i > found_ptr)
                //no shifting
                0 : begin
                    
                    //update tags
                     if(sbuff[i][`ADDR_TAG] && addr_tags[i][`TAG_DEST] == CDB_REG_ID && addr_tags[i][`TAG_ISS_ID] == CDB_ISS_ID && addr_tags[i][`TAG_FU_ID] == CDB_FU_ID) begin
                         sbuff[i][`ADDR_TAG] <= 0;
                         sbuff[i][`ADDR_SLOT] <= CDB + $signed(sbuff[i][`IMM]);
                     end

                     if(sbuff[i][`DATA_TAG] && data_tags[i][`TAG_DEST] == CDB_REG_ID && data_tags[i][`TAG_ISS_ID] == CDB_ISS_ID && data_tags[i][`TAG_FU_ID] == CDB_FU_ID) begin
                         sbuff[i][`DATA_TAG] <= 0;
                         sbuff[i][`DATA_SLOT] <= CDB;
                     end

                end

                //instructions will shift
                1 : begin
                    if(i >= 1) begin
                        //update tags
                        if(sbuff[i-1][`ADDR_TAG] && addr_tags[i-1][`TAG_DEST] == CDB_REG_ID && addr_tags[i-1][`TAG_ISS_ID] == CDB_ISS_ID && addr_tags[i-1][`TAG_FU_ID] == CDB_FU_ID) begin
                            sbuff[i-1][`ADDR_TAG] <= 0;
                            sbuff[i-1][`ADDR_SLOT] <= CDB + $signed(sbuff[i-1][`IMM]);
                        end

                        if(sbuff[i-1][`DATA_TAG] && data_tags[i-1][`TAG_DEST] == CDB_REG_ID && data_tags[i-1][`TAG_ISS_ID] == CDB_ISS_ID && data_tags[i-1][`TAG_FU_ID] == CDB_FU_ID) begin
                            sbuff[i-1][`DATA_TAG] <= 0;
                            sbuff[i-1][`DATA_SLOT] <= CDB;
                        end
                    end
                
                end
            endcase
        end
    end
end


endmodule
