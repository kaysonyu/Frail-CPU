#!/bin/bash
echo "$1 without delay"
make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$1/axi_ram.coe -f bubble_select.fst" || exit
# echo "$1 with delay"
# make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$1/axi_ram.coe -p 0.99 "  || exit