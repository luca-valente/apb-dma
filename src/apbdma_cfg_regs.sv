`include "dma_utils.sv"

module apbdam_cfg_regs #(
    parameter int unsigned  RegAddrWidth    = -1,
    parameter int unsigned  RegDataWidth    = -1,
    parameter int unsigned  MstDataWidth    = -1,
    parameter int unsigned  SlvDataWidth    = -1,
    parameter type          req_t           = logic,
    parameter type          rsp_t           = logic
 ) (
    input logic     clk_i,
    input logic     rst_ni,

    input  req_t    req_i,
    output rsp_t    rsp_o,

    input logic [7:0] rfifo_numelements_i,
    input logic backend_busy_i,

    output logic rw_o,
    output logic start_o,
    output logic [RegDataWidth-1:0] start_addr_o,
    output logic [7:0] num_bytes_o

);
    `include "common_cells/registers.svh"

    // Internal Parameters
    localparam int unsigned NumRegs         = `NUM_REGS;
    localparam int unsigned RegsBits        = cf_math_pkg::idx_width(NumRegs);
    localparam int unsigned RegStrbWidth    = RegDataWidth/8;                   // TODO ASSERT: Must be power of two >= 16!!
    localparam int unsigned BiggerDataWidth = ( MstDataWidth > SlvDataWidth ) ?  MstDataWidth : SlvDataWidth;

    // Data and index types
    typedef logic [RegsBits-1:0]        reg_idx_t;
    typedef logic [RegDataWidth-1:0]    reg_data_t;

    // Local signals
    typedef struct packed {
        logic [RegDataWidth:0] start_addr;
        logic [7:0]            num_bytes;
        logic                  rw;
        logic                  start;
        logic [7:0]            rfifo_numelements;
        logic                  busy;
    } cfg_t;
    
    cfg_t       cfg_d, cfg_q;
    reg_idx_t   sel_reg;
    logic       sel_reg_mapped;
    reg_data_t  wmask;

    assign sel_reg          = req_i.paddr[$clog2(RegStrbWidth) +: RegsBits];
    assign sel_reg_mapped   = (sel_reg < NumRegs);

    assign rsp_o.pready  = 1'b1;  // Config writeable unless currently in transfer
    assign rsp_o.pslverr = sel_reg_mapped ? '0 : '1 ;

    // Read from register
    always_comb begin : proc_comb_read
        reg_data_t [NumRegs-1:0] rfield;
        reg_rsp_o.rdata = '0;
        if (sel_reg_mapped) begin
            rfield = {
                reg_data_t'(cfg_q.start_addr),
                reg_data_t'(cfg_q.num_bytes),
                reg_data_t'(cfg_q.rw),
                reg_data_t'(cfg_q.start),
                reg_data_t'(cfg_q.rfifo_numelements),
                reg_data_t'(cfg_q.busy)
            };
            rsp_o.prdata = rfield[sel_reg];
        end
    end

    // Generate write mask
    for (genvar i = 0; unsigned'(i) < RegStrbWidth; ++i ) begin : gen_wmask
        assign wmask[8*i +: 8] = {8{reg_req_i.wstrb[i]}};
    end

    // Write to register
    always_comb begin : proc_comb_write
        logic  chip_reg;
        logic [$clog2(NumChips)-1:0] sel_chip;
        cfg_d     = cfg_q;
        if (req_i.penable & req_i.psel & req_i.pwrite & sel_reg_mapped) begin
            case (sel_reg)
                'h0: cfg_d.start_addr        = (~wmask & cfg_q.start_addr        ) | (wmask & req_i.pwdata);
                'h1: cfg_d.num_bytes         = (~wmask & cfg_q.num_bytes         ) | (wmask & req_i.pwdata);
                'h2: cfg_d.rw                = (~wmask & cfg_q.rw                ) | (wmask & req_i.pwdata);
                'h3: cfg_d.start             = (~wmask & cfg_q.start             ) | (wmask & req_i.pwdata);
            endcase // sel_reg
        end
        cfg_d.rfifo_numelements = rfifo_numelements_i;
        cfg_d.busy              = busy_i;
    end

    // Registers
    `FFARN(cfg_q, cfg_d, cfg_t'('0), clk_i, rst_ni);

    // Outputs
    assign start_addr_o = cfg_q.start_addr;
    assign start_o = cfg_d.start_o;
    assign rw_o = cfg_q.rw;
    assign num_bytes_o = cfg_q.num_bytes;

    // pragma translate_off
    `ifndef VERILATOR

    access_aligned : assert property( 
        @(posedge clk_i) (req_i.penable & req_i.psel & req_i.pwrite) |-> 
        ( ( ( cfg_d.start_addr >> (BiggerDataWidth/8-1) ) << (BiggerDataWidth/8-1) )  == cfg_d.start_addr ) 
        ) else $fatal (1, "The starting address of a transaction must be aligned to APB_MST_DW/8.");

    num_bytes_aligned : assert property( 
        @(posedge clk_i) (req_i.penable & req_i.psel & req_i.pwrite) |-> 
        ( ( ( cfg_d.num_bytes >> (BiggerDataWidth/8-1) ) << (BiggerDataWidth/8-1) )  == cfg_d.num_bytes ) 
        ) else $fatal (1, "The number of bytes to be sent in a transaction must be a multiple of APB_MST_DW/8.");

    `endif
endmodule : hyperbus_cfg_regs