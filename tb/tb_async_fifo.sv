// CDC test

`timescale 1ns/1ps

module tb_async_fifo;

  logic clk_net;
  logic clk_host;
  logic rst_n;
  logic wr_en;
  logic rd_en;
  logic [76:0] din;
  logic [76:0] dout;
  logic full;
  logic empty;

  async_fifo #(.WIDTH(77), .DEPTH(16)) dut (
    .clk_net(clk_net),
    .clk_host(clk_host),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .din(din),
    .rd_en(rd_en),
    .dout(dout),
    .full(full),
    .empty(empty)
  );

  // write clock (250 MHz)
  initial clk_net = 0;
  always #2 clk_net = ~clk_net;

  // read clock (500 MHz)
  initial clk_host = 0;
  always #1 clk_host = ~clk_host;

  initial begin
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    din   = 0;

    #10 rst_n = 1;

    // Wait some time after reset
    #10;

    // Write one word into FIFO
    @(negedge clk_net);
    din   = 77'h0123456789ABCDEF012;
    wr_en = 1;

    @(negedge clk_net);
    wr_en = 0;

    // Wait until data becomes available
    wait (!empty);

    // Read one word out
    @(negedge clk_host);
    rd_en = 1;

    @(negedge clk_host);
    rd_en = 0;

    // Wait for stable output
    #2;

    // Check
    if (dout !== 77'h0123456789ABCDEF012) begin
      $fatal("FAIL: FIFO data mismatch! Expected: %h, Got: %h", 77'h0123456789ABCDEF012, dout);
    end else begin
      $display("PASS: FIFO data = %h", dout);
    end

    #10;
    $finish;
  end

endmodule
