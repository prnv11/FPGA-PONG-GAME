`timescale 1ns / 1ps
module vga_controller (
    input  wire        clk25,
    input  wire        rst,
    input  wire [9:0]  player_x,
    input  wire [9:0]  player_y,
    input  wire [9:0]  player_w,
    input  wire [9:0]  ball_x,
    input  wire [9:0]  ball_y,
    input  wire [9:0]  score,
    input  wire        game_over,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    output reg         vga_hs,
    output reg         vga_vs
);
    // ================= VGA TIMING =================
    localparam H_ACTIVE=640, H_TOTAL=800;
    localparam V_ACTIVE=480, V_TOTAL=525;
    localparam H_SYNC_START=656, H_SYNC_END=752;
    localparam V_SYNC_START=490, V_SYNC_END=492;
    localparam PLAYER_H = 10;
    localparam BALL_W   = 10;
    localparam BALL_H   = 10;
    localparam BORDER   = 4;

    reg [9:0] h_cnt = 0, v_cnt = 0;
    always @(posedge clk25 or posedge rst) begin
        if (rst) begin h_cnt <= 0; v_cnt <= 0; end
        else begin
            if (h_cnt == H_TOTAL-1) begin
                h_cnt <= 0;
                v_cnt <= (v_cnt == V_TOTAL-1) ? 0 : v_cnt + 1;
            end else
                h_cnt <= h_cnt + 1;
        end
    end
    always @(posedge clk25) begin
        vga_hs <= ~(h_cnt >= H_SYNC_START && h_cnt < H_SYNC_END);
        vga_vs <= ~(v_cnt >= V_SYNC_START && v_cnt < V_SYNC_END);
    end

    wire active = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
    wire [9:0] px = h_cnt;
    wire [9:0] py = v_cnt;

    // ================= OBJECTS =================
    wire in_player = (player_w > 0) &&
                     (px >= player_x) && (px < player_x + player_w) &&
                     (py >= player_y) && (py < player_y + PLAYER_H);
    wire in_player_hi = (player_w > 0) &&
                        (px >= player_x) && (px < player_x + player_w) &&
                        (py >= player_y) && (py < player_y + 2);
    wire in_ball = (px >= ball_x) && (px < ball_x + BALL_W) &&
                   (py >= ball_y) && (py < ball_y + BALL_H);
    wire in_border = (px < BORDER) || (px >= H_ACTIVE-BORDER) ||
                     (py < BORDER) || (py >= V_ACTIVE-BORDER);

    // ================= FONT 5x7 =================
    // indices 0-8  : G A M E (sp) O V E R   (9 chars)
    // indices 9-18 : digits 0-9
    reg [4:0] font [0:18][0:6];
    initial begin
        // G (0)
        font[0][0]=5'b01110; font[0][1]=5'b10001; font[0][2]=5'b10000;
        font[0][3]=5'b10111; font[0][4]=5'b10001; font[0][5]=5'b10001; font[0][6]=5'b01110;
        // A (1)
        font[1][0]=5'b01110; font[1][1]=5'b10001; font[1][2]=5'b10001;
        font[1][3]=5'b11111; font[1][4]=5'b10001; font[1][5]=5'b10001; font[1][6]=5'b10001;
        // M (2)
        font[2][0]=5'b10001; font[2][1]=5'b11011; font[2][2]=5'b10101;
        font[2][3]=5'b10101; font[2][4]=5'b10001; font[2][5]=5'b10001; font[2][6]=5'b10001;
        // E (3)
        font[3][0]=5'b11111; font[3][1]=5'b10000; font[3][2]=5'b11110;
        font[3][3]=5'b10000; font[3][4]=5'b10000; font[3][5]=5'b10000; font[3][6]=5'b11111;
        // SPACE (4)
        font[4][0]=5'b00000; font[4][1]=5'b00000; font[4][2]=5'b00000;
        font[4][3]=5'b00000; font[4][4]=5'b00000; font[4][5]=5'b00000; font[4][6]=5'b00000;
        // O (5)
        font[5][0]=5'b01110; font[5][1]=5'b10001; font[5][2]=5'b10001;
        font[5][3]=5'b10001; font[5][4]=5'b10001; font[5][5]=5'b10001; font[5][6]=5'b01110;
        // V (6)
        font[6][0]=5'b10001; font[6][1]=5'b10001; font[6][2]=5'b10001;
        font[6][3]=5'b10001; font[6][4]=5'b01010; font[6][5]=5'b01010; font[6][6]=5'b00100;
        // E (7) - same as index 3
        font[7][0]=5'b11111; font[7][1]=5'b10000; font[7][2]=5'b11110;
        font[7][3]=5'b10000; font[7][4]=5'b10000; font[7][5]=5'b10000; font[7][6]=5'b11111;
        // R (8)
        font[8][0]=5'b11110; font[8][1]=5'b10001; font[8][2]=5'b10001;
        font[8][3]=5'b11110; font[8][4]=5'b10100; font[8][5]=5'b10010; font[8][6]=5'b10001;

        // digit 0 (9)
        font[9][0]=5'b01110;  font[9][1]=5'b10001; font[9][2]=5'b10011;
        font[9][3]=5'b10101;  font[9][4]=5'b11001; font[9][5]=5'b10001; font[9][6]=5'b01110;
        // digit 1 (10)
        font[10][0]=5'b00100; font[10][1]=5'b01100; font[10][2]=5'b00100;
        font[10][3]=5'b00100; font[10][4]=5'b00100; font[10][5]=5'b00100; font[10][6]=5'b01110;
        // digit 2 (11)
        font[11][0]=5'b01110; font[11][1]=5'b10001; font[11][2]=5'b00001;
        font[11][3]=5'b00110; font[11][4]=5'b01000; font[11][5]=5'b10000; font[11][6]=5'b11111;
        // digit 3 (12)
        font[12][0]=5'b11111; font[12][1]=5'b00010; font[12][2]=5'b00100;
        font[12][3]=5'b00010; font[12][4]=5'b00001; font[12][5]=5'b10001; font[12][6]=5'b01110;
        // digit 4 (13)
        font[13][0]=5'b00010; font[13][1]=5'b00110; font[13][2]=5'b01010;
        font[13][3]=5'b10010; font[13][4]=5'b11111; font[13][5]=5'b00010; font[13][6]=5'b00010;
        // digit 5 (14)
        font[14][0]=5'b11111; font[14][1]=5'b10000; font[14][2]=5'b11110;
        font[14][3]=5'b00001; font[14][4]=5'b00001; font[14][5]=5'b10001; font[14][6]=5'b01110;
        // digit 6 (15)
        font[15][0]=5'b00110; font[15][1]=5'b01000; font[15][2]=5'b10000;
        font[15][3]=5'b11110; font[15][4]=5'b10001; font[15][5]=5'b10001; font[15][6]=5'b01110;
        // digit 7 (16)
        font[16][0]=5'b11111; font[16][1]=5'b00001; font[16][2]=5'b00010;
        font[16][3]=5'b00100; font[16][4]=5'b01000; font[16][5]=5'b01000; font[16][6]=5'b01000;
        // digit 8 (17)
        font[17][0]=5'b01110; font[17][1]=5'b10001; font[17][2]=5'b10001;
        font[17][3]=5'b01110; font[17][4]=5'b10001; font[17][5]=5'b10001; font[17][6]=5'b01110;
        // digit 9 (18)
        font[18][0]=5'b01110; font[18][1]=5'b10001; font[18][2]=5'b10001;
        font[18][3]=5'b01111; font[18][4]=5'b00001; font[18][5]=5'b00010; font[18][6]=5'b01100;
    end

    // ================= SCORE DISPLAY =================
    // Each digit scaled x3 = 15x21 px
    // hundreds@560, tens@576, ones@592, py=10..30
    function draw_digit;
        input [9:0] x, y, ox;
        input [3:0] d;
        reg [2:0] r, c;
        begin
            r = (y - 10) / 3;
            c = (x - ox) / 3;
            // digit font now starts at index 9
            draw_digit = (r < 7 && c < 5) ? font[d + 9][r][4 - c] : 1'b0;
        end
    endfunction

    wire in_score_band = (py >= 10) && (py < 31) &&
                         (px >= 560) && (px < 607);

    wire score_pixel = in_score_band && (
        ((px >= 560) && (px < 575) && draw_digit(px, py, 560, (score / 100) % 10)) ||
        ((px >= 576) && (px < 591) && draw_digit(px, py, 576, (score / 10)  % 10)) ||
        ((px >= 592) && (px < 607) && draw_digit(px, py, 592,  score        % 10))
    );

    // ================= GAME OVER BOX =================
    // Box: x=180..460 (280px wide), y=160..320 (160px tall)
    localparam BOX_X0 = 180, BOX_X1 = 460;
    localparam BOX_Y0 = 160, BOX_Y1 = 320;

    wire in_box = game_over &&
                  (px >= BOX_X0) && (px < BOX_X1) &&
                  (py >= BOX_Y0) && (py < BOX_Y1);
    wire in_box_border = in_box &&
        ((px < BOX_X0+3) || (px >= BOX_X1-3) ||
         (py < BOX_Y0+3) || (py >= BOX_Y1-3));

    // ================= "GAME OVER" TEXT =================
    // 9 chars (G A M E sp O V E R)
    // Each char: 5 cols x scale-4 = 20px wide, 7 rows x scale-3 = 21px tall
    // Total width  = 9 x 20 = 180px
    // Box width    = 280px  => left margin = (280-180)/2 = 50
    // TEXT_X0      = BOX_X0 + 50 = 230
    // Box height   = 160px, char height = 21px
    // Top margin   = (160-21)/2 = 69
    // TEXT_Y0      = BOX_Y0 + 69 = 229
    localparam TEXT_X0  = 230;   // BOX_X0 + 50
    localparam TEXT_Y0  = 229;   // BOX_Y0 + 69
    localparam CHAR_W   = 20;    // 5 cols x scale-4
    localparam CHAR_H   = 21;    // 7 rows x scale-3
    localparam NUM_CHARS = 9;

    function draw_gameover;
        input [9:0] x, y;
        reg [9:0] lx, ly;
        reg [3:0] id;
        reg [2:0] col, row;
        begin
            lx  = x - TEXT_X0;
            ly  = y - TEXT_Y0;
            id  = lx / CHAR_W;        // 0..8
            col = (lx % CHAR_W) / 4;  // 0..4  (20px / 4 = 5 cols)
            row = ly / 3;             // 0..6  (21px / 3 = 7 rows)
            if (id < NUM_CHARS && row < 7 && col < 5)
                draw_gameover = font[id][row][4 - col];
            else
                draw_gameover = 1'b0;
        end
    endfunction

    wire text_pixel = game_over &&
                      (px >= TEXT_X0) && (px < TEXT_X0 + NUM_CHARS * CHAR_W) &&
                      (py >= TEXT_Y0) && (py < TEXT_Y0 + CHAR_H) &&
                      draw_gameover(px, py);

    // ================= COLOR OUTPUT =================
    always @(posedge clk25) begin
        if (!active) begin
            vga_r<=0; vga_g<=0; vga_b<=0;

        end else if (score_pixel) begin
            {vga_r,vga_g,vga_b} <= {4'hF,4'hF,4'h0};       // yellow digits

        end else if (in_box) begin
            if (in_box_border)
                {vga_r,vga_g,vga_b} <= {4'hF,4'hA,4'h0};   // orange border
            else if (text_pixel)
                {vga_r,vga_g,vga_b} <= {4'hF,4'hF,4'hF};   // white text
            else
                {vga_r,vga_g,vga_b} <= {4'h1,4'h0,4'h2};   // dark purple fill

        end else if (in_player_hi) begin
            {vga_r,vga_g,vga_b} <= {4'h8,4'hF,4'hF};
        end else if (in_player) begin
            {vga_r,vga_g,vga_b} <= {4'h0,4'hC,4'hC};
        end else if (in_ball) begin
            {vga_r,vga_g,vga_b} <= {4'hF,4'hF,4'hF};
        end else if (in_border) begin
            {vga_r,vga_g,vga_b} <= {4'hA,4'hA,4'hA};
        end else begin
            {vga_r,vga_g,vga_b} <= {4'h0,4'h1,4'h2};
        end
    end

endmodule