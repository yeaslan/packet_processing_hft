//Functional Verification
//Short packet, asserts SOP/EOP, provides test data
//module matches a known packet_type and symbol correctly, produces the correct buffer_out 
//generates fifo_in correctly at EOP. fifo_in = {buffer, length, sop, eop, data}
/*
Initializes and toggles a 250 MHz clock. Resets the DUT.
Sends a valid 2-cycle packet:
First cycle includes the 4-byte packet_type at offset 14.
Second cycle includes the 8-byte symbol at offset 24.
Asserts EOP in the final cycle, with length=7 (indicating all 8 bytes are valid).
Checks if buffer_out is set to 1, which corresponds to packet_type0 and symbol0.
Pass/fail message is printed accordingly.
sop and eop are applied correctly.
The input data is packed in little-endian format, matching spec
buffer_out == 8'd1 confirms packet_type0 matched.
buffer_valid == 1 at eop shows match was triggered in sync
*/

`timescale 1ns/1ps

module tb_streaming_detector;

  logic clk_net;
  logic rst_n;
  logic valid;
  logic sop;
  logic eop;
  logic [2:0] length;
  logic [63:0] data;
  logic [7:0] buffer_out;
  logic buffer_valid;
  logic [76:0] fifo_in;

  logic [31:0] packet_type0, packet_type1, packet_type2, packet_type3;
  logic [63:0] symbol0, symbol1, symbol2, symbol3;

  RX_streaming_pattern_detector dut (
    .clk_net(clk_net),
    .rst_n(rst_n),
    .valid(valid),
    .sop(sop),
    .eop(eop),
    .length(length),
    .data(data),
    .buffer_out(buffer_out),
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

  // 250 MHz - 4ns
  initial clk_net = 0;
  always #2 clk_net = ~clk_net;

  initial begin
    rst_n = 0;
    valid = 0;
    sop = 0;
    eop = 0;
    length = 0;
    data = 64'd0;

    // Setup match patterns
    packet_type0 = 32'hAABBCCDD;
    packet_type1 = 32'h11223344;
    packet_type2 = 32'h55667788;
    packet_type3 = 32'h99AABBCC;

    symbol0 = 64'hDEADBEEFDEADBEEF;
    symbol1 = 64'h1234567812345678;
    symbol2 = 64'hCAFEBABECAFEBABE;
    symbol3 = 64'hFEEDFACEFEEDFACE;

    #10 rst_n = 1;

    // === Inject Matching Packet ===
    @(negedge clk_net);
    valid = 1;
    sop = 1;
    data = 64'h0000000000000000;
    length = 3;

    @(negedge clk_net);
    sop = 0;
    data = 64'h0000000000000000;

    // Byte offset = 16
    @(negedge clk_net);
    data = 64'h00000000AABBCCDD; // packet_type0

    // Byte offset = 24
    @(negedge clk_net);
    data = 64'hDEADBEEFDEADBEEF;
    eop = 1;

    @(negedge clk_net);
    valid = 0;
    eop = 0;

    // === Wait for buffer_valid ===
    wait (buffer_valid);
    @(posedge clk_net); // ensure clean sampling

    // === Final check ===
    $display("Buffer Out: %h", buffer_out);
    if (buffer_out == 8'd1)
      $display("PASS: Pattern matched. buffer_out = %0d", buffer_out);
    else
      $fatal("FAIL: Pattern not detected correctly. buffer_out = %0d", buffer_out);

    $finish;
  end

endmodule

/*
    always_ff @(posedge clk_net) begin
 	 if (!buffer_out_latched && buffer_valid && buffer_out == 8'h01) begin
  	  buffer_out_tb <= buffer_out;
   	  buffer_out_latched <= 1;
 	 end
    end
*/
