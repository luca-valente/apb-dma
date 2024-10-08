module midend #(
  parameter int unsigned SlvDataWidth    = -1,
  parameter int unsigned MstDataWidth    = -1,
  parameter type slv_write_beat_t        = logic,  // Write struct
  parameter type slv_read_beat_t         = logic,  // Read struct
  parameter type mst_write_beat_t        = logic,  // Write struct
  parameter type mst_read_beat_t         = logic,  // Read struct
  parameter int unsigned ASYNC = 0
) (
 input logic pclk_1,
 input logic preset_n_c1,

 input logic pclk_2,
 input logic preset_n_c2,
 // Write interface from frontend
 input slv_write_beat_t         w_data_i,
 input logic                w_valid_i,
 output  logic              w_ready_o,

 // Write interface to backend
 output mst_write_beat_t        w_data_o,
 output logic               w_valid_o,
 input  logic               w_ready_i,

// Read interface to frontend
 output slv_read_beat_t        r_data_o,
 output logic               r_valid_o,
 input  logic               r_ready_i,

// Read interface from backend
 input mst_read_beat_t         r_data_i,
 input logic                r_valid_i,
 output  logic              r_ready_o,
);

 slv_write_beat_t    w_data;
 logic               w_valid;
 logic               w_ready;
 slv_read_beat_t     r_data;
 logic               r_valid;
 logic               r_ready;
  if (SlvDataWidth == MstDataWidth) begin
     assign w_data_o = w_data;
     assign w_valid_o = w_valid;
     assign w_ready = w_ready_i;

     assign r_data = r_data_i;
     assign r_valid = r_valid_i;
     assign r_ready_o = r_ready;
  end else if(SlvDataWidth<MstDataWidth) begin
     apbdma_upsizer #(
      .InDataWidth  ( SlvDataWidth ),
      .OutDataWidth ( MstDataWidth )
     ) i_apbdma_upsizer (
      .clk_i   ( pclk_c2     ),
      .rst_ni  ( preset_n_c2 ),
      .data_i  ( w_data.data ),
      .strb_i  ( w_data.strb ),
      .valid_i ( w_ready     ),
      .ready_o ( w_ready     ),
      .data_o  ( w_data_o.data ),
      .strb_o  ( w_data_o.strb )
      .valid_o ( w_valid_o   ),
      .ready_i ( w_ready_i   )
     );
     apbdma_downsizer #(
      .InDataWidth  ( MstDataWidth ),
      .OutDataWidth ( SlvDataWidth )
     ) i_apbdma_downsizer (
      .clk_i   ( pclk_c2     ),
      .rst_ni  ( preset_n_c2 ),
      .data_i  ( r_data_i    ),
      .strb_i  ( '0          ),
      .valid_i ( r_valid_i   ),
      .ready_o ( r_ready_o   ),
      .data_o  ( r_data      ),
      .strb_o  (             ),
      .valid_o ( r_valid     ),
      .ready_i ( r_ready     )
     );
  end else begin
     apbdma_downsizer #(
      .InDataWidth  ( SlvDataWidth ),
      .OutDataWidth ( MstDataWidth )
     ) i_apbdma_upsizer (
      .clk_i   ( pclk_c2     ),
      .rst_ni  ( preset_n_c2 ),
      .data_i  ( w_data.data ),
      .strb_i  ( w_data.strb ),
      .valid_i ( w_ready     ),
      .ready_o ( w_ready     ),
      .data_o  ( w_data_o.data ),
      .strb_o  ( w_data_o.strb ),
      .valid_o ( w_valid_o   ),
      .ready_i ( w_ready_i   )
     );
     apbdma_upsizer #(
      .InDataWidth  ( MstDataWidth ),
      .OutDataWidth ( SlvDataWidth )
     ) i_apbdma_downsizer (
      .clk_i   ( pclk_c2     ),
      .rst_ni  ( preset_n_c2 ),
      .data_i  ( r_data_i    ),
      .strb_i  ( '0          ),
      .valid_i ( r_valid_i   ),
      .ready_o ( r_ready_o   ),
      .data_o  ( r_data      ),
      .strb_o  (             ),
      .valid_o ( r_valid     ),
      .ready_i ( r_ready     )
     );

  end

  if (ASYNC == 0) begin
     assign w_data = w_data_i;
     assign w_valid = w_valid_i;
     assign w_ready = w_ready_o;

     assign r_data_o = r_data;
     assign r_valid_o = r_valid;
     assign r_ready_i = r_ready;
  end else begin

    cdc_fifo_gray #(
        .T           (write_beat_t),
        .LOG_DEPTH   ( 3          ),
        .SYNC_STAGES ( 3          )
    ) i_w_cdc_fifo (
        .src_clk_i   ( pclk_1      ),
        .src_rst_ni  ( preset_n_c1 ),

        .src_data_i  ( w_data_i    ),
        .src_valid_i ( w_valid_i   ),
        .src_ready_o ( w_ready_o   ),

        .dst_clk_i   ( pclk_c2     ),
        .dst_rst_ni  ( preset_n_c2 ),

        .dst_data_o  ( w_data      ),
        .dst_valid_o ( w_valid     ),
        .dst_ready_i ( w_ready     )
    )

    cdc_fifo_gray #(
        .T           ( read_beat_t ),
        .LOG_DEPTH   ( 3           ),
        .SYNC_STAGES ( 3           )
    ) i_r_cdc_fifo (
        .src_clk_i   ( pclk_2      ),
        .src_rst_ni  ( preset_n_c2 ),

        .src_data_i  ( r_data_i    ),
        .src_valid_i ( r_valid_i   ),
        .src_ready_o ( r_ready_o   ),

        .dst_clk_i   ( pclk_c2     ),
        .dst_rst_ni  ( pclk_c2     ),

        .dst_data_o  ( r_data      ),
        .dst_valid_o ( r_valid     ),
        .dst_ready_i ( r_ready     )
    )

  end


endmodule