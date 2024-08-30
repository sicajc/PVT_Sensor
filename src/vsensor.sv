`include "DEFINE.svh"
module vsensor (
    input          clk,
    input          en,
    input          rstn,
    input          calib,
    input   [ 9:0] offset,
    output         o_valid,
    output         calib_done,
    output  [ 9:0] o_data
);
    `ifdef BEHAVIOR
        assign o_data = 10'd1023;
        assign o_valid = 1;
        assign calib_done = 0;
    `else
        ir_sensor u_ir_sensor (
            .clk        (clk & en),
            .rstn       (rstn),
            .calib      (calib),
            .offset     (offset),
            .o_valid    (o_valid),
            .calib_done (calib_done),
            .o_data     (o_data)
        );
    `endif
endmodule