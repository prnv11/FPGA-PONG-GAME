`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 03:49:29 PM
// Design Name: 
// Module Name: tb_top
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


module tb_top;

    reg  clk100  = 0;
    reg  rst_n   = 0;
    reg  spi_miso= 0;

    wire spi_sclk, spi_mosi, spi_cs_n;
    wire [3:0] vga_r, vga_g, vga_b;
    wire vga_hs, vga_vs;
    wire [6:0] seg;
    wire [7:0] an;

    // 100 MHz clock
    always #5 clk100 = ~clk100;

    // DUT
    top dut (
        .clk100   (clk100),
        .rst_n    (rst_n),
        .spi_sclk (spi_sclk),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .spi_cs_n (spi_cs_n),
        .vga_r    (vga_r),
        .vga_g    (vga_g),
        .vga_b    (vga_b),
        .vga_hs   (vga_hs),
        .vga_vs   (vga_vs),
        .seg      (seg),
        .an       (an)
    );

    // Simple MISO responder: return 0x00 on all reads
    // (simulates accelerometer at 0 g)
    always @(negedge spi_sclk) begin
        spi_miso <= 0;
    end

    // Test sequence
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        // Hold reset
        rst_n = 0;
        #200;
        rst_n = 1;

        // Run for enough time to see some game frames
        // (shortened for sim: 10000 cycles)
        #100_000;

        $display("Simulation complete.");
        $display("VGA HS=%b VS=%b R=%h G=%h B=%h",
                  vga_hs, vga_vs, vga_r, vga_g, vga_b);
        $finish;
    end

    // Monitor VGA sync edges
    always @(negedge vga_vs) begin
        $display("[%0t] VSYNC pulse (frame boundary)", $time);
    end

endmodule

// ============================================================
// tb_game_fsm.v  -  Unit test for game FSM
// ============================================================
module tb_game_fsm;

    reg clk = 0, rst = 1;
    reg signed [11:0] accel_x = 0, accel_y = 0;
    reg accel_valid = 0;

    wire [9:0] player_x, player_y, ball_x, ball_y, score;
    wire       game_over;

    always #20 clk = ~clk; // 25 MHz

    game_fsm dut (
        .clk         (clk),
        .rst         (rst),
        .accel_x     (accel_x),
        .accel_y     (accel_y),
        .accel_valid (accel_valid),
        .player_x    (player_x),
        .player_y    (player_y),
        .ball_x      (ball_x),
        .ball_y      (ball_y),
        .score       (score),
        .game_over   (game_over)
    );

    task send_accel;
        input signed [11:0] ax, ay;
        begin
            accel_x = ax; accel_y = ay;
            accel_valid = 1; #40;
            accel_valid = 0;
        end
    endtask

    initial begin
        $dumpfile("tb_fsm.vcd");
        $dumpvars(0, tb_game_fsm);

        #100; rst = 0;

        // Test: tilt right
        repeat(10) begin
            send_accel(200, 0);
            #400;
        end
        $display("Player X after tilt right: %0d (expect > 290)", player_x);

        // Test: tilt left
        repeat(10) begin
            send_accel(-200, 0);
            #400;
        end
        $display("Player X after tilt left: %0d", player_x);

        $display("Score=%0d, GameOver=%b", score, game_over);
        $finish;
    end

endmodule
