# Fuzzing CLIgen

Two complementary setups:

| Directory      | Method                   | What it fuzzes |
|----------------|--------------------------|----------------|
| [`libfuzzer/`](libfuzzer/README.md) | libFuzzer (recommended) | Spec parser, value parsers, full user-input pipeline — in-process with ASan/UBSan |
| [`afl/`](afl/README.md)             | AFL (black-box)          | `cligen_file` binary end-to-end via stdin |

Before building either, generate the parser sources in the repo root:

```sh
CC=clang ./configure && make
```
