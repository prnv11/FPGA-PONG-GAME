`timescale 1ns / 1ps

module game_fsm (
    input  wire        clk,
    input  wire        rst,
    input  wire        btnC,
    input  wire signed [11:0] accel_x,
    input  wire signed [11:0] accel_y,
    input  wire        accel_valid,

    output reg  [9:0]  player_x,
    output reg  [9:0]  player_y,
    output reg  [9:0]  player_w_out,
    output reg  [9:0]  ball_x,
    output reg  [9:0]  ball_y,
    output reg  [9:0]  score,
    output reg         game_over
);

    // ---------------- CONSTANTS ----------------
    localparam SCREEN_W  = 640;
    localparam SCREEN_H  = 480;
    localparam BORDER    = 4;

    localparam PLAYER_W_INIT = 120;
    localparam PLAYER_H      = 10;
    localparam BALL_W        = 10;
    localparam BALL_H        = 10;

    localparam MIN_PLAYER_W = 30;

    // Per-bounce speed cap (normal play)
    localparam MAX_SPEED_X  = 8;
    localparam MAX_SPEED_Y  = 10;

    // Hard ceiling that milestone boost must never exceed
    localparam THRESH_SPEED_X = 12;
    localparam THRESH_SPEED_Y = 15;

    localparam PLAYER_Y0 = SCREEN_H - BORDER - PLAYER_H;
    localparam BALL_X0   = SCREEN_W / 2;
    localparam BALL_Y0   = 50;

    localparam DEAD_ZONE  = 150;
    localparam TILT_SHIFT = 6;

    // ---------------- RANDOM ----------------
    reg [7:0] lfsr = 8'hA5;
    always @(posedge clk)
        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};

    // ---------------- FSM STATES ----------------
    localparam ST_INIT=0, ST_PLAY=1, ST_SCORE=2,
               ST_MISS=3, ST_GAMEOVER=4, ST_RESTART=5;
    reg [2:0] state;

    // ---------------- REGISTERS ----------------
    reg signed [11:0] px_s;
    reg signed [10:0] ball_dx, ball_dy;
    reg signed [11:0] prev_ball_y;

    reg [9:0] player_w;
    reg [2:0] level;

    reg signed [11:0] tmp_dx, tmp_dy, nx, ny;
    reg        [9:0]  tmp_pw;

    // ---------------- ACCEL FILTER ----------------
    reg signed [11:0] ax_filt;
    always @(posedge clk or posedge rst) begin
        if (rst) ax_filt <= 0;
        else if (accel_valid)
            ax_filt <= ax_filt + ((-accel_y - ax_filt) >>> 5);
    end

    // ---------------- BUTTON ----------------
    reg btn_prev;
    always @(posedge clk) btn_prev <= btnC;
    wire btn_edge = btnC & ~btn_prev;

    // ---------------- TICK  (~60 Hz at 25 MHz clk) ----------------
    localparam TICK_DIV = 416_667;
    reg [19:0] tick_cnt;
    reg tick;

    always @(posedge clk or posedge rst) begin
        if (rst) begin tick_cnt <= 0; tick <= 0; end
        else begin
            tick <= 0;
            if (tick_cnt == TICK_DIV - 1) begin
                tick_cnt <= 0; tick <= 1;
            end else
                tick_cnt <= tick_cnt + 1;
        end
    end

    // ---------------- HELPER: signed abs ----------------
    function [10:0] sabs;
        input signed [10:0] v;
        sabs = (v < 0) ? -v : v;
    endfunction

    // ---------------- FSM ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= ST_INIT;
        end else begin
            case (state)

            // ---- INIT ----
            ST_INIT: begin
                score        <= 0;
                game_over    <= 0;
                player_w     <= PLAYER_W_INIT;
                level        <= 0;

                px_s         <= (SCREEN_W - PLAYER_W_INIT) / 2;
                player_x     <= (SCREEN_W - PLAYER_W_INIT) / 2;
                player_y     <= PLAYER_Y0;
                player_w_out <= PLAYER_W_INIT;

                ball_x       <= BALL_X0;
                ball_y       <= BALL_Y0;
                prev_ball_y  <= BALL_Y0;

                ball_dx      <= (lfsr[0]) ? 2 : -2;
                ball_dy      <= -3;

                state        <= ST_PLAY;
            end

            // ---- PLAY ----
            ST_PLAY: begin
                if (tick) begin

                    // --- Paddle movement ---
                    if (ax_filt > DEAD_ZONE)
                        px_s <= px_s + (ax_filt >>> TILT_SHIFT);
                    else if (ax_filt < -DEAD_ZONE)
                        px_s <= px_s + (ax_filt >>> TILT_SHIFT);

                    if (px_s < BORDER)
                        px_s <= BORDER;
                    else if (px_s > SCREEN_W - player_w - BORDER)
                        px_s <= SCREEN_W - player_w - BORDER;

                    player_x     <= px_s;
                    player_y     <= PLAYER_Y0;
                    player_w_out <= player_w;

                    // --- Ball motion ---
                    tmp_dx = ball_dx;
                    tmp_dy = ball_dy;

                    nx = ball_x + tmp_dx;
                    ny = ball_y + tmp_dy;

                    // Wall bounces - direction only, NO speed change
                    if (nx <= BORDER) begin
                        nx = BORDER; tmp_dx = -tmp_dx;
                    end
                    if (nx + BALL_W >= SCREEN_W - BORDER) begin
                        nx = SCREEN_W - BORDER - BALL_W; tmp_dx = -tmp_dx;
                    end
                    if (ny <= BORDER) begin
                        ny = BORDER; tmp_dy = -tmp_dy;
                    end

                    // Paddle bounce - direction only, NO speed change
                    if ((tmp_dy > 0) &&
                        (prev_ball_y + BALL_H <= PLAYER_Y0) &&
                        (ny + BALL_H >= PLAYER_Y0) &&
                        (nx + BALL_W > px_s) &&
                        (nx < px_s + player_w)) begin

                        ny      = PLAYER_Y0 - BALL_H;
                        tmp_dy  = -tmp_dy;

                        case (lfsr[1:0])
                            2'b00: tmp_dx = -3;
                            2'b01: tmp_dx = -2;
                            2'b10: tmp_dx =  2;
                            2'b11: tmp_dx =  3;
                        endcase

                        state <= ST_SCORE;
                    end

                    // NOTE: No per-bounce speed cap needed here since speed
                    // only changes at milestones; random dx is always ±2..3
                    prev_ball_y <= ball_y;
                    ball_dx     <= tmp_dx;
                    ball_dy     <= tmp_dy;
                    ball_x      <= nx;
                    ball_y      <= ny;

                    if (ny + BALL_H >= SCREEN_H - BORDER)
                        state <= ST_MISS;
                end
            end

            // ---- SCORE ----
            ST_SCORE: begin
                score <= score + 1;

                // --- No per-bounce speed/paddle change ---
                // Speed and paddle only change at milestones (multiples of 5)

                level <= level + 1;

                // --- Milestone: every 5 points, speed x1.25 + paddle -15% ---
                if (((score + 1) % 5) == 0) begin

                    // Speed boost x1.25
                    tmp_dx = (ball_dx * 5) / 4;
                    tmp_dy = (ball_dy * 5) / 4;

                    // Hard threshold ceiling
                    if (tmp_dx >  THRESH_SPEED_X) tmp_dx =  THRESH_SPEED_X;
                    if (tmp_dx < -THRESH_SPEED_X) tmp_dx = -THRESH_SPEED_X;
                    if (tmp_dy >  THRESH_SPEED_Y) tmp_dy =  THRESH_SPEED_Y;
                    if (tmp_dy < -THRESH_SPEED_Y) tmp_dy = -THRESH_SPEED_Y;

                    ball_dx <= tmp_dx;
                    ball_dy <= tmp_dy;

                    // Paddle shrink -15%
                    if (player_w > MIN_PLAYER_W) begin
                        tmp_pw   = (player_w * 85) / 100;
                        player_w <= (tmp_pw < MIN_PLAYER_W) ? MIN_PLAYER_W : tmp_pw;
                    end
                end

                state <= ST_PLAY;
            end

            // ---- MISS ----
            ST_MISS: begin
                game_over <= 1;
                state     <= ST_GAMEOVER;
            end

            // ---- GAME OVER ----
            ST_GAMEOVER: begin
                if (btn_edge)
                    state <= ST_RESTART;
            end

            // ---- RESTART ----
            ST_RESTART: begin
                state <= ST_INIT;
            end

            endcase
        end
    end

endmodule