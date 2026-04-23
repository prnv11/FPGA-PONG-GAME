# FPGA Breakout Game — Nexys A7

An accelerometer-controlled breakout-style game implemented in Verilog on the **Digilent Nexys A7** FPGA board. Tilt the board to move the paddle, bounce the ball, and survive as long as you can.

---

## Hardware
- **Board:** Digilent Nexys A7 (Artix-7)
- **Display:** VGA monitor (640×480 @ 60 Hz)
- **Tools:** Xilinx Vivado 2022.2+

---

## Features
- **Tilt control** — Paddle moves via real-time SPI reads from the on-board ADXL362 accelerometer
- **VGA rendering** — Live 640×480 display with ball, paddle, border, score text, and Game Over screen
- **7-segment score** — Live score shown on the board's 4-digit display
- **Progressive difficulty** — Every 5 points the ball speeds up and the paddle shrinks
- **One-button restart** — Press centre button (btnC) after game over

---

## Project Structure
```
project_11/
├── project_11.srcs/
│   ├── sources_1/new/
│   │   ├── top.v              # Game FSM — core logic, physics, state machine
│   │   ├── a.v                # 7-segment score display driver
│   │   ├── b.v                # VGA controller & pixel renderer
│   │   └── c.v                # SPI driver for ADXL362 accelerometer
│   ├── sources_1/ip/
│   │   └── clk_wiz_0/         # Clock Wizard IP (100 MHz → 25 MHz for VGA)
│   ├── sim_1/new/
│   │   └── tb_top.v           # Behavioural testbench
│   └── constrs_1/new/
│       └── vga_game.xdc       # Pin constraints for Nexys A7
└── project_11.runs/
    └── impl_1/
        └── top.bit            # ✅ Ready-to-program bitstream
```

---

## How to Run

### Option A — Flash the prebuilt bitstream
1. Open **Vivado Hardware Manager**
2. Connect the Nexys A7 via USB
3. Program the device with `project_11.runs/impl_1/top.bit`

### Option B — Build from source
```bash
vivado project_11/project_11.xpr
```
Then in Vivado: **Run Synthesis → Run Implementation → Generate Bitstream → Program Device**

---

## How to Play

| Action | Control |
|---|---|
| Move paddle left / right | Tilt the board |
| Restart after Game Over | Press **btnC** (centre button) |

- Each successful bounce scores **+1 point**
- Every **5 points**: ball gets faster, paddle gets smaller (minimum width: 30 px)
- Miss the ball → **Game Over**

---

## Architecture

```
CLK100MHZ ──► clk_wiz_0 ──► 25 MHz ──► vga_controller
                  │
                  └──► 100 MHz ──► game_fsm ──────► vga_controller
                                       ▲                 ▲
                                  spi_adxl362       seg7_display
```

| Module | File | Description |
|---|---|---|
| `game_fsm` | `top.v` | 6-state FSM: INIT → PLAY → SCORE → MISS → GAMEOVER → RESTART |
| `vga_controller` | `b.v` | VGA sync generation, object rendering, pixel-font text overlay |
| `spi_adxl362` | `c.v` | SPI master for ADXL362 — init, continuous X/Y reads, 12-bit output |
| `seg7_display` | `a.v` | Multiplexed 4-digit BCD score display |

---
