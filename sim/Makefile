SRC_DIR  := ../src
TB_DIR   := ../tb
BUILD_DIR := build

VERILATOR := verilator
VFLAGS    := --binary --assert -Wall -Wno-UNUSED -Wno-TIMESCALEMOD \
             -Wno-DECLFILENAME \
             +1800-2012ext+sv --timing --trace \
             -I$(SRC_DIR)/if -I$(SRC_DIR)/id -I$(SRC_DIR)/ex \
             -I$(SRC_DIR)/mem -I$(SRC_DIR)/wb -I$(SRC_DIR)/core

# ---------------------------------------------------------------------------
# Design selection: PIPELINE=0              → single-cycle core.sv
#                   PIPELINE=1              → core_pipeline.sv  (module still named `core`)
#                   PIPELINE=1 BRANCH_PREDICT=1 → core_pipeline_bp.sv
# ---------------------------------------------------------------------------
PIPELINE ?= 0
BRANCH_PREDICT ?= 0

ifeq ($(PIPELINE),1)
  ifeq ($(BRANCH_PREDICT),1)
    CORE_TOP  := $(SRC_DIR)/core/core_pipeline_bp.sv
    EXTRA_SRC := $(SRC_DIR)/core/hazard_unit.sv $(SRC_DIR)/core/branch_predictor.sv
    TESTS     := tb_alu tb_regfile tb_decoder tb_if_stage tb_branch_predictor
    BUILD_SUB := pipeline_bp
  else
    CORE_TOP  := $(SRC_DIR)/core/core_pipeline.sv
    EXTRA_SRC := $(SRC_DIR)/core/hazard_unit.sv
    # tb_core timing assumptions are single-cycle specific; skip it for pipeline
    TESTS     := tb_alu tb_regfile tb_decoder tb_if_stage
    BUILD_SUB := pipeline
  endif
else
  CORE_TOP  := $(SRC_DIR)/core/core.sv
  EXTRA_SRC :=
  TESTS     := tb_alu tb_regfile tb_decoder tb_if_stage tb_core
  BUILD_SUB := single_cycle
endif

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
  $(EXTRA_SRC) \
  $(CORE_TOP)

.PHONY: all clean run wave prog $(TESTS)

all: $(TESTS)

run: all
	@echo "=== Running all tests (PIPELINE=$(PIPELINE)) ==="
	@fail=0; \
	for t in $(TESTS); do \
	  printf "--- $$t ---\n"; \
	  if ./$(BUILD_DIR)/$(BUILD_SUB)/$$t/V$$t; then \
	    printf "RESULT: PASS $$t\n"; \
	  else \
	    printf "RESULT: FAIL $$t\n"; \
	    fail=$$((fail+1)); \
	  fi; \
	done; \
	[ $$fail -eq 0 ] && echo "=== ALL TESTS PASSED ===" || echo "=== FAILED: $$fail test(s) ==="

tb_alu:
	mkdir -p $(BUILD_DIR)/$(BUILD_SUB)/tb_alu
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/ex/alu.sv \
	  $(TB_DIR)/tb_alu.sv \
	  --top-module tb_alu \
	  -Mdir $(BUILD_DIR)/$(BUILD_SUB)/tb_alu

tb_regfile:
	mkdir -p $(BUILD_DIR)/$(BUILD_SUB)/tb_regfile
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/id/regfile.sv \
	  $(TB_DIR)/tb_regfile.sv \
	  --top-module tb_regfile \
	  -Mdir $(BUILD_DIR)/$(BUILD_SUB)/tb_regfile

tb_decoder:
	mkdir -p $(BUILD_DIR)/$(BUILD_SUB)/tb_decoder
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/id/decoder.sv \
	  $(TB_DIR)/tb_decoder.sv \
	  --top-module tb_decoder \
	  -Mdir $(BUILD_DIR)/$(BUILD_SUB)/tb_decoder

tb_if_stage:
	mkdir -p $(BUILD_DIR)/$(BUILD_SUB)/tb_if_stage
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/if/if_stage.sv \
	  $(TB_DIR)/tb_if_stage.sv \
	  --top-module tb_if_stage \
	  -Mdir $(BUILD_DIR)/$(BUILD_SUB)/tb_if_stage

tb_core:
	$(VERILATOR) $(VFLAGS) \
	  $(CORE_SRCS) \
	  $(TB_DIR)/tb_core.sv \
	  --top-module tb_core \
	  -Mdir $(BUILD_DIR)/$(BUILD_SUB)/tb_core

tb_branch_predictor:
	mkdir -p $(BUILD_DIR)/$(BUILD_SUB)/tb_branch_predictor
	$(VERILATOR) $(VFLAGS) \
	  $(SRC_DIR)/core/branch_predictor.sv \
	  $(TB_DIR)/tb_branch_predictor.sv \
	  --top-module tb_branch_predictor \
	  -Mdir $(BUILD_DIR)/$(BUILD_SUB)/tb_branch_predictor

# ---------------------------------------------------------------------------
# tb_prog — generic program runner (compiled once, driven by plusargs)
# ---------------------------------------------------------------------------
PROG_SRCS := $(CORE_SRCS) $(TB_DIR)/tb_prog.sv

tb_prog:
	mkdir -p $(BUILD_DIR)/$(BUILD_SUB)/tb_prog
	$(VERILATOR) $(VFLAGS) \
	  $(PROG_SRCS) \
	  --top-module tb_prog \
	  -Mdir $(BUILD_DIR)/$(BUILD_SUB)/tb_prog

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
	$(BUILD_DIR)/$(BUILD_SUB)/tb_prog/Vtb_prog \
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
	./$(BUILD_DIR)/$(BUILD_SUB)/$(MOD)/V$(MOD)
	gtkwave $(MOD).vcd &

clean:
	rm -rf $(BUILD_DIR) *.vcd
