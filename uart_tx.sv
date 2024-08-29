// give me a uart verilog i/o module
// uart module is a wrapper for the uart_rx and uart_tx modules
// uart_rx and uart_tx modules are the actual uart modules
module  uart_tx
(
    input wire clk,
    input wire rst_n,
    input wire start,

    // load 32 bits at once
    input [7:0] in_data,

    output reg tx,
    output reg busy
);

typedef enum logic[3:0] {IDLE,DATA,STOP} state_t;
state_t cur_st;

reg[7:0] shift_ff;
reg[7:0]  cnt;

wire send_done_f = cnt == 7 && cur_st == DATA;

always_ff @(posedge clk or negedge rst_n)
begin
    if(~rst_n)
    begin
        cur_st   <= IDLE;
        shift_ff <= 0;
        tx <= 1'b1; // Active low signal
        busy <= 1'b0;
        cnt <= 0;
    end
    else
    begin
        case(cur_st)
        IDLE:
        begin
            cur_st <= start == 1'b1 ? DATA : IDLE;
            shift_ff <= start == 1'b1 ? in_data : 0;
            tx <= start == 1'b1 ? 1'b0 : 1'b1; // Start bit is 0
            busy <= start == 1'b1 ? 1'b1 : 1'b0;
            cnt  <= 0;
        end
        DATA:
        begin
            cur_st         <= send_done_f ? STOP : DATA;
            shift_ff       <= shift_ff << 1;
            tx             <= shift_ff[7];
            cnt            <= send_done_f ? 0 : cnt + 1;
        end
        STOP:
        begin
            cur_st  <= IDLE;
            cnt     <= 0;
            shift_ff <= 0;
            tx      <= 1'b1; // stop bit
            busy    <= 1'b0;
        end
        endcase
    end
end

endmodule