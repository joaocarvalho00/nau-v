// Minimal bare-metal startup for Claude-V (RV32I)
// Execution entry point.  Sets up the stack, zeroes .bss, then calls main.
// The core resets with PC=0, so _start must be linked first.

    .section .text.start, "ax"
    .global  _start
    .type    _start, @function

_start:
    // -------------------------------------------------------
    // 1. Set stack pointer to top of data memory (16 KB)
    // -------------------------------------------------------
    li   sp, 0x4000

    // -------------------------------------------------------
    // 2. Zero the .bss section
    // -------------------------------------------------------
    la   t0, _bss_start
    la   t1, _bss_end
.Lbss_loop:
    bgeu t0, t1, .Lbss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    .Lbss_loop
.Lbss_done:

    // -------------------------------------------------------
    // 3. Call main
    // -------------------------------------------------------
    call main

    // -------------------------------------------------------
    // 4. Spin forever after main returns
    // -------------------------------------------------------
_halt:
    j    _halt

    .size _start, . - _start
