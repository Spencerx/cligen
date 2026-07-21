# AFL fuzzing for CLIgen

Black-box fuzzing of the `cligen_file` binary via stdin using
[American Fuzzy Lop](https://github.com/google/AFL).

Useful when you want to fuzz the complete application end-to-end without
recompiling to a libFuzzer harness. For deeper, faster fuzzing with memory
error detection, prefer the [`../libfuzzer/`](../libfuzzer/README.md) setup.

## Prerequisites

Install AFL:

```sh
apt install afl   # Debian/Ubuntu
# or build from https://github.com/google/AFL
```

You may also need to adjust the CPU governor and core pattern:

```sh
echo performance | tee /sys/devices/system/cpu/cpu?/cpufreq/scaling_governor
echo core > /proc/sys/kernel/core_pattern
```

## Build

CLIgen must be built statically with the AFL compiler. From the repo root:

```sh
CC=/usr/bin/afl-gcc CXX=/usr/bin/afl-g++ LINKAGE=static ./configure
make clean && make
```

## Run

`runfuzz.sh` takes a `.cli` spec file and an initial input string:

```sh
./runfuzz.sh ./specs/commands.cli "show version"
./runfuzz.sh ./specs/sets.cli "b f c d ?"
```

Findings are written to `output/`. Only one run at a time is supported
(single shared `output/` directory).

With AFL++ you can also use the CLIgen token dictionary:

```sh
afl-fuzz -i input -o output -x ../libfuzzer/cligen.dict \
    -- ../../cligen_file -f specs/commands.cli
```

## Specs

`specs/` contains a small set of `.cli` files used as fuzz targets.
Additional specs can be copied from the [test directory](../../test).
