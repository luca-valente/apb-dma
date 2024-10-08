`include "common_cells/registers.svh"

module apbdma_downsizer #(
    parameter int unsigned InDataWidth = -1,
    parameter int unsigned OutDataWidth = -1
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [InDataWidth-1:0] data_i,
    input logic [InDataWidth/8-1:0] strb_i,
    input logic valid_i,
    output logic ready_o,
    output logic [OutDataWidth-1:0] data_o,
    output logic [OutDataWidth/8-1:0] strb_o,
    output logic valid_o,
    input logic ready_i
);

localparam MaxCount = InDataWidth / OutDataWidth;
logic [InDataWidth-1:0] data_d, data_q;
logic [InDataWidth-1:0] strb_d, strb_q;
logic [clog2(MaxCount)-1:0] count_d, count_q;
logic count_en, count_reset;

typedef enum logic [1:0] { 
    Idle,
    Send
} state_t;
state_t state_d, state_q;

always_comb begin
    state_d = state_q;
    ready_o = 1'b1;
    count_en = 1'b0;
    data_d = data_q;
    strb_d = strb_q;
    valid_o = 1'b0;
    count_reset = 1'b0;
    case(state_q) 
        Idle: begin
            if(valid_i) begin
                data_d = data_i;
                strb_d = strb_i;
                state_d = Send;
            end
        end
        Send: begin
            ready_o = 1'b0;
            valid_o = 1'b1;
            data_o = data_q[count_q*OutDataWidth +: OutDataWidth];
            strb_o = strb_q[count_q*OutDataWidth +: OutDataWidth];
            if (ready_i) begin
                count_en = 1'b1;
                if(count_q=='1) begin
                    if(~valid_i) begin 
                        state_d = Idle;
                    end else begin
                        data_d = data_i;
                    end
                end
            end
        end
    endcase
end

always_comb begin
 count_d = count_q;
 if (count_reset) begin
   count_d = '0;
 end else if (count_en) begin
   count_d = count_q + 1;
 end
end

`FFARN(count_q, count_d, '0, clk_i, rst_ni);
`FFARN(data_q, data_d, '0, clk_i, rst_ni);
`FFARN(strb_q, strb_d, '0, clk_i, rst_ni);
`FFARN(state_q,state_d,Idle,clk_i,rst_ni);

endmodule