/*
 * Linker script for Claude-V bare-metal (Harvard, RV32I)
 *
 * Memory map (virtual addresses = physical addresses within each memory):
 *
 *   0x0000_0000  +------------------+
 *                |  .text           |  → imem (instruction fetches via PC)
 *                |  .rodata         |
 *                +------------------+  ← _text_end
 *                |  .data           |  → dmem (load/store data space, same
 *                |  .bss            |    virtual address, separate physical
 *                +------------------+    memory in the core)
 *   0x0000_4000  |  stack top       |
 *                |  (grows down)    |
 *
 * Both memories are 16 KB (4096 × 32-bit words), base address 0x0.
 * The CPU uses separate buses for instruction fetch and data access, so
 * .text and .data may share the same virtual address range without conflict.
 *
 * NOTE: initialised .data is NOT copied from ROM to RAM at start-up
 * because the CPU cannot issue load instructions to imem (Harvard arch).
 * Use only zero-initialised globals (.bss) or stack-allocated variables.
 * Initialised globals will be silently wrong — you will get a linker warning
 * if .data is non-empty.
 */

MEMORY
{
    MEM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

ENTRY(_start)

SECTIONS
{
    /* ------------------------------------------------------------------ */
    /* .text — code and read-only data                                     */
    /* ------------------------------------------------------------------ */
    .text 0x00000000 :
    {
        KEEP(*(.text.start))   /* startup code first so PC=0 hits _start */
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
        _text_end = .;
    } > MEM

    /* ------------------------------------------------------------------ */
    /* .data — initialised globals (should be empty; see note above)       */
    /* ------------------------------------------------------------------ */
    .data :
    {
        _data_start = .;
        *(.data*)
        . = ALIGN(4);
        _data_end = .;
    } > MEM

    /* ------------------------------------------------------------------ */
    /* .bss — zero-initialised globals; zeroed by startup.S               */
    /* ------------------------------------------------------------------ */
    .bss :
    {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > MEM

    /* Stack lives at top of dmem; pointer set in startup.S */
    _stack_top = 0x00004000;
}
