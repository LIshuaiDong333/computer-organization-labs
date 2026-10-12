# Computer Organization Labs

Assembly and Verilog experiment files for a computer organization course.

## Experiments

| Directory | Contents |
| --- | --- |
| `实验1` | RISC-V floating-point addition assembly, preprocessed C, generated assembly, and disassembly listings |
| `实验2` | Floating-point unit implementation (`fpu.v`) |
| `实验3` | Instruction cache (`ICache.v`) and linear-feedback shift register (`lfsr.v`) |
| `实验4` | AXI master interface (`axi_master.v`) |

The original directory names and source file bytes are preserved. The Verilog files use GBK encoding for Chinese comments; select GBK in your editor if the comments appear garbled.

## Usage

- Use a compatible RISC-V assembler or RARS for the assembly experiment. The local RARS JAR is excluded from this repository; obtain the tool separately.
- Add the Verilog modules to the corresponding simulation or FPGA project.
- These are experiment files rather than complete standalone projects. For example, `ICache.v` references `defines.vh`, which is absent from this directory. Testbenches and project configuration files are also absent.
- The original RARS setup notes are available in `使用说明.txt`.

## Upload scope

Only reviewed source files, text listings, setup notes, and this repository's documentation are tracked. Word and PDF reports, submission archives containing reports, compiled objects, and bundled binary tools remain local.

The `.gitignore` file uses an explicit allowlist. Review any new file for personal information before adding it to that list.
