#!/usr/bin/env python3
"""
bin2hex.py  —  Convert a raw binary file to Verilog $readmemh hex format.

Usage:
    bin2hex.py <input.bin> <output.hex> [--base-addr BYTE_ADDR]

Each output line is one 32-bit word in little-endian byte order.
An @address marker (word address) is written at the start so the file
can be loaded at a non-zero offset with $readmemh.

Examples:
    bin2hex.py hello.text.bin hello.text.hex
    bin2hex.py hello.data.bin hello.data.hex --base-addr 0x200
"""

import sys
import struct
import argparse


def bin2hex(src: str, dst: str, base_byte_addr: int = 0) -> None:
    with open(src, "rb") as f:
        data = f.read()

    if len(data) == 0:
        # Nothing to write; create an empty file so Make targets don't fail.
        open(dst, "w").close()
        return

    # Pad to 4-byte boundary
    pad = (4 - len(data) % 4) % 4
    data += b"\x00" * pad

    words = struct.unpack_from(f"<{len(data) // 4}I", data)

    # $readmemh uses word (not byte) addresses in the @ marker
    base_word_addr = base_byte_addr >> 2

    with open(dst, "w") as f:
        f.write(f"@{base_word_addr:08x}\n")
        for w in words:
            f.write(f"{w:08x}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input",  help="Input raw binary file")
    parser.add_argument("output", help="Output hex file")
    parser.add_argument(
        "--base-addr",
        default="0x0",
        help="Byte address where this section starts in memory (default 0x0)",
    )
    args = parser.parse_args()
    base = int(args.base_addr, 0)
    bin2hex(args.input, args.output, base)
    print(f"  {args.input} → {args.output}  (base=0x{base:08x}, "
          f"{len(open(args.input,'rb').read())} bytes)")


if __name__ == "__main__":
    main()
