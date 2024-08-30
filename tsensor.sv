`include "DEFINE.svh"
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
