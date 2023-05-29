module single_port_sync_sram(
	clk,
	addr,
	data,
	sel,
	we,
	en
);
/*verilator public_module*/
//Parameters
parameter ADDR_WIDTH = 15; //32k ram
parameter DATA_WIDTH = 32;
localparam DEPTH 		= 2**ADDR_WIDTH;


//Ports
input							clk;
input	[ADDR_WIDTH-1:0] 	addr;
inout [DATA_WIDTH-1:0]	data;
input							sel;
input							we;
input							en;

//signals
reg	[DATA_WIDTH-1:0] tmp_data;
reg 	[DATA_WIDTH-1:0] mem [DEPTH:0];

always @ (posedge clk) begin 
	case({sel, we})
		2'b11 : mem[addr] <= data;
		2'b10 : tmp_data  <= mem[addr];
	endcase
end

assign data = sel & en & !we ? tmp_data : 'hz;


endmodule
