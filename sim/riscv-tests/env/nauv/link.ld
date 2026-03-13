/*
 * Linker script for riscv-tests on NauV (Harvard, RV32I)
 *
 * Memory layout:
 *   0x0000  .text.init   — RVTEST_CODE_BEGIN / _start
 *   ...     .text        — test body
 *   ...     .rodata      — constants (typically empty for RV32UI tests)
 *   0x2000  .data / .bss — test data arrays (if any)
 *
 * tohost is NOT placed via a linker symbol.  RVTEST_PASS and RVTEST_FAIL
 * write to 0x1000 with an absolute address loaded by li+sw.  That store
 * hits dmem (data memory), which the tb_prog monitor watches.  The code
 * at 0x0–0x0FFF in imem and the dmem write at 0x1000 are physically
 * separate — no collision on a Harvard machine.
 *
 * Stack top is 0x4000 (top of dmem), initialised by RVTEST_CODE_BEGIN.
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    . = 0x00000000;

    .text.init : { *(.text.init) }
    .text      : { *(.text*)    }
    .rodata    : { *(.rodata*)  }

    . = 0x00002000;

    .data : { *(.data*) }
    .bss  : { *(.bss*)  *(COMMON) }

    _stack_top = 0x00004000;
}
