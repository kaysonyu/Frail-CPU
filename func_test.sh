#!/bin/bash
echo "func_test without delay"
make vsim -j TEST=func_test
echo "func_test with delay"
make vsim -j TEST=func_test VSIM_ARGS='-p 0.99'
