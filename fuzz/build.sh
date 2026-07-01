#!/usr/bin/env bash
#
# Build the CLIgen libFuzzer targets with AddressSanitizer + UndefinedBehavior.
#
# Requirements: clang with libFuzzer (clang >= 6). The generated parser files
# (cligen_parse.tab.c, lex.cligen_parse.c) must already exist in the repo root;
# run `./configure && make` once in the repo root if they do not.
#
# Usage:
#   cd fuzz
#   ./build.sh                 # build all targets
#   ./build.sh fuzz_spec       # build a single target
#
# Run, e.g.:
#   ./fuzz_spec   corpus_spec   -dict=cligen.dict
#   ./fuzz_match  corpus_match
#   ./fuzz_cv     corpus_cv
#
set -euo pipefail

CC=${CC:-clang}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FUZZDIR=$(cd "$(dirname "$0")" && pwd)

# Sanitizer + coverage flags shared by library objects and harnesses.
#
# Note: -fno-sanitize=object-size disables UBSan's object-size check. CLIgen
# deliberately under-allocates non-CO_VARIABLE objects to sizeof(struct
# cg_obj_common) (see co_size() in cligen_object.c) and accesses them through a
# cg_obj* pointer. The accessed fields live in the common prefix so this is safe
# in practice, but object-size flags every such access and would drown out real
# bugs. Remove this flag if you specifically want to audit that pattern.
SAN="-fsanitize=fuzzer-no-link,address,undefined -fno-sanitize=object-size -fno-omit-frame-pointer"
CFLAGS="-g -O1 ${SAN} -I${ROOT} -Wno-deprecated-declarations"

# libFuzzer needs the C++ runtime; clang may not search the gcc lib dir.
STDCPPDIR=$(dirname "$(gcc -print-file-name=libstdc++.so 2>/dev/null)" 2>/dev/null || true)
LDEXTRA=""
if [ -n "${STDCPPDIR}" ] && [ -d "${STDCPPDIR}" ]; then
  LDEXTRA="-L${STDCPPDIR}"
fi

# Hand-written library sources (mirrors SRC in ../Makefile.in) + generated parser.
LIBSRC=(
  cligen_object.c cligen_callback.c cligen_parsetree.c cligen_pt_head.c
  cligen_handle.c cligen_cv.c cligen_match.c cligen_result.c
  cligen_read.c cligen_io.c cligen_expand.c cligen_syntax.c
  cligen_print.c cligen_cvec.c cligen_buf.c cligen_util.c
  cligen_history.c cligen_regex.c cligen_getline.c build.c
  lex.cligen_parse.c cligen_parse.tab.c
)

for f in cligen_parse.tab.c lex.cligen_parse.c cligen_config.h; do
  if [ ! -f "${ROOT}/${f}" ]; then
    echo "ERROR: ${ROOT}/${f} missing. Run './configure && make' in ${ROOT} first." >&2
    exit 1
  fi
done

OBJDIR="${FUZZDIR}/obj"
mkdir -p "${OBJDIR}"

echo "== Compiling instrumented library objects =="
OBJS=()
for src in "${LIBSRC[@]}"; do
  obj="${OBJDIR}/${src%.c}.o"
  echo "  CC ${src}"
  # shellcheck disable=SC2086
  ${CC} ${CFLAGS} -c "${ROOT}/${src}" -o "${obj}"
  OBJS+=("${obj}")
done

build_target() {
  local name="$1"
  echo "== Linking ${name} =="
  # shellcheck disable=SC2086
  ${CC} ${CFLAGS} -fsanitize=fuzzer ${LDEXTRA} \
      "${FUZZDIR}/${name}.c" "${OBJS[@]}" \
      -o "${FUZZDIR}/${name}"
}

TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(fuzz_spec fuzz_match fuzz_cv)
fi
for t in "${TARGETS[@]}"; do
  build_target "${t}"
done

echo "== Seeding corpora =="
mkdir -p "${FUZZDIR}/corpus_spec" "${FUZZDIR}/corpus_match" "${FUZZDIR}/corpus_cv"
# Spec corpus: existing .cli files are ideal seeds.
cp -f "${ROOT}"/*.cli "${FUZZDIR}/corpus_spec/" 2>/dev/null || true
cp -f "${ROOT}"/test/*.cli "${FUZZDIR}/corpus_spec/" 2>/dev/null || true
# Match corpus: a few representative command lines.
printf 'set ip address 1.2.3.4 255.255.255.0\n' > "${FUZZDIR}/corpus_match/seed1"
printf 'show history | count\n'                  > "${FUZZDIR}/corpus_match/seed2"
printf 'show interface e0\n'                      > "${FUZZDIR}/corpus_match/seed3"
printf 'config a b 50 c on\n'                     > "${FUZZDIR}/corpus_match/seed4"
# Cv corpus: type-selector byte + a value string.
printf '\x0e1.2.3.4'                              > "${FUZZDIR}/corpus_cv/seed_ipv4"
printf '\x10f0:de:f1:1b:10:47'                    > "${FUZZDIR}/corpus_cv/seed_mac"
printf '\x12550e8400-e29b-41d4-a716-446655440000' > "${FUZZDIR}/corpus_cv/seed_uuid"

echo "Done. Example: ${FUZZDIR}/fuzz_spec ${FUZZDIR}/corpus_spec -dict=${FUZZDIR}/cligen.dict"
