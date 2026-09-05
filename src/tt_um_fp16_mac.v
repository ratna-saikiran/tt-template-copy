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

    // Internal registers for our FP32 operands (now 32 bits)
    reg [31:0] a_val;
    reg [31:0] b_val;
    reg [31:0] c_val;

    // --------------------------------------------------------
    // 1. Map Switches [2:0] to 8 Fixed FP32 Test Cases
    // --------------------------------------------------------
    // FP32 Hex Reference:
    // 0.0  = 32'h00000000  |  1.0 = 32'h3F800000  |  1.5 = 32'h3FC00000 
    // 2.0  = 32'h40000000  |  2.5 = 32'h40200000  | -1.0 = 32'hBF800000
    
    always @(*) begin
        case (ui_in[2:0])
            // Case 0: (1.0 * 1.5) + 0.0 = 1.5
            3'b000: begin a_val = 32'h3F800000; b_val = 32'h3FC00000; c_val = 32'h00000000; end 
            
            // Case 1: (2.0 * 2.0) + 1.0 = 5.0 (32'h40A00000)
            3'b001: begin a_val = 32'h40000000; b_val = 32'h40000000; c_val = 32'h3F800000; end 
            
            // Case 2: (1.5 * 2.0) + 1.5 = 4.5 (32'h40900000)
            3'b010: begin a_val = 32'h3FC00000; b_val = 32'h40000000; c_val = 32'h3FC00000; end 
            
            // Case 3: (-1.0 * 2.5) + 0.0 = -2.5 (32'hC0200000)
            3'b011: begin a_val = 32'hBF800000; b_val = 32'h40200000; c_val = 32'h00000000; end 
            
            // Case 4: (0.0 * 2.0) + 2.5 = 2.5 (32'h40200000)
            3'b100: begin a_val = 32'h00000000; b_val = 32'h40000000; c_val = 32'h40200000; end 
            
            // Case 5: (1.0 * 1.0) + 1.0 = 2.0 (32'h40000000)
            3'b101: begin a_val = 32'h3F800000; b_val = 32'h3F800000; c_val = 32'h3F800000; end 
            
            // Case 6: (2.0 * 1.5) + 2.0 = 5.0 (32'h40A00000)
            3'b110: begin a_val = 32'h40000000; b_val = 32'h3FC00000; c_val = 32'h40000000; end 
            
            // Case 7: (2.5 * 2.5) + 2.5 = 8.75 (32'h410C0000)
            3'b111: begin a_val = 32'h40200000; b_val = 32'h40200000; c_val = 32'h40200000; end 
        endcase
    end

    // --------------------------------------------------------
    // 2. Instantiate your Math module
    // --------------------------------------------------------
    wire [31:0] mac_out;  // Updated to 32 bits
    wire ce_out_dummy;    // Dummy wire to prevent empty pin warnings
    
    FP16 my_fp16_mac (
        .clk(clk),
        .reset(~rst_n),      // TT provides active-low rst_n; invert for active-high
        .clk_enable(1'b1),   // Tie clock enable constantly high
        .a(a_val),
        .b(b_val),
        .c(c_val),
        .ce_out(ce_out_dummy),
        .Out(mac_out)
    );

    // --------------------------------------------------------
    // 3. Output Display Multiplexer using Switches [5:3]
    // --------------------------------------------------------
    // Since the output is now 32 bits, we need 8 chunks (nibbles) to see the full number.
    // I expanded the select switch mapping to use 3 switches (ui_in[5:3]) to select the 4-bit chunk.
    reg [3:0] display_nibble;
    
    always @(*) begin
        case (ui_in[5:3])
            3'b000: display_nibble = mac_out[3:0];   // Lowest 4 bits (Bits 3:0)
            3'b001: display_nibble = mac_out[7:4];   // Bits 7:4
            3'b010: display_nibble = mac_out[11:8];  // Bits 11:8
            3'b011: display_nibble = mac_out[15:12]; // Bits 15:12
            3'b100: display_nibble = mac_out[19:16]; // Bits 19:16
            3'b101: display_nibble = mac_out[23:20]; // Bits 23:20
            3'b110: display_nibble = mac_out[27:24]; // Bits 27:24
            3'b111: display_nibble = mac_out[31:28]; // Highest 4 bits (Bits 31:28)
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
