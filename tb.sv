`timescale 1ns/1ps
`define CYCLE 10.0

module tb;

	parameter int NO_OF_PSENSORS = 10;
	parameter int NO_OF_VSENSORS = 4;
	parameter int NO_OF_TSENSORS = 8;
	parameter int TEST_CASES = 1000;
	localparam int NO_OF_GROUPS = max(max(NO_OF_PSENSORS, NO_OF_VSENSORS), NO_OF_TSENSORS);
	localparam int addr_width   = $clog2(NO_OF_GROUPS*4);

    logic       clk;
    logic       rstn;

	logic [addr_width+1:0] s_apb_addr;
	logic 	     s_apb_sel;
	logic 	     s_apb_enable;
	logic 	     s_apb_write;
	logic [31:0] s_apb_wdata;
	logic [ 3:0] s_apb_wstrb; // not use
	logic [31:0] s_apb_rdata;
	logic 	     s_apb_ready;
	logic 	     s_apb_slverr;

	integer j;
	int rand_num;

	apb_pvt_sensor #(.NO_OF_PSENSORS(NO_OF_PSENSORS),
					 .NO_OF_VSENSORS(NO_OF_VSENSORS),
					 .NO_OF_TSENSORS(NO_OF_TSENSORS),
					 .NO_OF_GROUPS(NO_OF_GROUPS) )u_apb_pvt_sensor (
    	.s_apb_clk      (clk),
    	.s_apb_rstn     (rstn),
    	.s_apb_addr     (s_apb_addr),
    	.s_apb_sel      (s_apb_sel),
    	.s_apb_enable   (s_apb_enable),
    	.s_apb_write    (s_apb_write),
    	.s_apb_wdata    (s_apb_wdata),
    	.s_apb_wstrb	(s_apb_wstrb),
    	.s_apb_rdata    (s_apb_rdata),
    	.s_apb_ready    (s_apb_ready),
	    .s_apb_slverr	(s_apb_slverr)
	);

	// open a file
	// integer file;
	// initial begin
		// file = $fopen("tb_apb_pvt_sensor.txt", "w");
	// end


	// always@(s_apb_write)
	// begin
		// $display("Time : %t", $realtime);
		// $write(file, "Time : %t\n", $realtime);
		// write result to a file
		// for(int i = 0; i < NO_OF_GROUPS; i = i + 1)begin
			// $display("slave register %d: %h", i,apb_pvt_sensor.slv_reg[i]);
			// $write("slave register 0: %h\n",apb_pvt_sensor.slv_reg[i]);
		// end
	// end


    initial begin
    	clk = 0;
	end
	always #(`CYCLE/2.0) clk = ~clk;

    initial begin
        // $fsdbDumpfile("tb_apb_pvt_sensor.fsdb");
        // $fsdbDumpvars(0, tb, "+mda");
    end

    initial begin
	    j = 0;
		rstn	= 1;
		s_apb_sel = 0;
		s_apb_addr = 0;
		s_apb_enable = 0;
		s_apb_write = 0;
		s_apb_wdata = 0;
		s_apb_wstrb = 0;
		@(posedge clk) rstn = 0;
		@(posedge clk) rstn = 1;

		// Test 4 cases , 1,1,1 , 2,1,1 , 32,32,32 , 15,4,8
		// addr should be a multiple of 4
		for(j = 0; j < NO_OF_GROUPS; j = j + 1) begin
			// This write the control register
			apb_write ((j*4)*4, 32'b0000_0000_0000_0001_1111_1111_1100_0011, 4'hf);
			apb_read  ((j*4)*4);
			apb_read  ((j*4+1)*4);
			apb_read  ((j*4+2)*4);
			apb_read  ((j*4+3)*4);
		end

		// random test, generate random number and write to rand_num
		for(int i = 0 ;i< TEST_CASES ; i=i+1)
		begin
			rand_num = $random;
			rand_num = rand_num % NO_OF_GROUPS;

			// Note only the enable p,v,t sensor would return the valid back certain cycles
			// after the enable is pulled down

			// Write t sensors 8's register c0,c1,a
			apb_write ((rand_num*4 + NO_OF_GROUPS)*4 , $random, 4'hf);
			apb_read  ((rand_num*4 + NO_OF_GROUPS)*4+rand_num%4);
		end

		repeat(10) @(posedge clk);
		$finish;
	end

	task apb_write;
		input [ addr_width+1:0] addr;
		input [31:0] wdata;
		input [ 3:0] wstrb;

		@(posedge clk);
		s_apb_sel = 1'b1;
		s_apb_addr = addr;
		s_apb_write = 1;
		s_apb_enable = 0;
		s_apb_wdata = wdata;
		s_apb_wstrb = 4'hf;

		@(posedge clk);
		s_apb_enable = 1;

		while (s_apb_enable & ~s_apb_ready) @(posedge clk);
		s_apb_sel = 1'b0;
		s_apb_wstrb = 4'h0;
	endtask

	task apb_read;
		input  logic [addr_width+1:0] addr;

		@(posedge clk);
		s_apb_sel = 1'b1;
		s_apb_addr = addr;
		s_apb_write = 0;
		s_apb_enable = 0;

		@(posedge clk);
		s_apb_enable = 1;

		while (s_apb_enable & ~s_apb_ready) @(posedge clk);
		s_apb_sel = 1'b0;
		s_apb_enable = 1'b0;
	endtask
endmodule

// // Function to find the maximum of two values
// function int max(input int a, input int b);
//   if (a > b)
//     max = a;
//   else
//     max = b;
// endfunction
