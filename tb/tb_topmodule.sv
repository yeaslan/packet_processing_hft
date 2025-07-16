/*
Covers dual-clock behavior async_fifo (250 MHz clk_net, 500 MHz clk_host)
Injects a test packet with matching pattern type and symbol
Offset alignment for packet_type + symbol
	packet_type at byte offset 16 (PACKET_TYPE_OFFSET)
	symbol at byte offset 24 (SYMBOL_OFFSET)
	Word size = 8 bytes, so offsets align every 8-byte cycleFIFO handshaking and host side unpacking
1 cycle FIFO to host delay
packet_type0 and symbol0 match, and both conditions are met at EOP
Verifies buffer_out correctness via $fatal check
End-to-end functional check (buffer_out == 1)
*/

`timescale 1ns/1ps

module tb_topmodule;

  logic clk_net;
  logic clk_host;
  logic rst_n;

  logic valid_in, sop_in, eop_in;
  logic [2:0] length_in;
  logic [63:0] data_in;

  logic valid_out, sop_out, eop_out;
  logic [2:0] length_out;
  logic [63:0] data_out;
  logic [7:0] buffer_out;

  // Pattern Configs
  logic [31:0] packet_type0, packet_type1, packet_type2, packet_type3;
  logic [63:0] symbol0, symbol1, symbol2, symbol3;

  top_pattern_detector_system dut (
    .clk_net(clk_net),
    .clk_host(clk_host),
    .rst_n(rst_n),

    .valid_in(valid_in),
    .sop_in(sop_in),
    .eop_in(eop_in),
    .length_in(length_in),
    .data_in(data_in),

    .valid_out(valid_out),
    .data_out(data_out),
    .length_out(length_out),
    .buffer_out(buffer_out),
    .sop_out(sop_out),
    .eop_out(eop_out),

    .packet_type0(packet_type0),
    .packet_type1(packet_type1),
    .packet_type2(packet_type2),
    .packet_type3(packet_type3),
    .symbol0(symbol0),
    .symbol1(symbol1),
    .symbol2(symbol2),
    .symbol3(symbol3)
  );

  initial clk_net = 0;
  always #2 clk_net = ~clk_net; // 250 MHz

  initial clk_host = 0;
  always #1 clk_host = ~clk_host; // 500 MHz

  // Stimulus
  initial begin
    rst_n = 0;
    valid_in = 0;
    sop_in = 0;
    eop_in = 0;
    length_in = 0;
    data_in = 0;

    // Set match configuration
    packet_type0 = 32'hAABBCCDD; // used in test below
    packet_type1 = 32'h00000000;
    packet_type2 = 32'h00000000;
    packet_type3 = 32'h00000000;

    symbol0 = 64'hDEADBEEFDEADBEEF; // used in test below
    symbol1 = 64'h0;
    symbol2 = 64'h0;
    symbol3 = 64'h0;

    #10 rst_n = 1;
    #10;

    // === Send packet ===
    // Cycle 0 - SOP
    @(negedge clk_net);
    valid_in = 1;
    sop_in   = 1;
    data_in  = 64'h0000000000000000;
    length_in = 3;

    // Cycle 1
    @(negedge clk_net);
    sop_in  = 0;
    data_in = 64'h0000000000000000;

    // Cycle 2 - offset = 16 -> this is byte 16
    @(negedge clk_net);
    data_in = 64'h00000000AABBCCDD; // packet_type0 at correct offset

    // Cycle 3 - SYMBOL
    @(negedge clk_net);
    data_in = 64'hDEADBEEFDEADBEEF;
    eop_in = 1;
    length_in = 7;

    // Cycle 4 - End of packet
    @(negedge clk_net);
    valid_in = 0;
    eop_in   = 0;

    // Wait for host clock to pick it up
    repeat (10) @(posedge clk_host);

    $display("Buffer Out: %h, Data Out: %h", buffer_out, data_out);
    if (buffer_out !== 8'd1)
      $fatal("FAIL: Pattern not detected correctly. buffer_out = %0d", buffer_out);
    else
      $display("PASS: Pattern detected. buffer_out = %0d", buffer_out);

    $finish;
  end

endmodule

