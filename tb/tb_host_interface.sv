`timescale 1ns/1ps

module tb_host_interface;

  logic clk_host;
  logic rst_n;
  logic valid_fifo;
  logic [76:0] fifo_data;
  logic rd_en;
  logic valid_out;
  logic [2:0] length_out;
  logic [63:0] data_out;
  logic [7:0] buffer_out;
  logic sop_out, eop_out;

  host_interface dut (
    .clk_host(clk_host),
    .rst_n(rst_n),
    .valid_fifo(valid_fifo),
    .fifo_data(fifo_data),
    .rd_en(rd_en),
    .valid_out(valid_out),
    .length_out(length_out),
    .data_out(data_out),
    .buffer_out(buffer_out),
    .sop_out(sop_out),
    .eop_out(eop_out)
  );

  // 500 MHz
  initial clk_host = 0;
  always #1 clk_host = ~clk_host;

  initial begin

    rst_n = 0;
    valid_fifo = 0;
    fifo_data = 0;

    // Reset deassertion
    #5 rst_n = 1;

    // test FIFO input
    @(negedge clk_host);
    valid_fifo = 1;
    fifo_data = {8'hAB, 3'd4, 1'b1, 1'b1, 64'hDEADBEEFCAFEBABE}; // sop=1, eop=1

    @(negedge clk_host);
    valid_fifo = 0;

    // Wait for data to be captured and output to be valid
    @(posedge clk_host);

    // Check 
    if (valid_out && buffer_out == 8'hAB && length_out == 3'd4 && data_out == 64'hDEADBEEFCAFEBABE && sop_out == 1'b1 && eop_out == 1'b1) begin
      $display(" PASS: Host interface unpacked correctly.");
      $display(" buffer=%h, length=%0d, sop=%0b, eop=%0b, data=%h",
                buffer_out, length_out, sop_out, eop_out, data_out);
    end else begin
      $fatal("FAIL: Host interface output incorrect.\n  buffer=%h, length=%0d, sop=%0b, eop=%0b, data=%h",
              buffer_out, length_out, sop_out, eop_out, data_out);
    end

    #5 $finish;
  end

endmodule

