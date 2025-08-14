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