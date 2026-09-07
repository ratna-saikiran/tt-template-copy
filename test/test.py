import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# 7-Segment decoding map exactly as defined in your Verilog (0-F)
segments_map = {
    0x0: int('0111111', 2), # 63
    0x1: int('0000110', 2), # 6
    0x2: int('1011011', 2), # 91
    0x3: int('1001111', 2), # 79
    0x4: int('1100110', 2), # 102
    0x5: int('1101101', 2), # 109
    0x6: int('1111101', 2), # 125
    0x7: int('0000111', 2), # 7
    0x8: int('1111111', 2), # 127
    0x9: int('1101111', 2), # 111
    0xA: int('1110111', 2), # 119
    0xB: int('1111100', 2), # 124
    0xC: int('0111001', 2), # 57
    0xD: int('1011110', 2), # 94
    0xE: int('1111001', 2), # 121
    0xF: int('1110001', 2)  # 113
}

# The expected 32-bit FP32 results for your 8 test cases
expected_results = [
    0x40200000, # Case 0: 1.0 + 1.5 = 2.5
    0x40800000, # Case 1: 2.0 + 2.0 = 4.0
    0x40600000, # Case 2: 1.5 + 2.0 = 3.5
    0x3FC00000, # Case 3: -1.0 + 2.5 = 1.5
    0x40200000, # Case 4: 0.0 + 2.5 = 2.5
    0x40000000, # Case 5: 1.0 + 1.0 = 2.0
    0x40600000, # Case 6: 2.0 + 1.5 = 3.5
    0x40A00000  # Case 7: 2.5 + 2.5 = 5.0
]

@cocotb.test()
async def test_fp32_mac(dut):
    dut._log.info("Starting FP32 Adder Test")

    # 1. Start the clock (50 MHz / 20ns period)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # 2. Initialize inputs
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # 3. Apply Reset
    dut._log.info("Applying Reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # 4. Iterate through all 8 Test Cases
    for test_case in range(8):
        expected_32bit = expected_results[test_case]
        dut._log.info(f"--- Running Test Case {test_case} ---")
        
        # Set the test case selection (ui_in[2:0])
        # Keep nibble selection and control pins at 0 for now
        dut.ui_in.value = test_case
        
        # Give the MATLAB FP32 IP time to process the math (Pipeline Latency)
        # 30 cycles is generous enough to clear any standard FP32 addition pipeline
        await ClockCycles(dut.clk, 30)
        
        # 5. Iterate through the 8 display nibbles to check the 32-bit output
        for nibble_idx in range(8):
            # ui_in[2:0] = test_case
            # ui_in[5:3] = nibble_idx
            # ui_in[7:6] = 0 (rst and dir are safely 0)
            dut.ui_in.value = (nibble_idx << 3) | test_case
            
            # The display multiplexer is combinatorial, so we only need a tiny wait
            await ClockCycles(dut.clk, 2)
            
            # Calculate what we expect to see on the 7-segment display
            expected_nibble = (expected_32bit >> (nibble_idx * 4)) & 0xF
            expected_7seg = segments_map[expected_nibble]
            
            # Read actual output
            actual_7seg = dut.uo_out.value.integer
            
            # Assert they match
            assert actual_7seg == expected_7seg, \
                f"FAIL in Case {test_case}, Nibble {nibble_idx}: " \
                f"Expected Hex {hex(expected_nibble)} -> 7Seg {bin(expected_7seg)}, " \
                f"but got {bin(actual_7seg)}"
                
        dut._log.info(f"Test Case {test_case} PASSED!")
