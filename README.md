# FSM Combination Lock

A digital security system implemented on FPGA hardware, featuring a dual-module architecture for secure keypad entry, asynchronous communication, and electromechanical signal processing.

This project implements a hotel-style safe mechanism split across two distinct hardware modules: a Keyboard Controller handling input scanning and debouncing, and a Combination Lock (Combo) managing security state and user feedback. The system demonstrates advanced digital design concepts including Clock Domain Crossing (CDC), Moore/Mealy FSMs, and custom GPIO protocols.

## Overview
The core objective was to design a secure, re-programmable lock system that mimics real-world embedded security devices. The project evolved in two phases:
1. **Part 1 (Core Logic):** A 10-bit binary lock using switches, implementing a manually optimized Moore FSM for state control.
2. **Part 2 (Integration):** A 6-digit PIN system using a 4x4 matrix keypad, requiring a distributed architecture where the input controller and lock logic run on separate hardware instances, communicating via a custom protocol.

## Features
- **Dual-Module Distributed Design:** Decouples input processing from security logic to simulate real-world peripheral integration.
- **Clock Domain Crossing (CDC):** Synchronization logic (2-stage flip-flop synchronizers) to prevent metastability when passing signals between independent FPGA clocks.
- **Dynamic Password Management:**
  - **Runtime Configuration:** Users can set a custom password sequence in the "OPEN" state.
  - **Feedback System:** 7-segment displays provide visual status updates (`_OPEn_`, `LOCHED`) and real-time input masking.
- **Security Logic:**
  - **Hardware Interlocks:** Prevents state transitions during unstable signal periods.
  - **Unlock Hints:** LED indicators display the bitwise difference (Hamming distance) between the attempted entry and the stored password for debugging purposes.

## Architecture

The system is designed as a distributed embedded system where the **Keyboard** acts as a peripheral transmitter and the **Combo** acts as the central processing unit.

**Communication Protocol** <br>
To facilitate communication between the independent modules, a custom 5-wire GPIO protocol was implemented:
- **Data Bus (`key_code[3:0]`):** Carries the 4-bit hexadecimal representation of the pressed key.
- **Control Line (`key_validn`):** An active-low validation signal. To ensure data integrity across asynchronous clock domains, the transmitter holds data stable for at least 3 clock cycles while asserting valid, allowing the receiver's double-flop synchronizer to capture the signal safely.

## Hardware Implementation

### Part 1: The Safe

The core logic is driven by a Finite State Machine (FSM) that governs the `LOCKED` and `OPEN` states.

- **Manual Gate Design:** Initially implemented using raw logic equations derived from Karnaugh maps to optimize gate usage.
- **RTL Synthesis:** Migrated to high-level behavioral SystemVerilog using `enum` states (`OPEN`, `OPENING`, `LOCKED`, `LOCKING`) for scalability and readability.
- Logic:
  - **Comparison:** Continuous 10-bit parallel comparison between `ATTEMPT` and `PASSWORD` registers.
  - **Control:** Dedicated `savePW` and `saveAT` control signals manage register enables based on current state.

### Part 2: The Keypad Interface

The keypad interface transforms raw matrix scans into clean digital events.

- **Scanning FSM:** A specialized FSM (`keyboard_fsm`) drives the keypad rows (`ROW_ONE` to `ROW_FOUR`) in a round-robin sequence.
- **Scanning Timer:** To accommodate the physical properties of the switch contacts, the FSM pauses on each row for ~4ms (`SCAN_DELAY = 200000` cycles).
- **Decoding:** A combinatorial decoder maps the active-low `{row, col}` coordinates to 4-bit hex values (`0-9`, `A-F`).
- **Shift Register:** A visual history buffer displays the last 6 key presses on the FPGA's hex display for user verification.


## Technical Challenges & Solutions

| Challenge         | Solution                                     |
| :---              | :---                                        |
| Mechanical Bounce | Physical switches vibrate when pressed. Implemented a `kb_db` module with a saturating counter that waits for 16-bit timer overflow (~1.3ms) before validating a signal. |
| Metastability     | Asynchronous inputs from the keypad and other FPGAs can violate setup/hold times. Used 2-stage synchronizers (`key_validn_sync1`, `key_validn_sync2`) on all ingress signals. |
| Clock Drift       | Two FPGAs operating at "50MHz" will strictly never be perfectly in phase. The protocol requires the transmitter to hold data stable for >3 cycles to guarantee the receiver captures it regardless of phase offset. |

## Repository Structure
```
├── Part 1/
│   ├── fsm_gates_safe.sv    # Manual gate-level FSM implementation
│   └── fsm_synth_safe.sv    # Behavioral SystemVerilog FSM implementation
├── Part 2/
│   ├── combo.sv             # Receiver module (Safe Logic & Display)
│   └── keyboard.sv          # Transmitter module (Scanner & Debouncer)
└── README.md                # Project Documentation
```

## Getting Started

**Prerequisites** <br>
- Hardware: Terasic DE10-Lite (MAX 10 FPGA).
- Peripherals: 4x4 Matrix Keypad, GPIO ribbon cables.
- Software: Intel Quartus Prime Lite Edition.

**Installation & Usage** <br>

1. **Clone the repository:** <br>
```
git clone https://github.com/arvinsaghafi/FSM-Combination-Lock.git
```
**Part 1 Setup:**

- Open Part 1 in Quartus.
- Assign pins for `SW[9:0]` (Input) and `HEX[0:5]` (Output).
- Compile and upload to a single DE10-Lite board.

**Part 2 Setup:**
- Board A (Keyboard): Connect Keypad to GPIO pins as defined in `keyboard.sv.` Upload keyboard.sof.
- Board B (Combo): Connect Board A's GPIO output to Board B's GPIO input. Upload `combo.sof`.
- Operation: Enter a 6-digit code on the keypad. Press `#` to Lock/Unlock. Press `*` to clear.
