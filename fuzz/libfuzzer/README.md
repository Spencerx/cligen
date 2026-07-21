# libFuzzer harnesses for CLIgen

In-process, coverage-guided fuzzing with AddressSanitizer + UndefinedBehaviorSanitizer.
Detects crashes, memory errors, and leaks. Requires `clang` (ships with libFuzzer).

## Targets

| Target        | Entry point                                                                           | Exercises |
|---------------|---------------------------------------------------------------------------------------|-----------|
| `fuzz_spec`   | `clispec_parse_str()`                                                                 | The `.cli` syntax grammar (Bison/Flex) and parse-tree construction. |
| `fuzz_cv`     | `cv_parse1()`                                                                         | Per-type value parsers (ipv4/ipv6/mac/uuid/time/url/decimal/int/...). The first input byte selects the type. |
| `fuzz_input`  | `cligen_str2cvv()` + `match_pattern()` + `match_complete()` + `match_pattern_exact()` | The full user-input pipeline against a complex spec with subtrees, pipe trees, @{} sets, optionals, and many variable types; exercises both the prefix-match/completion path and the exact-match/execute path. |

## Build

The generated parser sources must exist first — run this once in the repo root:

```sh
cd ../..         # repo root
./configure && make
```

Then build from this directory or from `fuzz/`:

```sh
# From fuzz/libfuzzer/:
make             # all targets; also seeds corpus_*/ dirs
make fuzz_cv     # single target
CC=clang-18 ./build.sh   # override compiler

# From fuzz/:
make             # delegates here via $(MAKE) -C libfuzzer
make fuzz_cv
```

Instrumented library objects are cached in `obj/`.

## Run

```sh
./fuzz_spec  corpus_spec  -dict=cligen.dict
./fuzz_cv    corpus_cv    -dict=cligen.dict
./fuzz_input corpus_input -dict=cligen.dict
```

Or via the `fuzz/` Makefile:

```sh
make -C .. run_spec
make -C .. run_cv
make -C .. run_input
```

The first argument is the corpus directory (created and seeded by `build.sh`);
libFuzzer saves newly-discovered inputs back into it.

Useful flags:

| Flag                  | Purpose |
|-----------------------|---------|
| `-runs=N`             | Stop after N inputs (omit to run forever). |
| `-max_len=4096`       | Cap input size. |
| `-fork=N`             | Parallel fuzzing across N processes. |
| `-dict=cligen.dict`   | Token dictionary (recommended for `spec`/`input`). |
| `-rss_limit_mb=2048`  | Memory ceiling. |
| `-timeout=10`         | Per-input timeout (catches hangs/ReDoS). |
| `-max_total_time=300` | Stop after 300s (useful for CI). |

Examples:

```sh
# Run forever, 4 parallel workers:
./fuzz_spec corpus_spec -dict=cligen.dict -fork=4 -max_len=4096

# Time-boxed CI run (5 min):
./fuzz_input corpus_input -dict=cligen.dict -max_total_time=300

# Continuous run, log to file, save findings to artifacts_spec/:
nohup ./fuzz_spec corpus_spec -dict=cligen.dict \
    -fork=8 -ignore_crashes=1 -ignore_timeouts=1 -ignore_ooms=1 \
    -max_len=4096 -rss_limit_mb=2048 -timeout=10 \
    -artifact_prefix=artifacts_spec/ > spec.log
```

## Reproducing a finding

libFuzzer writes the offending input to `crash-<sha1>` (or `leak-<sha1>`,
`timeout-<sha1>`) in this directory and aborts. Reproduce with full sanitizer
report:

```sh
./fuzz_input crash-<sha1>
```

Minimize for easier debugging:

```sh
./fuzz_input -minimize_crash=1 -runs=10000 crash-<sha1>
```

## Notes

- **`-fno-sanitize=object-size`** is set in `build.sh`. CLIgen deliberately
  under-allocates non-`CO_VARIABLE` objects to `sizeof(struct cg_obj_common)`
  (see `co_size()` in `cligen_object.c`) and accesses them through a `cg_obj*`.
  The fields accessed live in the common prefix, so it is safe in practice, but
  UBSan's object-size check flags every such access. Remove the flag if you
  specifically want to audit that pattern.
- If UBSan reports noise from the generated Flex/Bison files
  (`lex.cligen_parse.c`, `cligen_parse.tab.c`), recompile just those objects
  without `-fsanitize=undefined`.
- Build artifacts (`obj/`, the `fuzz_*` binaries, `corpus_*/`, `crash-*`,
  `leak-*`, `timeout-*`, `*.log`) are gitignored and should not be committed.
