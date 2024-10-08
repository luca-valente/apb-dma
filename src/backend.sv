`include "common_cells/registers.svh"

module backend #(
  parameter type req_t               = logic, // APB request strcut
  parameter type resp_t              = logic,  // APB response struct
  parameter type write_beat_t        = logic,  // Write struct
  parameter type read_beat_t         = logic,  // Read struct
  parameter type addr_t              = logic,
  parameter int unsigned AddrWidth   = -1,
  parameter int unsigned DataWidth   = -1
)(
    input   logic                        clk_i     ,
    input   logic                        rst_ni    ,
    output  req_t                        mst_req_o ,
    input   resp_t                       mst_resp_i,

    input   write_beat_t                 w_data_i  ,
    input   logic                        w_valid_i ,
    output  logic                        w_ready_o ,
    
    output  read_beat_t                  r_data_o  ,
    output  logic                        r_valid_o ,
    input   logic                        r_ready_i ,

    input   logic                        start_i   ,
    input   logic        [DataWidth-1:0] start_addr_i,
    input   logic        [7:0]           num_bytes_i,
    input   logic                        rw_i      ,
    output  logic                        busy_o    
);

  logic                        start;
  logic        [DataWidth-1:0] start_addr_q;
  logic        [7:0]           num_bytes_q;
  logic                        rw_q;
  logic count_en, count_reset;

  addr_t out_addr_d, out_addr_q; 

  typedef enum logic [1:0] { 
    Idle,
    Transaction
   } state_t;
  state_t state_d, state_q;

   sync_wedge #(
	  .STAGES     ( 3    ),
	  .ResetValue ( 1'b0 )
   ) i_sync (
    .clk_i    ( clk_i                          ),
    .rst_ni   ( rst_ni                         ),
    .en_i     ( 1'b1                           ),
    .serial_i ( start_i                        ),
    .serial_o (                                ),
    .r_edge_o ( start                          ),
    .f_edge_o (                                )
   );

   always_comb begin
    state_d = state_q;
    busy_o = 1'b0;
    count_en = 1'b0;
    count_reset = 1'b0;
    mst_req_o.pwrite = ~rw_q;
    mst_req_o.psel = 1'b0;
    mst_req_o.penable = 1'b0;
    mst_req_o.paddr = start_addr_q + count_q;
    mst_req_o.pwdata = '0;
    mst_req_o.pstrb = '0;
    r_valid_o = 1'b0;
    r_data_o = '0;
    count_en = 1'b0;
    w_ready_o = 1'b0;
    case(state_q) 
      Idle: begin
        if(start)
          state_d = Transaction
      end
      Transaction: begin
        busy_o = 1'b1;
        if(rw_q) begin
          mst_req_o.psel = r_ready_i;
          mst_req_o.penable = r_ready_i;
          r_valid_o = mst_resp_i.pready;
          r_data_o = mst_resp_i.prdata;
        end else begin
          mst_req_o.psel = w_valid_i;
          mst_req_o.penable = w_valid_i;
          count_en = w_valid_i & mst_resp_i.pready;
          mst_req_o.pwdata = w_data_i.data;
          mst_req_o.pstrb = w_data_i.strb;
          w_ready_o = mst_resp_i.pready;
        end
        if (count_d >= num_bytes_q) begin
          count_reset = 1'b1;
          state_d = Idle;
        end
      end
    endcase
   end

   always_comb begin
    count_d = count_q;
    if (count_reset) begin
      count_d = '0;
    end else if (count_en) begin
      count_d = count_q + DataWidth/8;
    end
   end

   `FFL(start_addr_q,start_addr_i,start,'0,clk_i,rst_ni);
   `FFL(start_addr_q,num_bytes_i,start,'0,clk_i,rst_ni);
   `FFL(rw_q,rw_i,start,'0,clk_i,rst_ni);
   `FFARN(state_q,state_d,Idle,clk_i,rst_ni);
   `FFARN(count_q,count_d,'0,clk_i,rst_ni);

endmodule