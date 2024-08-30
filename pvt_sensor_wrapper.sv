module pvt_sensor_wrapper #(parameter TYPE = 0,parameter GROUP_NO = 0)
    (
        // Clock and reset
        input  clk,
        input  rst_n,
        // UART interface
        input wire rx,
        output wire tx
    );

    // add input controls, output controls
    typedef enum logic[3:0] {IDLE,DATA,DONE,WAIT_VALID} state_t;

    // T = 0, V = 1, P = 2
    typedef enum logic[5:0] {EN,I_BYPASS,COEF_C0,COEF_C1,COEF_A,CALIB,OFFSET,RST,SEL,COUNT,READ_DATA,NONE} type_t;

    state_t in_cur_st;
    type_t  type_ff;

    logic sensor_en_ff;

    logic sensor_out_valid;
    logic[15:0] sensor_out_dat;

    logic[7:0] rx_dat_out;

    wire[4:0] cur_addr = rx_dat_out[4:0];
    type_t cur_type;

    always_comb
    begin// decode the type
        case(rx_dat_out[4:0])
            5'd0: begin
                assign cur_type = EN;
            end
            5'd1: begin
                assign cur_type = I_BYPASS;
            end
            5'd2: begin
                assign cur_type = COEF_C0;
            end
            5'd3: begin
                assign cur_type = COEF_C1;
            end
            5'd4: begin
                assign cur_type = COEF_A;
            end
            5'd5: begin
                assign cur_type = CALIB;
            end
            5'd6: begin
                assign cur_type = OFFSET;
            end
            5'd7: begin
                assign cur_type = RST;
            end
            5'd8: begin
                assign cur_type = SEL;
            end
            5'd9: begin
                assign cur_type = COUNT;
            end
            default:begin
                assign cur_type = READ_DATA;
            end
        endcase
    end

    wire input_transaction_start_f = in_cur_st == IDLE && rx_out_valid == 1'b1 && cur_addr == GROUP_NO;
    logic[3:0] transaction_down_cnt;

    // Input ctr and types
    always_ff @(posedge clk or negedge rst_n)
    begin
        if(~rst_n)
        begin
            in_cur_st <= IDLE;
            transaction_down_cnt <= 0;
            type_ff <= NONE;
        end
        else
        begin
            case(in_cur_st)
            IDLE:
            begin
                in_cur_st <= input_transaction_start_f ? DATA : IDLE;

                if(input_transaction_start_f)
                begin
                    type_ff <= cur_type;

                    if(TYPE == 0)
                    begin
                        case(cur_type)
                        EN,I_BYPASS : begin
                            // Need 1 cycle
                            transaction_down_cnt <= 0;
                        end
                        COEF_C0,COEF_C1,COEF_A : begin
                            // need 4 cycles
                            transaction_down_cnt <= 3;
                        end
                        default:begin
                            transaction_down_cnt <= 0;
                        end
                        endcase
                    end
                    else if(TYPE == 1)
                    begin
                        case(cur_type)
                            EN,RST,SEL : begin
                                transaction_down_cnt <= 0;
                            end
                            COUNT : begin
                                transaction_down_cnt <= 1;
                            end
                            default:begin
                                transaction_down_cnt <= 0;
                            end
                        endcase
                    end
                    else
                    begin
                        transaction_down_cnt <= 0;
                    end
                end
                else
                begin
                    transaction_down_cnt <= 0;
                end
            end
            DATA:
            begin
                in_cur_st <= rx_out_valid ? DONE : DATA;

                // decode the addr and store the needed times of transactions
                transaction_down_cnt <= rx_out_valid && transaction_down_cnt!=0 ? transaction_down_cnt - 1 : transaction_down_cnt;
            end
            DONE:
            begin
                in_cur_st <= IDLE;
                transaction_down_cnt <= 0;
                type_ff <= NONE;
            end
            endcase
        end
    end

    generate
        if (TYPE == 0) begin
            logic tsensor_bypass_ff;
            logic [31:0] i_c0_ff, i_c1_ff, i_a_ff;

            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    // Reset logic for TYPE 0
                    sensor_en_ff <= 0 ;
                    tsensor_bypass_ff <= 0;
                    i_c0_ff <= 0;
                    i_c1_ff <= 0;
                    i_a_ff <= 0;
                end
                else if(in_cur_st == DATA && rx_out_valid)
                begin
                    sensor_en_ff <= type_ff == EN ? rx_dat_out[0] : sensor_en_ff;

                    case(type_ff)
                        I_BYPASS:begin
                            tsensor_bypass_ff <= rx_dat_out[0];
                        end
                        COEF_C0:begin
                            case(transaction_down_cnt)
                            3:  i_c0_ff[31:24] <= rx_dat_out;
                            2:  i_c0_ff[23:16] <= rx_dat_out;
                            1:  i_c0_ff[15:8] <= rx_dat_out;
                            0:  i_c0_ff[7:0] <= rx_dat_out;
                            endcase
                        end
                        COEF_C1:begin
                            case(transaction_down_cnt)
                            3: i_c1_ff[31:24] <= rx_dat_out;
                            2: i_c1_ff[23:16] <= rx_dat_out;
                            1: i_c1_ff[15:8] <= rx_dat_out;
                            0: i_c1_ff[7:0] <= rx_dat_out;
                            endcase
                        end
                        COEF_A:begin
                            case(transaction_down_cnt)
                            3: i_a_ff[31:24] <= rx_dat_out;
                            2: i_a_ff[23:16] <= rx_dat_out;
                            1: i_a_ff[15:8] <= rx_dat_out;
                            0: i_a_ff[7:0] <= rx_dat_out;
                            endcase
                        end
                    endcase
                end
            end

            // T sensor instance
            tsensor u_tsensor (
           	.clk	 (clk),
           	.rstn	 (rst_n),
           	.en		 (sensor_en_ff),
            .i_bypass(tsensor_bypass_ff),
            .i_c0    (i_c0_ff),
            .i_c1    (i_c1_ff),
            .i_a     (i_a_ff),
           	.o_valid (sensor_out_valid),
           	.o_data	 (sensor_out_dat)
           );
        end
        else if (TYPE == 1) begin
            logic calib_ff, calib_done;
            logic [9:0] offset_ff;

            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    // Reset logic for TYPE 1
                    sensor_en_ff <= 0;
                    calib_ff <= 0;
                    calib_done <= 0;
                    offset_ff <= 0;
                end
                else if(in_cur_st == DATA && rx_out_valid)
                begin
                    // v sensor
                    sensor_en_ff <= type_ff == EN ? rx_dat_out[0] : sensor_en_ff;
                    case(type_ff)
                        CALIB:begin
                            calib_ff <= rx_dat_out;
                        end
                        OFFSET:begin
                            case(transaction_down_cnt)
                            1: offset_ff[9:8] <= rx_dat_out;
                            0: offset_ff[7:0] <= rx_dat_out;
                            endcase
                        end
                    endcase
                end
            end

            // V sensor instance
            vsensor u_vsensor (
                   	.clk		(clk),
                   	.en			(sensor_en),
                   	.rstn		(rst_n),
                   	.calib		(calib),
                   	.offset		(offset),
                   	.calib_done	(calib_done),
                   	.o_valid	(sensor_out_valid),
                   	.o_data		(sensor_out_dat)
                   );
        end
        else begin

            logic psensor_rstn_ff;
            logic [3:0] psensor_sel_ff;
            logic [9:0] psensor_count_ff;


            always_ff @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    // Reset logic for other TYPEs
                    sensor_en_ff <= 0;
                    psensor_rstn_ff <= 0;
                    psensor_sel_ff <= 0;
                    psensor_count_ff <= 0;
                end
                else if(in_cur_st == DATA && rx_out_valid)
                begin
                    sensor_en_ff <= type_ff == EN ? rx_dat_out[0] : sensor_en_ff;
                    // p sensor
                    case(type_ff)
                        RST:begin
                            psensor_rstn_ff <= 1'b1;
                        end
                        SEL:begin
                            psensor_sel_ff <= rx_dat_out;
                        end
                        COUNT:begin
                            case(transaction_down_cnt)
                            1: psensor_count_ff[9:8] <= rx_dat_out;
                            0: psensor_count_ff[7:0] <= rx_dat_out;
                            endcase
                        end
                    endcase
                end
            end

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
    endgenerate

    // Output control
    state_t out_cur_st;

    logic rd_from_sensor_ff;
    // valid,data from pvt sensor
    logic valid_ff;
    logic[15:0] out_dat_ff;

    always_ff@(posedge clk or negedge rst_n)
    begin
        if(~rst_n)
        begin
            out_cur_st <= IDLE;
            rd_from_sensor_ff <= 1'b0;

            valid_ff <= 0;
            out_dat_ff <= 0;
        end
        else
        begin
            case(out_cur_st)
                IDLE:
                begin
                    out_cur_st <= (sensor_out_valid && type_ff == READ_DATA) ? WAIT_VALID : IDLE;
                    rd_from_sensor_ff <= type_ff == READ_DATA ? 1'b1 : 1'b0;

                    valid_ff <= 0;
                    out_dat_ff <= 0;
                end
                WAIT_VALID:
                begin
                    out_cur_st <= sensor_out_valid ? DONE : WAIT_VALID;

                    if(sensor_out_valid)
                    begin
                        valid_ff <= sensor_out_valid;
                        out_dat_ff <= sensor_out_dat;
                    end
                end
                DONE:
                begin
                    out_cur_st <= IDLE;
                    rd_from_sensor_ff <= 1'b0;
                end
            endcase
        end
    end

    // UART instance, use the uart_rx module
    uart_rx u_uart_rx(
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),

        .out_valid(rx_out_valid),
        .data_out(rx_dat_out)
    );

    // UART instance, use the uart_tx module
    uart_tx u_uart_tx(
        .clk(clk),
        .rst_n(rst_n),

        .start(rd_from_sensor_ff && valid_ff),
        .in_data(out_dat_ff),

        .tx(tx)
    );

endmodule