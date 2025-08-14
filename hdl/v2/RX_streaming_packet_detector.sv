module RX_streaming_pattern_detector #(
    parameter integer PACKET_TYPE_OFFSET = 16, //byte_offset where 4-bytes packet type expected
    parameter integer SYMBOL_OFFSET      = 24  //byte_offset for the 8-bytes symbol match field
)(
    input  logic        clk_net,
    input  logic        rst_n,   //active-low
    input  logic        valid,
    input  logic        sop, 
    input  logic        eop,
    input  logic [2:0]  length, //Number of valid bytes in the final data word (used at EOP)
    input  logic [63:0] data,   //8-byte wide data bus from the receiver
    output logic [7:0]  buffer_out,   // Match result, packet type ID(0 = no match, 1to4 = pattern matched)
    output logic        buffer_valid, // Goes high only at EOP 1-cycle, when match is complete
    output logic [76:0] fifo_in, //data packing

    input  logic [31:0] packet_type0, packet_type1, packet_type2, packet_type3, //programmable //loaded at run-time
    input  logic [63:0] symbol0, symbol1, symbol2, symbol3 //configurable
    // The module supports matching up to 4 programmable patterns: These are used for real-time comparison
);
    logic [10:0] byte_index_next;
    logic [10:0] byte_index; // 1.5MBytes, tracks the current byte offset inside the packet (increments in steps of 8)
    logic [7:0]  match_buffer_stage1, match_buffer_stage2;// Hold/match result tag through pipeline stages
    logic        match_packet_stage1, match_symbol_stage1; //Booleans indicating match status
    logic        match_packet_stage2, match_symbol_stage2; //Booleans indicating match status
    logic [31:0] type_word_now;
    logic [63:0] sym_word_now;
    logic eop_d; //pipeline stage 1
    logic eop_d2; //pipeline stage 2

   logic [7:0] match_buffer_now;
   logic       match_packet_now, match_symbol_now;
   logic       match_packet_stage3; //timing pipeline as symbol_stage2 comes one cycle later
   logic [7:0] match_buffer_stage3;


    always_ff @(posedge clk_net or negedge rst_n) begin
        if (!rst_n) begin
            byte_index           <= 0;
	    eop_d <= 0; 
            match_packet_stage1  <= 0;
            match_symbol_stage1  <= 0;
            match_buffer_stage1  <= 8'd0;
        end else begin
            if (sop) begin  //when SOP received, reset all match tracking and begin new indexing
                byte_index            <= 0;
            end else if (valid) begin //if word is valid Do Matching
		 eop_d <= eop; // Timing pipeline alignment
		 match_packet_stage1  <= match_packet_now;
                 match_symbol_stage1  <= match_symbol_now;
                 match_buffer_stage1  <= match_buffer_now;
		 $display("match_packet_now = %0d -> match_packet_stage1 = %0d", match_packet_now, match_packet_stage1);
		 byte_index <= byte_index + 8; //after each valid word increment the byte index
      
		/* Specification - When these patterns are detected, the value of buffer should be set to a value 
		that uniquely identifies that pattern. Only one matches permitted per packet */
		/* Matching packets will have a valid 8-byte value at offset (SYMBOL_OFFSET) which matches one 
		of four programmable values. Matching packets contain a 4-byte value (PACKET_TYPE) at a fixed offset...*/
    		
            end
        end
    end

      always_comb begin
 	   	 match_packet_now = 0;
    	   	 match_symbol_now = 0;
 	   	 match_buffer_now = 8'd0;

 		 // Default to current index
 		 byte_index_next = byte_index;

 		 // Predict next index (if not SOP, since SOP resets index)
  		if (valid) begin
 			if (!sop) begin
   			   byte_index_next = byte_index + 8;
  			end else begin
   			   byte_index_next = 0;
		end

   	 	if (byte_index_next == PACKET_TYPE_OFFSET) begin
			$display("Matching packet_type @ %0t: 0x%08X", $time, type_word_now);
    	  		if      (type_word_now == packet_type0) begin match_buffer_now = 8'd1; match_packet_now = 1; end
     			else if (type_word_now == packet_type1) begin match_buffer_now = 8'd2; match_packet_now = 1; end
    	 		else if (type_word_now == packet_type2) begin match_buffer_now = 8'd3; match_packet_now = 1; end
    	  		else if (type_word_now == packet_type3) begin match_buffer_now = 8'd4; match_packet_now = 1; end
			else begin match_packet_now = 0; end 
    	        end

   	 	if (byte_index_next == SYMBOL_OFFSET) begin
	 		$display("Matching symbol @ %0t: 0x%016X", $time, sym_word_now);
    	  		if (sym_word_now == symbol0 || sym_word_now == symbol1 || sym_word_now == symbol2 || sym_word_now == symbol3) begin
     	  	  	 match_symbol_now = 1; 
			end
			else begin match_symbol_now = 0; end
	        end
	  end 
   end

    always_comb begin
 	   type_word_now = {data[31:24], data[23:16], data[15:8], data[7:0]};
           sym_word_now  = {data[63:56], data[55:48], data[47:40], data[39:32], data[31:24], data[23:16], data[15:8], data[7:0]};  
    end

    always_ff @(posedge clk_net or negedge rst_n) begin
        if (!rst_n) begin
            match_packet_stage2 <= 0;
            match_symbol_stage2 <= 0;
            match_buffer_stage2 <= 8'd0;
	    eop_d2 <= 0;
        //end else if (valid) begin      to always capture EOP status
	    end else begin  
            match_packet_stage2 <= match_packet_stage1;
            match_symbol_stage2 <= match_symbol_stage1;
            match_buffer_stage2 <= match_buffer_stage1;
            eop_d2 <= eop_d;
        end
    end

   always_ff @(posedge clk_net) begin
	  match_packet_stage3     <= match_packet_stage2;
  	  match_buffer_stage3     <= match_buffer_stage2;
   end	

    assign buffer_valid = eop_d2; // at the final cycle of the packet
    assign buffer_out   = (match_packet_stage3 && match_symbol_stage2) ? match_buffer_stage3 : 8'd0;
    // Tagging the output in sync with the EOP, but using results that were computed earlier and registered
    assign fifo_in = {buffer_out, length, sop, eop, data}; // Upstream data-packing

endmodule

