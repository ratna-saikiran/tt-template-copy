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

    // Internal registers for our FP32 operands (32 bits)
    reg [31:0] a_val;
    reg [31:0] b_val;

    // --------------------------------------------------------
    // 1. Map Switches [2:0] to 8 Fixed FP32 Test Cases
    // --------------------------------------------------------
    // The underlying math is an ADDER: Out1 = In1 + In2
    
    always @(*) begin
        case (ui_in[2:0])
            // Case 0: 1.0 + 1.5 = 2.5 (32'h40200000)
            3'b000: begin a_val = 32'h3F800000; b_val = 32'h3FC00000; end 
            
            // Case 1: 2.0 + 2.0 = 4.0 (32'h40800000)
            3'b001: begin a_val = 32'h40000000; b_val = 32'h40000000; end 
            
            // Case 2: 1.5 + 2.0 = 3.5 (32'h40600000)
            3'b010: begin a_val = 32'h3FC00000; b_val = 32'h40000000; end 
            
            // Case 3: -1.0 + 2.5 = 1.5 (32'h3FC00000)
            3'b011: begin a_val = 32'hBF800000; b_val = 32'h40200000; end 
            
            // Case 4: 0.0 + 2.5 = 2.5 (32'h40200000)
            3'b100: begin a_val = 32'h00000000; b_val = 32'h40200000; end 
            
            // Case 5: 1.0 + 1.0 = 2.0 (32'h40000000)
            3'b101: begin a_val = 32'h3F800000; b_val = 32'h3F800000; end 
            
            // Case 6: 2.0 + 1.5 = 3.5 (32'h40600000)
            3'b110: begin a_val = 32'h40000000; b_val = 32'h3FC00000; end 
            
            // Case 7: 2.5 + 2.5 = 5.0 (32'h40A00000)
            3'b111: begin a_val = 32'h40200000; b_val = 32'h40200000; end 
        endcase
    end

    // --------------------------------------------------------
    // 2. Instantiate your CS_TT Top module
    // --------------------------------------------------------
    wire [31:0] adder_out;  
    wire [7:0]  count_out;
    wire ce_out_dummy;    
    
    // Instantiating the new CS_TT module
    CS_TT my_cs_tt (
        .clk(clk),
        .reset(~rst_n),      
        .clk_enable(1'b1),   
        .In1(a_val),
        .In2(b_val),
        .rst(ui_in[6]),      // Map Switch 6 to the 'rst' signal
        .dir(ui_in[7]),      // Map Switch 7 to the 'dir' signal
        .ce_out(ce_out_dummy),
        .Out1(adder_out),
        .count(count_out)
    );

    // --------------------------------------------------------
    // 3. Output Display Multiplexer using Switches [5:3]
    // --------------------------------------------------------
    // Since the output is 32 bits, we need 8 chunks (nibbles) to see the full number.
    // Use 3 switches (ui_in[5:3]) to select the 4-bit chunk.
    reg [3:0] display_nibble;
    
    always @(*) begin
        case (ui_in[5:3])
            3'b000: display_nibble = adder_out[3:0];   // Lowest 4 bits (Bits 3:0)
            3'b001: display_nibble = adder_out[7:4];   // Bits 7:4
            3'b010: display_nibble = adder_out[11:8];  // Bits 11:8
            3'b011: display_nibble = adder_out[15:12]; // Bits 15:12
            3'b100: display_nibble = adder_out[19:16]; // Bits 19:16
            3'b101: display_nibble = adder_out[23:20]; // Bits 23:20
            3'b110: display_nibble = adder_out[27:24]; // Bits 27:24
            3'b111: display_nibble = adder_out[31:28]; // Highest 4 bits (Bits 31:28)
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
