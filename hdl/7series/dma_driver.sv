/*
 * Copyright (c) 2018, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its contributors
 * may be used to endorse or promote products derived from this software
 * without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
`timescale 1ns / 1ps
`default_nettype none

`include "os_types.svh"

typedef struct packed
{
    logic[255:0]    data;
    logic[31:0]     keep;
    logic           last;
} axi_word_256;


typedef struct packed
{
    logic[511:0]    data;
    logic[63:0]     keep;
    logic           last;
} axi_word_512;

module dma_driver(
    input wire          sys_clk,
    input wire          sys_rst_n,
    output logic        user_lnk_up,

    input wire[7:0]     pcie_rx_p,
    input wire[7:0]     pcie_rx_n,
    output logic[7:0]   pcie_tx_p,
    output logic[7:0]   pcie_tx_n,

    output logic        pcie_clk,
    output logic        pcie_aresetn,
    /*input wire[0:0]     user_irq_req,
    output logic        user_irq_ack,
    output logic        msi_enable,
    output logic[2:0]   msi_vector_width,*/

    // Axi Lite Control interface
    axi_lite.master     m_axil,
    
    // AXI Stream Interface
    input wire          s_axis_c2h_tvalid_0,
    output logic        s_axis_c2h_tready_0,
    //input axi_word_512  s_axis_c2h_tdata_0,
    input wire[511:0]   s_axis_c2h_tdata_0,
    input wire[63:0]    s_axis_c2h_tkeep_0,
    input wire          s_axis_c2h_tlast_0,

    output logic        m_axis_h2c_tvalid_0,
    input wire          m_axis_h2c_tready_0,
    //output axi_word_512 m_axis_h2c_tdata_0,
    output logic[511:0] m_axis_h2c_tdata_0,
    output logic[63:0]  m_axis_h2c_tkeep_0,
    output logic        m_axis_h2c_tlast_0,

    // Descriptor Bypass
    output logic        c2h_dsc_byp_ready_0,
    //input wire[63:0]    c2h_dsc_byp_src_addr_0,
    input wire[63:0]    c2h_dsc_byp_addr_0,
    input wire[31:0]    c2h_dsc_byp_len_0,
    //input wire[15:0]    c2h_dsc_byp_ctl_0,
    input wire          c2h_dsc_byp_load_0,
    
    output logic        h2c_dsc_byp_ready_0,
    input wire[63:0]    h2c_dsc_byp_addr_0,
    //input wire[63:0]    h2c_dsc_byp_dst_addr_0,
    input wire[31:0]    h2c_dsc_byp_len_0,
    //input wire[15:0]    h2c_dsc_byp_ctl_0,
    input wire          h2c_dsc_byp_load_0,
    
    output logic[7:0]   c2h_sts_0,
    output logic[7:0]   h2c_sts_0
);


//For 7 Series with PCIe 3.0 8x, the data width has to be converted from 512bit to 256bit

logic           axis_dma_read_data_256_tvalid;
logic           axis_dma_read_data_256_tready;
axi_word_256    axis_dma_read_data_256_tdata;

logic           axis_dma_write_data_256_tvalid;
logic           axis_dma_write_data_256_tready;
axi_word_256    axis_dma_write_data_256_tdata;


axis_256_to_512_converter dma_read_data_width_converter (
  .aclk(pcie_clk),                    // input wire aclk
  .aresetn(pcie_aresetn),              // input wire aresetn
  .s_axis_tvalid(axis_dma_read_data_256_tvalid),  // input wire s_axis_tvalid
  .s_axis_tready(axis_dma_read_data_256_tready),  // output wire s_axis_tready
  .s_axis_tdata(axis_dma_read_data_256_tdata.data),    // input wire [255 : 0] s_axis_tdata
  .s_axis_tkeep(axis_dma_read_data_256_tdata.keep),    // input wire [31 : 0] s_axis_tkeep
  .s_axis_tlast(axis_dma_read_data_256_tdata.last),    // input wire s_axis_tlast
  .m_axis_tvalid(m_axis_h2c_tvalid_0),  // output wire m_axis_tvalid
  .m_axis_tready(m_axis_h2c_tready_0),  // input wire m_axis_tready
  .m_axis_tdata(m_axis_h2c_tdata_0),    // output wire [511 : 0] m_axis_tdata
  .m_axis_tkeep(m_axis_h2c_tkeep_0),    // output wire [63 : 0] m_axis_tkeep
  .m_axis_tlast(m_axis_h2c_tlast_0)    // output wire m_axis_tlast
);


axis_512_to_256_converter pcie_axis_write_data_512_256 (
  .aclk(pcie_clk),                    // input wire aclk
  .aresetn(pcie_aresetn),              // input wire aresetn
  .s_axis_tvalid(s_axis_c2h_tvalid_0),  // input wire s_axis_tvalid
  .s_axis_tready(s_axis_c2h_tready_0),  // output wire s_axis_tready
  .s_axis_tdata(s_axis_c2h_tdata_0),    // input wire [511 : 0] s_axis_tdata
  .s_axis_tkeep(s_axis_c2h_tkeep_0),    // input wire [63 : 0] s_axis_tkeep
  .s_axis_tlast(s_axis_c2h_tlast_0),    // input wire s_axis_tlast
  .m_axis_tvalid(axis_dma_write_data_256_tvalid),  // output wire m_axis_tvalid
  .m_axis_tready(axis_dma_write_data_256_tready),  // input wire m_axis_tready
  .m_axis_tdata(axis_dma_write_data_256_tdata.data),    // output wire [255 : 0] m_axis_tdata
  .m_axis_tkeep(axis_dma_write_data_256_tdata.keep),    // output wire [31 : 0] m_axis_tkeep
  .m_axis_tlast(axis_dma_write_data_256_tdata.last)    // output wire m_axis_tlast
);




xdma_ip dma_inst (
  .sys_clk(sys_clk),                                              // input wire sys_clk
  .sys_rst_n(sys_rst_n),                                          // input wire sys_rst_n
  .user_lnk_up(user_lnk_up),                                      // output wire user_lnk_up
  .pci_exp_txp(pcie_tx_p),                                      // output wire [7 : 0] pci_exp_txp
  .pci_exp_txn(pcie_tx_n),                                      // output wire [7 : 0] pci_exp_txn
  .pci_exp_rxp(pcie_rx_p),                                      // input wire [7 : 0] pci_exp_rxp
  .pci_exp_rxn(pcie_rx_n),                                      // input wire [7 : 0] pci_exp_rxn
  .axi_aclk(pcie_clk),                                            // output wire axi_aclk
  .axi_aresetn(pcie_aresetn),                                      // output wire axi_aresetn
  .usr_irq_req(1'b0),                                      // input wire [0 : 0] usr_irq_req
  .usr_irq_ack(),                                      // output wire [0 : 0] usr_irq_ack
  .msi_enable(),                                        // output wire msi_enable
  .msi_vector_width(),                            // output wire [2 : 0] msi_vector_width
  
  // LITE interface   
  //-- AXI Master Write Address Channel
  .m_axil_awaddr(m_axil.awaddr),              // output wire [31 : 0] m_axil_awaddr
  .m_axil_awprot(),              // output wire [2 : 0] m_axil_awprot
  .m_axil_awvalid(m_axil.awvalid),            // output wire m_axil_awvalid
  .m_axil_awready(m_axil.awready),            // input wire m_axil_awready
  //-- AXI Master Write Data Channel
  .m_axil_wdata(m_axil.wdata),                // output wire [31 : 0] m_axil_wdata
  .m_axil_wstrb(m_axil.wstrb),                // output wire [3 : 0] m_axil_wstrb
  .m_axil_wvalid(m_axil.wvalid),              // output wire m_axil_wvalid
  .m_axil_wready(m_axil.wready),              // input wire m_axil_wready
  //-- AXI Master Write Response Channel
  .m_axil_bvalid(m_axil.bvalid),              // input wire m_axil_bvalid
  .m_axil_bresp(m_axil.bresp),                // input wire [1 : 0] m_axil_bresp
  .m_axil_bready(m_axil.bready),              // output wire m_axil_bready
  //-- AXI Master Read Address Channel
  .m_axil_araddr(m_axil.araddr),              // output wire [31 : 0] m_axil_araddr
  .m_axil_arprot(),              // output wire [2 : 0] m_axil_arprot
  .m_axil_arvalid(m_axil.arvalid),            // output wire m_axil_arvalid
  .m_axil_arready(m_axil.arready),            // input wire m_axil_arready
  .m_axil_rdata(m_axil.rdata),                // input wire [31 : 0] m_axil_rdata
  //-- AXI Master Read Data Channel
  .m_axil_rresp(m_axil.rresp),                // input wire [1 : 0] m_axil_rresp
  .m_axil_rvalid(m_axil.rvalid),              // input wire m_axil_rvalid
  .m_axil_rready(m_axil.rready),              // output wire m_axil_rready
  
  // AXI Stream Interface
  .s_axis_c2h_tvalid_0(axis_dma_write_data_256_tvalid),                      // input wire s_axis_c2h_tvalid_0
  .s_axis_c2h_tready_0(axis_dma_write_data_256_tready),                      // output wire s_axis_c2h_tready_0
  .s_axis_c2h_tdata_0(axis_dma_write_data_256_tdata.data),                        // input wire [255 : 0] s_axis_c2h_tdata_0
  .s_axis_c2h_tkeep_0(axis_dma_write_data_256_tdata.keep),                        // input wire [31 : 0] s_axis_c2h_tkeep_0
  .s_axis_c2h_tlast_0(axis_dma_write_data_256_tdata.last),                        // input wire s_axis_c2h_tlast_0
  .m_axis_h2c_tvalid_0(axis_dma_read_data_256_tvalid),                      // output wire m_axis_h2c_tvalid_0
  .m_axis_h2c_tready_0(axis_dma_read_data_256_tready),                      // input wire m_axis_h2c_tready_0
  .m_axis_h2c_tdata_0(axis_dma_read_data_256_tdata.data),                        // output wire [255 : 0] m_axis_h2c_tdata_0
  .m_axis_h2c_tkeep_0(axis_dma_read_data_256_tdata.keep),                        // output wire [31 : 0] m_axis_h2c_tkeep_0
  .m_axis_h2c_tlast_0(axis_dma_read_data_256_tdata.last),                        // output wire m_axis_h2c_tlast_0

  // Descriptor Bypass
  .c2h_dsc_byp_ready_0    (c2h_dsc_byp_ready_0),
  .c2h_dsc_byp_src_addr_0 (64'h0),
  .c2h_dsc_byp_dst_addr_0 (c2h_dsc_byp_addr_0),
  .c2h_dsc_byp_len_0      (c2h_dsc_byp_len_0),
  .c2h_dsc_byp_ctl_0      (16'h13), //was 16'h3
  .c2h_dsc_byp_load_0     (c2h_dsc_byp_load_0),
  
  .h2c_dsc_byp_ready_0    (h2c_dsc_byp_ready_0),
  .h2c_dsc_byp_src_addr_0 (h2c_dsc_byp_addr_0),
  .h2c_dsc_byp_dst_addr_0 (64'h0),
  .h2c_dsc_byp_len_0      (h2c_dsc_byp_len_0),
  .h2c_dsc_byp_ctl_0      (16'h13), //was 16'h3
  .h2c_dsc_byp_load_0     (h2c_dsc_byp_load_0),
  
  .c2h_sts_0(c2h_sts_0),                                          // output wire [7 : 0] c2h_sts_0
  .h2c_sts_0(h2c_sts_0)                                          // output wire [7 : 0] h2c_sts_0
);


    
endmodule
`default_nettype wire