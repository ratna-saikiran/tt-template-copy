/* verilator lint_off TIMESCALEMOD */
/* verilator lint_off PINCONNECTEMPTY */
/* verilator lint_off PINMISSING */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off UNUSEDSIGNAL */
`default_nettype none

module tt_um_fp16_mac (
    input  wire [7:0] ui_in,    // Dedicated inputs (Switches)
    output wire [7:0] uo_out,   // Dedicated outputs (7-Segment display)
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Disable bidirectional IOs by forcing them to input mode
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Internal registers for 8-bit Integer operands (matching FP16.v)
    reg signed [7:0] a_val;
    reg signed [7:0] b_val;
    reg signed [7:0] c_val;

    // --------------------------------------------------------
    // 1. Map Switches [2:0] to 8 Fixed Integer Test Cases
    // --------------------------------------------------------
    // The underlying math is: Out = (a * b) + c
    
    always @(*) begin
        case (ui_in[2:0])
            // Case 0: (5 * 4) + 2 = 22  (16'h0016)
            3'b000: begin a_val = 8'd5;  b_val = 8'd4;  c_val = 8'd2;  end 
            
            // Case 1: (10 * 10) + 5 = 105 (16'h0069)
            3'b001: begin a_val = 8'd10; b_val = 8'd10; c_val = 8'd5;  end 
            
            // Case 2: (-3 * 8) + 4 = -20 (16'hFFEC)
            3'b010: begin a_val = -8'd3; b_val = 8'd8;  c_val = 8'd4;  end 
            
            // Case 3: (12 * -5) + -10 = -70 (16'hFFBA)
            3'b011: begin a_val = 8'd12; b_val = -8'd5; c_val = -8'd10; end 
            
            // Case 4: (0 * 50) + 127 = 127 (16'h007F)
            3'b100: begin a_val = 8'd0;  b_val = 8'd50; c_val = 8'd127; end 
            
            // Case 5: (15 * 15) + 0 = 225 (16'h00E1)
            3'b101: begin a_val = 8'd15; b_val = 8'd15; c_val = 8'd0;  end 
            
            // Case 6: (-10 * -10) + -50 = 50 (16'h0032)
            3'b110: begin a_val = -8'd10; b_val = -8'd10; c_val = -8'd50; end 
            
            // Case 7: (127 * 2) + 1 = 255 (16'h00FF)
            3'b111: begin a_val = 8'd127; b_val = 8'd2;  c_val = 8'd1;  end 
        endcase
    end

    // --------------------------------------------------------
    // 2. Instantiate your Math module
    // --------------------------------------------------------
    // FP16.v outputs a 16-bit signed integer
    wire signed [15:0] mac_out;  
    
    // Note: FP16.v doesn't use clk, reset, or clk_enable, 
    // it is purely combinatorial math.
    FP16 my_fp16_mac (
        .a(a_val),
        .b(b_val),
        .c(c_val),
        .Out(mac_out)
    );

    // --------------------------------------------------------
    // 3. Output Display Multiplexer using Switches [4:3]
    // --------------------------------------------------------
    // The output is 16 bits. We need 4 chunks (nibbles) to see the full number.
    reg [3:0] display_nibble;
    
    always @(*) begin
        case (ui_in[4:3])
            2'b00: display_nibble = mac_out[3:0];   // Lowest 4 bits (Bits 3:0)
            2'b01: display_nibble = mac_out[7:4];   // Bits 7:4
            2'b10: display_nibble = mac_out[11:8];  // Bits 11:8
            2'b11: display_nibble = mac_out[15:12]; // Highest 4 bits (Bits 15:12)
        endcase
    end

    // --------------------------------------------------------
    // 4. Seven-Segment Decoder
    // --------------------------------------------------------
    reg [6:0] segments;
    
    always @(*) begin
        case (display_nibble)
            4'h0: segments = 7'b0111111; 
            4'h1: segments = 7'b0000110; 
            4'h2: segments = 7'b1011011; 
            4'h3: segments = 7'b1001111; 
            4'h4: segments = 7'b1100110; 
            4'h5: segments = 7'b1101101; 
            4'h6: segments = 7'b1111101; 
            4'h7: segments = 7'b0000111; 
            4'h8: segments = 7'b1111111; 
            4'h9: segments = 7'b1101111; 
            4'hA: segments = 7'b1110111; 
            4'hB: segments = 7'b1111100; 
            4'hC: segments = 7'b0111001; 
            4'hD: segments = 7'b1011110; 
            4'hE: segments = 7'b1111001; 
            4'hF: segments = 7'b1110001; 
            default: segments = 7'b0000000;
        endcase
    end

    assign uo_out = {1'b0, segments};

endmodule
