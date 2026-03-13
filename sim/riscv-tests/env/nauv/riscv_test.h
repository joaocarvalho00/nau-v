// riscv_test.h — NauV test environment for riscv-tests
//
// Differences from the standard "p" environment:
//  - No privilege modes, CSRs, or exception/trap handling.
//  - Harvard architecture: instruction and data spaces are separate physical
//    memories sharing the same virtual address range.
//  - tohost is at a fixed address (0x1000) rather than a linker symbol,
//    matching the tohost monitor in tb_prog.sv.
//  - RVTEST_PASS/FAIL write directly to 0x1000 via an absolute li+sw.

#ifndef _ENV_NAUV_H
#define _ENV_NAUV_H

// Used by test_macros.h as the test-number register.
#define TESTNUM gp

// Required by test_macros.h to select the RV32U instruction set.
#define RVTEST_RV32U

// ---------------------------------------------------------------------------
// Code prologue: place code in .text.init so the linker puts it first.
// Initialise the stack pointer and the test-number register.
// ---------------------------------------------------------------------------
#define RVTEST_CODE_BEGIN        \
    .section .text.init;         \
    .align 2;                    \
    .globl _start;               \
_start:                          \
    li   sp, 0x4000;             \
    li   TESTNUM, 1;

// No special code epilogue needed.
#define RVTEST_CODE_END

// ---------------------------------------------------------------------------
// PASS: write 1 to tohost (0x1000) then spin.
// ---------------------------------------------------------------------------
#define RVTEST_PASS              \
    fence;                       \
    li   a0, 1;                  \
    li   t5, 0x1000;             \
    sw   a0, 0(t5);              \
97: j    97b;

// ---------------------------------------------------------------------------
// FAIL: encode the failing test number as (TESTNUM<<1)|1 and write to tohost.
// If TESTNUM is somehow 0, spin without writing (avoids a false PASS).
// ---------------------------------------------------------------------------
#define RVTEST_FAIL              \
    fence;                       \
    beqz TESTNUM, 98f;           \
    sll  TESTNUM, TESTNUM, 1;    \
    ori  TESTNUM, TESTNUM, 1;    \
    li   t5, 0x1000;             \
    sw   TESTNUM, 0(t5);         \
98: j    98b;

// ---------------------------------------------------------------------------
// Data section markers (test data placed in .data; no tohost linker symbol
// needed since RVTEST_PASS/FAIL use hardcoded addresses).
// ---------------------------------------------------------------------------
#define RVTEST_DATA_BEGIN .data
#define RVTEST_DATA_END

#endif /* _ENV_NAUV_H */
