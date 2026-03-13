// dhrystone_main.c — NauV bare-metal Dhrystone harness
//
// Adapted from Dhrystone C 2.2 for the NauV RV32I core:
//   - alloca() replaced with statically allocated globals
//   - printf/debug output removed (no libc in baremetal)
//   - Timing loop removed; cycle count is captured by tb_prog externally
//   - Writes 1 to TOHOST_ADDR on completion to signal PASS
//
// Compile with -DNUMBER_OF_RUNS=N to set iteration count.

#pragma GCC optimize ("no-inline")

#include "dhrystone.h"

// Forward declarations
void Proc_1(REG Rec_Pointer Ptr_Val_Par);
void Proc_2(One_Fifty *Int_Par_Ref);
void Proc_3(Rec_Pointer *Ptr_Ref_Par);
void Proc_4(void);
void Proc_5(void);
void Proc_6(Enumeration Enum_Val_Par, Enumeration *Enum_Ref_Par);
void Proc_7(One_Fifty Int_1_Par_Val, One_Fifty Int_2_Par_Val, One_Fifty *Int_Par_Ref);
void Proc_8(Arr_1_Dim Arr_1_Par_Ref, Arr_2_Dim Arr_2_Par_Ref, int Int_1_Par_Val, int Int_2_Par_Val);
Enumeration Func_1(Capital_Letter Ch_1_Par_Val, Capital_Letter Ch_2_Par_Val);
Boolean Func_2(Str_30 Str_1_Par_Ref, Str_30 Str_2_Par_Ref);

// Global variables (use static allocation instead of alloca)
static Rec_Type  Rec_Glob_0;
static Rec_Type  Rec_Glob_1;

Rec_Pointer     Ptr_Glob      = &Rec_Glob_0;
Rec_Pointer     Next_Ptr_Glob = &Rec_Glob_1;

int             Int_Glob;
Boolean         Bool_Glob;
char            Ch_1_Glob;
char            Ch_2_Glob;
int             Arr_1_Glob[50];
int             Arr_2_Glob[50][50];

// String constants for the benchmark.
//
// These MUST live in .data (dmem), not .rodata (imem), because the NauV
// Harvard architecture cannot read instruction memory via load instructions.
// The __attribute__((section(".data"))) guarantees placement in .data so the
// strings are included in dhrystone.data.hex and loaded into dmem at runtime.
static char __attribute__((section(".data"))) dhry_str_some[] = "DHRYSTONE PROGRAM, SOME STRING";
static char __attribute__((section(".data"))) dhry_str_1st[]  = "DHRYSTONE PROGRAM, 1'ST STRING";
static char __attribute__((section(".data"))) dhry_str_2nd[]  = "DHRYSTONE PROGRAM, 2'ND STRING";
static char __attribute__((section(".data"))) dhry_str_3rd[]  = "DHRYSTONE PROGRAM, 3'RD STRING";

int main(void)
{
    One_Fifty   Int_1_Loc;
    One_Fifty   Int_2_Loc;
    One_Fifty   Int_3_Loc;
    char        Ch_Index;
    Enumeration Enum_Loc;
    Str_30      Str_1_Loc;
    Str_30      Str_2_Loc;
    int         Run_Index;
    int         Number_Of_Runs = NUMBER_OF_RUNS;

    // Initialise record fields
    Ptr_Glob->Ptr_Comp                    = Next_Ptr_Glob;
    Ptr_Glob->Discr                       = Ident_1;
    Ptr_Glob->variant.var_1.Enum_Comp     = Ident_3;
    Ptr_Glob->variant.var_1.Int_Comp      = 40;
    strcpy(Ptr_Glob->variant.var_1.Str_Comp, dhry_str_some);
    strcpy(Str_1_Loc, dhry_str_1st);
    Arr_2_Glob[8][7] = 10;

    // -----------------------------------------------------------------------
    // Main benchmark loop
    // -----------------------------------------------------------------------
    for (Run_Index = 1; Run_Index <= Number_Of_Runs; ++Run_Index) {

        Proc_5();
        Proc_4();
        Int_1_Loc = 2;
        Int_2_Loc = 3;
        strcpy(Str_2_Loc, dhry_str_2nd);
        Enum_Loc  = Ident_2;
        Bool_Glob = !Func_2(Str_1_Loc, Str_2_Loc);

        while (Int_1_Loc < Int_2_Loc) {
            Int_3_Loc = 5 * Int_1_Loc - Int_2_Loc;
            Proc_7(Int_1_Loc, Int_2_Loc, &Int_3_Loc);
            Int_1_Loc += 1;
        }

        Proc_8(Arr_1_Glob, Arr_2_Glob, Int_1_Loc, Int_3_Loc);
        Proc_1(Ptr_Glob);

        for (Ch_Index = 'A'; Ch_Index <= Ch_2_Glob; ++Ch_Index) {
            if (Enum_Loc == Func_1(Ch_Index, 'C')) {
                Proc_6(Ident_1, &Enum_Loc);
                strcpy(Str_2_Loc, dhry_str_3rd);
                Int_2_Loc = Run_Index;
                Int_Glob  = Run_Index;
            }
        }

        Int_2_Loc = Int_2_Loc * Int_1_Loc;
        Int_1_Loc = Int_2_Loc / Int_3_Loc;
        Int_2_Loc = 7 * (Int_2_Loc - Int_3_Loc) - Int_1_Loc;
        Proc_2(&Int_1_Loc);

    } // for Run_Index

    // -----------------------------------------------------------------------
    // Signal PASS to tb_prog via tohost write
    // -----------------------------------------------------------------------
    *((volatile int *)TOHOST_ADDR) = 1;

    while (1) {} // spin (tb_prog will terminate the simulation)
    return 0;
}


void Proc_1(REG Rec_Pointer Ptr_Val_Par)
{
    REG Rec_Pointer Next_Record = Ptr_Val_Par->Ptr_Comp;

    structassign(*Ptr_Val_Par->Ptr_Comp, *Ptr_Glob);
    Ptr_Val_Par->variant.var_1.Int_Comp = 5;
    Next_Record->variant.var_1.Int_Comp = Ptr_Val_Par->variant.var_1.Int_Comp;
    Next_Record->Ptr_Comp = Ptr_Val_Par->Ptr_Comp;
    Proc_3(&Next_Record->Ptr_Comp);

    if (Next_Record->Discr == Ident_1) {
        Next_Record->variant.var_1.Int_Comp = 6;
        Proc_6(Ptr_Val_Par->variant.var_1.Enum_Comp,
               &Next_Record->variant.var_1.Enum_Comp);
        Next_Record->Ptr_Comp = Ptr_Glob->Ptr_Comp;
        Proc_7(Next_Record->variant.var_1.Int_Comp, 10,
               &Next_Record->variant.var_1.Int_Comp);
    } else {
        structassign(*Ptr_Val_Par, *Ptr_Val_Par->Ptr_Comp);
    }
}


void Proc_2(One_Fifty *Int_Par_Ref)
{
    One_Fifty   Int_Loc;
    Enumeration Enum_Loc;

    Int_Loc = *Int_Par_Ref + 10;
    do {
        if (Ch_1_Glob == 'A') {
            Int_Loc    -= 1;
            *Int_Par_Ref = Int_Loc - Int_Glob;
            Enum_Loc   = Ident_1;
        }
    } while (Enum_Loc != Ident_1);
}


void Proc_3(Rec_Pointer *Ptr_Ref_Par)
{
    if (Ptr_Glob != Null)
        *Ptr_Ref_Par = Ptr_Glob->Ptr_Comp;
    Proc_7(10, Int_Glob, &Ptr_Glob->variant.var_1.Int_Comp);
}


void Proc_4(void)
{
    Boolean Bool_Loc = (Ch_1_Glob == 'A');
    Bool_Glob = Bool_Loc | Bool_Glob;
    Ch_2_Glob = 'B';
}


void Proc_5(void)
{
    Ch_1_Glob = 'A';
    Bool_Glob = false;
}
