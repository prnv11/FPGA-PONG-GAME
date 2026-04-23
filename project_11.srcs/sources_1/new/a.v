`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 03:38:00 PM
// Design Name: 
// Module Name: a
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module seg7_display (
    input  wire        clk,     // 100 MHz
    input  wire        rst,
    input  wire [9:0]  value,   // 0 – 999
    output reg  [6:0]  seg,     // active-low segments {g,f,e,d,c,b,a}
    output reg  [7:0]  an       // active-low digit anodes
);

    // ----------------------------------------------------------
    // BCD digits
    // ----------------------------------------------------------
    wire [3:0] d0 = value % 10;
    wire [3:0] d1 = (value / 10) % 10;
    wire [3:0] d2 = (value / 100) % 10;
    // d3 = 0 (blank)

    // ----------------------------------------------------------
    // Refresh counter: ~1 kHz total → ~250 Hz per digit
    // ----------------------------------------------------------
    reg [16:0] refresh_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) refresh_cnt <= 0;
        else      refresh_cnt <= refresh_cnt + 1;
    end

    wire [1:0] digit_sel = refresh_cnt[16:15]; // cycles 0→3

    // ----------------------------------------------------------
    // Digit anode select
    // ----------------------------------------------------------
    always @(*) begin
        case (digit_sel)
            2'd0: an = 8'b1111_1110; // digit 0 (rightmost)
            2'd1: an = 8'b1111_1101;
            2'd2: an = 8'b1111_1011;
            2'd3: an = 8'b1111_0111; // blank (leading)
            default: an = 8'b1111_1111;
        endcase
    end

    // ----------------------------------------------------------
    // BCD → 7-segment decode (active low, segment order: gfedcba)
    // ----------------------------------------------------------
    function [6:0] bcd_to_seg;
        input [3:0] bcd;
        case (bcd)
            4'd0: bcd_to_seg = 7'b100_0000;
            4'd1: bcd_to_seg = 7'b111_1001;
            4'd2: bcd_to_seg = 7'b010_0100;
            4'd3: bcd_to_seg = 7'b011_0000;
            4'd4: bcd_to_seg = 7'b001_1001;
            4'd5: bcd_to_seg = 7'b001_0010;
            4'd6: bcd_to_seg = 7'b000_0010;
            4'd7: bcd_to_seg = 7'b111_1000;
            4'd8: bcd_to_seg = 7'b000_0000;
            4'd9: bcd_to_seg = 7'b001_0000;
            default: bcd_to_seg = 7'b111_1111; // blank
        endcase
    endfunction

    always @(*) begin
        case (digit_sel)
            2'd0: seg = bcd_to_seg(d0);
            2'd1: seg = bcd_to_seg(d1);
            2'd2: seg = bcd_to_seg(d2);
            2'd3: seg = 7'b111_1111; // blank
            default: seg = 7'b111_1111;
        endcase
    end

endmodule
