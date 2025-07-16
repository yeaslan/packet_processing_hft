// Added to show design development process

module pattern_detector #(
    parameter MAX_PACKET_LEN = 1500 //Pass Full Packet from receiver_interface_packet_buffer.sv
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         pkt_done,
    input  logic [10:0]  byte_count,

    input  logic [7:0]   mem [0:MAX_PACKET_LEN-1], // packet data

    input  logic [15:0]  PACKET_TYPE_OFFSET,
    input  logic [15:0]  SYMBOL_OFFSET,

    input  logic [31:0]  packet_type0,
    input  logic [31:0]  packet_type1,
    input  logic [31:0]  packet_type2,
    input  logic [31:0]  packet_type3,

    input  logic [63:0]  symbol0,
    input  logic [63:0]  symbol1,
    input  logic [63:0]  symbol2,
    input  logic [63:0]  symbol3,

    output logic [7:0]   buffer
);

    logic [31:0] packet_type_val; //hold the extracted values from the packet memory
    logic [63:0] symbol_val;

//To not read outside memory
always_ff @(posedge clk) begin
    if (pkt_done) begin
        assert(PACKET_TYPE_OFFSET + 3 < byte_count)
        else $fatal("PACKET_TYPE access out of bounds");

        assert(SYMBOL_OFFSET + 7 < byte_count)
        else $fatal("SYMBOL access out of bounds");
    end
end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer <= 8'd0;
        end else if (pkt_done) begin
            // Extract 4-byte PACKET_TYPE (little-endian)
            packet_type_val = {
                mem[PACKET_TYPE_OFFSET + 3],
                mem[PACKET_TYPE_OFFSET + 2],
                mem[PACKET_TYPE_OFFSET + 1],
                mem[PACKET_TYPE_OFFSET + 0]
            };

            // Extract 8-byte SYMBOL
            symbol_val = {
                mem[SYMBOL_OFFSET + 7],
                mem[SYMBOL_OFFSET + 6],
                mem[SYMBOL_OFFSET + 5],
                mem[SYMBOL_OFFSET + 4],
                mem[SYMBOL_OFFSET + 3],
                mem[SYMBOL_OFFSET + 2],
                mem[SYMBOL_OFFSET + 1],
                mem[SYMBOL_OFFSET + 0]
            };

            // Match against known patterns
	    // This value will be delivered with the packet on the host interface and tell the system about match case
	    // Each pattern has unique buffer code
            if (packet_type_val == packet_type0 && symbol_val == symbol0) //both the packet type and symbol match, assign unique buffer
                buffer <= 8'd1;
            else if (packet_type_val == packet_type1 && symbol_val == symbol1)
                buffer <= 8'd2;
            else if (packet_type_val == packet_type2 && symbol_val == symbol2)
                buffer <= 8'd3;
            else if (packet_type_val == packet_type3 && symbol_val == symbol3)
                buffer <= 8'd4;
            else
                buffer <= 8'd0;
        end
    end

endmodule

