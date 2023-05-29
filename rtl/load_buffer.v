module load_buffer(
    //input
    clk,
    reset,
    store_buffer_match,
    pull_MEM_RS_raw,
    decoded_opcode_MEM_next,	
    op1_MEM_next,
    op2_MEM_next,
    dest_MEM_next,
    imm_MEM_next,
    res_id_MEM_next,
    execute_stage_opcode_addr_MEM_next,
    speculative,
    prediction_success,
    prediction_failed,

    //output
    computed_addr,
    search_store_buffer,
    decoded_opcode_MEM_next_load_queue_o,
    op1_MEM_next_load_queue_o,
    op2_MEM_next_load_queue_o,
    dest_MEM_next_load_queue_o,
    imm_MEM_next_load_queue_o,
    res_id_MEM_next_load_queue_o,
    execute_stage_opcode_addr_MEM_next_load_queue_o,

    pull_non_load_MEM,


    pull_MEM_RS



);

//////
//LOAD buffer (fixed size 1)
///////

parameter LB = 7'd11;
parameter LH = 7'd12;
parameter LW = 7'd13;
parameter LBU = 7'd14;
parameter LHU = 7'd15;

parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;

//ports
input clk;
input reset;

output reg [ADDR_WIDTH-1:0] computed_addr;
output reg search_store_buffer;
input store_buffer_match;

output reg [6:0]decoded_opcode_MEM_next_load_queue_o;	
output reg [63:0] op1_MEM_next_load_queue_o;
output reg [63:0] op2_MEM_next_load_queue_o;
output reg [4:0] dest_MEM_next_load_queue_o;
output reg [31:0] imm_MEM_next_load_queue_o;
output reg [31:0] res_id_MEM_next_load_queue_o;
output reg [ADDR_WIDTH-1:0] execute_stage_opcode_addr_MEM_next_load_queue_o;

output pull_non_load_MEM;

input pull_MEM_RS_raw;
output reg pull_MEM_RS;

input speculative;
input prediction_success;
input prediction_failed;


input [6:0]decoded_opcode_MEM_next;	
input [63:0] op1_MEM_next;
input [63:0] op2_MEM_next;
input [4:0] dest_MEM_next;
input [31:0] imm_MEM_next;
input [31:0] res_id_MEM_next;
input [ADDR_WIDTH-1:0] execute_stage_opcode_addr_MEM_next;

//buffer latches
reg [6:0]decoded_opcode_MEM_next_load_queue;	
reg [63:0] op1_MEM_next_load_queue;
reg [63:0] op2_MEM_next_load_queue;
reg [4:0] dest_MEM_next_load_queue;
reg [31:0] imm_MEM_next_load_queue;
reg [31:0] res_id_MEM_next_load_queue;
reg [ADDR_WIDTH-1:0] execute_stage_opcode_addr_MEM_next_load_queue;
reg buffer_full;
reg speculative_r;

//detect incoming load instruction + compute address
reg load_instruction;
always @(*) begin
    load_instruction = 0;
    computed_addr = -1;
    search_store_buffer = 0;
    case(decoded_opcode_MEM_next)   
        //Load
        LB, 
        LH, 
        LW,		
        LBU,	
        LHU : begin 
       	load_instruction = 1;
        end
    endcase

    if(load_instruction || buffer_full) computed_addr = buffer_full ? op1_MEM_next_load_queue + $signed(imm_MEM_next_load_queue) : op1_MEM_next + $signed(imm_MEM_next);
    if(load_instruction || buffer_full) search_store_buffer = 1;
end

//latch load instruction if conflict detected

always @(posedge clk) begin
    if(reset) begin
        decoded_opcode_MEM_next_load_queue              <= 'h0;	
        op1_MEM_next_load_queue                         <= 'h0;
        op2_MEM_next_load_queue                         <= 'h0;
        dest_MEM_next_load_queue                        <= 'h0;
        imm_MEM_next_load_queue                         <= 'h0;
        res_id_MEM_next_load_queue                      <= 'h0;
        execute_stage_opcode_addr_MEM_next_load_queue   <= 'h0;
        buffer_full                                     <= 'h0;
        speculative_r                                   <= 'h0;
    end else begin
        //store buffer match, load into buffer
        if(store_buffer_match && !buffer_full) begin
            decoded_opcode_MEM_next_load_queue              <= decoded_opcode_MEM_next;	
            op1_MEM_next_load_queue                         <= op1_MEM_next;
            op2_MEM_next_load_queue                         <= op2_MEM_next;
            dest_MEM_next_load_queue                        <= dest_MEM_next;
            imm_MEM_next_load_queue                         <= imm_MEM_next;
            res_id_MEM_next_load_queue                      <= res_id_MEM_next;
            execute_stage_opcode_addr_MEM_next_load_queue   <= execute_stage_opcode_addr_MEM_next;
            buffer_full                                     <= 'h1;
            speculative_r                                   <= speculative;
        end
        //store buffer match has cleared, issue load
        if(!store_buffer_match && buffer_full && pull_MEM_RS_raw) begin
            decoded_opcode_MEM_next_load_queue                  <= 'h0;	
            op1_MEM_next_load_queue                             <= 'h0;
            op2_MEM_next_load_queue                             <= 'h0;
            dest_MEM_next_load_queue                            <= 'h0;
            imm_MEM_next_load_queue                             <= 'h0;
            res_id_MEM_next_load_queue                          <= 'h0;
            execute_stage_opcode_addr_MEM_next_load_queue       <= 'h0;
            buffer_full                                         <= 'h0;
            speculative_r                                       <= 'h0;
        end
        //speculative result has resolved
        //prediction failed
        if(prediction_failed && speculative_r && buffer_full) begin
            decoded_opcode_MEM_next_load_queue                  <= 'h0;	
            op1_MEM_next_load_queue                             <= 'h0;
            op2_MEM_next_load_queue                             <= 'h0;
            dest_MEM_next_load_queue                            <= 'h0;
            imm_MEM_next_load_queue                             <= 'h0;
            res_id_MEM_next_load_queue                          <= 'h0;
            execute_stage_opcode_addr_MEM_next_load_queue       <= 'h0;
            buffer_full                                         <= 'h0;
            speculative_r                                       <= 'h0;
        end
        //prediction success
        if(prediction_success && speculative_r && buffer_full) begin
            speculative_r                                       <= 'h0;
        end
    end
end

assign pull_non_load_MEM = buffer_full;

//MUX the input to Mem_ctl
always @(*) begin
    if(store_buffer_match && !buffer_full) begin
        decoded_opcode_MEM_next_load_queue_o              = -1;	
        op1_MEM_next_load_queue_o                         = -1;
        op2_MEM_next_load_queue_o                         = -1;
        dest_MEM_next_load_queue_o                        = -1;
        imm_MEM_next_load_queue_o                         = -1;
        res_id_MEM_next_load_queue_o                      = -1;
        execute_stage_opcode_addr_MEM_next_load_queue_o   = -1;
    end else if((!store_buffer_match && buffer_full && pull_MEM_RS_raw) && !(prediction_failed && speculative_r && buffer_full)) begin
        decoded_opcode_MEM_next_load_queue_o              = decoded_opcode_MEM_next_load_queue;	
        op1_MEM_next_load_queue_o                         = op1_MEM_next_load_queue;
        op2_MEM_next_load_queue_o                         = op2_MEM_next_load_queue;
        dest_MEM_next_load_queue_o                        = dest_MEM_next_load_queue;
        imm_MEM_next_load_queue_o                         = imm_MEM_next_load_queue;
        res_id_MEM_next_load_queue_o                      = res_id_MEM_next_load_queue;
        execute_stage_opcode_addr_MEM_next_load_queue_o   = execute_stage_opcode_addr_MEM_next_load_queue;
    end else begin
        decoded_opcode_MEM_next_load_queue_o              = decoded_opcode_MEM_next;	
        op1_MEM_next_load_queue_o                         = op1_MEM_next;
        op2_MEM_next_load_queue_o                         = op2_MEM_next;
        dest_MEM_next_load_queue_o                        = dest_MEM_next;
        imm_MEM_next_load_queue_o                         = imm_MEM_next;
        res_id_MEM_next_load_queue_o                      = res_id_MEM_next;
        execute_stage_opcode_addr_MEM_next_load_queue_o   = execute_stage_opcode_addr_MEM_next;
    end
end
//MUX the pull request from Mem_ctl to Mem_ctl_RS
always @(*) begin
    if((!store_buffer_match && buffer_full && pull_MEM_RS_raw) && !(prediction_failed && speculative_r && buffer_full)) pull_MEM_RS = 0;
    else pull_MEM_RS = pull_MEM_RS_raw;
end
endmodule
