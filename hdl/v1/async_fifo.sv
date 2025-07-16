// Dual-clock FIFO for clk_net, clk_host, latency-optimized
// The actual packet data (data, sop, eop, length) is passed through immediately to the async FIFO, not held
// No full-packet storage - One word per clock, supports streaming, single cycle read/write access
// No stalls - If FIFO isn't full/empty, writes/reads proceed
// Simple & Efficient

/*
Optional Improvement
	Add Gray-coded pointers & sync stages, to handle metastability cleanly when wr_clk ? rd_clk.
	Add "almost_full"/"almost_empty" flags, for preemptive control in longer pipelines.
	Using FPGA?s built-in FIFO IP, for area efficiency, speed, and robustness.
*/

/*
din = {buffer[7:0], length[2:0], sop, eop, data[63:0]};
{buffer_out, length_out, sop_out, eop_out, data_out} <= fifo_data; 
assign fifo_in = {buffer, length, sop, eop, data};

*/
module async_fifo #(parameter WIDTH = 77, DEPTH = 16) ( // Shallow <= 32, Storage , less BRAM
    input  logic             clk_net, // Writing data into FIFO as it streams from network
    input  logic             clk_host, //Reading data out to the host at higher speed
    input  logic             rst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] din, //fifo_in from RX_streaming_packet_detector.sv
    input  logic             rd_en,
    output logic [WIDTH-1:0] dout, //holds data read
    output logic             full,
    output logic             empty
);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    logic [$clog2(DEPTH):0] wr_cnt, rd_cnt;
    //write/read counters for full and empty status

    // Write logic
    always_ff @(posedge clk_net or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            wr_cnt <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1;
            wr_cnt <= wr_cnt + 1;
        end
    end

    // Read logic
    always_ff @(posedge clk_host or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            rd_cnt <= 0;
            dout   <= '0;
        end else if (rd_en && !empty) begin
            dout <= mem[rd_ptr];
            rd_ptr <= rd_ptr + 1;
            rd_cnt <= rd_cnt + 1;
        end
    end

    // Combinatorial Full/Empty Logic
    assign full  = (wr_cnt - rd_cnt) == DEPTH; //when number of writes exceeds reads by DEPTH
    assign empty = (wr_cnt == rd_cnt);

endmodule
