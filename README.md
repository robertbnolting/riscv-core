# riscv-core
## Introduction
This project contains the Verilog implementation of a pipelined [RISC-V](https://en.wikipedia.org/wiki/RISC-V) core.

I started this project to teach me the basics about CPU design and HDLs,
so it is only an implementation of the RV32I Base Integer Instruction Set from [here](https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf).

It is not thoroughly tested and thus not guaranteed to always work!

In order to work with real RISC-V binaries some changes would need to be made (primarily to the instruction fetch stage).
