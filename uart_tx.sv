// give me a uart verilog i/o module
// uart module is a wrapper for the uart_rx and uart_tx modules
// uart_rx and uart_tx modules are the actual uart modules
module  uart_tx
(
    input wire clk,
    input wire rstn,
    output reg tx,

    input wire start,
    
    // load 32 bits at once
    input load_dat;
    input [31:0] dat,
    input num_of_data,

    output reg busy,
    output reg done
);

typedef enum logic[3:0] {IDLE,START,DATA,STOP} state_t;
state_t cur_st,next_st;

reg[31:0] shift_ff;
reg[7:0]  num_of_data_ff;
reg[7:0]  cnt; 

wire send_done_f = cnt == num_of_data_ff*8 && cur_st == DATA; 

always_ff @(posedge clk or negedge rstn)
begin
    if(~rst)
    begin
        cur_st   <= IDLE;
        shift_ff <= 0;
        num_of_data_ff <= 0;
        tx <= 1'b0;
        busy <= 1'b0;
        done <= 1'b0;
    end
    else
    begin
        case(cur_st)
        IDLE:
        begin
            cur_st <= start == 1'b1 ? START : IDLE;
            shift_ff <= 0;
            num_of_data_ff <= 0;
            tx <= 1'b0;
            busy <= start == 1'b1 ? 1'b1 : 1'b0;
            done <= 1'b0;
            cnt  <= 0;
        end
        START:
        begin
            // waits for data to be loaded into register
            cur_st         <= load_dat == 1'b1 ? DATA : START;
            shift_ff       <= load_dat == 1'b1 ? dat : shift_ff;
            num_of_data_ff <= load_dat == 1'b1 ? num_of_data : num_of_data_ff;
            tx             <= load_dat == 1'b1 ? 1'b0 : 1'b1; // start bit
        end
        DATA:
        begin
            cur_st         <= send_done_f ? STOP : DATA;
            shift_ff       <= shift_ff >> 1;
            num_of_data_ff <= send_done_f ? 0 : num_of_data_ff;
            tx             <= shift_ff[0];
            cnt            <= send_done_f ? 0 : cnt + 1;
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