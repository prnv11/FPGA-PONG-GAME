`timescale 1ns / 1ps




module spi_adxl362 (
    input  wire        clk,          // 100 MHz
    input  wire        rst,          // synchronous active-high
    output reg         spi_sclk,
    output reg         spi_mosi,
    input  wire        spi_miso,
    output reg         spi_cs_n,
    output reg  signed [11:0] accel_x,
    output reg  signed [11:0] accel_y,
    output reg         data_valid
);

    // ---- Clock divider: 100 MHz / (2×25) = 2 MHz SCLK --------
    localparam CLK_DIV   = 25;          // half-period in sys clocks
    localparam INIT_WAIT = 20_000_000;  // 200 ms @ 100 MHz
    localparam RST_WAIT  =  5_000_000;  //  50 ms @ 100 MHz
    localparam IDLE_WAIT =    100_000;  //   1 ms @ 100 MHz

    // ---- ADXL362 protocol constants ---------------------------
    localparam CMD_WRITE     = 8'h0A;
    localparam CMD_READ      = 8'h0B;
    localparam REG_SOFT_RST  = 8'h1F;
    localparam REG_POWER_CTL = 8'h2D;
    localparam REG_XDATA_L   = 8'h0E;

    // ---- States -----------------------------------------------
    localparam S_WAIT_INIT  = 4'd0;
    localparam S_SOFT_RST   = 4'd1;
    localparam S_WAIT_RST   = 4'd2;
    localparam S_POWER_ON   = 4'd3;
    localparam S_IDLE       = 4'd4;
    localparam S_START_READ = 4'd5;
    localparam S_TRANSFER   = 4'd6;
    localparam S_CS_HIGH    = 4'd7;
    localparam S_PROCESS    = 4'd8;

    localparam TOTAL_BYTES = 6; // cmd + addr + 4 data bytes

    reg [3:0]  state, next_state;
    reg [26:0] wait_cnt;
    reg [7:0]  clk_cnt;
    reg [2:0]  bit_in_byte;   // 0-7, resets each new byte
    reg [7:0]  byte_idx;      // 0 to TOTAL_BYTES-1
    reg [7:0]  tx_byte;       // byte currently being shifted out
    reg [7:0]  rx_shift;      // MISO shift register
    reg        is_read;       // 1 = this transfer is a data read
    reg [7:0]  tx_data [0:5];
    reg [7:0]  rx_buf  [0:3]; // X_L, X_H, Y_L, Y_H

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= S_WAIT_INIT;
            next_state  <= S_IDLE;
            wait_cnt    <= 0;
            clk_cnt     <= 0;
            bit_in_byte <= 0;
            byte_idx    <= 0;
            tx_byte     <= 0;
            rx_shift    <= 0;
            is_read     <= 0;
            spi_cs_n    <= 1;
            spi_sclk    <= 0;
            spi_mosi    <= 0;
            data_valid  <= 0;
            accel_x     <= 0;
            accel_y     <= 0;
        end else begin
            data_valid <= 0; // default; pulse for 1 cycle in S_PROCESS

            case (state)

                // ---- 200 ms power-up wait -----------------------
                S_WAIT_INIT: begin
                    wait_cnt <= wait_cnt + 1;
                    if (wait_cnt == INIT_WAIT - 1) begin
                        wait_cnt <= 0;
                        state    <= S_SOFT_RST;
                    end
                end

                // ---- Issue soft-reset (WRITE 0x1F = 0x52) -------
                S_SOFT_RST: begin
                    tx_data[0] <= CMD_WRITE;
                    tx_data[1] <= REG_SOFT_RST;
                    tx_data[2] <= 8'h52;
                    tx_data[3] <= 8'h00;
                    tx_data[4] <= 8'h00;
                    tx_data[5] <= 8'h00;
                    byte_idx    <= 0;
                    bit_in_byte <= 0;
                    clk_cnt     <= 0;
                    spi_sclk    <= 0;
                    spi_cs_n    <= 0;
                    is_read     <= 0;
                    next_state  <= S_WAIT_RST;   // FIX [1]
                    state       <= S_TRANSFER;
                end

                // ---- 50 ms wait after soft-reset ----------------
                S_WAIT_RST: begin
                    spi_cs_n <= 1;
                    wait_cnt <= wait_cnt + 1;
                    if (wait_cnt == RST_WAIT - 1) begin
                        wait_cnt <= 0;
                        state    <= S_POWER_ON;
                    end
                end

                // ---- Enable measurement mode (WRITE 0x2D = 0x02) -
                S_POWER_ON: begin
                    tx_data[0] <= CMD_WRITE;
                    tx_data[1] <= REG_POWER_CTL;
                    tx_data[2] <= 8'h02;         // Measure bit
                    tx_data[3] <= 8'h00;
                    tx_data[4] <= 8'h00;
                    tx_data[5] <= 8'h00;
                    byte_idx    <= 0;
                    bit_in_byte <= 0;
                    clk_cnt     <= 0;
                    spi_sclk    <= 0;
                    spi_cs_n    <= 0;
                    is_read     <= 0;
                    next_state  <= S_IDLE;        // FIX [1]
                    state       <= S_TRANSFER;
                end

                // ---- 1 ms idle between reads --------------------
                S_IDLE: begin
                    spi_cs_n <= 1;
                    wait_cnt <= wait_cnt + 1;
                    if (wait_cnt == IDLE_WAIT - 1) begin
                        wait_cnt <= 0;
                        state    <= S_START_READ;
                    end
                end

                // ---- Burst read: CMD_READ + REG_XDATA_L + 4 dummy
                S_START_READ: begin
                    tx_data[0] <= CMD_READ;
                    tx_data[1] <= REG_XDATA_L;
                    tx_data[2] <= 8'h00; // dummy → X_L
                    tx_data[3] <= 8'h00; // dummy → X_H
                    tx_data[4] <= 8'h00; // dummy → Y_L
                    tx_data[5] <= 8'h00; // dummy → Y_H
                    byte_idx    <= 0;
                    bit_in_byte <= 0;
                    clk_cnt     <= 0;
                    spi_sclk    <= 0;
                    spi_cs_n    <= 0;
                    is_read     <= 1;             // FIX [5]
                    next_state  <= S_PROCESS;
                    state       <= S_TRANSFER;
                end

                // ---- SPI Mode-0 transfer engine -----------------
                // CPOL=0 CPHA=0: MOSI driven on falling/first edge,
                //                MISO sampled on rising edge
                S_TRANSFER: begin
                    // Pre-load MOSI with MSB of first byte before
                    // any clock edges occur (FIX [3])
                    if (clk_cnt == 0 && byte_idx == 0 &&
                        bit_in_byte == 0 && spi_sclk == 0) begin
                        tx_byte  <= tx_data[0];
                        spi_mosi <= tx_data[0][7];
                    end

                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt  <= 0;
                        spi_sclk <= ~spi_sclk;

                        if (spi_sclk == 1'b0) begin
                            // ---- RISING edge: sample MISO -------
                            // FIX [4]: capture here, not on falling
                            rx_shift <= {rx_shift[6:0], spi_miso};

                            // Last bit of a data byte → save it
                            if (bit_in_byte == 3'd7 && byte_idx >= 2)
                                rx_buf[byte_idx - 2] <=
                                    {rx_shift[6:0], spi_miso};

                        end else begin
                            // ---- FALLING edge: drive MOSI --------
                            if (bit_in_byte == 3'd7) begin
                                // Finished this byte
                                if (byte_idx == TOTAL_BYTES - 1) begin
                                    // All bytes done
                                    spi_sclk <= 1'b0;
                                    spi_cs_n <= 1'b1;
                                    spi_mosi <= 1'b0;
                                    state    <= S_CS_HIGH;
                                end else begin
                                    // FIX [3]: load MSB of next byte
                                    // BEFORE incrementing byte_idx
                                    tx_byte     <= tx_data[byte_idx + 1];
                                    spi_mosi    <= tx_data[byte_idx + 1][7];
                                    byte_idx    <= byte_idx + 1;
                                    bit_in_byte <= 0;  // FIX [2]
                                end
                            end else begin
                                // FIX [2]: use bit_in_byte, not global
                                spi_mosi    <= tx_byte[6 - bit_in_byte];
                                bit_in_byte <= bit_in_byte + 1;
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                // ---- CS de-assert hold (~250 ns) ----------------
                S_CS_HIGH: begin
                    wait_cnt <= wait_cnt + 1;
                    if (wait_cnt == 24) begin  // 25 sys clocks = 250 ns
                        wait_cnt <= 0;
                        // FIX [1]: go to the right next state
                        state    <= next_state;
                    end
                end

                // ---- Assemble accel data & pulse data_valid -----
                S_PROCESS: begin
                    // 12-bit two's-complement: {upper-nibble of MSB, full LSB}
                    accel_x    <= {rx_buf[1][3:0], rx_buf[0]};
                    accel_y    <= {rx_buf[3][3:0], rx_buf[2]};
                    data_valid <= is_read;  // FIX [5]
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule