module  uart_tx_tb;

	// Inputs
	reg clk;
	reg rst_n;
	reg[7:0] in_data;
    reg start;

	// Outputs
    wire busy,tx;

	// Instantiate the Unit Under Test (UUT)
	uart_tx uut (
        // connect the port for me automatically
        .*
	);

    always #1 clk = ~clk;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst_n = 0;
		start = 1'b0;
		in_data = 0;

		// Wait 100 ns for global reset to finish
		#20; rst_n = 1;

        #10;

		for(int i = 0; i < 10; i++) begin
        	#2 start = 1'b1;
				// generate a random 8 bit data
				in_data = $random;
			#2 start = 1'b0;

			// Give condition wait until busy is 0
			while(busy) begin
				#2;
			end
		end

	end




endmodule