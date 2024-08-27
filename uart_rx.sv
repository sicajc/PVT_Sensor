module  uart_rx
(
    input wire clk,
    input wire rstn,
    input wire rx,

    output reg out_valid,
    output reg[7:0] dat_out,

    output reg done
);

typedef enum logic[3:0] {IDLE,START,DATA,STOP} state_t;
state_t cur_st,next_st;

reg[7:0] shift_ff;
reg[7:0]  num_of_data_ff;
reg[7:0]  cnt; 

wire send_done_f = cnt == num_of_data_ff*8 && cur_st == DATA; 
wire multiple_of_8_f    = cnt % 8 == 0 && cur_st == DATA && cnt != 0;

always_ff @(posedge clk or negedge rstn)
begin
    if(~rst)
    begin
        cur_st   <= IDLE;
        shift_ff <= 0;
        done <= 1'b0;
        cnt <= 0;
        out_valid <= 1'b0;
        dat_out  <= 0;
    end
    else
    begin
        case(cur_st)
        IDLE:
        begin
            cur_st <= rx == 1'b0 ? DATA : IDLE;
            shift_ff <= 0;
            busy <= start == 1'b0 ? 1'b1 : 1'b0;
            cnt  <= 0;
            out_valid <= 1'b0;
            dat_out  <= 0;
        end
        DATA:
        begin
            cur_st         <= send_done_f ? STOP : DATA;
            // bit 0 of shift_ff gets rx, other shift left
            shift_ff       <= {shift_ff[6:0],rx};
            cnt            <= send_done_f ? 0 : cnt + 1;
            out_valid      <= multiple_of_8_f ? 1'b1 : 1'b0;
            dat_out        <= shift_ff;
        end
        STOP:
        begin
            cur_st  <= IDLE;
            tx      <= 1'b1; // stop bit
            done    <= 1'b1;
        end
        endcase
    end
end

endmodule