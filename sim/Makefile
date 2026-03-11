SRC_DIR  := ../src
TB_DIR   := ../tb
BUILD_DIR := build

VERILATOR := verilator
VFLAGS    := --binary --assert -Wall -Wno-UNUSED -Wno-TIMESCALEMOD \
             +1800-2012ext+sv --timing --trace \
             -I$(SRC_DIR)/if -I$(SRC_DIR)/id -I$(SRC_DIR)/ex \
             -I$(SRC_DIR)/mem -I$(SRC_DIR)/wb -I$(SRC_DIR)/core

TESTS := tb_alu tb_regfile tb_decoder tb_if_stage tb_core

CORE_SRCS := \
  $(SRC_DIR)/if/if_stage.sv \
  $(SRC_DIR)/id/decoder.sv \
  $(SRC_DIR)/id/regfile.sv \
  $(SRC_DIR)/id/id_stage.sv \
  $(SRC_DIR)/ex/alu.sv \
  $(SRC_DIR)/ex/ex_stage.sv \
  $(SRC_DIR)/mem/mem_stage.sv \
  $(SRC_DIR)/wb/wb_stage.sv \
  $(SRC_DIR)/core/imem.sv \
  $(SRC_DIR)/core/dmem.sv \
  $(SRC_DIR)/core/core.sv

.PHONY: all clean run wave prog $(TESTS)

all: $(TESTS)

run: all
	@echo "=== Running all tests ==="
	@fail=0; \
	for t in $(TESTS); do \
	  printf "--- $$t ---\n"; \
	  if ./$(BUILD_DIR)/$$t/V$$t; then \
	    printf "RESULT: PASS $$t\n"; \
	  else \
	    printf "RESULT: FAIL $$t\n"; \
	    fail=$$((fail+1)); \
	  fi; \
	done; \
	[ $$fail -eq 0 ] && echo "=== ALL TESTS PASSED ===" || echo "=== FAILED: $$fail test(s) ==="

tb_alu:
	mkdir -p $(BUILD_DIR)/tb_alu
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/ex/alu.sv \
	  $(TB_DIR)/tb_alu.sv \
	  --top-module tb_alu \
	  -Mdir $(BUILD_DIR)/tb_alu

tb_regfile:
	mkdir -p $(BUILD_DIR)/tb_regfile
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/id/regfile.sv \
	  $(TB_DIR)/tb_regfile.sv \
	  --top-module tb_regfile \
	  -Mdir $(BUILD_DIR)/tb_regfile

tb_decoder:
	mkdir -p $(BUILD_DIR)/tb_decoder
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/id/decoder.sv \
	  $(TB_DIR)/tb_decoder.sv \
	  --top-module tb_decoder \
	  -Mdir $(BUILD_DIR)/tb_decoder

tb_if_stage:
	mkdir -p $(BUILD_DIR)/tb_if_stage
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/if/if_stage.sv \
	  $(TB_DIR)/tb_if_stage.sv \
	  --top-module tb_if_stage \
	  -Mdir $(BUILD_DIR)/tb_if_stage

tb_core:
	$(VERILATOR) $(VFLAGS) \
	  $(CORE_SRCS) \
	  $(TB_DIR)/tb_core.sv \
	  --top-module tb_core \
	  -Mdir $(BUILD_DIR)/tb_core

# ---------------------------------------------------------------------------
# tb_prog — generic program runner (compiled once, driven by plusargs)
# ---------------------------------------------------------------------------
PROG_SRCS := $(CORE_SRCS) $(TB_DIR)/tb_prog.sv

tb_prog:
	$(VERILATOR) $(VFLAGS) \
	  $(PROG_SRCS) \
	  --top-module tb_prog \
	  -Mdir $(BUILD_DIR)/tb_prog

# Run a program:  make prog TEXT=path/to/prog.text.hex [DATA=path/to/prog.data.hex]
#                           [TOHOST=0x1000] [TIMEOUT=100000] [VCD=1]
TEXT    ?=
DATA    ?=
TOHOST  ?= 0x1000
TIMEOUT ?= 100000

prog: tb_prog
ifndef TEXT
	$(error Usage: make prog TEXT=<path/to/prog.text.hex> [DATA=<path>] [TOHOST=0x1000] [TIMEOUT=100000] [VCD=1])
endif
	$(BUILD_DIR)/tb_prog/Vtb_prog \
	  +TEXT_HEX=$(TEXT) \
	  $(if $(DATA),+DATA_HEX=$(DATA),) \
	  +TOHOST_ADDR=$(TOHOST) \
	  +TIMEOUT=$(TIMEOUT) \
	  $(if $(VCD),+DUMP_VCD,)

# ---------------------------------------------------------------------------
# Waveform viewer
# ---------------------------------------------------------------------------
wave:
ifndef MOD
	$(error Usage: make wave MOD=<module_name>  e.g. make wave MOD=tb_core)
endif
	$(MAKE) $(MOD)
	./$(BUILD_DIR)/$(MOD)/V$(MOD)
	gtkwave $(MOD).vcd &

clean:
	rm -rf $(BUILD_DIR) *.vcd
