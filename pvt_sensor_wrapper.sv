module pvt_sensor_wrapper #(parameter TYPE = 0,parameter group_no = 0)
    (   
        // Clock and reset
        input  clk,
        input  rstn,
        // UART interface
        input wire rx,
        output wire tx
    );
    typedef enum logic[3:0] {IDLE,WAIT_TYPE,RECEIVE_DATA} in_state_t;
    
    if(TYPE == 0)
    begin
        typedef enum logic[3:0] {EN,I_BYPASS,COEF,READ_DATA} type_t;
    end
    else if(TYPE == 1)
    begin
        typedef enum logic[3:0] {EN,RST,SEL,COUNT,READ_DATA} type_t;
    end
    else
    begin
        typedef enum logic[3:0] {EN,CALIB,OFFSET,READ_DATA} type_t;
    end

    state_t cur_st;
    type_t  type_wr,type_ff;
    logic sensor_out_valid;
    logic[31:0] sensor_out_dat;
    logic sensor_en_ff;

    logic rd_from_sensor_ff;

    always_ff@(posedge clk or negedge rstn)
    begin
        if(~rstn)
        begin
            rd_from_sensor_ff <= 0;
        end
        else
        begin
           rd_from_sensor_ff <= sensor_out_valid ? 0 : (type_ff == READ_DATA ? 1 : 0); 
        end
    end

    // For T sensor, address , type , need to read in c0,c1,a & 
    if (TYPE == 0)
    begin
        logic[31:0] i_c0_ff,i_c1_ff,i_a_ff;
        logic tsensor_bypass_ff;

         // T sensor instance
         tsensor u_tsensor (
	                	.clk	 (s_apb_clk),
	                	.rstn	 (s_apb_rstn),
	                	.en		 (sensor_en_ff),
                        .i_bypass(tsensor_bypass_ff),
                        .i_c0    (i_c0_ff),
                        .i_c1    (i_c1_ff),
                        .i_a     (i_a_ff),
	                	.o_valid (sensor_out_valid),
	                	.o_data	 (sensor_out_dat)
                    );
    end
    else if(TYPE == 1) 
    begin
        logic calib_ff,calib_done;
        logic[9:0] offset_ff;

        // V sensor instance
         vsensor u_vsensor (
	            	.clk		(clk),
	            	.en			(sensor_en),
	            	.rstn		(rstn),
	            	.calib		(calib),
	            	.offset		(offset),
	            	.calib_done	(calib_done),
	            	.o_valid	(sensor_out_valid),
	            	.o_data		(sensor_out_dat)
                );

    end
    else
    begin
        logic      psensor_rstn_ff;
        logic[3:0] psensor_sel_ff;
        logic[9:0] psensor_count_ff;

          // P sensor instance
          psensor u_psensor (
	            	.clk	 (clk),
	            	.rstn	 (psensor_rstn),
	            	.en(sensor_en),
	            	.sel	 (psensor_sel),
	            	.count	 (psensor_count),
	            	.o_valid (sensor_out_valid),
	            	.o_data	 (sensor_out_dat)
	            );
        
    end

    wire start_f = cur_st == IDLE && in_valid == 1'b1 && dat_out == group_no;

    // Main ctr
    always_ff @(posedge clk or negedge rstn)
    begin
        if(~rstn)
        begin
            cur_st <= IDLE;
        end
        else
        begin
            case(cur_st)
            IDLE:
            begin
                cur_st <= start_f ? WAIT_TYPE : IDLE;
            end
            WAIT_TYPE:
            begin
                cur_st <= rx_out_valid ? RECEIVE_DATA : WAIT_TYPE;
            end
            RECEIVE_DATA:
            begin
                cur_st <= done == 1'b1 ? IDLE : RECEIVE_DATA;
            end
            endcase
        end
    end

    if(TYPE == 0)
    begin
        logic[3:0] coef_cnt;
    end
    begin
        logic count_cnt;
    end

    always_ff@(posedge clk or negedge rstn)
    begin
        if(~rstn)
        begin
            sensor_en_ff <= 0;
            if(TYPE == 0)
            begin
                tsensor_bypass_ff <= 0;
                i_c0_ff <= 0;
                i_c1_ff <= 0;
                i_a_ff <= 0;
                coef_cnt <= 0;
            end
            else if(TYPE == 1)
            begin
                calib_ff <= 0;
                offset_ff <= 0;
            end
            else
            begin
                psensor_rstn_ff <= 1;
                psensor_sel_ff <= 0;
                psensor_count_ff <= 0;
            end
        end
        else if(in_valid == 1'b1 && cur_st == RECEIVE_DATA)
        begin
            if(TYPE == 0)
            begin
                case(type_ff)
                EN: sensor_en_ff <= dat_in[0];
                I_BYPASS: tsensor_bypass_ff <= dat_in[0];
                COEF:
                begin
                    coef_cnt <=  coef_cnt == 11 ? 0 : coef_cnt + 1;
                    case(coef_cnt)
                    // Note to modify, coef is 32 bits, it needs 
                    // 4 cycles to send in
                    0: i_c0_ff[7:0] <= dat_in;
                    1: i_c0_ff[15:8] <= dat_in;
                    2: i_c0_ff[23:16] <= dat_in;
                    3: i_c0_ff[31:24] <= dat_in;
                    4: i_c1_ff[7:0] <= dat_in;
                    5: i_c1_ff[15:8] <= dat_in;
                    6: i_c1_ff[23:16] <= dat_in;
                    7: i_c1_ff[31:24] <= dat_in;
                    8: i_a_ff[7:0] <= dat_in;
                    9: i_a_ff[15:8] <= dat_in;
                    10: i_a_ff[23:16] <= dat_in;
                    11: i_a_ff[31:24] <= dat_in;
                    endcase
                end     
                endcase
            end
            else if(TYPE == 1)
            begin
                case(type_ff)
                EN: sensor_en_ff <= dat_in[0];
                RST:psensor_rstn_ff <= dat_in[0];
                SEL:psensor_sel_ff  <= dat_in[3:0];
                COUNT:// psensorff is of 8 bits
                begin
                    case(count_cnt)
                    0:  psensor_count_ff[7:0] <= dat_in;
                    1:  psensor_count_ff[9:8] <= dat_in[1:0];
                    endcase
                end
                endcase
            end
            else
            begin
                case(type_ff)
                EN:    sensor_en_ff <= dat_in[0];
                CALIB: calib_ff <= dat_in[0];
                OFFSET:
                begin
                    case(count_cnt)
                    0: offset_ff[7:0] <= dat_in;
                    1: offset_ff[9:8] <= dat_in[1:0];
                    endcase
                end
                endcase
            end
        end
    end

    // valid,data from pvt sensor
    logic valid_ff;
    logic[31:0] out_dat_ff;

    always_ff@(posedge clk or negedge rstn)
    begin
        if(~rstn)
        begin
            valid_ff <= 0;
            out_dat_ff <= 0;
        end
        else if(o_valid == 1'b1)
        begin
            valid_ff <= sensor_out_valid;
            out_dat_ff <= sensor_out_dat;
        end
    end

    // UART instance, use the uart_rx module
    uart_rx u_uart_rx(
        .clk(clk),
        .rstn(rstn),
        .rx(rx),
        .out_valid(rx_out_valid),
        .dat_out(rx_dat_out),
        .done(done)
    );

    // UART instance, use the uart_tx module
    uart_tx u_uart_tx(
        .clk(clk),
        .rstn(rstn),
        .tx(tx),
        .in_valid(valid_ff),
        .dat_in(out_dat_ff),
        .start(rd_from_sensor_ff && sensor_out_valid)
    );

endmodule