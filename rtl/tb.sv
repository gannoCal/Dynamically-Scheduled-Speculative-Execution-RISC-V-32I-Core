`timescale 1ns/1ps
module tb;
parameter ADDR_WIDTH = 15; //32k ram
	parameter DATA_WIDTH = 32;
	localparam DEPTH 		= 2**ADDR_WIDTH;
	cpu_control_interface 		cpu_control_if();
	cpu_sram_interface 		cpu_sram_if();
	int n_File_ID;

//initial begin
//$display("Hello, World");
	//#100000;
      //$finish ;
//end
//
	initial begin
		forever begin
			#10ps;
			cpu_control_if.clk = ~cpu_control_if.clk;
		end
	end

        int initial_pc_i;
        wire[ADDR_WIDTH-1:0] initial_pc;
        assign initial_pc = initial_pc_i;

	initial begin
		int sram_ctr;
		$dumpfile("wave.vcd");
		$dumpvars;
		sram_ctr = 0;
		cpu_control_if.reset = 1;
		cpu_control_if.clk = 0;
                initial_pc_i = 'h0;
		#1ns;

                //test1
		// program_sram(sram_ctr++,32'hfe010113);
		// program_sram(sram_ctr++,32'h00812e23);
		// program_sram(sram_ctr++,32'h02010413);
		// program_sram(sram_ctr++,32'h00200793);
		// program_sram(sram_ctr++,32'hfef42423);
		// program_sram(sram_ctr++,32'h00300793);
		// program_sram(sram_ctr++,32'hfef42223);
		// program_sram(sram_ctr++,32'hfe042623);
		// program_sram(sram_ctr++,32'hfe842783);
		// program_sram(sram_ctr++,32'h00179713);
		// program_sram(sram_ctr++,32'hfe442783);
		// program_sram(sram_ctr++,32'h40f70733);
		// program_sram(sram_ctr++,32'hfec42783);
		// program_sram(sram_ctr++,32'h00179793);
		// program_sram(sram_ctr++,32'h00f707b3);
		// program_sram(sram_ctr++,32'hfef42623);
		// program_sram(sram_ctr++,32'hfe1ff06f);
                // initial_pc_i = 'h0;
                 
                //test2
                 program_sram(sram_ctr++,32'h00050693); 
                 program_sram(sram_ctr++,32'h00000713); 
                 program_sram(sram_ctr++,32'h00000513); 
                 program_sram(sram_ctr++,32'h00d04e63); 
                 program_sram(sram_ctr++,32'h00008067); 
                 program_sram(sram_ctr++,32'h00178793); 
                 program_sram(sram_ctr++,32'hfef59ee3); 
                 program_sram(sram_ctr++,32'h00a78533); 
                 program_sram(sram_ctr++,32'h00170713); 
                 program_sram(sram_ctr++,32'h00e68863); 
                 program_sram(sram_ctr++,32'h00000793); 
                 program_sram(sram_ctr++,32'hfeb044e3); 
                 program_sram(sram_ctr++,32'hff1ff06f); 
                 program_sram(sram_ctr++,32'h00008067); 
                 
                 program_sram(sram_ctr++,32'hff010113); 
                 program_sram(sram_ctr++,32'h00112623); 
                 program_sram(sram_ctr++,32'h00812423); 
                 program_sram(sram_ctr++,32'h00912223); 
                 program_sram(sram_ctr++,32'h01212023); 
                 program_sram(sram_ctr++,32'h00000513); 
                 program_sram(sram_ctr++,32'h00600493); 
                 program_sram(sram_ctr++,32'h00200413); 
                 program_sram(sram_ctr++,32'h06300913); 
                 program_sram(sram_ctr++,32'h0080006f); 
                 program_sram(sram_ctr++,32'h00040493); 
                 program_sram(sram_ctr++,32'h00040593); 
                 program_sram(sram_ctr++,32'hf99ff0ef); 
                 program_sram(sram_ctr++,32'h00950533); 
                 program_sram(sram_ctr++,32'h40850433); 
                 program_sram(sram_ctr++,32'hfea956e3); 
                 program_sram(sram_ctr++,32'h00000513);           	
                 program_sram(sram_ctr++,32'h00c12083);           	
                 program_sram(sram_ctr++,32'h00812403);           	
                 program_sram(sram_ctr++,32'h00412483);           	
                 program_sram(sram_ctr++,32'h00012903);           	
                 program_sram(sram_ctr++,32'h01010113);           	
                 program_sram(sram_ctr++,32'h00008067); 
                 initial_pc_i = 'd14;
                 

                //test3
              //  program_sram(sram_ctr++,32'h00000113);         	
              //  program_sram(sram_ctr++,32'h00100613);         	
              //  program_sram(sram_ctr++,32'h00a00513);         	
              //  program_sram(sram_ctr++,32'h00a12023);        	
              //  program_sram(sram_ctr++,32'h00200593);         	
              //           	
              //  program_sram(sram_ctr++,32'h00a12023); 
              //  program_sram(sram_ctr++,32'h40c50533);        	
              //  program_sram(sram_ctr++,32'hfeb51ae3);         	         	
              //  program_sram(sram_ctr++,32'h00012503);         	
              //  program_sram(sram_ctr++,32'h00000513);         	
              //  program_sram(sram_ctr++,32'h00008067);
              //  initial_pc_i = 'h0;

		//init stack pointer
		//DUT.regmap[2] = 2**15 -1;
		DUT.Decode.regmap[2] = 500;
		//init x0
		DUT.Decode.regmap[0] = 0;
		//init s0/fp
		//DUT.regmap[8] = 2**15 -1;
		DUT.Decode.regmap[8] = 500;
		#5ns;
		cpu_control_if.reset = 0;
		#120ns;
		$display("Hello World");
		$finish;
	end

	task program_sram([ADDR_WIDTH-1:0]addr, [DATA_WIDTH-1:0]data);
		@(negedge cpu_control_if.clk);
		#5ps; // setup time (arbitrary)
		cpu_sram_if.en 	= 1;
		cpu_sram_if.sel 	= 1;
		cpu_sram_if.we		= 1;
		cpu_sram_if.addr	= addr;
		cpu_sram_if.data	= data;
		@(posedge cpu_control_if.clk);
		#3ps;// hold time (arbitrary)
		cpu_sram_if.en 	= 'hz;
		cpu_sram_if.sel 	= 'hz;
		cpu_sram_if.we		= 'hz;
		cpu_sram_if.addr	= 'hz;
		cpu_sram_if.data	= 'hz;
	endtask : program_sram

	assign cpu_sram_if.addr_w = cpu_sram_if.addr;
	assign cpu_sram_if.data_w = cpu_sram_if.data;
	assign cpu_sram_if.we_w = cpu_sram_if.we;
	assign cpu_sram_if.sel_w = cpu_sram_if.sel;
	assign cpu_sram_if.en_w = cpu_sram_if.en;

	Quartus_Verif_RISCV DUT(
		//power
		.reset(cpu_control_if.reset),
		.clk(cpu_control_if.clk),
		//sram
		.sram_addr(cpu_sram_if.addr_w),
		.sram_data(cpu_sram_if.data_w),
		.sram_we(cpu_sram_if.we_w),
		.sram_sel(cpu_sram_if.sel_w),
		.sram_en(cpu_sram_if.en_w),
		.PC_init(initial_pc)
	);

endmodule

interface cpu_control_interface();
	logic reset;
	logic clk;
endinterface


interface cpu_sram_interface();
	parameter ADDR_WIDTH = 15; //32k ram
	parameter DATA_WIDTH = 32;
	localparam DEPTH 		= 2**ADDR_WIDTH;

	logic	[ADDR_WIDTH-1:0]addr;
	logic  [DATA_WIDTH-1:0]data;
	logic we;
	logic sel;
	logic en;
	
	wire	[ADDR_WIDTH-1:0]addr_w;
	wire  [DATA_WIDTH-1:0]data_w;
	wire we_w;
	wire sel_w;
	wire en_w;
endinterface
