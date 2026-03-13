NAME     := dhrystone
SRCS     := dhrystone_main.c dhrystone_procs.c syscalls.c
PROG_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Number of benchmark iterations; override: make NUMBER_OF_RUNS=5000
NUMBER_OF_RUNS ?= 1000

include ../startup/Makefile

# Append define after include so it's picked up at recipe execution time
override CFLAGS += -DNUMBER_OF_RUNS=$(NUMBER_OF_RUNS)
