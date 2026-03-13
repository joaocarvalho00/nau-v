// dhrystone.h — NauV bare-metal adaptation of Dhrystone C 2.2
// Clock/OS dependencies removed; tohost signalling added.

#ifndef _DHRYSTONE_H
#define _DHRYSTONE_H

#define Version "C, Version 2.2 (NauV bare-metal)"

// Number of benchmark iterations; override at build time: -DNUMBER_OF_RUNS=N
#ifndef NUMBER_OF_RUNS
#define NUMBER_OF_RUNS 1000
#endif

// NauV tohost address: write 1 here to signal PASS to tb_prog.
// Must be outside the .bss region (0x0628–0x2E60) to avoid the startup
// .bss-zeroing loop triggering a spurious tohost write before main runs.
// 0x3000 sits above .bss_end and well below the stack (grows down from 0x4000).
#define TOHOST_ADDR 0x3000

// String function declarations (implemented in syscalls.c)
char *strcpy(char *dest, const char *src);
int   strcmp(const char *s1, const char *s2);

#define Null  0
#define true  1
#define false 0

// REG: empty by default (no register storage class)
#define REG

typedef int     Boolean;
typedef int     One_Thirty;
typedef int     One_Fifty;
typedef char    Capital_Letter;
typedef char    Str_30[31];
typedef int     Arr_1_Dim[50];
typedef int     Arr_2_Dim[50][50];

typedef enum { Ident_1, Ident_2, Ident_3, Ident_4, Ident_5 } Enumeration;

typedef struct record {
    struct record *Ptr_Comp;
    Enumeration    Discr;
    union {
        struct {
            Enumeration Enum_Comp;
            int         Int_Comp;
            char        Str_Comp[31];
        } var_1;
        struct {
            Enumeration E_Comp_2;
            char        Str_2_Comp[31];
        } var_2;
        struct {
            char Ch_1_Comp;
            char Ch_2_Comp;
        } var_3;
    } variant;
} Rec_Type, *Rec_Pointer;

#define structassign(d, s) ((d) = (s))

#endif // _DHRYSTONE_H
