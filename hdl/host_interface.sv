module host_interface (
    input  logic         clk_host,
    input  logic         rst_n,

    input  logic         valid_fifo, //FIFO has valid data to read
    input  logic [76:0]  fifo_data,
    output logic         rd_en, //Asserts when data is ready to be read

    output logic         valid_out, //Signals data is valid for the host
    output logic [2:0]   length_out, //Forwarded packet data
    output logic [63:0]  data_out,
    output logic [7:0]   buffer_out,
    output logic 	 sop_out, //Packet boundary indicators
    output logic 	 eop_out
);

    always_ff @(posedge clk_host or negedge rst_n) begin
        if (!rst_n) begin
            valid_out  <= 0;
            data_out   <= 0;
            length_out <= 0;
            buffer_out <= 0;
            rd_en      <= 0;
            sop_out    <= 1'b0;  
            eop_out    <= 1'b0;
        end else begin
            rd_en      <= !valid_out && valid_fifo; // Asserted only when the output is not already valid for host and new data is available in FIFO 1-cycle handshaking
            valid_out  <= valid_fifo; // Controls when downstream logic should read the outputs
            {buffer_out, length_out, sop_out, eop_out, data_out} <= fifo_data; //77-bit word {buffer_out, length_out, sop_out, eop_out, data_out} unpacked in-place
	end
    end
endmodule