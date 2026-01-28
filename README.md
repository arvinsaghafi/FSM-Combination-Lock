# FPGA Combination Lock System

A robust, digital security system implemented on FPGA hardware, featuring a dual-module architecture for secure keypad entry and state management.

This project implements a digital combination lock system using SystemVerilog on an FPGA development board. The system mimics a hotel safe, allowing users to lock and unlock a secure mechanism using a programmable 10-bit password (Lab 5) or a 6-digit keypad PIN (Lab 6).

The architecture is split into two distinct hardware modules keyboard and combo, which communicate via a custom GPIO protocol. This design challenges traditional single-module approaches by introducing complexity related to CDC (Clock Domain Crossing), signal synchronization, and electromechanical switch debouncing.

## Features
- **Dual-Board/Module Architecture:** Decoupled input processing (Keyboard) from state management (Safe) to simulate real-world security peripherals.
- **Input Debouncing:** Custom kb_db module handles metastability and mechanical bounce from the 4x4 matrix keypad, ensuring clean signal registration.
- **Secure FSM Design:** Moore Machine finite state automata control the locking logic, featuring dedicated states for OPEN, LOCKED, and intermediate transition processing.
- **Dynamic Password Storage:** Users can set a custom combination (store SW to PASSWORD) at runtime.
- **Hardware User Interface:**
  - **7-Segment Display:** Visual feedback for "OPEN" (`_OPEn_`) and "LOCKED" (`LOCHED`) states.
  - **LED Indicators:** Real-time debugging of FSM states and "Hint" logic (showing bit-difference between attempt and password).
 
  ## Repository Structure

  ## Technical Architecture
