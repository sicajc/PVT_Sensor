module  uart_rx
(
    input wire clk,
    input wire rst_n,
    input wire rx,

    output reg      out_valid,
    output reg[7:0] data_out
);

typedef enum logic[3:0] {IDLE,DATA,STOP} state_t;
state_t cur_st;

reg[7:0] shift_ff;
reg[7:0]  cnt;

wire send_done_f = (cnt == 8) && cur_st == DATA;

always_ff @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
    begin
        cur_st   <= IDLE;
        shift_ff <= 0;
        cnt <= 0;
        out_valid <= 1'b0;
        data_out  <= 0;
    end
    else
    begin
        case(cur_st)
        IDLE:
        begin
            cur_st <= rx == 1'b0 ? DATA : IDLE;
            shift_ff <= 0;
            cnt  <= 0;
            out_valid <= 1'b0;
            data_out  <= 0;
        end
        DATA:
        begin
            cur_st         <= (send_done_f && rx == 1'b1) ? STOP : DATA;
            out_valid <= 1'b0;
            cnt            <=  send_done_f ? cnt : cnt + 1;
            // bit 0 of shift_ff gets rx stop bit, other shift left
            shift_ff       <= (send_done_f && rx == 1'b1) ? shift_ff : {shift_ff[6:0],rx};
        end
        STOP:
        begin
            cur_st          <=  rx == 1'b0 ? DATA :IDLE;
            out_valid       <=  1'b1;
            cnt             <=  0;
            data_out        <=  shift_ff;
        end
        endcase
    end
end

endmodule