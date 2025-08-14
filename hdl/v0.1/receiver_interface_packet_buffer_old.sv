// Added to show Design iteration(life-cycle) ; Step 1.) Making it functional & Working Principle 
// Step2.) HW Efficiency Optimization - HFT (Removing for loop, FSM, loop un-rolling...)

// This module buffers each packet and trigger pkt_done when a packet ends.
// Replaced into receiver_interface_streaming_packet_detector.sv for Ultra Low Latency > Optimized Design > Faster, Robust, Reliable, Efficient

module receiver_interface_packet_buffer #(
    parameter MAX_PACKET_LEN = 1500
)(
    input  logic        clk_net,
    input  logic        rst_n,
    input  logic        valid,
    input  logic        sop,
    input  logic        eop,
    input  logic [2:0]  length,
    input  logic [63:0] data,

    output logic        pkt_done,
    output logic [10:0] byte_count, //2^11 = 2048 > 1.5 MB   number of bytes received
    output logic [7:0]  mem_buffer [0:MAX_PACKET_LEN-1] //mem[0] to mem[1499] > uint8_t mem[1500];
// Every cycle we write up to 8-bytes into memory
);

    typedef enum logic [1:0] {
        IDLE,
        RECEIVE,
        DONE
    } state_t;

    state_t state, next_state;

    logic [10:0] count; // How many bytes we've buffered 
    logic [7:0]  data_bytes[0:7]; // Temporary array to hold individual bytes extracted from data[63:0]

    // FSM: State transition - Sequential
    always_ff @(posedge clk_net or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM: Next state Combinatorial logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (sop) next_state = RECEIVE;
            RECEIVE: if (valid && eop) next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end

    // Main data-buffering logic
    always_ff @(posedge clk_net or negedge rst_n) begin
        int i; int max;

        if (!rst_n) begin
            count <= 0;
            byte_count <= 0;
        end else if (state == RECEIVE && valid) begin
            {data_bytes[7], data_bytes[6], data_bytes[5], data_bytes[4],
             data_bytes[3], data_bytes[2], data_bytes[1], data_bytes[0]} = data; // Little-Endian

            if (eop)
                max = length + 1;
            else
                max = 8;

            for (i = 0; i < max; i++) begin // Not efficient way of design for Ultra-Low-Latency and solid synthesiable logic, limits are variables
                if ((count + i) < MAX_PACKET_LEN)
                    mem_buffer[count + i] <= data_bytes[i];
            end

            count <= count + max; //  Update count to point to next available byte in memory

        end else if (state == DONE) begin // Wait one-cycle for clean hand-shaking, signal completion
            byte_count <= count; // latch
            count <= 0; //reset
        end
    end

//Packet complete
    assign pkt_done = (state == DONE); // Combinatorial, error prone but more dynamic power consumption

/*
// Catch invalid length
always_ff @(posedge clk_net) begin
    if (valid && eop) begin
        assert(length <= 7)
        else $fatal("ERROR: Invalid length %0d on EOP!", length);
    end
end

// Catch SOP during RECEIVE (should only happen in IDLE)
 always_ff @(posedge clk_net) begin
    if (state == RECEIVE && valid && sop) begin
        assert(0) else $fatal("ERROR: SOP asserted during RECEIVE!");
    end
end

// EOP without SOP
always_ff @(posedge clk_net) begin
    if (state == IDLE && valid && eop) begin
        assert(0) else $fatal("ERROR: EOP received without SOP!");
    end
end

*/

endmodule

