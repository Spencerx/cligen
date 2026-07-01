# Fuzzing CLIgen

Two complementary fuzzing setups live here:

1. **libFuzzer targets** (recommended) — in-process, coverage-guided harnesses
   built with AddressSanitizer + UndefinedBehaviorSanitizer. Fast, and they
   detect memory errors and leaks, not just crashes. Requires `clang` (ships
   with libFuzzer).
2. **AFL** — black-box fuzzing of the `cligen_file` binary via stdin. Useful if
   you prefer AFL or want to fuzz the whole application end-to-end.

---

## 1. libFuzzer targets

| Target       | Entry point                                  | Exercises |
|--------------|----------------------------------------------|-----------|
| `fuzz_spec`  | `clispec_parse_str()`                        | The `.cli` syntax grammar (Bison/Flex) and parse-tree construction. |
| `fuzz_match` | `cligen_str2cvv()` + `match_pattern_exact()` | The command-line tokenizer (`next_token`: quotes/escapes/pipes) and the matching engine, including variable type parsing/validation against a fixed tree. |
| `fuzz_cv`    | `cv_parse1()`                                | Per-type value parsers (ipv4/ipv6/mac/uuid/time/url/decimal/int/...). The first input byte selects the type. |

### Build

The generated parser sources must exist first, so build the library once in
the repo root:

```sh
cd ..            # repo root
./configure && make
```

Then build the fuzzers:

```sh
cd fuzz
make                 # all targets; also seeds corpus_*/ dirs
make fuzz_match      # or just one target
```

Instrumented library objects are cached in `fuzz/obj/`. Override the compiler
with `CC=clang-18 ./build.sh` if needed.

### Run

Specific runs:
```sh
make run-spec
make run-match
make run-cv
```sh

Or using the binary directly:
```
./fuzz_spec  corpus_spec  -dict=cligen.dict
./fuzz_match corpus_match -dict=cligen.dict
./fuzz_cv    corpus_cv
```

The first argument is the corpus directory (created and seeded by `build.sh`);
libFuzzer saves newly-discovered inputs back into it. Useful flags:

| Flag                  | Purpose |
|-----------------------|---------|
| `-runs=N`             | Stop after N inputs (omit to run forever). |
| `-max_len=4096`       | Cap input size. |
| `-jobs=N -workers=N`  | Parallel fuzzing across N processes. |
| `-dict=cligen.dict`   | Use the CLIgen token dictionary (recommended for `spec`/`match`). |
| `-rss_limit_mb=4096`  | Memory ceiling. |
| `-timeout=10`         | Per-input timeout (catches hangs/ReDoS). |
| `-max_total_time=300` | Stop after 300s (time-boxed/CI runs). |

Examples:

```sh
# Run forever, 4 parallel workers, with the dictionary:
./fuzz_spec corpus_spec -dict=cligen.dict -fork=4 -max_len=4096

# Time-boxed CI-style run (5 min, single process):
./fuzz_match corpus_match -dict=cligen.dict -max_total_time=300

# Continue and log errors in artifact dir
nohup ./fuzz_spec corpus_spec -dict=cligen.dict \
     -fork=8 -ignore_crashes=1 -ignore_timeouts=1 -ignore_ooms=1 \
     -max_len=4096 -rss_limit_mb=2048 -timeout=10 \
     -artifact_prefix=artifacts_spec/ > spec.log
```

### Reproducing a finding

On a finding, libFuzzer writes the offending input to `crash-<sha1>` (or
`leak-<sha1>`, `timeout-<sha1>`) and aborts. Re-run that single input to
reproduce with a full sanitizer report:

```sh
./fuzz_match crash-da39a3ee5e6b4b0d3255bfef95601890afd80709
```

Minimize it for easier debugging:

```sh
./fuzz_match -minimize_crash=1 -runs=10000 crash-<sha1>
```

### Notes / caveats

- **`-fno-sanitize=object-size`** is set in `build.sh`. CLIgen deliberately
  under-allocates non-`CO_VARIABLE` objects to `sizeof(struct cg_obj_common)`
  (see `co_size()` in `cligen_object.c`) and accesses them through a `cg_obj*`.
  The accessed fields live in the common prefix, so it is safe in practice, but
  UBSan's object-size check flags every such access and would drown out real
  bugs. Remove the flag if you specifically want to audit that pattern.
- If UBSan reports noise from the generated Flex/Bison files
  (`lex.cligen_parse.c`, `cligen_parse.tab.c`), recompile just those objects
  without `undefined`.
- The `.cli` spec used by `fuzz_match` is embedded at the top of `fuzz_match.c`;
  extend it to reach more matcher paths.
- Build artifacts (`obj/`, the `fuzz_*` binaries, `corpus_*/`, `crash-*`,
  `leak-*`, `timeout-*`) should not be committed.

---

## 2. AFL (black-box, via `cligen_file`)

See the [AFL docs](https://afl-1.readthedocs.io/en/latest) for installing AFL.

You may have to change cpu frequency:
```sh
cd /sys/devices/system/cpu
echo performance | tee cpu?/cpufreq/scaling_governor
```
and the core pattern:
```sh
echo core >/proc/sys/kernel/core_pattern
```

### Build

CLIgen must be built statically with the AFL compiler:
```sh
CC=/usr/bin/afl-gcc CXX=/usr/bin/afl-g++ LINKAGE=static ./configure
make clean
make
```

### Run

`runfuzz.sh` runs one test given a CLI spec and an input string:
```sh
./runfuzz.sh ./specs/commands.cli "abd a"
./runfuzz.sh ./specs/sets.cli "b f c d ?"
```
CLIgen specs are taken from the [test dir](../test). Investigate results in the
`output/` directory during/after the run. Only one test runs at a time (single
shared `output/` dir), so concurrent runs are not supported this way.


