module  uart_rx_tb;

	// Inputs
	reg clk;
	reg rst_n;

	reg [7:0] in_data;

	// Outputs
	wire tx;
    wire busy;

	// Instantiate the Unit Under Test (UUT)
	uart_rx uut (
        // connect the port for me automatically
        .*
	);

    always #1 clk = ~clk;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst_n = 0;
		rx = 1;

		// Wait 100 ns for global reset to finish
		#20;

		// Add stimulus here
        rst_n = 1;

        #20;
        // Generate Start bit
        #2 rx = 1'b0;
        // 8 data bits
        // 10101010 = decimal
        #2 rx = 1'b1;
        #2 rx = 1'b0;
        #2 rx = 1'b1;
        #2 rx = 1'b0;
        #2 rx = 1'b1;
        #2 rx = 1'b0;
        #2 rx = 1'b1;
        #2 rx = 1'b0;

        // Generate Stop bit
        #2 rx = 1'b1;

        // Generate start bit
        #10 rx = 1'b0;

        // Data bits, 00101101
        #2 rx = 1'b0;
        #2 rx = 1'b0;
        #2 rx = 1'b1;
        #2 rx = 1'b0;
        #2 rx = 1'b1;
        #2 rx = 1'b1;
        #2 rx = 1'b0;
        #2 rx = 1'b1;

        // Generate stop bits
        #2 rx = 1'b1;
	end




endmodule