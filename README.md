# Introduction to Computer Systems (II)

Spring 2021, Fudan University.

## Prerequisites

* Xilinx Vivado (= 2019.2, HLx version)
* Verilator (≥ 4.028)
* `build-essential`
    * GNU make
    * C++17 capable compiler: GNU C++ (≥ 9.0.0) or LLVM clang (≥ 7.0.0)
    * gdb
* GTKWave
* `libz-dev` (or the correct devel packege for zlib on your Linux distribution)

### Ubuntu 20.04

```shell
apt update
apt install -y build-essential gdb gtkwave libz-dev verilator
```

Run RefCPU functional test:

```shell
make vsim -j
```

### Ubuntu 18.04

Because Verilator 3.x on Ubuntu 18.04 is outdated, we need to install a newer version from SiFive. First, download the `.deb` package file from <https://github.com/sifive/verilator/releases> (or eLearning if your network connection to GitHub is not stable) and save it to `verilator4.deb`. And then execute the following commands as root:

```shell
apt update
apt install -y make gdb gtkwave libz-dev clang-10 libc++-10-dev libc++abi-10-dev
# wget -O verilator4.deb https://github.com/sifive/verilator/releases/download/4.036-0sifive2/verilator_4.036-0sifive2_amd64.deb
dpkg -i verilator4.deb
ln -s /usr/local/share/verilator /usr/share/
```

NOTE: there's no GCC 9 officially on Ubuntu 18.04, so we installed clang instead. As a result, every time you run `make vsim`, you have to specify `USE_CLANG=1` in command line. For example:

```shell
make vsim -j USE_CLANG=1
```

## NSCSCC Performance Test

By default, `make vsim` will simulate RefCPU with NSCSCC functional test. We provide memory initialization files (`.coe`) of performance test from NSCSCC. For example, if you want to run CoreMark on verilated models, you can specify the `--memfile` (or `-m` for short) and set `--ref-trace` (ot `-r` for short) to empty string to disable text trace diff.

```shell
make vsim -j VSIM_ARGS='--no-status -m ./misc/nscscc/coremark.coe -r ""'
```

See `make vsim VSIM_ARGS='-h'` for more details.

## File Organization

* `misc/`: miscellaneous files.
* `doc/`: lab handouts.
* `source/`: SystemVerilog source files.
* `vivado/`: SoC and testbenches on Vivado.
* `verilate/`: C++ source files for verilated simulation.
* `build/`: temporary build files.
