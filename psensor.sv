`include "DEFINE.svh"
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