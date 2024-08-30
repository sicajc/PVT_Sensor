`include "DEFINE.svh"

module pvt_sensor_wrapper_tb;

  // define the ports of pvt_sensor_wrapper for me
    reg clk;
    reg rst_n;

    reg tx;
    wire rx;

    reg[7:0] received_data;
    reg[31:0] c0_coef;

  parameter TYPE = 0;
  parameter GROUP_NO = 0;

  // instantiate the unit under test (UUT)
  pvt_sensor_wrapper #(.TYPE(TYPE),.GROUP_NO(GROUP_NO)) uut (
    // connect the port for me automatically
    .clk(clk),
    .rst_n(rst_n),

    .rx(tx),

    .tx(rx)
  );

// declare a clk for me
    always #(`CYCLE/2) clk = ~clk;

  // Initial block to apply test stimuli
  initial
  begin
    $display("Test Case 1: Initial state");
    // Add your initial state checks here
    reset_task;
    #10;

    // Test case 1: write en signal to t sensor
    $display("Test Case 2: write en signal to t sensor #0");
    // First send addr/type, enabling the tsensor
    uart_send_type_addr(3'd0,5'd0 );

    // Then send data
    uart_send_u8(8'd1);

    #(`CYCLE*20);

    // Set en to 0
    uart_send_type_addr(3'd0,5'd0);

    // send data
    uart_send_u8(8'd0);

    #(`CYCLE*20);

    // Write coef to t sensor
    $display("Test Case 3: write coef to t sensor #0");
    // send addr/type, enabling the tsensor
    uart_send_type_addr(3'd0,5'd0 );

    // Then send data
    c0_coef = 32'h10101010;
    uart_send_u8(c0_coef[31:24]);
    uart_send_u8(c0_coef[23:16]);
    uart_send_u8(c0_coef[15:8]);
    uart_send_u8(c0_coef[7:0]);

    // Read from psensor
    $display("Test Case 3: read from t sensor #0");
    uart_send_type_addr(3'd2,5'd0);
    uart_receive_task(received_data);
    $display("Data from p sensor #0: %h", received_data);
    assert(received_data == 8'h00);

    // End simulation
    $finish;
  end

    // Task to reset the DUT
    task reset_task;
        // force clk 0
        force clk = 0;
        tx = 1'b1;
        // Apply reset
        rst_n = 1;
        // Wait for some time
        #(`CYCLE*5);
        // Release reset
        rst_n = 0;
        // add clk
        // Wait for some time
        #(`CYCLE*5);
        rst_n = 1;
        // add clk
        // Wait for some time
        #(`CYCLE*5);

        // relase the clk
        release clk;

    endtask

  // UART send task
  task uart_send_u8;
  input [7:0] in_data;
  integer i;
  reg[7:0] data;
  begin
    // Start bit (low)
    #(`c2q)tx = 0;
    data = in_data;
    #(`CYCLE);
    // Data bits (MSB first)
    for (i = 7; i >= 0; i = i - 1) begin
      #(`c2q)  tx = data[i];
      #(`CYCLE);
    end
    // Stop bit (high)
    #(`c2q)tx = 1;
    #(`CYCLE);
  end
endtask

  // UART send task
  task uart_send_type_addr;
    input [2:0] dat_type;
    input [4:0] addr;
    integer i;
    reg[7:0] data;

    begin
      // Start bit (low)
      #(`c2q)tx = 0;
      data = {dat_type,addr};
      #(`CYCLE);
      // Data bits (MSB first)
      for (i = 7; i >= 0; i = i - 1) begin
        #(`c2q)  tx = data[i];
        #(`CYCLE);
      end
      // Stop bit (high)
      #(`c2q)tx = 1;
      #(`CYCLE);
    end
  endtask

 // UART receive task
  task uart_receive_task;
    output [7:0] data;
    integer i;
    begin
      // Wait for start bit (low)
      @(negedge rx);
      #(`CYCLE/2); // Wait half bit period to sample in the middle
      // Sample data bits (MSB first)
      for (i = 7; i >= 0; i = i - 1) begin
        #(`CYCLE);
        data[i] = rx;
      end
      // Wait for stop bit (high)
      #(`CYCLE);
    end
  endtask


endmodule