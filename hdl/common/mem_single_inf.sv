`timescale 1ns / 1ps
`default_nettype none

`include "os_types.svh"

module mem_single_inf #(
    parameter ENABLE = 1,
    parameter AXI_ID_WIDTH = 1
)(
    input wire                  user_clk,
    input wire                  user_aresetn,
    input wire                  mem_clk,
    input wire                  mem_aresetn,
    input wire                  pcie_clk,
    input wire                  pcie_aresetn, //TODO remove
    
    /* USER INTERFACE */    
    //memory access
    //read cmd
    axis_mem_cmd.slave      s_axis_mem_read_cmd,
    //read status
    axis_mem_status.master  m_axis_mem_read_status,
    //read data stream
    axi_stream.master       m_axis_mem_read_data,
    
    //write cmd
    axis_mem_cmd.slave      s_axis_mem_write_cmd,
    //write status
    axis_mem_status.master  m_axis_mem_write_status,
    //write data stream
    axi_stream.slave        s_axis_mem_write_data,

    /* CONTROL INTERFACE */
    axi_lite.slave      s_axil,

    /* DRIVER INTERFACE */
    // Slave Interface Write Address Ports
    output logic [AXI_ID_WIDTH-1:0]                 m_axi_awid,
    output logic [31:0]                             m_axi_awaddr,
    output logic [7:0]                              m_axi_awlen,
    output logic [2:0]                              m_axi_awsize,
    output logic [1:0]                              m_axi_awburst,
    output logic [0:0]                              m_axi_awlock,
    output logic [3:0]                              m_axi_awcache,
    output logic [2:0]                              m_axi_awprot,
    output logic                                    m_axi_awvalid,
    input wire                                      m_axi_awready,
    // Slave Interface Write Data Ports
    output logic [511:0]                            m_axi_wdata,
    output logic [63:0]                             m_axi_wstrb,
    output logic                                    m_axi_wlast,
    output logic                                    m_axi_wvalid,
    input wire                                      m_axi_wready,
    // Slave Interface Write Response Ports
    output logic                                    m_axi_bready,
    input wire [AXI_ID_WIDTH-1:0]                   m_axi_bid,
    input wire [1:0]                                m_axi_bresp,
    input wire                                      m_axi_bvalid,
    // Slave Interface Read Address Ports
    output logic [AXI_ID_WIDTH-1:0]                 m_axi_arid,
    output logic [31:0]                             m_axi_araddr,
    output logic [7:0]                              m_axi_arlen,
    output logic [2:0]                              m_axi_arsize,
    output logic [1:0]                              m_axi_arburst,
    output logic [0:0]                              m_axi_arlock,
    output logic [3:0]                              m_axi_arcache,
    output logic [2:0]                              m_axi_arprot,
    output logic                                    m_axi_arvalid,
    input wire                                      m_axi_arready,
    // Slave Interface Read Data Ports
    output logic                                    m_axi_rready,
    input wire [AXI_ID_WIDTH-1:0]                   m_axi_rid,
    input wire [511:0]                              m_axi_rdata,
    input wire [1:0]                                m_axi_rresp,
    input wire                                      m_axi_rlast,
    input wire                                      m_axi_rvalid

    );

assign m_axi_awlock = 0;
assign m_axi_arlock = 0;



/*
 * CLOCK CROSSING
 */

wire        axis_to_dm_mem_write_cmd_tvalid;
wire        axis_to_dm_mem_write_cmd_tready;
wire[71:0]  axis_to_dm_mem_write_cmd_tdata;
assign axis_to_dm_mem_write_cmd_tvalid = s_axis_mem_write_cmd.valid;
assign s_axis_mem_write_cmd.ready = axis_to_dm_mem_write_cmd_tready;
// [71:68] reserved, [67:64] tag, [63:32] address,[31] drr, [30] eof, [29:24] dsa, [23] type, [22:0] btt (bytes to transfer)
assign axis_to_dm_mem_write_cmd_tdata = {8'h0, s_axis_mem_write_cmd.address[31:0], 1'b1, 1'b1, 6'h0, 1'b1, s_axis_mem_write_cmd.length[22:0]};
wire        axis_to_dm_mem_read_cmd_tvalid;
wire        axis_to_dm_mem_read_cmd_tready;
wire[71:0]  axis_to_dm_mem_read_cmd_tdata;
assign axis_to_dm_mem_read_cmd_tvalid = s_axis_mem_read_cmd.valid;
assign s_axis_mem_read_cmd.ready = axis_to_dm_mem_read_cmd_tready;
// [71:68] reserved, [67:64] tag, [63:32] address,[31] drr, [30] eof, [29:24] dsa, [23] type, [22:0] btt (bytes to transfer)
assign axis_to_dm_mem_read_cmd_tdata = {8'h0, s_axis_mem_read_cmd.address[31:0], 1'b1, 1'b1, 6'h0, 1'b1, s_axis_mem_read_cmd.length[22:0]};

wire        axis_mem_cc_to_dm_write_tvalid;
wire        axis_mem_cc_to_dm_write_tready;
wire[511:0] axis_mem_cc_to_dm_write_tdata;
wire[63:0]  axis_mem_cc_to_dm_write_tkeep;
wire        axis_mem_cc_to_dm_write_tlast;

wire        axis_mem_dm_to_cc_read_tvalid;
wire        axis_mem_dm_to_cc_read_tready;
wire[511:0] axis_mem_dm_to_cc_read_tdata;
wire[63:0]  axis_mem_dm_to_cc_read_tkeep;
wire        axis_mem_dm_to_cc_read_tlast;

generate
    if (ENABLE == 1) begin
    
axis_data_fifo_512_cc axis_write_data_fifo_mem (
   .s_axis_aclk(user_clk),                // input wire s_axis_aclk
   .s_axis_aresetn(user_aresetn),          // input wire s_axis_aresetn
   .s_axis_tvalid(s_axis_mem_write_data.valid),            // input wire s_axis_tvalid
   .s_axis_tready(s_axis_mem_write_data.ready),            // output wire s_axis_tready
   .s_axis_tdata(s_axis_mem_write_data.data),              // input wire [255 : 0] s_axis_tdata
   .s_axis_tkeep(s_axis_mem_write_data.keep),              // input wire [31 : 0] s_axis_tkeep
   .s_axis_tlast(s_axis_mem_write_data.last),              // input wire s_axis_tlast
   
   .m_axis_aclk(mem_clk),                // input wire m_axis_aclk
   .m_axis_aresetn(mem_aresetn),          // input wire m_axis_aresetn
   .m_axis_tvalid(axis_mem_cc_to_dm_write_tvalid),            // output wire m_axis_tvalid
   .m_axis_tready(axis_mem_cc_to_dm_write_tready),            // input wire m_axis_tready
   .m_axis_tdata(axis_mem_cc_to_dm_write_tdata),              // output wire [255 : 0] m_axis_tdata
   .m_axis_tkeep(axis_mem_cc_to_dm_write_tkeep),              // output wire [31 : 0] m_axis_tkeep
   .m_axis_tlast(axis_mem_cc_to_dm_write_tlast),              // output wire m_axis_tlast
   
   .axis_data_count(),        // output wire [31 : 0] axis_data_count
   .axis_wr_data_count(),  // output wire [31 : 0] axis_wr_data_count
   .axis_rd_data_count()  // output wire [31 : 0] axis_rd_data_count
 );

axis_data_fifo_512_cc axis_read_data_fifo_mem (
   .s_axis_aclk(mem_clk),                // input wire s_axis_aclk
   .s_axis_aresetn(mem_aresetn),          // input wire s_axis_aresetn
   .s_axis_tvalid(axis_mem_dm_to_cc_read_tvalid),            // input wire s_axis_tvalid
   .s_axis_tready(axis_mem_dm_to_cc_read_tready),            // output wire s_axis_tready
   .s_axis_tdata(axis_mem_dm_to_cc_read_tdata),              // input wire [255 : 0] s_axis_tdata
   .s_axis_tkeep(axis_mem_dm_to_cc_read_tkeep),              // input wire [31 : 0] s_axis_tkeep
   .s_axis_tlast(axis_mem_dm_to_cc_read_tlast),              // input wire s_axis_tlast
   
   .m_axis_aclk(user_clk),                // input wire m_axis_aclk
   .m_axis_aresetn(user_aresetn),          // input wire m_axis_aresetn
   .m_axis_tvalid(m_axis_mem_read_data.valid),            // output wire m_axis_tvalid
   .m_axis_tready(m_axis_mem_read_data.ready),            // input wire m_axis_tready
   .m_axis_tdata(m_axis_mem_read_data.data),              // output wire [255 : 0] m_axis_tdata
   .m_axis_tkeep(m_axis_mem_read_data.keep),              // output wire [31 : 0] m_axis_tkeep
   .m_axis_tlast(m_axis_mem_read_data.last),              // output wire m_axis_tlast
   
   .axis_data_count(),        // output wire [31 : 0] axis_data_count
   .axis_wr_data_count(),  // output wire [31 : 0] axis_wr_data_count
   .axis_rd_data_count()  // output wire [31 : 0] axis_rd_data_count
 );
    end
 else begin
     assign s_axis_mem_write_data.ready = 1'b1;
     assign m_axis_mem_read_data.valid = 1'b0;
 end
endgenerate


/*
 * DATA MOVERS
 */
wire s2mm_error;
wire mm2s_error;

generate
    if (ENABLE == 1) begin

axi_datamover_mem datamover_mem (
    .m_axi_mm2s_aclk(mem_clk),// : IN STD_LOGIC;
    .m_axi_mm2s_aresetn(mem_aresetn), //: IN STD_LOGIC;
    .mm2s_err(mm2s_error), //: OUT STD_LOGIC;
    .m_axis_mm2s_cmdsts_aclk(user_clk), //: IN STD_LOGIC;
    .m_axis_mm2s_cmdsts_aresetn(user_aresetn), //: IN STD_LOGIC;
    .s_axis_mm2s_cmd_tvalid(axis_to_dm_mem_read_cmd_tvalid), //: IN STD_LOGIC;
    .s_axis_mm2s_cmd_tready(axis_to_dm_mem_read_cmd_tready), //: OUT STD_LOGIC;
    .s_axis_mm2s_cmd_tdata(axis_to_dm_mem_read_cmd_tdata), //: IN STD_LOGIC_VECTOR(71 DOWNTO 0);
    .m_axis_mm2s_sts_tvalid(m_axis_mem_read_status.valid), //: OUT STD_LOGIC;
    .m_axis_mm2s_sts_tready(m_axis_mem_read_status.ready), //: IN STD_LOGIC;
    .m_axis_mm2s_sts_tdata(m_axis_mem_read_status.data), //: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    .m_axis_mm2s_sts_tkeep(), //: OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    .m_axis_mm2s_sts_tlast(), //: OUT STD_LOGIC;
    .m_axi_mm2s_arid(m_axi_arid), //: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    .m_axi_mm2s_araddr(m_axi_araddr), //: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    .m_axi_mm2s_arlen(m_axi_arlen), //: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    .m_axi_mm2s_arsize(m_axi_arsize), //: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    .m_axi_mm2s_arburst(m_axi_arburst), //: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    .m_axi_mm2s_arprot(m_axi_arprot), //: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    .m_axi_mm2s_arcache(m_axi_arcache), //: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    .m_axi_mm2s_aruser(), //: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    .m_axi_mm2s_arvalid(m_axi_arvalid), //: OUT STD_LOGIC;
    .m_axi_mm2s_arready(m_axi_arready), //: IN STD_LOGIC;
    .m_axi_mm2s_rdata(m_axi_rdata), //: IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    .m_axi_mm2s_rresp(m_axi_rresp), //: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    .m_axi_mm2s_rlast(m_axi_rlast), //: IN STD_LOGIC;
    .m_axi_mm2s_rvalid(m_axi_rvalid), //: IN STD_LOGIC;
    .m_axi_mm2s_rready(m_axi_rready), //: OUT STD_LOGIC;
    .m_axis_mm2s_tdata(axis_mem_dm_to_cc_read_tdata), //: OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
    .m_axis_mm2s_tkeep(axis_mem_dm_to_cc_read_tkeep), //: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    .m_axis_mm2s_tlast(axis_mem_dm_to_cc_read_tlast), //: OUT STD_LOGIC;
    .m_axis_mm2s_tvalid(axis_mem_dm_to_cc_read_tvalid), //: OUT STD_LOGIC;
    .m_axis_mm2s_tready(axis_mem_dm_to_cc_read_tready), //: IN STD_LOGIC;
    .m_axi_s2mm_aclk(mem_clk), //: IN STD_LOGIC;
    .m_axi_s2mm_aresetn(mem_aresetn), //: IN STD_LOGIC;
    .s2mm_err(s2mm_error), //: OUT STD_LOGIC;
    .m_axis_s2mm_cmdsts_awclk(user_clk), //: IN STD_LOGIC;
    .m_axis_s2mm_cmdsts_aresetn(user_aresetn), //: IN STD_LOGIC;
    .s_axis_s2mm_cmd_tvalid(axis_to_dm_mem_write_cmd_tvalid), //: IN STD_LOGIC;
    .s_axis_s2mm_cmd_tready(axis_to_dm_mem_write_cmd_tready), //: OUT STD_LOGIC;
    .s_axis_s2mm_cmd_tdata(axis_to_dm_mem_write_cmd_tdata), //: IN STD_LOGIC_VECTOR(71 DOWNTO 0);
    .m_axis_s2mm_sts_tvalid(m_axis_mem_write_status.valid), //: OUT STD_LOGIC;
    .m_axis_s2mm_sts_tready(m_axis_mem_write_status.ready), //: IN STD_LOGIC;
    .m_axis_s2mm_sts_tdata(m_axis_mem_write_status.data), //: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    .m_axis_s2mm_sts_tkeep(), //: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    .m_axis_s2mm_sts_tlast(), //: OUT STD_LOGIC;
    .m_axi_s2mm_awid(m_axi_awid), //: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    .m_axi_s2mm_awaddr(m_axi_awaddr), //: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    .m_axi_s2mm_awlen(m_axi_awlen), //: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    .m_axi_s2mm_awsize(m_axi_awsize), //: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    .m_axi_s2mm_awburst(m_axi_awburst), //: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    .m_axi_s2mm_awprot(m_axi_awprot), //: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    .m_axi_s2mm_awcache(m_axi_awcache), //: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    .m_axi_s2mm_awuser(), //: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    .m_axi_s2mm_awvalid(m_axi_awvalid), //: OUT STD_LOGIC;
    .m_axi_s2mm_awready(m_axi_awready), //: IN STD_LOGIC;
    .m_axi_s2mm_wdata(m_axi_wdata), //: OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
    .m_axi_s2mm_wstrb(m_axi_wstrb), //: OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    .m_axi_s2mm_wlast(m_axi_wlast), //: OUT STD_LOGIC;
    .m_axi_s2mm_wvalid(m_axi_wvalid), //: OUT STD_LOGIC;
    .m_axi_s2mm_wready(m_axi_wready), //: IN STD_LOGIC;
    .m_axi_s2mm_bresp(m_axi_bresp), //: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    .m_axi_s2mm_bvalid(m_axi_bvalid), //: IN STD_LOGIC;
    .m_axi_s2mm_bready(m_axi_bready), //: OUT STD_LOGIC;
    .s_axis_s2mm_tdata(axis_mem_cc_to_dm_write_tdata), //: IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    .s_axis_s2mm_tkeep(axis_mem_cc_to_dm_write_tkeep), //: IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    .s_axis_s2mm_tlast(axis_mem_cc_to_dm_write_tlast), //: IN STD_LOGIC;
    .s_axis_s2mm_tvalid(axis_mem_cc_to_dm_write_tvalid), //: IN STD_LOGIC;
    .s_axis_s2mm_tready(axis_mem_cc_to_dm_write_tready) //: OUT STD_LOGIC;
);
    end
else begin
    assign s_axis_mem_read_cmd.ready = 1'b1;
    //assign axis_mem_dm_to_cc_read_tvalid = 1'b0;
    assign m_axis_mem_read_status.valid = 1'b0;
    assign s_axis_mem_write_cmd.ready = 1'b1;
    assign m_axis_mem_write_status.valid = 1'b0;
    //assign axis_mem_cc_to_dm_write_tready = 1'b1;
end
endgenerate


/*
 * DDR Controller
 */
 ddr_controller controller_inst(
    .pcie_clk(pcie_clk),
    .pcie_aresetn(pcie_aresetn),
    .mem_clk(mem_clk), //TODO
    .mem_aresetn(mem_aresetn),
    
     // AXI Lite Master Interface connections
    .s_axil                         (s_axil),

    // Statistics
    .write_cmd_counter              (write_cmd_counter),
    .write_word_counter             (write_word_counter),
    .write_pkg_counter              (write_pkg_counter),
    .write_length_counter           (write_length_counter),
    .write_sts_counter              (write_sts_counter),
    .write_sts_error_counter        (write_sts_error_counter),

    .read_cmd_counter               (read_cmd_counter),
    .read_word_counter              (read_word_counter),
    .read_pkg_counter               (read_pkg_counter),
    .read_length_counter            (read_length_counter),
    .read_sts_counter               (read_sts_counter),
    .read_sts_error_counter         (read_sts_error_counter),

    .s2mm_error                     (mm2s_error),
    .mm2s_error                     (s2mm_error)

);



/*
 * DDR Statistics
 */ 
logic[31:0] user_write_cmd_counter;
logic[31:0] user_write_sts_counter;
logic[31:0] user_write_sts_error_counter;
logic[31:0] user_read_cmd_counter;
logic[31:0] user_read_sts_counter;
logic[31:0] user_read_sts_error_counter;

logic[31:0] write_cmd_counter;
//logic[47:0] write_cmd_length_counter;
logic[31:0] write_word_counter;
logic[31:0] write_pkg_counter;
logic[47:0] write_length_counter;
logic[31:0] write_sts_counter;
logic[31:0] write_sts_error_counter;

logic[31:0] read_cmd_counter;
// logic[47:0] read_cmd_length_counter;
logic[31:0] read_word_counter;
logic[31:0] read_pkg_counter;
logic[47:0] read_length_counter;
logic[31:0] read_sts_counter;
logic[31:0] read_sts_error_counter;


always @(posedge user_clk)
begin
    if (~user_aresetn) begin
        user_write_cmd_counter <= '0;
        user_write_sts_counter <= '0;
        user_write_sts_error_counter <= '0;
        user_read_cmd_counter <= '0;
        user_read_sts_counter <= '0;
        user_read_sts_error_counter <= '0;
    end
    else begin
        if (axis_to_dm_mem_write_cmd_tvalid && axis_to_dm_mem_write_cmd_tready) begin
            user_write_cmd_counter <= user_write_cmd_counter + 1;
        end
        if (m_axis_mem_write_status.valid && m_axis_mem_write_status.ready) begin
            user_write_sts_counter <= user_write_sts_counter + 1;
            //Check if error occured
            if (m_axis_mem_write_status.data[7] != 1'b1) begin
                user_write_sts_error_counter <= user_write_sts_error_counter;
            end
        end
        if (axis_to_dm_mem_read_cmd_tvalid && axis_to_dm_mem_read_cmd_tready) begin
            user_read_cmd_counter <= user_read_cmd_counter + 1;
        end
        if (m_axis_mem_read_status.valid && m_axis_mem_read_status.ready) begin
            user_read_sts_counter <= user_read_sts_counter + 1;
            //Check if error occured
            if (m_axis_mem_read_status.data[7] != 1'b1) begin
                user_read_sts_error_counter <= user_read_sts_error_counter;
            end
        end

    end
end

always @(posedge mem_clk)
begin
    if (~mem_aresetn) begin
        write_word_counter <= '0;
        write_pkg_counter <= '0;
        write_length_counter <= '0;
        read_word_counter <= '0;
        read_pkg_counter <= '0;
        read_length_counter <= '0;
    end
    else begin
        if (axis_mem_cc_to_dm_write_tvalid && axis_mem_cc_to_dm_write_tready) begin
            write_word_counter <= write_word_counter + 1;
            if (axis_mem_cc_to_dm_write_tlast) begin
                write_pkg_counter <= write_pkg_counter + 1;
            end
            //Assumes multiple of 8
            case (axis_mem_cc_to_dm_write_tkeep)
                64'hFF: write_length_counter <= write_length_counter + 8;
                64'hFFFF: write_length_counter <= write_length_counter + 16;
                64'hFFFFFF: write_length_counter <= write_length_counter + 24;
                64'hFFFFFFFF: write_length_counter <= write_length_counter + 32;
                64'hFFFFFFFFFF: write_length_counter <= write_length_counter + 40;
                64'hFFFFFFFFFFFF: write_length_counter <= write_length_counter + 48;
                64'hFFFFFFFFFFFFFF: write_length_counter <= write_length_counter + 56;
                64'hFFFFFFFFFFFFFFFF: write_length_counter <= write_length_counter + 64;
            endcase
        end
        if (axis_mem_dm_to_cc_read_tvalid && axis_mem_dm_to_cc_read_tready) begin
            read_word_counter <= read_word_counter + 1;
            if (axis_mem_dm_to_cc_read_tlast) begin
                read_pkg_counter <= read_pkg_counter + 1;
            end
            //Assumes multiple of 8
            case (axis_mem_dm_to_cc_read_tkeep)
                64'hFF: read_length_counter <= read_length_counter + 8;
                64'hFFFF: read_length_counter <= read_length_counter + 16;
                64'hFFFFFF: read_length_counter <= read_length_counter + 24;
                64'hFFFFFFFF: read_length_counter <= read_length_counter + 32;
                64'hFFFFFFFFFF: read_length_counter <= read_length_counter + 40;
                64'hFFFFFFFFFFFF: read_length_counter <= read_length_counter + 48;
                64'hFFFFFFFFFFFFFF: read_length_counter <= read_length_counter + 56;
                64'hFFFFFFFFFFFFFFFF: read_length_counter <= read_length_counter + 64;
            endcase
        end
    end
end


// Clock Conversions
axis_clock_converter_32 axis_clock_converter_write_cmd_counter (
   .s_axis_aresetn(user_aresetn),
   .s_axis_aclk(user_clk),
   .s_axis_tvalid(1'b1),
   .s_axis_tready(),
   .s_axis_tdata(user_write_cmd_counter),
   
   .m_axis_aclk(mem_clk),
   .m_axis_aresetn(mem_aresetn),
   .m_axis_tvalid(),
   .m_axis_tready(1'b1),
   .m_axis_tdata(write_cmd_counter)
 );

axis_clock_converter_32 axis_clock_converter_write_sts_counter (
   .s_axis_aresetn(user_aresetn),
   .s_axis_aclk(user_clk),
   .s_axis_tvalid(1'b1),
   .s_axis_tready(),
   .s_axis_tdata(user_write_sts_counter),
   
   .m_axis_aclk(mem_clk),
   .m_axis_aresetn(mem_aresetn),
   .m_axis_tvalid(),
   .m_axis_tready(1'b1),
   .m_axis_tdata(write_sts_counter)
 );

axis_clock_converter_32 axis_clock_converter_write_sts_error_counter (
   .s_axis_aresetn(user_aresetn),
   .s_axis_aclk(user_clk),
   .s_axis_tvalid(1'b1),
   .s_axis_tready(),
   .s_axis_tdata(user_write_sts_error_counter),
   
   .m_axis_aclk(mem_clk),
   .m_axis_aresetn(mem_aresetn),
   .m_axis_tvalid(),
   .m_axis_tready(1'b1),
   .m_axis_tdata(write_sts_error_counter)
 );

axis_clock_converter_32 axis_clock_converter_read_cmd_counter (
   .s_axis_aresetn(user_aresetn),
   .s_axis_aclk(user_clk),
   .s_axis_tvalid(1'b1),
   .s_axis_tready(),
   .s_axis_tdata(user_read_cmd_counter),
   
   .m_axis_aclk(mem_clk),
   .m_axis_aresetn(mem_aresetn),
   .m_axis_tvalid(),
   .m_axis_tready(1'b1),
   .m_axis_tdata(read_cmd_counter)
 );

axis_clock_converter_32 axis_clock_converter_read_sts_counter (
   .s_axis_aresetn(user_aresetn),
   .s_axis_aclk(user_clk),
   .s_axis_tvalid(1'b1),
   .s_axis_tready(),
   .s_axis_tdata(user_read_sts_counter),
   
   .m_axis_aclk(mem_clk),
   .m_axis_aresetn(mem_aresetn),
   .m_axis_tvalid(),
   .m_axis_tready(1'b1),
   .m_axis_tdata(read_sts_counter)
 );

axis_clock_converter_32 axis_clock_converter_read_sts_error_counter (
   .s_axis_aresetn(user_aresetn),
   .s_axis_aclk(user_clk),
   .s_axis_tvalid(1'b1),
   .s_axis_tready(),
   .s_axis_tdata(user_read_sts_error_counter),
   
   .m_axis_aclk(mem_clk),
   .m_axis_aresetn(mem_aresetn),
   .m_axis_tvalid(),
   .m_axis_tready(1'b1),
   .m_axis_tdata(read_sts_error_counter)
 );

endmodule

`default_nettype wire
