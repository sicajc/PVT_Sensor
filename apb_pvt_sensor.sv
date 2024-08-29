`define BEHAVIOR
module apb_pvt_sensor #(
    parameter int NO_OF_PSENSORS = 25,
    parameter int NO_OF_VSENSORS = 25,
    parameter int NO_OF_TSENSORS = 25,
    parameter int NO_OF_GROUPS   = 25
)
(
	input  wire 	   s_apb_clk,
	input  wire 	   s_apb_rstn,

    input  wire[addr_width+1:0] s_apb_addr,

	input  wire 	   s_apb_sel,
	input  wire 	   s_apb_enable,
	input  wire 	   s_apb_write,
	input  wire [31:0] s_apb_wdata,
	input  wire [ 3:0] s_apb_wstrb, // not use
	output wire [31:0] s_apb_rdata,
	output wire 	   s_apb_ready,
	output wire 	   s_apb_slverr
);


    // localparam int NO_OF_GROUPS = max(max(NO_OF_PSENSORS, NO_OF_VSENSORS), NO_OF_TSENSORS);
    localparam int addr_width   = $clog2(NO_OF_GROUPS*4);

    // add assertions
    // assert (NO_OF_PSENSORS >= 1 && NO_OF_PSENSORS <= 32) $display("No_of_psensor:%d",NO_OF_PSENSORS);else $error("NO_OF_PSENSORS should be more than 1 or less than or equal to 32");
    // assert (NO_OF_VSENSORS >= 1 && NO_OF_VSENSORS <= 32) $display("No_of_vensors:%d",NO_OF_VSENSORS);else $error("NO_OF_VSENSORS should be more than 1 or less than or equal to 32");
    // assert (NO_OF_TSENSORS >= 1 && NO_OF_TSENSORS <=32) $display("No_of_tensors:%d",NO_OF_TSENSORS);else $error("NO_OF_TSENSORS should be more than 1 or less than or equal to 32");

    // maximum of NO_OF_PSENSORS, NO_OF_VSENSORS, NO_OF_TSENSORS
    genvar g_idx;

    // To modify
	logic [addr_width+1:0] addr_w,  addr_r ;
	logic [31:0] slv_reg[0:NO_OF_GROUPS-1];

    // APB controls
    typedef enum logic[1:0] {S_IDLE,S_SETUP,S_ACCESS} state_t;
	state_t current_state, next_state;
	logic [31:0] rdata_w, rdata_r;
	logic 		 ready_w, ready_r;
	logic 	     write_w, write_r;
	logic [31:0] wdata_w, wdata_r;
	logic [14:0] q;
	logic 		 clk_div;

	assign s_apb_rdata  = rdata_r;
	assign s_apb_ready  = ready_r;
	assign s_apb_slverr = 1'b0;

    // PVT sensors logic
	logic 		 psensor_o_valid[0:NO_OF_GROUPS-1],vsensor_o_valid[0:NO_OF_GROUPS-1],tsensor_o_valid[0:NO_OF_GROUPS-1];
	logic 		 vsensor_calib_done[0:NO_OF_GROUPS-1];
	logic [15:0] psensor_o_data[0:NO_OF_GROUPS-1];
    logic [15:0] tsensor_o_data[0:NO_OF_GROUPS-1];
	logic [ 9:0] vsensor_o_data[0:NO_OF_GROUPS-1];
	logic [31:0] psensor_o_data_32[0:NO_OF_GROUPS-1];
    logic [31:0] vsensor_o_data_32[0:NO_OF_GROUPS-1];
    logic [31:0] tsensor_o_data_32[0:NO_OF_GROUPS-1];

    logic wait_tsensor_valid_ffs[0:NO_OF_GROUPS-1];
    logic wait_vsensor_valid_ffs[0:NO_OF_GROUPS-1];
    logic wait_psensor_valid_ffs[0:NO_OF_GROUPS-1];

    wire v_sensor_en[0:NO_OF_GROUPS-1];
    wire psensor_en[0:NO_OF_GROUPS-1];

    genvar k_idx;

    generate
        for(k_idx = 0; k_idx < NO_OF_GROUPS; k_idx = k_idx + 1)
        begin
            assign psensor_en[k_idx]  = slv_reg[k_idx][1];
            assign v_sensor_en[k_idx] = slv_reg[k_idx][16];
        end
    endgenerate

    // Waiting out valid of p,v,t sensor to prevent accidentaly stucking the controller
    // If the p,v,t sensors are not enable, yet you try to access them, the outvalid would never pull up
    // system would eventually stuck
    always_ff@(posedge s_apb_clk or negedge s_apb_rstn)
    begin
        if(~s_apb_rstn)
        begin
            for(int i =0;i<NO_OF_GROUPS;i=i+1)
            begin
                wait_tsensor_valid_ffs[i] <= 0;
                wait_vsensor_valid_ffs[i] <= 0;
                wait_psensor_valid_ffs[i] <= 0;
            end
        end
        else
        begin
            for(int i =0;i<NO_OF_GROUPS;i=i+1)
            begin
                wait_tsensor_valid_ffs[i] <=  tsensor_o_valid[i]?  0 : (t_sensor_en[i] ? 1 : 0);
                wait_vsensor_valid_ffs[i] <=  vsensor_o_valid[i]?  0 : (psensor_en[i]  ? 1 : 0);
                wait_psensor_valid_ffs[i] <=  psensor_o_valid[i]?  0 : (v_sensor_en[i] ? 1 : 0);
            end
        end
    end

	always @(*) begin
		ready_w = ready_r;
		rdata_w = rdata_r;
		addr_w  = addr_r ;
		wdata_w = wdata_r;
		write_w = write_r;
		next_state = current_state;
		case (current_state)
			S_IDLE   : begin
				if (s_apb_sel) begin
					addr_w  = s_apb_addr;
					wdata_w = s_apb_wdata;
					write_w = s_apb_write;
					next_state = S_SETUP;
				end
			end
			S_SETUP  : begin
				next_state = S_ACCESS;
			end
			S_ACCESS : begin
				if (s_apb_enable & ~s_apb_ready)
                begin
					ready_w = 1;
					if (~write_r)
                    begin
                        // To modify, add logic to read out from specified c0,c1,a group
                        for(int i = 0; i < NO_OF_GROUPS; i = i + 1)
                        begin
						case(addr_r[addr_width+1:2])
                            i*4:begin
                                rdata_w = slv_reg[i];
                            end
                            (i*4+1):
                            begin
                                if(i > NO_OF_PSENSORS-1)
                                begin
                                    rdata_w = 0;
                                    ready_w = 1;
                                end
                                else
                                begin
                                    rdata_w = wait_tsensor_valid_ffs[i] ? psensor_o_data_32[i] : 0;
                                    ready_w = wait_psensor_valid_ffs[i] ? psensor_o_valid[i] : 1;
                                end
                            end
                            (i*4+2):
                            begin
                                if(i > NO_OF_VSENSORS-1)
                                begin
                                    rdata_w = 0;
                                    ready_w = 1;
                                end
                                else
                                begin
                                    rdata_w = wait_tsensor_valid_ffs[i] ? vsensor_o_data_32[i] : 0;
                                    ready_w = wait_vsensor_valid_ffs[i] ? vsensor_o_valid[i] : 1;
                                end
                            end
                            (i*4+3):
                            begin
                                if(i > NO_OF_TSENSORS-1)
                                begin
                                    rdata_w = 0;
                                end
                                else
                                begin
                                    rdata_w = wait_tsensor_valid_ffs[i] ? tsensor_o_data_32[i] : 0;
                                    ready_w = wait_tsensor_valid_ffs[i] ? tsensor_o_valid[i] : 1;
                                end
                            end
                            ((i+NO_OF_GROUPS)*4):
                            begin
                                rdata_w = c0_rf[i];
                            end
                            ((i+NO_OF_GROUPS)*4+1):
                            begin
                                rdata_w = c1_rf[i];
                            end
                            ((i+NO_OF_GROUPS)*4+2):
                            begin
                                rdata_w = a_rf[i];
                            end
					    endcase
				end
                    end
				end else begin
					ready_w = 0;
				end
				if (s_apb_enable & s_apb_ready) begin
					next_state = S_IDLE;
				end
			end
		endcase
	end

	always @(posedge s_apb_clk or negedge s_apb_rstn) begin
		if (~s_apb_rstn) begin
			ready_r <= 0;
			rdata_r <= 0;
			addr_r  <= 0;
			wdata_r <= 0;
			write_r <= 0;
		end else begin
			ready_r <= ready_w;
			rdata_r <= rdata_w;
			addr_r  <= addr_w ;
			wdata_r <= wdata_w;
			write_r <= write_w;
		end
	end

	always @(posedge s_apb_clk or negedge s_apb_rstn) begin
		if (~s_apb_rstn) begin
			current_state <= S_IDLE;
		end else begin
			current_state <= next_state;
		end
	end

    // Add c0,c1,a rfs to store info of these parameters from w_data_r
    // Number of c0,c1,a groups is determined by the number of groups for easier modification
    // The address starting of c0,c1,a is aligned to 4 and is corresponding to the group number
    // c0: 0,4,8,12,16,20,24,28 , N
    // c1: 1,5,9,13,17,21,25,29
    // a : 2,6,10,14,18,22,26,30
    logic [31:0] c0_rf[0:NO_OF_GROUPS-1],c1_rf[0:NO_OF_GROUPS-1],a_rf[0:NO_OF_GROUPS-1];

    wire wr_coef_f = $signed(addr_r[addr_width+1:2] - NO_OF_GROUPS*4) >= 0;
    // prevent overflow, only greater than NO of groups makes sense add guard
    wire[31:0] coef_group_addr = ($signed(addr_r[addr_width+1:2] - NO_OF_GROUPS*4) >= 0)? addr_r[addr_width+1:2] - NO_OF_GROUPS*4 : 0;

    always @(posedge s_apb_clk or negedge s_apb_rstn) begin
		if (~s_apb_rstn) begin
            for(int i = 0; i < NO_OF_GROUPS; i = i + 1)
            begin
			    c0_rf[i] <= 0;
                c1_rf[i] <= 0;
                a_rf[i]  <= 0;
            end
		end else begin
			if (current_state == S_ACCESS) begin
				if (write_r && wr_coef_f) begin
                    for(int i = 0; i < NO_OF_GROUPS; i = i + 1)
                    begin
                       if(i < NO_OF_TSENSORS)
                       begin
					        case(coef_group_addr)
                                    i*3:begin
                                        c0_rf[i] <= wdata_r;
                                    end
                                    (i*3+1):
                                    begin
                                        c1_rf[i] <= wdata_r;
                                    end
                                    (i*3+2):
                                    begin
                                        a_rf[i]  <= wdata_r;
                                    end
                            endcase
                       end
                       else
                       begin
                            // Not used
                            c0_rf[i] <= 0;
                            c1_rf[i] <= 0;
                            a_rf[i]  <= 0;
                       end
                    end
				end
			end
		end
	end


	always @(posedge s_apb_clk or negedge s_apb_rstn) begin
		if (~s_apb_rstn) begin
            for(int i = 0; i < NO_OF_GROUPS; i = i + 1)
            begin
			    slv_reg[i] <= 0;
            end
		end else begin
			if (current_state == S_ACCESS) begin
				if (write_r) begin
                    for(int i = 0; i < NO_OF_GROUPS; i = i + 1)
                    begin
					    if (addr_r[addr_width+1:2] == i*4)
                        begin
					    	slv_reg[i] <= wdata_r;
					    end
                    end
				end
			end
		end
	end

    // Change these to uart compactable pvt sensor groups
    generate
        for(g_idx = 0; g_idx < NO_OF_GROUPS; g_idx = g_idx + 1)
        begin
	        assign psensor_o_data_32[g_idx] = {16'b0,psensor_o_data[g_idx]};
	        assign vsensor_o_data_32[g_idx] = {21'b0,vsensor_calib_done[g_idx],vsensor_o_data[g_idx]};
	        assign tsensor_o_data_32[g_idx] = {16'b0,tsensor_o_data[g_idx]};
        end
    endgenerate

    generate
        for(g_idx = 0; g_idx < NO_OF_GROUPS; g_idx = g_idx + 1)
        begin
            if(g_idx < NO_OF_PSENSORS)
            begin
	            psensor u_psensor (
	            	.clk	 (s_apb_clk),
	            	.rstn	 (slv_reg[g_idx][0]),
	            	.en		 (slv_reg[g_idx][1]),
	            	.sel	 (slv_reg[g_idx][5:2]),
	            	.count	 (slv_reg[g_idx][15:6]),
	            	.o_valid (psensor_o_valid[g_idx]),
	            	.o_data	 (psensor_o_data[g_idx])
	            );
            end
            else
            begin
               assign psensor_o_valid[g_idx] = 0;
               assign psensor_o_data[g_idx] = 0;
            end
        end
    endgenerate

    generate
        for(g_idx = 0; g_idx < NO_OF_GROUPS; g_idx = g_idx + 1)
        begin
            if(g_idx < NO_OF_VSENSORS)
            begin
                vsensor u_vsensor (
	            	.clk		(s_apb_clk),
	            	.en			(slv_reg[g_idx][16]),
	            	.rstn		(s_apb_rstn),
	            	.calib		(slv_reg[g_idx][17]),
	            	.offset		(slv_reg[g_idx][27:18]),
	            	.o_valid	(vsensor_o_valid[g_idx]),
	            	.calib_done	(vsensor_calib_done[g_idx]),
	            	.o_data		(vsensor_o_data[g_idx])
                );
            end
            else
            begin
                assign vsensor_o_valid[g_idx] = 0;
                assign vsensor_calib_done[g_idx] = 0;
                assign vsensor_o_data[g_idx] = 0;
            end
        end
    endgenerate

    logic t_sensor_en[0:NO_OF_GROUPS-1];

    generate
        for(g_idx = 0; g_idx < NO_OF_GROUPS; g_idx = g_idx + 1)
        begin
            if(g_idx < NO_OF_TSENSORS)
                begin
                    tsensor u_tsensor (
	                	.clk	 (s_apb_clk),
	                	.rstn	 (s_apb_rstn),
	                	.en		 (t_sensor_en[g_idx]),
                        .i_bypass(slv_reg[g_idx][28]),
                        .i_c0    (c0_rf[g_idx]),
                        .i_c1    (c1_rf[g_idx]),
                        .i_a     (a_rf[g_idx]),
	                	.o_valid (tsensor_o_valid[g_idx]),
	                	.o_data	 (tsensor_o_data[g_idx])
                    );
                end
            else
            begin
                assign tsensor_o_valid[g_idx] = 0;
                assign tsensor_o_data[g_idx] = 0;
            end
        end
    endgenerate

	// clock divider 32768
    wire[1:0] type_f   = addr_r[addr_width+1:2]%4;
    wire[4:0] group_no = addr_r[addr_width+1:2]/4;

    always_comb begin : t_sensor_clk_sel
        // initilization
        for(int i = 0; i < NO_OF_GROUPS; i = i + 1)
            t_sensor_en[i] = 0;

        for(int i = 0; i < NO_OF_GROUPS; i = i + 1)
        begin
            if(i < NO_OF_TSENSORS)
            begin
                if(type_f == 3)
                    case(group_no)
                        i: t_sensor_en[i] = clk_div;
                        default: t_sensor_en[i] = 0;
                    endcase
            end
            else
            begin
                t_sensor_en[i] = 0;
            end
        end
    end

    assign clk_div = q[14];

	generate
		for (genvar m = 0; m < 15; m = m + 1) begin
			if (m == 0) begin
				always @(posedge s_apb_clk or negedge s_apb_rstn) begin
					if (~s_apb_rstn) begin
						q[m] <= 0;
					end else begin
						q[m] <= ~q[m];
					end
				end
			end else begin
				always @(posedge q[m-1] or negedge s_apb_rstn) begin
					if (~s_apb_rstn) begin
						q [m] <= 0;
					end else begin
						q [m] <= ~q[m];
					end
				end
			end
		end
	endgenerate
endmodule

module psensor (
    input          clk,
    input          rstn,
    input          en,
    input   [ 3:0] sel,
    input   [ 9:0] count,
    output         o_valid,
    output  [15:0] o_data
);

    `ifdef BEHAVIOR
        reg o_valid_w, o_valid_r;
        assign o_data = 16'hff;
        assign o_valid = o_valid_r;
        reg [ 9:0] cnt_w, cnt_r;
        reg    current_state, next_state;
        reg en_d0, en_d1;

        always @(*) begin
            cnt_w = cnt_r;
            case (current_state)
                0: cnt_w = 0;
                1: cnt_w = (cnt_r < count) ? cnt_r + 1 : 0;
            endcase
        end
        always @(posedge clk or negedge rstn) begin
            if (~rstn) begin
                cnt_r <= 0;
            end else begin
                cnt_r <= cnt_w;
            end
        end

        always @(posedge clk or negedge rstn) begin
            if (~rstn) begin
                current_state <= 0;
            end else begin
                current_state <= next_state;
            end
        end

        always @(posedge clk or negedge rstn) begin
            if(~rstn)begin
                o_valid_r <= 0;
            end else begin
                o_valid_r <= o_valid_w;
            end
        end

        // two ff sync
        always @(posedge clk or negedge rstn) begin
            if (~rstn) begin
                en_d0 <= 0;
                en_d1 <= 0;
            end else begin
                en_d0 <= en;
                en_d1 <= en_d0;
            end
        end

        always @(*) begin
            next_state = current_state;
            case (current_state)
                0: begin
                    if (en_d1) next_state = 1;
                    else next_state = current_state;
                end
                1: begin
                    if (cnt_r >= count) next_state = 0;
                    else next_state = current_state;
                end
            endcase
        end

        always @(*) begin
            o_valid_w = o_valid_r;
            case (current_state)
                0: begin
                    o_valid_w = (en_d1)? 0 : o_valid_r;
                end
                1: begin
                    o_valid_w = (cnt_r == count);
                end
            endcase
        end
    `else
        MXDWRO_1P1V u_ro (
            .CLK        (clk),
            .RSTn       (rstn),
            .EN         (en),
            .SEL        (sel),
            .COUNT      (count),
            .RDY        (o_valid),
            .RO_DATAOUT (o_data)
        );
    `endif
endmodule

// To modify, add Latency delay and bypass logic, add c0,c1,a ports for it
module tsensor #(parameter LATENCY = 20)  (
    input          clk,
    input          rstn,
    input          en,
    input          i_bypass,
    input[31:0]    i_c0,
    input[31:0]    i_c1,
    input[31:0]    i_a,
    output         o_valid,
    output  [15:0] o_data
);

    `ifdef BEHAVIOR
    	reg o_valid_w, o_valid_r;
        // To modify, need to add fixed point16 and fp32 conversion to int8 LUT
        assign o_data =  i_bypass ? 16'h32: 16'hff;
        assign o_valid = o_valid_delayN[0];
        reg [3:0] cnt_w, cnt_r;
        reg [1:0] current_state,next_state;

        reg o_valid_delayN[0:LATENCY-1];

        always_ff @( posedge clk or negedge rstn )
        begin
            if(~rstn)
            begin
                for(int i = 0; i < LATENCY; i = i + 1)
                    o_valid_delayN[i] <= 0;
            end
            else
            begin
                // delay lines
                for(int i = 0; i < LATENCY; i = i + 1)
                begin
                    if(i==LATENCY-1)
                        o_valid_delayN[i] <= o_valid_r;
                    else
                        o_valid_delayN[i] <= o_valid_delayN[i+1];
                end
            end
        end

        always @(*) begin
            cnt_w = cnt_r;
            case (current_state)
                0: cnt_w = 0;
				1: cnt_w = 0;
                2: cnt_w = (cnt_r < 15) ? cnt_r + 1 : 0;
            endcase
        end
        always @(posedge clk or negedge rstn) begin
            if (~rstn) begin
                cnt_r <= 0;
            end else begin
                cnt_r <= cnt_w;
            end
        end

        always @(posedge clk or negedge rstn) begin
            if (~rstn) begin
                current_state <= 0;
            end else begin
                current_state <= next_state;
            end
        end

        always @(posedge clk or negedge rstn) begin
            if(~rstn)begin
                o_valid_r <= 0;
            end else begin
                o_valid_r <= o_valid_w;
            end
        end

        always @(*) begin
            next_state = current_state;
            case (current_state)
                0: begin
                    if (en) next_state = 1;
                    else next_state = current_state;
                end
                1: begin
                    if (~en) next_state = 2;
                    else next_state = current_state;
                end
				2: begin
                    if (cnt_r == 15) next_state = 0;
                    else next_state = current_state;
				end
            endcase
        end

        always @(*) begin
            o_valid_w = o_valid_r;
            case (current_state)
                0: begin
                    o_valid_w = (en) ? 0 : o_valid_r;
                end
                2: begin
                    o_valid_w = (cnt_r == 15);
                end
            endcase
        end
    `else
        dwtn40_tsensor u_tsensor (
            .clk     (clk),
            .rstn    (rstn),
            .roen    (en),
            .o_valid (o_valid),
            .o_data  (o_data)
        );
    `endif
endmodule


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

// Function to find the maximum of two values
function int max(input int a, input int b);
  if (a > b)
    max = a;
  else
    max = b;
endfunction
