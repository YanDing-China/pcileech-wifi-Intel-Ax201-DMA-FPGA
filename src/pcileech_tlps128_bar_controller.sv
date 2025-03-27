

`timescale 1ns / 1ps
`include "pcileech_header.svh"

module pcileech_tlps128_bar_controller(
    input                   rst,
    input                   clk,
    input                   bar_en,
    input [15:0]            pcie_id,
    input [31:0]            base_address_register,
    IfAXIS128.sink_lite     tlps_in,
    IfAXIS128.source        tlps_out
);
    
    // ------------------------------------------------------------------------
    // 1: TLP RECEIVE:
    // Receive incoming BAR requests from the TLP stream:
    // send them onwards to read and write FIFOs
    // ------------------------------------------------------------------------
    wire in_is_wr_ready;
    bit  in_is_wr_last;
    wire in_is_first    = tlps_in.tuser[0];
    wire in_is_bar      = bar_en && (tlps_in.tuser[8:2] != 0);
    wire in_is_rd       = (in_is_first && tlps_in.tlast && ((tlps_in.tdata[31:25] == 7'b0000000) || (tlps_in.tdata[31:25] == 7'b0010000) || (tlps_in.tdata[31:24] == 8'b00000010)));
    wire in_is_wr       = in_is_wr_last || (in_is_first && in_is_wr_ready && ((tlps_in.tdata[31:25] == 7'b0100000) || (tlps_in.tdata[31:25] == 7'b0110000) || (tlps_in.tdata[31:24] == 8'b01000010)));
    
    always @ ( posedge clk )
        if ( rst ) begin
            in_is_wr_last <= 0;
        end
        else if ( tlps_in.tvalid ) begin
            in_is_wr_last <= !tlps_in.tlast && in_is_wr;
        end
    
    wire [6:0]  wr_bar;
    wire [31:0] wr_addr;
    wire [3:0]  wr_be;
    wire [31:0] wr_data;
    wire        wr_valid;
    wire [87:0] rd_req_ctx;
    wire [6:0]  rd_req_bar;
    wire [31:0] rd_req_addr;
    wire        rd_req_valid;
    wire [87:0] rd_rsp_ctx;
    wire [31:0] rd_rsp_data;
    wire        rd_rsp_valid;
        
    pcileech_tlps128_bar_rdengine i_pcileech_tlps128_bar_rdengine(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        // TLPs:
        .pcie_id        ( pcie_id                       ),
        .tlps_in        ( tlps_in                       ),
        .tlps_in_valid  ( tlps_in.tvalid && in_is_bar && in_is_rd ),
        .tlps_out       ( tlps_out                      ),
        // BAR reads:
        .rd_req_ctx     ( rd_req_ctx                    ),
        .rd_req_bar     ( rd_req_bar                    ),
        .rd_req_addr    ( rd_req_addr                   ),
        .rd_req_valid   ( rd_req_valid                  ),
        .rd_rsp_ctx     ( rd_rsp_ctx                    ),
        .rd_rsp_data    ( rd_rsp_data                   ),
        .rd_rsp_valid   ( rd_rsp_valid                  )
    );

    pcileech_tlps128_bar_wrengine i_pcileech_tlps128_bar_wrengine(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        // TLPs:
        .tlps_in        ( tlps_in                       ),
        .tlps_in_valid  ( tlps_in.tvalid && in_is_bar && in_is_wr ),
        .tlps_in_ready  ( in_is_wr_ready                ),
        // outgoing BAR writes:
        .wr_bar         ( wr_bar                        ),
        .wr_addr        ( wr_addr                       ),
        .wr_be          ( wr_be                         ),
        .wr_data        ( wr_data                       ),
        .wr_valid       ( wr_valid                      )
    );
    
    wire [87:0] bar_rsp_ctx[7];
    wire [31:0] bar_rsp_data[7];
    wire        bar_rsp_valid[7];
    
    assign rd_rsp_ctx = bar_rsp_valid[0] ? bar_rsp_ctx[0] :
                        bar_rsp_valid[1] ? bar_rsp_ctx[1] :
                        bar_rsp_valid[2] ? bar_rsp_ctx[2] :
                        bar_rsp_valid[3] ? bar_rsp_ctx[3] :
                        bar_rsp_valid[4] ? bar_rsp_ctx[4] :
                        bar_rsp_valid[5] ? bar_rsp_ctx[5] :
                        bar_rsp_valid[6] ? bar_rsp_ctx[6] : 0;
    assign rd_rsp_data = bar_rsp_valid[0] ? bar_rsp_data[0] :
                        bar_rsp_valid[1] ? bar_rsp_data[1] :
                        bar_rsp_valid[2] ? bar_rsp_data[2] :
                        bar_rsp_valid[3] ? bar_rsp_data[3] :
                        bar_rsp_valid[4] ? bar_rsp_data[4] :
                        bar_rsp_valid[5] ? bar_rsp_data[5] :
                        bar_rsp_valid[6] ? bar_rsp_data[6] : 0;
    assign rd_rsp_valid = bar_rsp_valid[0] || bar_rsp_valid[1] || bar_rsp_valid[2] || bar_rsp_valid[3] || bar_rsp_valid[4] || bar_rsp_valid[5] || bar_rsp_valid[6];
    
   
    pcileech_bar_impl_Bar0_Ax201_wifi i_bar0(
        .rst                   ( rst                           ),
        .clk                   ( clk                           ),
        .wr_addr               ( wr_addr                       ),
        .wr_be                 ( wr_be                         ),
        .wr_data               ( wr_data                       ),
        .wr_valid              ( wr_valid && wr_bar[0]         ),
        .rd_req_ctx            ( rd_req_ctx                    ),
        .rd_req_addr           ( rd_req_addr                   ),
        .rd_req_valid          ( rd_req_valid && rd_req_bar[0] ),
        .base_address_register ( base_address_register         ),
        .rd_rsp_ctx            ( bar_rsp_ctx[0]                ),
        .rd_rsp_data           ( bar_rsp_data[0]               ),
        .rd_rsp_valid          ( bar_rsp_valid[0]              )
    );
    
    pcileech_bar_impl_loopaddr i_bar1(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        .wr_addr        ( wr_addr                       ),
        .wr_be          ( wr_be                         ),
        .wr_data        ( wr_data                       ),
        .wr_valid       ( wr_valid && wr_bar[1]         ),
        .rd_req_ctx     ( rd_req_ctx                    ),
        .rd_req_addr    ( rd_req_addr                   ),
        .rd_req_valid   ( rd_req_valid && rd_req_bar[1] ),
        .rd_rsp_ctx     ( bar_rsp_ctx[1]                ),
        .rd_rsp_data    ( bar_rsp_data[1]               ),
        .rd_rsp_valid   ( bar_rsp_valid[1]              )
    );
    
    pcileech_bar_impl_none i_bar2(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        .wr_addr        ( wr_addr                       ),
        .wr_be          ( wr_be                         ),
        .wr_data        ( wr_data                       ),
        .wr_valid       ( wr_valid && wr_bar[2]         ),
        .rd_req_ctx     ( rd_req_ctx                    ),
        .rd_req_addr    ( rd_req_addr                   ),
        .rd_req_valid   ( rd_req_valid && rd_req_bar[2] ),
        .rd_rsp_ctx     ( bar_rsp_ctx[2]                ),
        .rd_rsp_data    ( bar_rsp_data[2]               ),
        .rd_rsp_valid   ( bar_rsp_valid[2]              )
    );
    
    pcileech_bar_impl_none i_bar3(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        .wr_addr        ( wr_addr                       ),
        .wr_be          ( wr_be                         ),
        .wr_data        ( wr_data                       ),
        .wr_valid       ( wr_valid && wr_bar[3]         ),
        .rd_req_ctx     ( rd_req_ctx                    ),
        .rd_req_addr    ( rd_req_addr                   ),
        .rd_req_valid   ( rd_req_valid && rd_req_bar[3] ),
        .rd_rsp_ctx     ( bar_rsp_ctx[3]                ),
        .rd_rsp_data    ( bar_rsp_data[3]               ),
        .rd_rsp_valid   ( bar_rsp_valid[3]              )
    );
    
    pcileech_bar_impl_none i_bar4(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        .wr_addr        ( wr_addr                       ),
        .wr_be          ( wr_be                         ),
        .wr_data        ( wr_data                       ),
        .wr_valid       ( wr_valid && wr_bar[4]         ),
        .rd_req_ctx     ( rd_req_ctx                    ),
        .rd_req_addr    ( rd_req_addr                   ),
        .rd_req_valid   ( rd_req_valid && rd_req_bar[4] ),
        .rd_rsp_ctx     ( bar_rsp_ctx[4]                ),
        .rd_rsp_data    ( bar_rsp_data[4]               ),
        .rd_rsp_valid   ( bar_rsp_valid[4]              )
    );
    
    pcileech_bar_impl_none i_bar5(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        .wr_addr        ( wr_addr                       ),
        .wr_be          ( wr_be                         ),
        .wr_data        ( wr_data                       ),
        .wr_valid       ( wr_valid && wr_bar[5]         ),
        .rd_req_ctx     ( rd_req_ctx                    ),
        .rd_req_addr    ( rd_req_addr                   ),
        .rd_req_valid   ( rd_req_valid && rd_req_bar[5] ),
        .rd_rsp_ctx     ( bar_rsp_ctx[5]                ),
        .rd_rsp_data    ( bar_rsp_data[5]               ),
        .rd_rsp_valid   ( bar_rsp_valid[5]              )
		// 注本人不出任何固件，不卖任何固件，不做任何固件，不加任何好友，没有任何联系方式，切勿用于非法盈利，仅供学习交流使用。
		// 教程：https://docs.qq.com/doc/DQ01lVGtHelROVHNv
    );
    
    pcileech_bar_impl_none i_bar6_optrom(
        .rst            ( rst                           ),
        .clk            ( clk                           ),
        .wr_addr        ( wr_addr                       ),
        .wr_be          ( wr_be                         ),
        .wr_data        ( wr_data                       ),
        .wr_valid       ( wr_valid && wr_bar[6]         ),
        .rd_req_ctx     ( rd_req_ctx                    ),
        .rd_req_addr    ( rd_req_addr                   ),
        .rd_req_valid   ( rd_req_valid && rd_req_bar[6] ),
        .rd_rsp_ctx     ( bar_rsp_ctx[6]                ),
        .rd_rsp_data    ( bar_rsp_data[6]               ),
        .rd_rsp_valid   ( bar_rsp_valid[6]              )
    );


endmodule



// ------------------------------------------------------------------------
// BAR WRITE ENGINE:
// Receives BAR WRITE TLPs and output BAR WRITE requests.
// Holds a 2048-byte buffer.
// Input flow rate is 16bytes/CLK (max).
// Output flow rate is 4bytes/CLK.
// If write engine overflows incoming TLP is completely discarded silently.
// ------------------------------------------------------------------------
module pcileech_tlps128_bar_wrengine(
    input                   rst,    
    input                   clk,
    // TLPs:
    IfAXIS128.sink_lite     tlps_in,
    input                   tlps_in_valid,
    output                  tlps_in_ready,
    // outgoing BAR writes:
    output bit [6:0]        wr_bar,
    output bit [31:0]       wr_addr,
    output bit [3:0]        wr_be,
    output bit [31:0]       wr_data,
    output bit              wr_valid
);

    wire            f_rd_en;
    wire [127:0]    f_tdata;
    wire [3:0]      f_tkeepdw;
    wire [8:0]      f_tuser;
    wire            f_tvalid;
    
    bit [127:0]     tdata;
    bit [3:0]       tkeepdw;
    bit             tlast;
    
    bit [3:0]       be_first;
    bit [3:0]       be_last;
    bit             first_dw;
    bit [31:0]      addr;

    fifo_141_141_clk1_bar_wr i_fifo_141_141_clk1_bar_wr(
        .srst           ( rst                           ),
        .clk            ( clk                           ),
        .wr_en          ( tlps_in_valid                 ),
        .din            ( {tlps_in.tuser[8:0], tlps_in.tkeepdw, tlps_in.tdata} ),
        .full           (                               ),
        .prog_empty     ( tlps_in_ready                 ),
        .rd_en          ( f_rd_en                       ),
        .dout           ( {f_tuser, f_tkeepdw, f_tdata} ),    
        .empty          (                               ),
        .valid          ( f_tvalid                      )
    );
    
    // STATE MACHINE:
    `define S_ENGINE_IDLE        3'h0
    `define S_ENGINE_FIRST       3'h1
    `define S_ENGINE_4DW_REQDATA 3'h2
    `define S_ENGINE_TX0         3'h4
    `define S_ENGINE_TX1         3'h5
    `define S_ENGINE_TX2         3'h6
    `define S_ENGINE_TX3         3'h7
    (* KEEP = "TRUE" *) bit [3:0] state = `S_ENGINE_IDLE;
    
    assign f_rd_en = (state == `S_ENGINE_IDLE) ||
                     (state == `S_ENGINE_4DW_REQDATA) ||
                     (state == `S_ENGINE_TX3) ||
                     ((state == `S_ENGINE_TX2 && !tkeepdw[3])) ||
                     ((state == `S_ENGINE_TX1 && !tkeepdw[2])) ||
                     ((state == `S_ENGINE_TX0 && !f_tkeepdw[1]));

    always @ ( posedge clk ) begin
        wr_addr     <= addr;
        wr_valid    <= ((state == `S_ENGINE_TX0) && f_tvalid) || (state == `S_ENGINE_TX1) || (state == `S_ENGINE_TX2) || (state == `S_ENGINE_TX3);
        
    end

    always @ ( posedge clk )
        if ( rst ) begin
            state <= `S_ENGINE_IDLE;
        end
        else case ( state )
            `S_ENGINE_IDLE: begin
                state   <= `S_ENGINE_FIRST;
            end
            `S_ENGINE_FIRST: begin
                if ( f_tvalid && f_tuser[0] ) begin
                    wr_bar      <= f_tuser[8:2];
                    tdata       <= f_tdata;
                    tkeepdw     <= f_tkeepdw;
                    tlast       <= f_tuser[1];
                    first_dw    <= 1;
                    be_first    <= f_tdata[35:32];
                    be_last     <= f_tdata[39:36];
                    if ( f_tdata[31:29] == 8'b010 ) begin       // 3 DW header, with data
                        addr    <= { f_tdata[95:66], 2'b00 };
                        state   <= `S_ENGINE_TX3;
                    end
                    else if ( f_tdata[31:29] == 8'b011 ) begin  // 4 DW header, with data
                        addr    <= { f_tdata[127:98], 2'b00 };
                        state   <= `S_ENGINE_4DW_REQDATA;
                    end 
                end
                else begin
                    state   <= `S_ENGINE_IDLE;
                end
            end 
            `S_ENGINE_4DW_REQDATA: begin
                state   <= `S_ENGINE_TX0;
            end
            `S_ENGINE_TX0: begin
                tdata       <= f_tdata;
                tkeepdw     <= f_tkeepdw;
                tlast       <= f_tuser[1];
                addr        <= addr + 4;
                wr_data     <= { f_tdata[0+00+:8], f_tdata[0+08+:8], f_tdata[0+16+:8], f_tdata[0+24+:8] };
                first_dw    <= 0;
                wr_be       <= first_dw ? be_first : (f_tkeepdw[1] ? 4'hf : be_last);
                state       <= f_tvalid ? (f_tkeepdw[1] ? `S_ENGINE_TX1 : `S_ENGINE_FIRST) : `S_ENGINE_IDLE;
            end
            `S_ENGINE_TX1: begin
                addr        <= addr + 4;
                wr_data     <= { tdata[32+00+:8], tdata[32+08+:8], tdata[32+16+:8], tdata[32+24+:8] };
                first_dw    <= 0;
                wr_be       <= first_dw ? be_first : (tkeepdw[2] ? 4'hf : be_last);
                state       <= tkeepdw[2] ? `S_ENGINE_TX2 : `S_ENGINE_FIRST;
            end
            `S_ENGINE_TX2: begin
                addr        <= addr + 4;
                wr_data     <= { tdata[64+00+:8], tdata[64+08+:8], tdata[64+16+:8], tdata[64+24+:8] };
                first_dw    <= 0;
                wr_be       <= first_dw ? be_first : (tkeepdw[3] ? 4'hf : be_last);
                state       <= tkeepdw[3] ? `S_ENGINE_TX3 : `S_ENGINE_FIRST;
            end
            `S_ENGINE_TX3: begin
                addr        <= addr + 4;
                wr_data     <= { tdata[96+00+:8], tdata[96+08+:8], tdata[96+16+:8], tdata[96+24+:8] };
                first_dw    <= 0;
                wr_be       <= first_dw ? be_first : (!tlast ? 4'hf : be_last);
                state       <= !tlast ? `S_ENGINE_TX0 : `S_ENGINE_FIRST;
            end
        endcase

endmodule



// ------------------------------------------------------------------------
// BAR READ ENGINE:
// Receives BAR READ TLPs and output BAR READ requests.
// ------------------------------------------------------------------------
module pcileech_tlps128_bar_rdengine(
    input                   rst,    
    input                   clk,
    // TLPs:
    input [15:0]            pcie_id,
    IfAXIS128.sink_lite     tlps_in,
    input                   tlps_in_valid,
    IfAXIS128.source        tlps_out,
    // BAR reads:
    output [87:0]           rd_req_ctx,
    output [6:0]            rd_req_bar,
    output [31:0]           rd_req_addr,
    output                  rd_req_valid,
    input  [87:0]           rd_rsp_ctx,
    input  [31:0]           rd_rsp_data,
    input                   rd_rsp_valid
);

    // ------------------------------------------------------------------------
    // 1: PROCESS AND QUEUE INCOMING READ TLPs:
    // ------------------------------------------------------------------------
    wire [10:0] rd1_in_dwlen    = (tlps_in.tdata[9:0] == 0) ? 11'd1024 : {1'b0, tlps_in.tdata[9:0]};
    wire [6:0]  rd1_in_bar      = tlps_in.tuser[8:2];
    wire [15:0] rd1_in_reqid    = tlps_in.tdata[63:48];
    wire [7:0]  rd1_in_tag      = tlps_in.tdata[47:40];
    wire [31:0] rd1_in_addr     = { ((tlps_in.tdata[31:29] == 3'b000) ? tlps_in.tdata[95:66] : tlps_in.tdata[127:98]), 2'b00 };
    wire [73:0] rd1_in_data;
    assign rd1_in_data[73:63]   = rd1_in_dwlen;
    assign rd1_in_data[62:56]   = rd1_in_bar;   
    assign rd1_in_data[55:48]   = rd1_in_tag;
    assign rd1_in_data[47:32]   = rd1_in_reqid;
    assign rd1_in_data[31:0]    = rd1_in_addr;
    
    wire        rd1_out_rden;
    wire [73:0] rd1_out_data;
    wire        rd1_out_valid;
    
    fifo_74_74_clk1_bar_rd1 i_fifo_74_74_clk1_bar_rd1(
        .srst           ( rst                           ),
        .clk            ( clk                           ),
        .wr_en          ( tlps_in_valid                 ),
        .din            ( rd1_in_data                   ),
        .full           (                               ),
        .rd_en          ( rd1_out_rden                  ),
        .dout           ( rd1_out_data                  ),    
        .empty          (                               ),
        .valid          ( rd1_out_valid                 )
    );
    
    // ------------------------------------------------------------------------
    // 2: PROCESS AND SPLIT READ TLPs INTO RESPONSE TLP READ REQUESTS AND QUEUE:
    //    (READ REQUESTS LARGER THAN 128-BYTES WILL BE SPLIT INTO MULTIPLE).
    // ------------------------------------------------------------------------
    
    wire [10:0] rd1_out_dwlen       = rd1_out_data[73:63];
    wire [4:0]  rd1_out_dwlen5      = rd1_out_data[67:63];
    wire [4:0]  rd1_out_addr5       = rd1_out_data[6:2];
    
    // 1st "instant" packet:
    wire [4:0]  rd2_pkt1_dwlen_pre  = ((rd1_out_addr5 + rd1_out_dwlen5 > 6'h20) || ((rd1_out_addr5 != 0) && (rd1_out_dwlen5 == 0))) ? (6'h20 - rd1_out_addr5) : rd1_out_dwlen5;
    wire [5:0]  rd2_pkt1_dwlen      = (rd2_pkt1_dwlen_pre == 0) ? 6'h20 : rd2_pkt1_dwlen_pre;
    wire [10:0] rd2_pkt1_dwlen_next = rd1_out_dwlen - rd2_pkt1_dwlen;
    wire        rd2_pkt1_large      = (rd1_out_dwlen > 32) || (rd1_out_dwlen != rd2_pkt1_dwlen);
    wire        rd2_pkt1_tiny       = (rd1_out_dwlen == 1);
    wire [11:0] rd2_pkt1_bc         = rd1_out_dwlen << 2;
    wire [85:0] rd2_pkt1;
    assign      rd2_pkt1[85:74]     = rd2_pkt1_bc;
    assign      rd2_pkt1[73:63]     = rd2_pkt1_dwlen;
    assign      rd2_pkt1[62:0]      = rd1_out_data[62:0];
    
    // Nth packet (if split should take place):
    bit  [10:0] rd2_total_dwlen;
    wire [10:0] rd2_total_dwlen_next = rd2_total_dwlen - 11'h20;
    
    bit  [85:0] rd2_pkt2;
    wire [10:0] rd2_pkt2_dwlen = rd2_pkt2[73:63];
    wire        rd2_pkt2_large = (rd2_total_dwlen > 11'h20);
    
    wire        rd2_out_rden;
    
    // STATE MACHINE:
    `define S2_ENGINE_REQDATA     1'h0
    `define S2_ENGINE_PROCESSING  1'h1
    (* KEEP = "TRUE" *) bit [0:0] state2 = `S2_ENGINE_REQDATA;
    
    always @ ( posedge clk )
        if ( rst ) begin
            state2 <= `S2_ENGINE_REQDATA;
        end
        else case ( state2 )
            `S2_ENGINE_REQDATA: begin
                if ( rd1_out_valid && rd2_pkt1_large ) begin
                    rd2_total_dwlen <= rd2_pkt1_dwlen_next;                             // dwlen (total remaining)
                    rd2_pkt2[85:74] <= rd2_pkt1_dwlen_next << 2;                        // byte-count
                    rd2_pkt2[73:63] <= (rd2_pkt1_dwlen_next > 11'h20) ? 11'h20 : rd2_pkt1_dwlen_next;   // dwlen next
                    rd2_pkt2[62:12] <= rd1_out_data[62:12];                             // various data
                    rd2_pkt2[11:0]  <= rd1_out_data[11:0] + (rd2_pkt1_dwlen << 2);      // base address (within 4k page)
                    state2 <= `S2_ENGINE_PROCESSING;
                end
            end
            `S2_ENGINE_PROCESSING: begin
                if ( rd2_out_rden ) begin
                    rd2_total_dwlen <= rd2_total_dwlen_next;                                // dwlen (total remaining)
                    rd2_pkt2[85:74] <= rd2_total_dwlen_next << 2;                           // byte-count
                    rd2_pkt2[73:63] <= (rd2_total_dwlen_next > 11'h20) ? 11'h20 : rd2_total_dwlen_next;   // dwlen next
                    rd2_pkt2[62:12] <= rd2_pkt2[62:12];                                     // various data
                    rd2_pkt2[11:0]  <= rd2_pkt2[11:0] + (rd2_pkt2_dwlen << 2);              // base address (within 4k page)
                    if ( !rd2_pkt2_large ) begin
                        state2 <= `S2_ENGINE_REQDATA;
                    end
                end
            end
        endcase
    
    assign rd1_out_rden = rd2_out_rden && (((state2 == `S2_ENGINE_REQDATA) && (!rd1_out_valid || rd2_pkt1_tiny)) || ((state2 == `S2_ENGINE_PROCESSING) && !rd2_pkt2_large));

    wire [85:0] rd2_in_data  = (state2 == `S2_ENGINE_REQDATA) ? rd2_pkt1 : rd2_pkt2;
    wire        rd2_in_valid = rd1_out_valid || ((state2 == `S2_ENGINE_PROCESSING) && rd2_out_rden);

    bit  [85:0] rd2_out_data;
    bit         rd2_out_valid;
    always @ ( posedge clk ) begin
        rd2_out_data    <= rd2_in_valid ? rd2_in_data : rd2_out_data;
        rd2_out_valid   <= rd2_in_valid && !rst;
    end

    // ------------------------------------------------------------------------
    // 3: PROCESS EACH READ REQUEST PACKAGE PER INDIVIDUAL 32-bit READ DWORDS:
    // ------------------------------------------------------------------------

    wire [4:0]  rd2_out_dwlen   = rd2_out_data[67:63];
    wire        rd2_out_last    = (rd2_out_dwlen == 1);
    wire [9:0]  rd2_out_dwaddr  = rd2_out_data[11:2];
    
    wire        rd3_enable;
    
    bit         rd3_process_valid;
    bit         rd3_process_first;
    bit         rd3_process_last;
    bit [4:0]   rd3_process_dwlen;
    bit [9:0]   rd3_process_dwaddr;
    bit [85:0]  rd3_process_data;
    wire        rd3_process_next_last = (rd3_process_dwlen == 2);
    wire        rd3_process_nextnext_last = (rd3_process_dwlen <= 3);
    
    assign rd_req_ctx   = { rd3_process_first, rd3_process_last, rd3_process_data };
    assign rd_req_bar   = rd3_process_data[62:56];
    assign rd_req_addr  = { rd3_process_data[31:12], rd3_process_dwaddr, 2'b00 };
    assign rd_req_valid = rd3_process_valid;
    
    // STATE MACHINE:
    `define S3_ENGINE_REQDATA     1'h0
    `define S3_ENGINE_PROCESSING  1'h1
    (* KEEP = "TRUE" *) bit [0:0] state3 = `S3_ENGINE_REQDATA;
    
    always @ ( posedge clk )
        if ( rst ) begin
            rd3_process_valid   <= 1'b0;
            state3              <= `S3_ENGINE_REQDATA;
        end
        else case ( state3 )
            `S3_ENGINE_REQDATA: begin
                if ( rd2_out_valid ) begin
                    rd3_process_valid       <= 1'b1;
                    rd3_process_first       <= 1'b1;                    // FIRST
                    rd3_process_last        <= rd2_out_last;            // LAST (low 5 bits of dwlen == 1, [max pktlen = 0x20))
                    rd3_process_dwlen       <= rd2_out_dwlen;           // PKT LENGTH IN DW
                    rd3_process_dwaddr      <= rd2_out_dwaddr;          // DWADDR OF THIS DWORD
                    rd3_process_data[85:0]  <= rd2_out_data[85:0];      // FORWARD / SAVE DATA
                    if ( !rd2_out_last ) begin
                        state3 <= `S3_ENGINE_PROCESSING;
                    end
                end
                else begin
                    rd3_process_valid       <= 1'b0;
                end
            end
            `S3_ENGINE_PROCESSING: begin
                rd3_process_first           <= 1'b0;                    // FIRST
                rd3_process_last            <= rd3_process_next_last;   // LAST
                rd3_process_dwlen           <= rd3_process_dwlen - 1;   // LEN DEC
                rd3_process_dwaddr          <= rd3_process_dwaddr + 1;  // ADDR INC
                if ( rd3_process_next_last ) begin
                    state3 <= `S3_ENGINE_REQDATA;
                end
            end
        endcase

    assign rd2_out_rden = rd3_enable && (
        ((state3 == `S3_ENGINE_REQDATA) && (!rd2_out_valid || rd2_out_last)) ||
        ((state3 == `S3_ENGINE_PROCESSING) && rd3_process_nextnext_last));
    
    // ------------------------------------------------------------------------
    // 4: PROCESS RESPONSES:
    // ------------------------------------------------------------------------
    
    wire        rd_rsp_first    = rd_rsp_ctx[87];
    wire        rd_rsp_last     = rd_rsp_ctx[86];
    
    wire [9:0]  rd_rsp_dwlen    = rd_rsp_ctx[72:63];
    wire [11:0] rd_rsp_bc       = rd_rsp_ctx[85:74];
    wire [15:0] rd_rsp_reqid    = rd_rsp_ctx[47:32];
    wire [7:0]  rd_rsp_tag      = rd_rsp_ctx[55:48];
    wire [6:0]  rd_rsp_lowaddr  = rd_rsp_ctx[6:0];
    wire [31:0] rd_rsp_addr     = rd_rsp_ctx[31:0];
    wire [31:0] rd_rsp_data_bs  = { rd_rsp_data[7:0], rd_rsp_data[15:8], rd_rsp_data[23:16], rd_rsp_data[31:24] };
    
    // 1: 32-bit -> 128-bit state machine:
    bit [127:0] tdata;
    bit [3:0]   tkeepdw = 0;
    bit         tlast;
    bit         first   = 1;
    wire        tvalid  = tlast || tkeepdw[3];
    
    always @ ( posedge clk )
        if ( rst ) begin
            tkeepdw <= 0;
            tlast   <= 0;
            first   <= 0;
        end
        else if ( rd_rsp_valid && rd_rsp_first ) begin
            tkeepdw         <= 4'b1111;
            tlast           <= rd_rsp_last;
            first           <= 1'b1;
            tdata[31:0]     <= { 22'b0100101000000000000000, rd_rsp_dwlen };            // format, type, length
            tdata[63:32]    <= { pcie_id[7:0], pcie_id[15:8], 4'b0, rd_rsp_bc };        // pcie_id, byte_count
            tdata[95:64]    <= { rd_rsp_reqid, rd_rsp_tag, 1'b0, rd_rsp_lowaddr };      // req_id, tag, lower_addr
            tdata[127:96]   <= rd_rsp_data_bs;
        end
        else begin
            tlast   <= rd_rsp_valid && rd_rsp_last;
            tkeepdw <= tvalid ? (rd_rsp_valid ? 4'b0001 : 4'b0000) : (rd_rsp_valid ? ((tkeepdw << 1) | 1'b1) : tkeepdw);
            first   <= 0;
            if ( rd_rsp_valid ) begin
                if ( tvalid || !tkeepdw[0] )
                    tdata[31:0]   <= rd_rsp_data_bs;
                if ( !tkeepdw[1] )
                    tdata[63:32]  <= rd_rsp_data_bs;
                if ( !tkeepdw[2] )
                    tdata[95:64]  <= rd_rsp_data_bs;
                if ( !tkeepdw[3] )
                    tdata[127:96] <= rd_rsp_data_bs;   
            end
        end
    
    // 2.1 - submit to output fifo - will feed into mux/pcie core.
    fifo_134_134_clk1_bar_rdrsp i_fifo_134_134_clk1_bar_rdrsp(
        .srst           ( rst                       ),
        .clk            ( clk                       ),
        .din            ( { first, tlast, tkeepdw, tdata } ),
        .wr_en          ( tvalid                    ),
        .rd_en          ( tlps_out.tready           ),
        .dout           ( { tlps_out.tuser[0], tlps_out.tlast, tlps_out.tkeepdw, tlps_out.tdata } ),
        .full           (                           ),
        .empty          (                           ),
        .prog_empty     ( rd3_enable                ),
        .valid          ( tlps_out.tvalid           )
    );
    
    assign tlps_out.tuser[1] = tlps_out.tlast;
    assign tlps_out.tuser[8:2] = 0;
    
    // 2.2 - packet count:
    bit [10:0]  pkt_count       = 0;
    wire        pkt_count_dec   = tlps_out.tvalid && tlps_out.tlast;
    wire        pkt_count_inc   = tvalid && tlast;
    wire [10:0] pkt_count_next  = pkt_count + pkt_count_inc - pkt_count_dec;
    assign tlps_out.has_data    = (pkt_count_next > 0);
    
    always @ ( posedge clk ) begin
        pkt_count <= rst ? 0 : pkt_count_next;
    end

endmodule



// ------------------------------------------------------------------------
// Example BAR implementation that does nothing but drop any read/writes
// silently without generating a response.
// This is only recommended for placeholder designs.
// Latency = N/A.
// ------------------------------------------------------------------------
module pcileech_bar_impl_none(
    input               rst,
    input               clk,
    // incoming BAR writes:
    input [31:0]        wr_addr,
    input [3:0]         wr_be,
    input [31:0]        wr_data,
    input               wr_valid,
    // incoming BAR reads:
    input  [87:0]       rd_req_ctx,
    input  [31:0]       rd_req_addr,
    input               rd_req_valid,
    // outgoing BAR read replies:
    output bit [87:0]   rd_rsp_ctx,
    output bit [31:0]   rd_rsp_data,
    output bit          rd_rsp_valid
);

    initial rd_rsp_ctx = 0;
    initial rd_rsp_data = 0;
    initial rd_rsp_valid = 0;

endmodule



// ------------------------------------------------------------------------
// Example BAR implementation of "address loopback" which can be useful
// for testing. Any read to a specific BAR address will result in the
// address as response.
// Latency = 2CLKs.
// ------------------------------------------------------------------------
module pcileech_bar_impl_loopaddr(
    input               rst,
    input               clk,
    // incoming BAR writes:
    input [31:0]        wr_addr,
    input [3:0]         wr_be,
    input [31:0]        wr_data,
    input               wr_valid,
    // incoming BAR reads:
    input [87:0]        rd_req_ctx,
    input [31:0]        rd_req_addr,
    input               rd_req_valid,
    // outgoing BAR read replies:
    output bit [87:0]   rd_rsp_ctx,
    output bit [31:0]   rd_rsp_data,
    output bit          rd_rsp_valid
);

    bit [87:0]      rd_req_ctx_1;
    bit [31:0]      rd_req_addr_1;
    bit             rd_req_valid_1;
    
    always @ ( posedge clk ) begin
        rd_req_ctx_1    <= rd_req_ctx;
        rd_req_addr_1   <= rd_req_addr;
        rd_req_valid_1  <= rd_req_valid;
        rd_rsp_ctx      <= rd_req_ctx_1;
        rd_rsp_data     <= rd_req_addr_1;
        rd_rsp_valid    <= rd_req_valid_1;
    end    

endmodule



// ------------------------------------------------------------------------
// Example BAR implementation of a 4kB writable initial-zero BAR.
// Latency = 2CLKs.
// ------------------------------------------------------------------------
module pcileech_bar_impl_zerowrite4k(
    input               rst,
    input               clk,
    // incoming BAR writes:
    input [31:0]        wr_addr,
    input [3:0]         wr_be,
    input [31:0]        wr_data,
    input               wr_valid,
    // incoming BAR reads:
    input  [87:0]       rd_req_ctx,
    input  [31:0]       rd_req_addr,
    input               rd_req_valid,
    // outgoing BAR read replies:
    output bit [87:0]   rd_rsp_ctx,
    output bit [31:0]   rd_rsp_data,
    output bit          rd_rsp_valid
);

    bit [87:0]  drd_req_ctx;
    bit         drd_req_valid;
    wire [31:0] doutb;
    
    always @ ( posedge clk ) begin
        drd_req_ctx     <= rd_req_ctx;
        drd_req_valid   <= rd_req_valid;
        rd_rsp_ctx      <= drd_req_ctx;
        rd_rsp_valid    <= drd_req_valid;
        rd_rsp_data     <= doutb; 
    end
    
    bram_bar_zero4k i_bram_bar_zero4k(
        // Port A - write:
        .addra  ( wr_addr[11:2]     ),
        .clka   ( clk               ),
        .dina   ( wr_data           ),
        .ena    ( wr_valid          ),
        .wea    ( wr_be             ),
        // Port A - read (2 CLK latency):
        .addrb  ( rd_req_addr[11:2] ),
        .clkb   ( clk               ),
        .doutb  ( doutb             ),
        .enb    ( rd_req_valid      )
    );

endmodule




// 英特尔AX201 WiFi 6适配器  源于笔记本采集 
// 注本人不出任何固件，不卖任何固件，不做任何固件，不加任何好友，没有任何联系方式，切勿用于非法盈利，仅供学习交流使用。
// 教程：https://docs.qq.com/doc/DQ01lVGtHelROVHNv
module pcileech_bar_impl_Bar0_Ax201_wifi(
    input               rst,
    input               clk,
    input [31:0]        wr_addr,
    input [3:0]         wr_be,
    input [31:0]        wr_data,
    input               wr_valid,
    input [87:0]        rd_req_ctx,
    input [31:0]        rd_req_addr,
    input               rd_req_valid,
    input [31:0]        base_address_register,
    output reg [87:0]   rd_rsp_ctx,
    output reg [31:0]   rd_rsp_data,
    output reg          rd_rsp_valid
);
	//本源码源于焱鼎，切勿用于非法盈利，仅供学习交流使用。
	/*
	localparam Time_End_1ns = 1;  				   // 纳秒 模块就是1纳秒的
	localparam Time_End_1us = Time_End_1ns * 1000; // 微秒
	localparam Time_End_1ms = Time_End_1us * 1000; // 毫秒
	localparam Time_End_1s  = Time_End_1ms * 1000; // 秒
	localparam Time_End_1m  = Time_End_1s  * 60;   // 分钟
	localparam Time_End_1h  = Time_End_1m  * 60;   // 小时
	*/
	/*
	//  FH中断原因   用不到的先屏蔽 防止内存溢出
        localparam CSR_INT_BIT_ALIVE                 = 1 << 0;    // uCode初始化后产生的中断
        localparam CSR_INT_BIT_WAKEUP                = 1 << 1;    // NIC控制器唤醒（电源管理）
	
	localparam CSR_INT_BIT_SW_RX                 = 1 << 3;    // 持续数据接收
	localparam CSR_INT_BIT_RX_PERIODIC           = 1 << 28;   // Rx周期性
		
	localparam CSR_INT_BIT_FH_RX                 = 1 << 31;   // Rx DMA，命令响应，FH_INT[17:16]
	
	localparam CSR_INT_BIT_CT_KILL               = 1 << 6;    // 临界温度（芯片过热）rfkill
	localparam CSR_INT_BIT_RF_KILL               = 1 << 7;    // 硬件RFKILL开关 GP_CNTRL[27]切换
	localparam CSR_INT_BIT_SW_ERR                = 1 << 25;   // uCode错误
	localparam CSR_INT_BIT_SCD                   = 1 << 26;   // TXQ指针前进
	localparam CSR_INT_BIT_FH_TX                 = 1 << 27;   // Tx DMA FH_INT[1:0]

	localparam CSR_INT_BIT_HW_ERR                = 1 << 29;   // DMA硬件错误 FH_INT[31]

	
	localparam CSR_FH_INT_BIT_TX_CHNL0           = 1 << 0;    // Tx通道0
	localparam CSR_FH_INT_BIT_TX_CHNL1           = 1 << 1;    // Tx通道1
	localparam CSR_FH_INT_BIT_RX_CHNL0           = 1 << 16;   // Rx通道0
	localparam CSR_FH_INT_BIT_RX_CHNL1           = 1 << 17;   // Rx通道1
        localparam CSR_FH_INT_BIT_HI_PRIOR           = 1 << 30;   // 高优先级Rx，绕过合并
        localparam CSR_FH_INT_BIT_ERR                = 1 << 31;   // 错误
    
	
	//MSIX  中断原因  FH是软件(内部)中断，HW是硬件(外部)中断  
	localparam MSIX_FH_INT_CAUSES_Q0             = 1 << 0;    // 队列 0
	localparam MSIX_FH_INT_CAUSES_Q1             = 1 << 1;    // 队列 1
	localparam MSIX_FH_INT_CAUSES_D2S_CH1_NUM    = 1 << 17;   // D2S 通道 1 数量
	localparam MSIX_FH_INT_CAUSES_S2D            = 1 << 19;   // S2D
	localparam MSIX_FH_INT_CAUSES_FH_ERR         = 1 << 21;   // FH 错误
	localparam MSIX_HW_INT_CAUSES_REG_ALIVE      = 1 << 0;    // 寄存器存活
	localparam MSIX_HW_INT_CAUSES_REG_WAKEUP     = 1 << 1;    // 寄存器唤醒
	localparam MSIX_HW_INT_CAUSES_REG_RESET_DONE = 1 << 2;    // 重置完成
	localparam MSIX_HW_INT_CAUSES_REG_SW_ERR_BZ  = 1 << 5;    // Bz软件错误
	localparam MSIX_HW_INT_CAUSES_REG_CT_KILL    = 1 << 6;    // 临界温度Kill
	localparam MSIX_HW_INT_CAUSES_REG_RF_KILL    = 1 << 7;    // RF Kill
	localparam MSIX_HW_INT_CAUSES_REG_PERIODIC   = 1 << 8;    // 周期性中断
	localparam MSIX_HW_INT_CAUSES_REG_SW_ERR     = 1 << 25;   // 软件错误 屏蔽就行
	localparam MSIX_HW_INT_CAUSES_REG_SCD        = 1 << 26;   // SCD
	localparam MSIX_HW_INT_CAUSES_REG_HW_ERR     = 1 << 29;   // 硬件错误
	*/
	
	//中断条件
	localparam MSIX_FH_INT_CAUSES_D2S_CH0_NUM    = 1 << 16;   // D2S 通道 0 数量  数据传输中断
	localparam MSIX_HW_INT_CAUSES_REG_FH_TX      = 1 << 27;   // FH发送     	  数据发送中断
	localparam MSIX_HW_INT_CAUSES_REG_HAP        = 1 << 30;   // 电源中断

	reg [31:0] CSR_MAC_ADDR0   = 32'h0534C286;
	reg [31:0] CSR_MAC_ADDR1   = 32'h00008048;
	
	reg [31:0] rd_addr_cmp       = 0;
	reg [31:0] wr_addr_cmp       = 0;
	reg [31:0] int_counter[6]    = {0,0,0,0,0,0};//定义6个中断计时器，防止被屏蔽，尽可能的拟真。

	//总中断
	reg [31:0] CSR_INT_ING    = 0;// 中断
	reg [31:0] CSR_INT_STATUS = 0;// 状态
	reg [31:0] CSR_INT_MASK   = 32'hFFFFFFFF;// 开关 默认0
	/*
	//传统中断 这里用不到就先屏蔽了，
	reg [31:0] INTA_MASK_FH   = 0;
	reg [31:0] INTA_MASK_HW   = 0;
	reg [31:0] INTA_CAUSES_FH = 0;
	reg [31:0] INTA_CAUSES_HW = 0;
	
	reg [31:0] MSI_MASK_FH    = 0;
	reg [31:0] MSI_MASK_HW    = 0;
	reg [31:0] MSI_CAUSES_FH  = 0;
	reg [31:0] MSI_CAUSES_HW  = 0;
	*/
	reg [31:0] MSIX_MASK_FH   = 32'h00200000;//尽可能的保证真实性
	reg [31:0] MSIX_MASK_HW   = 32'h91FFFE30;//为防止故保留原屏蔽数据，只用非屏蔽去中断，反正也不少不是吗。
	reg [31:0] MSIX_CAUSES_FH = 0;
	reg [31:0] MSIX_CAUSES_HW = 0;

    always @ (posedge clk) begin
		rd_rsp_ctx    <= rd_req_ctx;
		rd_rsp_valid  <= rd_req_valid;

		// 中断逻辑


		//下面是各类型的中断


		//先与驱动进行通讯交互，这样真实性更加安全保证
                //请注意，以下数据源于RW工具采集保存为Bin然后转换为源码，该数据仅供自用，部分电脑是不支持的；
	        //请注意，一切以群文档教程： https://docs.qq.com/doc/DQ01lVGtHelROVHNv
	        //请注意，因设备问题，最好是使用mmio得其数据，然后在结合此数据，才是最佳选择；
	        //请注意，本源码的作用和目的：仅提供一种写法而已；
	        //请注意，正常设备是什么样子，你的设备也应该是什么样子，这样才能正确搭配
	        //请自行根据工具：https://lvzhu.lanzoub.com/iyXDH2rfcsza
	        //请注意：本群网盘资料 2018年至今：https://lvzhu.lanzoub.com/b0mmm8ji
	        //请注意：网盘如果打不开，请搜索：蓝奏云；打开网页后，在后缀添加：/b0mmm8ji  即可

		if ((base_address_register > 0) && (base_address_register < 32'hFFFF0000)) begin
			rd_addr_cmp    <= ((rd_req_addr - (base_address_register & 32'hFFFFFFF0)) & 32'hFFFF);
			if (rd_req_valid) begin 
				if (rd_addr_cmp < 32'h2000) begin
					case (rd_addr_cmp)
						16'h0000 : rd_rsp_data <= 32'h00C80000;//CSR_HW_IF_CONFIG_REG 硬件接口配置，用于设置硬件接口相关参数
						16'h0004 : rd_rsp_data <= 32'h00000046;//CSR_INT_COALESCING 中断合并，可能涉及中断信号的整合处理
						16'h0008 : rd_rsp_data <= 32'h00000000;//CSR_INT 主机中断状态 / 确认，用于查看或确认主机中断情况
						16'h000C : rd_rsp_data <= 32'h00000000;//CSR_INT_MASK 主机中断使能，控制主机中断是否生效
						16'h0010 : rd_rsp_data <= 32'h00000000;//CSR_FH_INT_STATUS 总线主控中断状态 / 确认，关乎总线主控的中断相关状态及确认操作
						16'h0014 : rd_rsp_data <= 32'h00000000;
						16'h0018 : rd_rsp_data <= 32'h00000000;//CSR_GPIO_IN 读取外部芯片引脚，用于获取外部芯片引脚状态
						16'h001C : rd_rsp_data <= 32'h00000000;
						16'h0020 : rd_rsp_data <= 32'h00000010;//CSR_RESET 总线主控使能、NMI 等相关的重置寄存器，用于相关复位操作及使能控制
						16'h0024 : rd_rsp_data <= 32'h0C040005;//CSR_GP_CNTRL 设备控制，对一些通用功能进行控制设定
						16'h0028 : rd_rsp_data <= 32'h00000351;//CSR_HW_REV 硬件版本
						16'h0038 : rd_rsp_data <= 32'h80008040;
						16'h003C : rd_rsp_data <= 32'h041F0042;//CSR_GIO_REG，可能是和通用输入输出相关的寄存器
						16'h0040 : rd_rsp_data <= 32'h00000000;
						16'h0044 : rd_rsp_data <= 32'h00000000;
						16'h0048 : rd_rsp_data <= 32'h00000000;//CSR_GP_UCODE_REG，也许和通用可编程代码相关的寄存器
						16'h0050 : rd_rsp_data <= 32'h00000000;//CSR_GP_DRIVER_REG，可能用于通用驱动相关的设置
						16'h0054 : rd_rsp_data <= 32'h00000000;//CSR_UCODE_DRV_GP1，和可编程代码驱动相关的一种设置
						16'h0058 : rd_rsp_data <= 32'h00000000;//CSR_UCODE_DRV_GP1_SET，用于设置可编程代码驱动相关内容
						16'h005C : rd_rsp_data <= 32'h00000000;//CSR_UCODE_DRV_GP1_CLR，用于清除可编程代码驱动相关内容
						16'h0060 : rd_rsp_data <= 32'h00000000;//CSR_UCODE_DRV_GP2，另一种可编程代码驱动相关设置
						16'h0064 : rd_rsp_data <= 32'h00000000;
						16'h0068 : rd_rsp_data <= 32'h00000000;
						16'h0074 : rd_rsp_data <= 32'h00000000;
						16'h0078 : rd_rsp_data <= 32'h00000000;
						16'h007C : rd_rsp_data <= 32'h00000000;
						16'h0080 : rd_rsp_data <= 32'h00000000;
						16'h0084 : rd_rsp_data <= 32'h00000000;
						16'h0088 : rd_rsp_data <= 32'h00000000;//CSR_MBOX_SET_REG，可能用于邮箱设置相关功能
						16'h008C : rd_rsp_data <= 32'h00000000;
						16'h0090 : rd_rsp_data <= 32'h00000000;
						16'h0094 : rd_rsp_data <= 32'h00000020;//CSR_LED_REG，用于控制 LED 相关状态显示等功能
						16'h0098 : rd_rsp_data <= 32'h00000000;
						16'h009C : rd_rsp_data <= 32'h0010A100;//CSR_HW_RF_ID 频段范围 5GHz 2.4GHz，标识射频硬件的频段范围相关信息
						16'h00A0 : rd_rsp_data <= 32'h00000000;//CSR_DRAM_INT_TBL_REG，或许和 DRAM 中断表相关的寄存器
						16'h00A4 : rd_rsp_data <= 32'h00000000;
						16'h00A8 : rd_rsp_data <= 32'h802FFFFF;//CSR_MAC_SHADOW_REG_CTRL，用于 MAC 影子寄存器控制相关操作
						16'h00AC : rd_rsp_data <= 32'h00000000;//CSR_MAC_SHADOW_REG_CTL2，可能是 MAC 影子寄存器控制相关的另一种设置
						16'h00B0 : rd_rsp_data <= 32'h00000000;
						16'h00B4 : rd_rsp_data <= 32'h000007FF;
						16'h00B8 : rd_rsp_data <= 32'h00000000;
						16'h00BC : rd_rsp_data <= 32'h00000000;
						16'h00C0 : rd_rsp_data <= 32'h00000000;
						16'h00C4 : rd_rsp_data <= 32'h00000000;
						16'h00C8 : rd_rsp_data <= 32'hFFFFFFFF;
						16'h00DC : rd_rsp_data <= 32'h89088908;
						16'h00EC : rd_rsp_data <= 32'h08000000;//HEEP_CTRL_WRD_PCIEX_CTRL_REG，和 PCI Express 控制相关的寄存器
						16'h00F0 : rd_rsp_data <= 32'h00000000;
						16'h00F4 : rd_rsp_data <= 32'h00000049;//HEEP_CTRL_WRD_PCIEX_DATA_REG，和 PCI Express 数据相关的寄存器
						16'h00F8 : rd_rsp_data <= 32'h284053FC;
						16'h00FC : rd_rsp_data <= 32'h5FFF7FFE;
						16'h0200 : rd_rsp_data <= 32'h00000000;
						16'h0204 : rd_rsp_data <= 32'h05000010;//CSR_HOST_CHICKEN，可能是主机相关的一种特殊控制设置
						16'h0208 : rd_rsp_data <= 32'h00000000;
						16'h0210 : rd_rsp_data <= 32'h00000001;
						16'h0214 : rd_rsp_data <= 32'h00000000;//CSR_MONITOR_CFG_REG，用于监控相关配置的寄存器
						16'h0220 : rd_rsp_data <= 32'hAAAAA0AA;
						16'h0224 : rd_rsp_data <= 32'h00000000;
						16'h0228 : rd_rsp_data <= 32'h3F1F2210;//CSR_MONITOR_STATUS_REG，用于查看监控相关状态的寄存器
						16'h022C : rd_rsp_data <= 32'h0001105F;//CSR_HW_REV_WA_REG 硬件版本
						16'h0238 : rd_rsp_data <= 32'h00000000;
						16'h023C : rd_rsp_data <= 32'h00000000;
						16'h0240 : rd_rsp_data <= 32'hFFFF0010;//CSR_DBG_HPET_MEM_REG 调试 HPET 内存寄存器，用于调试高精度事件定时器相关内存
						16'h0244 : rd_rsp_data <= 32'h00000000;
						16'h0248 : rd_rsp_data <= 32'h00000000;
						16'h024C : rd_rsp_data <= 32'h00001FFB;
						16'h0250 : rd_rsp_data <= 32'h80000000;//CSR_DBG_LINK_PWR_MGMT_REG 调试链路电源管理寄存器，用于调试链路电源管理相关操作
						16'h0254 : rd_rsp_data <= 32'h00000100;
						16'h0258 : rd_rsp_data <= 32'h3666CCDC;
						16'h025C : rd_rsp_data <= 32'h00000000;
						16'h0260 : rd_rsp_data <= 32'h00000000;
						16'h0264 : rd_rsp_data <= 32'h00000FA0;
						16'h0270 : rd_rsp_data <= 32'h00000000;
						16'h0274 : rd_rsp_data <= 32'h00000000;
						16'h0278 : rd_rsp_data <= 32'h00000000;
						16'h0300 : rd_rsp_data <= 32'h00000000;
						16'h0304 : rd_rsp_data <= 32'h00000000;
						16'h0308 : rd_rsp_data <= 32'h00000000;
						16'h030C : rd_rsp_data <= 32'h00000000;
						16'h0310 : rd_rsp_data <= 32'h00000000;
						16'h0314 : rd_rsp_data <= 32'h00000000;
						16'h0318 : rd_rsp_data <= 32'h00000020;
						16'h031C : rd_rsp_data <= 32'h00000001;
						16'h0320 : rd_rsp_data <= 32'h00000F00;
						16'h0324 : rd_rsp_data <= 32'h00000000;
						16'h0328 : rd_rsp_data <= 32'h00000000;
						16'h032C : rd_rsp_data <= 32'h000042DB;
						16'h0330 : rd_rsp_data <= 32'h00000000;
						16'h0334 : rd_rsp_data <= 32'h00000000;
						16'h0338 : rd_rsp_data <= 32'h00000000;
						16'h0380 : rd_rsp_data <= CSR_MAC_ADDR0;//CSR_MAC_ADDR0_OTP
						16'h0384 : rd_rsp_data <= CSR_MAC_ADDR1;//CSR_MAC_ADDR1_OTP
						16'h0388 : rd_rsp_data <= 32'h00000000;//CSR_MAC_ADDR0_STRAP
						16'h038C : rd_rsp_data <= 32'h00000000;//CSR_MAC_ADDR1_STRAP
						16'h0400 : rd_rsp_data <= 32'h00000000;//HBUS_BASE，可能是 HBUS 相关的基础设置或状态标识
						16'h0414 : rd_rsp_data <= 32'h00000000;
						16'h041C : rd_rsp_data <= 32'h004C4560;//HBUS_TARG_MEM_RDAT HBUS 目标内存读数据，即通过 HBUS 读取到的内存中的数据
						16'h0420 : rd_rsp_data <= 32'h00000005;
						16'h0428 : rd_rsp_data <= 32'h200001E4;
						16'h042C : rd_rsp_data <= 32'h00000000;
						16'h0430 : rd_rsp_data <= 32'hFB10000C;//HBUS_TARG_MBX_C，可能与 HBUS 目标邮箱相关的某种控制或状态标识
						16'h0434 : rd_rsp_data <= 32'h00003000;
						16'h0440 : rd_rsp_data <= 32'h00000000;
						16'h0450 : rd_rsp_data <= 32'h00000014;//HBUS_TARG_PRPH_RDAT HBUS 目标外设读数据，即通过 HBUS 从外设读取到的数据
						16'h0454 : rd_rsp_data <= 32'h00000000;
						16'h0458 : rd_rsp_data <= 32'h00000000;
						16'h045C : rd_rsp_data <= 32'h00000000;//HBUS_TARG_TEST_REG HBUS 启用 DBGM，或许用于开启 HBUS 相关的调试功能
						16'h0460 : rd_rsp_data <= 32'h00020049;//HBUS_TARG_WRPTR 每个 Tx 队列的写指针，涉及到发送队列的写指针相关设置
						default: rd_rsp_data <= 32'hDEADBEEF;
					endcase
				end
				if (rd_addr_cmp > 32'h1FFF && rd_addr_cmp < 32'h4000) begin // 0x2000~0x4000
					case (rd_addr_cmp)
						16'h2000 : rd_rsp_data <= 32'hFEE0100C;
						16'h2008 : rd_rsp_data <= 32'h000049A2;
						16'h2010 : rd_rsp_data <= 32'hFEE0100C;
						16'h2018 : rd_rsp_data <= 32'h00004992;
						16'h2020 : rd_rsp_data <= 32'hFEE0100C;
						16'h2028 : rd_rsp_data <= 32'h000049A2;
						16'h2030 : rd_rsp_data <= 32'hFEE0100C;
						16'h2038 : rd_rsp_data <= 32'h000049A2;
						16'h2040 : rd_rsp_data <= 32'hFEE0100C;
						16'h2048 : rd_rsp_data <= 32'h000049A2;
						16'h2050 : rd_rsp_data <= 32'hFEE0100C;
						16'h2058 : rd_rsp_data <= 32'h000049A2;
						16'h2060 : rd_rsp_data <= 32'hFEE0100C;
						16'h2068 : rd_rsp_data <= 32'h000049A2;
						16'h2070 : rd_rsp_data <= 32'hFEE0100C;
						16'h2078 : rd_rsp_data <= 32'h000049A2;
						16'h2080 : rd_rsp_data <= 32'hFEE0100C;
						16'h2088 : rd_rsp_data <= 32'h000049A2;
						16'h2090 : rd_rsp_data <= 32'hFEE0100C;
						16'h2098 : rd_rsp_data <= 32'h000049A2;
						16'h2814 : rd_rsp_data <= 32'h0000FFFF;
						16'h2890 : rd_rsp_data <= 32'h81008181;//CSR_MSIX_IVAR_AD_REG，也许是 MSIX 中断向量相关的寄存器设置
						default: rd_rsp_data <= 32'h00000000;
					endcase
				end
			end
			//下面的代码就删了，只是单纯的交互逻辑，对于圈狗来说不重要！
		end
	end
endmodule
