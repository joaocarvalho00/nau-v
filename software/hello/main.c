/*
 * hello/main.c — first bare-metal C program for Claude-V
 *
 * Runs a few arithmetic checks and reports pass/fail by writing to
 * the "tohost" address (0x1000 in data memory).  The tb_prog testbench
 * monitors this address:
 *
 *   *tohost == 1  → PASS
 *   *tohost != 1  → FAIL (value encodes which test failed)
 *
 * Uses only stack-allocated variables (no initialised globals) because
 * the Harvard architecture cannot copy .data from imem to dmem at startup.
 */

#define TOHOST_ADDR 0x1000

static inline void write_tohost(int val)
{
    volatile int *tohost = (volatile int *)TOHOST_ADDR;
    *tohost = val;
}

/* Integer square root: largest k where k*k <= n.
   Uses the identity k^2 = sum of first k odd numbers.
   No multiplication required (safe for RV32I without M extension). */
static int isqrt(int n)
{
    int k = 0, sum = 0, odd = 1;
    while (sum + odd <= n) {
        sum += odd;
        odd += 2;
        k++;
    }
    return k;
}

int main(void)
{
    /* Test 1: basic addition */
    if (3 + 4 != 7) { write_tohost(2); return 1; }

    /* Test 2: subtraction */
    if (100 - 58 != 42) { write_tohost(3); return 1; }

    /* Test 3: multiplication (compiler expands to shifts/adds for RV32I) */
    if (6 * 7 != 42) { write_tohost(4); return 1; }

    /* Test 4: bitwise ops */
    if ((0xF0 & 0xFF) != 0xF0) { write_tohost(5); return 1; }
    if ((0xF0 | 0x0F) != 0xFF) { write_tohost(6); return 1; }
    if ((0xFF ^ 0x0F) != 0xF0) { write_tohost(7); return 1; }

    /* Test 5: shifts */
    if ((1 << 4) != 16)  { write_tohost(8); return 1; }
    if ((128 >> 3) != 16) { write_tohost(9); return 1; }

    /* Test 6: signed comparison */
    int a = -5, b = 3;
    if (!(a < b))  { write_tohost(10); return 1; }
    if (!(b > a))  { write_tohost(11); return 1; }

    /* Test 7: loop + accumulator */
    int sum = 0;
    for (int i = 1; i <= 10; i++) sum += i;
    if (sum != 55) { write_tohost(12); return 1; }

    /* Test 8: function call (isqrt) */
    if (isqrt(144) != 12) { write_tohost(13); return 1; }

    /* All tests passed */
    write_tohost(1);
    return 0;
}
