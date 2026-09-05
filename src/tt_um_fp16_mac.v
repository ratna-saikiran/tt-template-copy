`timescale 1ns / 1ps
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

    // Internal registers for our FP16 operands
    reg [15:0] a_val;
    reg [15:0] b_val;
    reg [15:0] c_val;

    // --------------------------------------------------------
    // 1. Map Switches [2:0] to Fixed FP16 Test Cases
    // --------------------------------------------------------
    always @(*) begin
        case (ui_in[2:0])
            3'b000: begin a_val = 16'h3C00; b_val = 16'h3E00; c_val = 16'h0000; end 
            3'b001: begin a_val = 16'h4000; b_val = 16'h4000; c_val = 16'h3C00; end 
            3'b010: begin a_val = 16'h3E00; b_val = 16'h4000; c_val = 16'h3E00; end 
            3'b011: begin a_val = 16'hBC00; b_val = 16'h4100; c_val = 16'h0000; end 
            3'b100: begin a_val = 16'h0000; b_val = 16'h4000; c_val = 16'h4100; end 
            3'b101: begin a_val = 16'h3C00; b_val = 16'h3C00; c_val = 16'h3C00; end 
            3'b110: begin a_val = 16'h4000; b_val = 16'h3E00; c_val = 16'h4000; end 
            3'b111: begin a_val = 16'h4100; b_val = 16'h4100; c_val = 16'h4100; end 
        endcase
    end

    // --------------------------------------------------------
    // 2. Instantiate your FP16 MAC module
    // --------------------------------------------------------
    wire [15:0] mac_out;
    
    FP16 my_fp16_mac (
        .clk(clk),
        .reset(~rst_n),       // Invert TinyTapeout's active-low reset
        .clk_enable(1'b1),    // Tie clock enable high
        .a(a_val),
        .b(b_val),
        .c(c_val),
        .ce_out(),            // Leave unused output floating
        .Out(mac_out)         // Note the capital 'O'
    );

    // --------------------------------------------------------
    // 3. Output Display Multiplexer using Switches [4:3]
    // --------------------------------------------------------
    reg [3:0] display_nibble;
    
    always @(*) begin
        case (ui_in[4:3])
            2'b00: display_nibble = mac_out[3:0];   
            2'b01: display_nibble = mac_out[7:4];   
            2'b10: display_nibble = mac_out[11:8];  
            2'b11: display_nibble = mac_out[15:12]; 
        endcase
    end

    // --------------------------------------------------------
    // 4. Seven-Segment Decoder
    // --------------------------------------------------------
    reg [6:0] segments;
    
    always @(*) begin
        case (display_nibble)
            4'h0: segments = 7'b0111111; // 0
            4'h1: segments = 7'b0000110; // 1
            4'h2: segments = 7'b1011011; // 2
            4'h3: segments = 7'b1001111; // 3
            4'h4: segments = 7'b1100110; // 4
            4'h5: segments = 7'b1101101; // 5
            4'h6: segments = 7'b1111101; // 6
            4'h7: segments = 7'b0000111; // 7
            4'h8: segments = 7'b1111111; // 8
            4'h9: segments = 7'b1101111; // 9
            4'hA: segments = 7'b1110111; // A
            4'hB: segments = 7'b1111100; // b
            4'hC: segments = 7'b0111001; // C
            4'hD: segments = 7'b1011110; // d
            4'hE: segments = 7'b1111001; // E
            4'hF: segments = 7'b1110001; // F
            default: segments = 7'b0000000;
        endcase
    end

    // Assign decoded segments to output
    assign uo_out = {1'b0, segments};

endmodule
