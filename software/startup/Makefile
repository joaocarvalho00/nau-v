# =============================================================================
# software/startup/Makefile
#
# Shared build rules included by each program's Makefile.
#
# Expected variables (set by the including Makefile):
#   NAME   — output binary name (e.g. hello)
#   SRCS   — C source files relative to the program directory
#   PROG_DIR — absolute path of the calling Makefile's directory
#
# Targets produced in $(PROG_DIR):
#   $(NAME).elf        — linked ELF
#   $(NAME).text.hex   — imem hex (Verilog $readmemh)
#   $(NAME).data.hex   — dmem hex (empty when no .data section)
#   $(NAME).dump       — disassembly (for debugging)
# =============================================================================

STARTUP_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

PREFIX   := riscv64-unknown-elf
CC       := $(PREFIX)-gcc
AS       := $(PREFIX)-as
LD       := $(PREFIX)-ld
OBJCOPY  := $(PREFIX)-objcopy
OBJDUMP  := $(PREFIX)-objdump
NM       := $(PREFIX)-nm
PYTHON   := python3

ARCH_FLAGS := -march=rv32i -mabi=ilp32

CFLAGS  := $(ARCH_FLAGS) \
           -O1 -g \
           -nostdlib -ffreestanding -fno-pic \
           -Wall -Wextra \
           -I$(STARTUP_DIR)

LDFLAGS := -T $(STARTUP_DIR)/link.ld \
           -nostdlib \
           -static

# ---------------------------------------------------------------------------
# Startup object (built once, shared across programs)
# ---------------------------------------------------------------------------
STARTUP_OBJ := $(STARTUP_DIR)/startup.o

$(STARTUP_OBJ): $(STARTUP_DIR)/startup.S
	$(CC) $(ARCH_FLAGS) -c $< -o $@

# ---------------------------------------------------------------------------
# Program objects
# ---------------------------------------------------------------------------
OBJS := $(addprefix $(PROG_DIR)/, $(SRCS:.c=.o))

$(PROG_DIR)/%.o: $(PROG_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# ---------------------------------------------------------------------------
# Link
# ---------------------------------------------------------------------------
$(PROG_DIR)/$(NAME).elf: $(STARTUP_OBJ) $(OBJS)
	$(CC) $(ARCH_FLAGS) $(LDFLAGS) $^ -o $@
	@echo "  Sections:"
	@$(OBJDUMP) -h $@ | grep -E "\.text|\.data|\.bss|\.rodata"

# ---------------------------------------------------------------------------
# Binary extraction
# ---------------------------------------------------------------------------
$(PROG_DIR)/$(NAME).text.bin: $(PROG_DIR)/$(NAME).elf
	$(OBJCOPY) -O binary \
	    --only-section=.text \
	    --only-section=.rodata \
	    $< $@

# .data extraction — grabs the byte address of .data section for the @marker
$(PROG_DIR)/$(NAME).data.bin: $(PROG_DIR)/$(NAME).elf
	@data_addr=$$($(OBJDUMP) -h $< | awk '/\.data/ {print "0x"$$4; exit}'); \
	 if [ -z "$$data_addr" ] || [ "$$data_addr" = "0x" ]; then \
	   touch $@; \
	 else \
	   $(OBJCOPY) -O binary --only-section=.data $< $@ 2>/dev/null || touch $@; \
	 fi

# ---------------------------------------------------------------------------
# Hex generation
# ---------------------------------------------------------------------------
$(PROG_DIR)/$(NAME).text.hex: $(PROG_DIR)/$(NAME).text.bin
	$(PYTHON) $(STARTUP_DIR)/bin2hex.py $< $@

$(PROG_DIR)/$(NAME).data.hex: $(PROG_DIR)/$(NAME).data.bin $(PROG_DIR)/$(NAME).elf
	@data_addr=$$($(OBJDUMP) -h $(PROG_DIR)/$(NAME).elf \
	    | awk '/\.data/ {print "0x"$$4; exit}'); \
	 base=$${data_addr:-0x0}; \
	 $(PYTHON) $(STARTUP_DIR)/bin2hex.py $< $@ --base-addr $$base

# ---------------------------------------------------------------------------
# Disassembly
# ---------------------------------------------------------------------------
$(PROG_DIR)/$(NAME).dump: $(PROG_DIR)/$(NAME).elf
	$(OBJDUMP) -d -M numeric,no-aliases $< > $@

# ---------------------------------------------------------------------------
# Top-level targets (called from program Makefile)
# ---------------------------------------------------------------------------
.PHONY: build clean

build: $(PROG_DIR)/$(NAME).text.hex \
       $(PROG_DIR)/$(NAME).data.hex \
       $(PROG_DIR)/$(NAME).dump
	@echo "Built $(NAME): text=$(NAME).text.hex  data=$(NAME).data.hex"

clean:
	rm -f $(PROG_DIR)/*.o \
	      $(PROG_DIR)/$(NAME).elf \
	      $(PROG_DIR)/$(NAME).*.bin \
	      $(PROG_DIR)/$(NAME).*.hex \
	      $(PROG_DIR)/$(NAME).dump
	rm -f $(STARTUP_OBJ)
