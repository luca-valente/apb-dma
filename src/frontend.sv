`include "register_interface/typedef.svh"
`include "dma_utils.sv"

module frontend #(
  parameter type req_t                = logic, // APB request strcut
  parameter type resp_t               = logic,  // APB response struct
  parameter type write_beat_t         = logic,  // Write struct
  parameter type read_beat_t          = logic,  // Read struct
  parameter type addr_t               = logic,
  parameter int unsigned MstDataWidth = -1,
  parameter int unsigned AddrWidth    = -1,
  parameter int unsigned DataWidth    = -1
)(
  input logic clk_i,
  input logic rst_ni,
  input req_t                 slv_req_i,
  output resp_t               slv_resp_o,

  output write_beat_t         w_data_o,
  output logic                w_valid_o,
  input  logic                w_ready_i,

  input write_beat_t         r_data_i,
  input logic                r_valid_i,
  output  logic              r_ready_o,

  output logic start_o,
  output logic [DataWidth=1:0] start_addr_o,
  output logic [7:0] num_bytes_o,
  output logic rw_o,
  input logic busy_i
);

   typedef struct packed {
     int unsigned idx;
     addr_t   start_addr;
     addr_t   end_addr;
   } rule_t;

   localparam	  NumSlaves = 4;

   req_t [NumSlaves-1:0] reqs;
   resp_t [NumSlaves-1:0] resps;

   rule_t [NumSlaves-1:0] addr_map ;

   localparam addr_t RegMaxAddr = `NUM_REGS * DataWidth / 8;
   localparam addr_t SingleWordSpace = DataWidth / 8;
   assign addr_map[0] = { idx : 0 , start_addr : addr_t'('0)                    , end_addr : RegMaxAddr                     }; // Cfg Regs
   assign addr_map[1] = { idx : 1 , start_addr : RegMaxAddr                     , end_addr : RegMaxAddr + SingleWordSpace   }; // W Fifo
   assign addr_map[2] = { idx : 2 , start_addr : RegMaxAddr + SingleWordSpace   , end_addr : RegMaxAddr + SingleWordSpace*2 }; // R Fifo
   assign addr_map[3] = { idx : 3 , start_addr : RegMaxAddr + SingleWordSpace*2 , end_addr : addr_t'('1)                    }; // Error slave

   logic	  sel;
   
   addr_decode #(
     .NoIndices ( 1         ),
     .NoRules   ( NumSlaves ),
     .addr_t    ( addr_t    ),
     .rule_t    ( rule_t    )
   ) i_addr_decode (
       .addr_i           ( slv_req_i.paddr ),
       .addr_map_i       ( addr_map        ),
       .idx_o            ( sel             ),
       .dec_valid_o      (                 ),
       .dec_error_o      (                 ),
       .en_default_idx_i ( 1'b1            ),
       .default_idx_i    ( 3               )
   );

   apb_demux #(   
     .NoMstPorts  ( NumSlaves ),
     .req_t       ( req_t     ),
     .resp_t      ( resp_t    )
   ) i_apb_demux (
       .slv_req_i  ( slv_req_i  ),
       .slv_resp_o ( slv_resp_o ),
       .mst_req_o  ( reqs       ),
       .mst_resp_i ( resps      ),
       .select_i   ( sel        )
   );

   logic rfifo_numelements;
   logic backend_busy;

   apbdma_cfg_regs #(
    .RegAddrWidth ( AddrWidth    ),
    .RegDataWidth ( DataWidth    ),
    .MstDataWidth ( MstDataWidth ),
    .SlvDataWidth ( DataWidth    ),
    .req_t        ( req_t        ),
    .rsp_t        ( resp_t       )
   ) i_cfg_regs (
    .clk_i               ( clk_i            ),
    .rst_ni              ( rst_ni           ),
    .req_i               ( reqs[0]          ),
    .rsp_o               ( resps[0]         ),
    .rfifo_numelements_i ( rfifo_numelements),
    .backend_busy        ( backend_busy     ),
    .rw_o                (rw_o              ),
    .start_o             (start_o           ),
    .start_addr_o        (start_addr_o      ),
    .num_bytes_o         (num_bytes_o       )
   );

   sync #(
	  .STAGES     ( 3    ),
	  .ResetValue ( 1'b0 )
   ) i_sync (
	.clk_i    ( clk_i                          ),
	.rst_ni   ( rst_ni                         ),
	.serial_i ( busy_i                         ),
	.serial_o ( backend_busy                   )
   );
   
   write_beat_t apb_write_beat, w_tobackend;
   logic	  w_valid;
   logic	  w_ready;
   

   assign apb_write_beat.data = reqs[1].pwdata;
   assign apb_write_beat.strb = reqs[1].pstrb;

   assign resps[1].pslverr = '0;
   
   stream_fifo #(
     .FALL_THROUGH ( 1'b0	            		),
     .DATA_WIDTH   ( $bits(apb_write_beat)),
     .DEPTH        ( 256			            ),
     .T            ( write_beat_t		      )
    ) i_wfifo (
        .clk_i      ( clk_i                          ),      // Clock
        .rst_ni     ( rst_ni                         ),     // Asynchronous reset active low
        .flush_i    ( 1'b0                           ),    // flush the fifo
        .testmode_i ( 1'b0                           ), // test_mode to bypass clock gating
        .usage_o    (                                ),    // fill pointer
    
        .data_i     ( apb_write_beat                 ),     // data to push into the fifo
        .valid_i    ( reqs[1].penable & reqs[1].psel ),    // input data valid
        .ready_o    ( resps[1].pready                ),    // fifo is not full
    
        .data_o     ( w_data_o                       ),     // output data
        .valid_o    ( w_valid_o                      ),    // fifo is not empty
        .ready_i    ( w_ready_i                      ) // pop head from fifo
   );

   assign resps[2].pslverr = '0;

   stream_fifo #(
     .FALL_THROUGH	( 1'b0		          	),
     .DATA_WIDTH	  ( $bits(r_data_i)   	),
     .DEPTH		      ( 256			            ),
     .T			        ( read_beat_t		      )
   ) i_rfifo (
        .clk_i      ( clk_i                               ),      // Clock
        .rst_ni     ( rst_ni                              ),     // Asynchronous reset active low
        .flush_i    ( 1'b0                                ),    // flush the fifo
        .testmode_i ( 1'b0                                ), // test_mode to bypass clock gating
        .usage_o    ( rfifo_numelements                   ),    // fill pointer
    
        .data_i     ( r_data_i                            ),     // data to push into the fifo
        .valid_i    ( r_valid_i                           ),    // input data valid
        .ready_o    ( r_ready_o                           ),    // fifo is not full
    
        .data_o     ( resps[2].prdata                     ),     // output data
        .valid_o    ( resps[2].pready                     ),    // fifo is not empty
        .ready_i    ( reqs[2].penable & reqs[2].psel      ) // pop head from fifo
   );

   apb_err_slv #(
     .req_t       ( req_t     ),
     .resp_t      ( resp_t    )
   ) i_apb_err_slv (
       .slv_req_i	  ( reqs[3]  ),
       .slv_resp_o	( resps[3] )
   );
   
endmodule // frontend
