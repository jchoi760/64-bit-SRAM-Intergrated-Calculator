# 64-bit SRAM-Integrated Calculator

A complete RTL design and verification project implementing a 64-bit calculator system with dual SRAM integration, built in synthesizable SystemVerilog. The design performs 128 sequential 64-bit additions using a 32-bit ripple carry adder with carry propagation, controlled by a 7-state finite state machine.

## System Architecture

<img width="1421" height="481" alt="image" src="https://github.com/user-attachments/assets/062c5243-db0a-4189-b0e8-26ab23eed4ca" />


The calculator reads pairs of 64-bit operands from dual SRAMs (A for lower 32 bits, B for upper 32 bits), adds them in two passes through a 32-bit adder with carry propagation, and writes the 64-bit result back to SRAM.

### Key Specifications

| Parameter | Value |
|-----------|-------|
| Data Width | 32 bits (adder operand size) |
| Memory Word Size | 64 bits (SRAM read/write width) |
| Address Width | 10 bits (1024 locations) |
| Input Addresses | 0x000 - 0x0FF (0 - 255) |
| Output Addresses | 0x180 - 0x1FF (384 - 511) |
| Total Additions | 128 pairs |

## RTL Design

### Module Hierarchy

```
top_lvl
├── controller          7-state FSM managing read/add/write sequencing
├── adder32             32-bit ripple carry adder
│   └── full_adder[31:0]    32 chained 1-bit full adders
├── result_buffer       64-bit register written in two 32-bit halves
├── sram_A              CF_SRAM_1024x32 — lower 32 bits
└── sram_B              CF_SRAM_1024x32 — upper 32 bits
```

### FSM Controller

<img width="892" height="252" alt="image" src="https://github.com/user-attachments/assets/ee509fdb-ad36-44f8-9dad-ce845955504b" />


The controller uses a 7-state Moore FSM to orchestrate the addition pipeline:

| State | Action |
|-------|--------|
| `S_IDLE` | Initialize address pointers from configuration inputs |
| `S_READ` | Assert read enable, output first operand address |
| `S_READ2` | Latch first operand, output second operand address |
| `S_ADD` | Add lower 32 bits (no carry in), save carry out |
| `S_ADD2` | Add upper 32 bits with carry from lower addition |
| `S_WRITE` | Write 64-bit result to SRAM, loop or finish |
| `S_END` | All additions complete, hold until reset |

The lower-before-upper addition order is critical for correct carry propagation across the 32-bit boundary.

### Memory Map

```
Address Range       Content                 Description
─────────────────────────────────────────────────────────
0x000 - 0x0FF       Input Operands          256 x 64-bit numbers (128 pairs)
0x100 - 0x17F       Reserved                Unused
0x180 - 0x1FF       Output Results          128 x 64-bit sums
0x200 - 0x3FF       Unused                  Remainder of SRAM
```

### Two-Pass Addition

Since the adder is 32 bits wide but memory words are 64 bits, each addition requires two passes:

1. **S_ADD**: Lower 32 bits added with `carry_in = 0`, carry output saved to `carry_reg`
2. **S_ADD2**: Upper 32 bits added with `carry_in = carry_reg`

The result buffer stores each 32-bit result in the appropriate half (controlled by `buffer_control`), then the full 64-bit word is written to SRAM in `S_WRITE`.

## Verification

### Testbench Architecture

<img width="3492" height="1407" alt="image" src="https://github.com/user-attachments/assets/0a4d6f21-0619-4dd9-80d8-e562dd331a15" />


A class-based SystemVerilog testbench (non-UVM) with modular components:

| Component | File | Role |
|-----------|------|------|
| **Driver** | `calc_driver.svh` | Converts transactions to pin-level signals, manages reset and SRAM initialization |
| **Monitor** | `calc_monitor.svh` | Passively observes interface signals, handles SRAM read latency (1-cycle delay) |
| **Scoreboard** | `calc_sb.svh` | Golden reference model comparing DUT output against expected results |
| **Sequence Item** | `calc_seq_item.svh` | Transaction object with randomizable fields and address constraints |
| **Sequencer** | `calc_sequencer.svh` | Generates constrained random transaction sequences |
| **Interface** | `calc_if.sv` | Signal bundle with clocking block for synchronization |

### Verification Plan

The test plan covers four categories:

#### 1. Functional Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| Basic Addition | 1 + 2 | Lower=0x3, Upper=0x0 |
| Overflow | 0xFFFFFFFF + 1 | Lower=0x0, Upper=0x1 (carry propagated) |
| Multiple Additions | 2 consecutive pairs | 2 correct results |
| Carry Propagation | 0x80000000 + 0x80000000 | Lower=0x0, Upper=0x1 |

#### 2. Edge Case Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| 0 + 0 | Both operands zero | Lower=0x0, Upper=0x0 |
| MAX + MAX | 0xFFFFFFFFFFFFFFFF + 0xFFFFFFFFFFFFFFFF | Lower=0xFFFFFFFE, Upper=0xFFFFFFFF |
| 0 + MAX | Zero plus maximum | Lower=0xFFFFFFFF, Upper=0xFFFFFFFF |

#### 3. Constrained Random Verification

Random sequences generated with constraints matching the RTL memory map:

- Read addresses within input region (0x000 - 0x0FF)
- Write addresses within output region (0x180 - 0x1FF)
- Even number of reads (operand pairs)
- Write count = read count / 2

#### 4. SystemVerilog Assertions (SVA)

10 concurrent assertions verifying internal behavior:

| # | Property | Description |
|---|----------|-------------|
| 1 | `lsb_before_msb` | S_ADD always followed by S_ADD2 |
| 2 | `carry_propagation` | Carry out in S_ADD feeds carry in during S_ADD2 |
| 3 | `reset_to_idle` | Rising edge of reset transitions FSM to S_IDLE |
| 4 | `rd_wr_mutex` | Read and write enables never both asserted |
| 5 | `valid_state_transitions` | FSM only enters defined states |
| 6 | `end_state_stable` | S_END holds until reset |
| 7 | `write_only_in_write_state` | Write enable only during S_WRITE |
| 8 | `read_only_in_read_states` | Read enable only during S_READ/S_READ2 |
| 9 | `buffer_control_correct` | LOWER select in S_ADD, UPPER in S_ADD2 |
| 10 | `read_add_write_sequence` | S_READ2 -> S_ADD -> S_ADD2 -> S_WRITE sequence |

### Coverage

<img width="1109" height="620" alt="image" src="https://github.com/user-attachments/assets/c2b42c98-e830-444d-9790-445e34a6e2a8" />


Target: **98%+** across line, branch, FSM state, FSM transition, and toggle coverage for the DUT.

## Project Structure

```
├── rtl/                        RTL source files
│   ├── calculator_pkg.sv           Parameters, types, state definitions
│   ├── full_adder.sv               1-bit full adder
│   ├── adder32.sv                  32-bit ripple carry adder (32 chained full adders)
│   ├── result_buffer.sv            64-bit register with upper/lower half select
│   ├── controller.sv               7-state FSM controller
│   ├── top_lvl.sv                  Top-level integration
│   └── CF_SRAM_1024x32.*.v        SRAM macro model
│
├── tb/                         Testbench files
│   ├── calc_tb_top.sv              Top-level testbench (tests + assertions)
│   ├── calc_tb_pkg.sv              Testbench package
│   ├── calc_if.sv                  Interface with clocking block
│   ├── calc_driver.svh             Driver component
│   ├── calc_monitor.svh            Monitor component
│   ├── calc_sb.svh                 Scoreboard with golden model
│   ├── calc_seq_item.svh           Sequence item with constraints
│   └── calc_sequencer.svh          Random sequence generator
│
├── sim/                        Simulation environment
│   ├── Makefile                    Build targets (xrun, coverage, etc.)
│   ├── link_files.py               Symbolic link generator
│   ├── include/                    Source file lists
│   └── WORKSPACE/                  Simulation outputs and logs
│
├── scripts/                    Utility scripts
│   ├── init_mem.py                 Test memory generation
│   └── check.py                    Result verification
│
└── docs/                       Documentation and diagrams
    ├── system_architecture.png     RTL block diagram
    ├── fsm_diagram.png             Controller state diagram
    ├── testbench_architecture.png  TB component diagram
    └── coverage_report.png         IMC coverage screenshot
```

## Tools

- **Cadence Xcelium** -- SystemVerilog compilation and simulation
- **Synopsys VCS** -- Alternative simulator (VCS-compatible testbench included)
- **Cadence IMC** -- Code coverage analysis and reporting
- **Cadence SimVision / Synopsys DVE** -- Waveform viewing and debug
