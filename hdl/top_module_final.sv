module top_pattern_detector_system (
    input  logic         clk_net,    // Network domain clock
    input  logic         clk_host,   // Host domain clock (2× faster)
    input  logic         rst_n,      // Active-low reset

    // Receiver interface
    input  logic         valid_in,
    input  logic         sop_in,
    input  logic         eop_in,
    input  logic [2:0]   length_in,
    input  logic [63:0]  data_in,

    // Pattern config inputs - Programmable match patterns 
    input  logic [31:0]  packet_type0, packet_type1, packet_type2, packet_type3,
    input  logic [63:0]  symbol0, symbol1, symbol2, symbol3,

    // Host interface outputs
    output logic         valid_out,
    output logic [63:0]  data_out,
    output logic [2:0]   length_out,
    output logic [7:0]   buffer_out,
    output logic         sop_out,
    output logic         eop_out
);

    // Internal signals
    logic         buffer_valid; //when a valid pattern match tag is available
    logic [7:0]   buffer_match; //holds the current tag before FIFO write
    logic [76:0]  fifo_in; //packed 77-bit data to write/read from async FIFO
    logic [76:0]  fifo_out; //packed 77-bit data to write/read from async FIFO
    logic         fifo_wr_en, fifo_rd_en; //control signals for FIFO write/read
    logic         fifo_full, fifo_empty; //flow control to avoid overflow/underflow

    RX_streaming_pattern_detector #(
        .PACKET_TYPE_OFFSET(16),
        .SYMBOL_OFFSET(24)
    ) detector_inst (
        .clk_net(clk_net),
        .rst_n(rst_n),
        .valid(valid_in),
        .sop(sop_in),
        .eop(eop_in),
        .length(length_in),
        .data(data_in),
        .buffer_out(buffer_match), //Outputs when a match is found at eop
        .buffer_valid(buffer_valid),
        .fifo_in(fifo_in),
        .packet_type0(packet_type0),
        .packet_type1(packet_type1),
        .packet_type2(packet_type2),
        .packet_type3(packet_type3),
        .symbol0(symbol0),
        .symbol1(symbol1),
        .symbol2(symbol2),
        .symbol3(symbol3)
    );

    
    assign fifo_wr_en = buffer_valid && !fifo_full; //no write happens when the FIFO is full, preventing overflow


    async_fifo #(
        .WIDTH(77),
        .DEPTH(16)
    ) fifo_inst (
        .clk_net(clk_net),
        .clk_host(clk_host),
        .rst_n(rst_n),
        .wr_en(fifo_wr_en),
        .din(fifo_in),
        .rd_en(fifo_rd_en),
        .dout(fifo_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    host_interface host_inst (
        .clk_host(clk_host),
        .rst_n(rst_n),
        .valid_fifo(!fifo_empty), // data is available to be read from the FIFO. Checks before asserting rd_en
        .fifo_data(fifo_out),
        .rd_en(fifo_rd_en), //Generates rd_en to pull data from FIFO
        .valid_out(valid_out),
        .data_out(data_out),
        .length_out(length_out),
        .buffer_out(buffer_out),
        .sop_out(sop_out),
        .eop_out(eop_out)
    );

endmodule
