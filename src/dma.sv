`include "apb/typedef.svh"
`include "dma_utils.sv"

module apb_dma #(
  parameter int unsigned APB_SLV_DW = 16,
  parameter int unsigned APB_MST_DW = 32,
  parameter int unsigned APB_MST_DW = 16,
  parameter int unsigned ASYNC = 0,
  // The LSB APB_SLV_DW/8 bits are taken by the size of the registers
  // Additionally, $clog2(`NUM_REGS + 2) bits are necessary to determine
  // if we are accessing a register or one of the two FIFOs
  localparam int unsigned APB_SLV_AW = $clog2(`NUM_REGS + 2) + APB_SLV_DW/8
)(
 input logic pclk_c1,
 input logic preset_n_c1,
 input logic [APB_SLV_AW-1:0] paddr_c1,
 input logic [APB_SLW_DW-1:0] pwdata_c1,
 input logic pwrite_c1,
 input logic psel_c1,
 input logic penable_c1,
 input logic pstrb_c1,
 input logic [APB_SLW_DW-1:0] prdata_c1,
 input logic pready_c1,
 input logic pslverr_c1,

 input logic pclk_c2,
 input logic preset_n_c2,
 input logic [APB_MST_AW-1:0] paddr_c2,
 input logic [APB_MST_DW-1:0] pwdata_c2,
 input logic pwrite_c2,
 input logic psel_c2,
 input logic penable_c2,
 input logic pstrb_c2,
 input logic [APB_MST_DW-1:0] prdata_c2,
 input logic pready_c2,
 input logic pslverr_c2
);

   typedef logic [APB_SLW_AW-1:0] slv_addr_t;
   typedef logic [APB_SLW_DW-1:0] slv_data_t;
   typedef logic [APB_SLW_DW/8-1:0] slv_strb_t;
   `APB_TYPEDEF_ALL(slv,slv_addr_t,slv_data_t,slv_strb_t)


   typedef logic [APB_MST_AW-1:0] mst_addr_t;
   typedef logic [APB_MST_DW-1:0] mst_data_t;
   typedef logic [APB_MST_DW/8-1:0] mst_strb_t;
   `APB_TYPEDEF_ALL(mst,mst_addr_t,mst_data_t,mst_strb_t)

   typedef struct packed {
      slv_data_t data;
      slv_strb_t strb;
   } slv_write_beat_t;

   typedef logic [APB_SLV_DW-1:0] slv_read_beat_t;

   slv_req_t frontend_req;
   slv_resp_t frontend_resp;

   typedef struct packed {
      mst_data_t data;
      mst_strb_t strb;
   } mst_write_beat_t;

   typedef logic [APB_MST_DW-1:0] mst_read_beat_t;

   mst_req_t  backend_req;
   mst_resp_t backend_resp;

    // Write interface to backend
    slv_write_beat_t        w_data_fe;
    logic               w_valid_fe;
    logic               w_ready_fe;
    mst_write_beat_t        w_data_be;
    logic               w_valid_be;
    logic               w_ready_be;

    // Read interface to frontend
    slv_read_beat_t         r_data_fe;
    logic               r_valid_fe;
    logic               r_ready_fe;
    mst_read_beat_t         r_data_be;
    logic               r_valid_be;
    logic               r_ready_be;

    logic                 start      ;
    logic [APB_SLV_DW-1:0]start_addr ;
    logic [7:0]           num_words  ;
    logic                 rw         ;
    logic                 busy       ;

   assign frontend_req.penable = penable_c1;
   assign frontend_req.pwrite  = pwrite_c1;
   assign frontend_req.paddr   = paddr_c1;
   assign frontend_req.psel    = psel_c1;
   assign frontend_req.pwdata  = pwdata_c1;
   assign  prdata_c1  = frontend_resp.prdata;
   assign  pready_c1  = frontend_resp.pready;
   assign  pslverr_c1 = frontend_resp.pslverr;

   frontend #(
     .req_t        (slv_req_t       ),
     .resp_t       (slv_resp_t      ),
     .write_beat_t (slv_write_beat_t),
     .read_beat_t  (slv_read_beat_t ),
     .addr_t       (slv_addr_t      ),
     .MstDataWidth (APB_MST_DW      ),
     .AddrWidth    (APB_SLV_AW      ),
     .DataWidth    (APB_SLV_DW      )
   ) i_frontend (
       .clk_i        ( pclk_c1       ),
       .rst_ni       ( preset_n_c1  ),
       .slv_req_i    ( frontend_req  ),
       .slv_resp_o   ( frontend_resp ),

       .w_data_o     ( w_data_fe    ),
       .w_valid_o    ( w_valid_fe   ),
       .w_ready_i    ( w_ready_fe   ),

       .r_data_i     ( r_data_fe    ),
       .r_valid_i    (r_valid_fe    ),
       .r_ready_o    ( r_ready_fe   )

       .start_o      ( start        ),
       .start_addr_o ( start_addr   ),
       .num_bytes_o  ( num_bytes    ),
       .rw_o         ( rw           ),
       .busy_i       ( busy         )
       );

 midend #(
  .SlvDataWidth     (APB_SLV_DW      ),
  .MstDataWidth     (APB_MST_DW      ),
  .slv_write_beat_t (slv_write_beat_t),
  .slv_read_beat_t  (slv_read_beat_t ),
  .mst_write_beat_t (mst_write_beat_t),
  .mst_read_beat_t  (mst_read_beat_t ),
  .ASYNC        (ASYNC)
 ) i_midend (
  .pclk_c1     ( pclk_c1    ),
  .preset_n_c1 ( preset_n_c1)
  .pclk_c2     ( pclk_c2    ),
  .preset_n_c2 (preset_n_c2 ),
  .w_data_i    (w_data_fe   ),
  .w_valid_i   (w_valid_fe  ),
  .w_ready_o   ( w_ready_fe ),

  .w_data_o    (w_data_be   ),
  .w_valid_o   (w_valid_be  ),
  .w_ready_i   ( w_ready_be ),

  .r_data_i    (r_data_fe   ),
  .r_valid_i   (r_valid_fe  ),
  .r_ready_o   ( r_ready_fe ),

  .r_data_o    (r_data_be   ),
  .r_valid_o   (r_valid_be  ),
  .r_ready_i   ( r_ready_be )
 );

 backend #(
     .req_t        (mst_req_t       ),
     .resp_t       (mst_resp_t      ),
     .write_beat_t (mst_write_beat_t),
     .read_beat_t  (mst_read_beat_t ),
     .addr_t       (mst_addr_t      ),
     .AddrWidth    (APB_MST_AW      ),
     .DataWidth    (APB_MST_DW      )
 ) i_backend (
    .clk_i        ( pclk_c2    ),
    .rst_ni       ( preset_n_c2),
    .mst_req_o    ( backend_req ),
    .mst_resp_i   ( backend_resp),
 
    .w_data_i     ( w_data_be  ),
    .w_valid_i    ( w_valid_be ),
    .w_ready_o    ( w_ready_be ),
     
    .r_data_o     ( r_data_be  ),
    .r_valid_o    ( r_valid_be ),
    .r_ready_i    ( r_ready_be ),

    .start_i      (start       ),
    .start_addr_i (start_addr  ),
    .num_bytes_i  (num_bytes   ),
    .rw_i         (rw          ),
    .busy_o       (busy        )

 );

   assign penable_c2 = backend_req.penable;
   assign pwrite_c2  = backend_req.pwrite ;
   assign paddr_c2   = backend_req.paddr  ;
   assign psel_c2    = backend_req.psel   ;
   assign pwdata_c2 = backend_req.pwdata ;
   assign backend_resp.prdata  = prdata_c2 ;
   assign backend_resp.pready  = pready_c2 ;
   assign backend_resp.pslverr = pslverr_c2;

endmodule // apb_dma

		 
