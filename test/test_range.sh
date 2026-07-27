#!/usr/bin/env bash
# Full range/length constraint regression tests.
#
# Covers range[] on all integer types (signed + unsigned), multiple ranges,
# decimal64 ranges and string length[]. For every narrow integer type it also
# checks the "overflow consistency" case: a value that violates the spec range
# AND overflows the base type must report the SAME spec-range message as a value
# that merely violates the spec range (regression for the cv_validate truncation
# bug where the broad int64/uint64 parse was truncated by a narrow type accessor).

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

fspec=$dir/spec.cli

cat > $fspec <<EOF
  prompt="cli> ";
  comment="#";
  treename="range";

  # Signed types with symmetric ranges
  i8  <v:int8 range[-100:100]>, callback();
  i16 <v:int16 range[-10000:10000]>, callback();
  i32 <v:int32 range[-1000000:1000000]>, callback();
  i64 <v:int64 range[-10000000000:10000000000]>, callback();

  # Unsigned types
  u8  <v:uint8 range[5:100]>, callback();
  u16 <v:uint16 range[10:1000]>, callback();
  u32 <v:uint32 range[100:1000000]>, callback();
  u64 <v:uint64 range[1000:10000000000]>, callback();

  # Multiple disjoint ranges
  multi <v:uint16 range[1:10] range[20:30]>, callback();
  imulti <v:int16 range[-30:-20] range[20:30]>, callback();

  # Decimal64
  d0 <v:decimal64 fraction-digits:2 range[1.0:10.0]>, callback();

  # String length
  slen <v:string length[3:5]>, callback();
EOF

newtest "$cligen_file -f $fspec"

# ---- int8 range[-100:100] ----
newtest "int8 valid"
expectpart "$(echo "i8 50" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> i8 50" --not-- "CLI syntax error"

newtest "int8 valid negative"
expectpart "$(echo "i8 -100" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> i8 -100" --not-- "CLI syntax error"

newtest "int8 above range within type"
expectpart "$(echo "i8 120" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -100 - 100"

newtest "int8 below range within type"
expectpart "$(echo "i8 -120" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -100 - 100"

newtest "int8 above range overflow type consistency"
expectpart "$(echo "i8 5000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -100 - 100" --not-- "out of range: -128 - 127"

newtest "int8 below range overflow type consistency"
expectpart "$(echo "i8 -5000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -100 - 100" --not-- "out of range: -128 - 127"

# ---- int16 range[-10000:10000] ----
newtest "int16 valid"
expectpart "$(echo "i16 9999" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> i16 9999" --not-- "CLI syntax error"

newtest "int16 above range within type"
expectpart "$(echo "i16 20000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -10000 - 10000"

newtest "int16 above range overflow type consistency"
expectpart "$(echo "i16 2000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -10000 - 10000" --not-- "out of range: -32768 - 32767"

# ---- int32 range[-1000000:1000000] ----
newtest "int32 valid"
expectpart "$(echo "i32 -1000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> i32 -1000000" --not-- "CLI syntax error"

newtest "int32 above range within type"
expectpart "$(echo "i32 2000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -1000000 - 1000000"

newtest "int32 above range overflow type consistency"
expectpart "$(echo "i32 5000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -1000000 - 1000000" --not-- "out of range: -2147483648 - 2147483647"

# ---- int64 range[-1e10:1e10] ----
newtest "int64 valid"
expectpart "$(echo "i64 10000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> i64 10000000000" --not-- "CLI syntax error"

newtest "int64 above range"
expectpart "$(echo "i64 20000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -10000000000 - 10000000000"

# ---- uint8 range[5:100] ----
newtest "uint8 valid"
expectpart "$(echo "u8 50" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> u8 50" --not-- "CLI syntax error"

newtest "uint8 below range"
expectpart "$(echo "u8 3" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100"

newtest "uint8 above range within type"
expectpart "$(echo "u8 200" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100"

newtest "uint8 above range overflow type (300) consistency"
expectpart "$(echo "u8 300" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100" --not-- "out of range: 0 - 255"

newtest "uint8 above range overflow type (1000) consistency"
expectpart "$(echo "u8 1000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100" --not-- "out of range: 0 - 255"

# ---- uint16 range[10:1000] ----
newtest "uint16 valid"
expectpart "$(echo "u16 500" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> u16 500" --not-- "CLI syntax error"

newtest "uint16 above range within type"
expectpart "$(echo "u16 60000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 10 - 1000"

newtest "uint16 above range overflow type consistency"
expectpart "$(echo "u16 100000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 10 - 1000" --not-- "out of range: 0 - 65535"

# ---- uint32 range[100:1000000] ----
newtest "uint32 valid"
expectpart "$(echo "u32 999999" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> u32 999999" --not-- "CLI syntax error"

newtest "uint32 above range within type"
expectpart "$(echo "u32 3000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 100 - 1000000"

newtest "uint32 above range overflow type consistency"
expectpart "$(echo "u32 5000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 100 - 1000000" --not-- "out of range: 0 - 4294967295"

# ---- uint64 range[1000:1e10] ----
newtest "uint64 valid"
expectpart "$(echo "u64 5000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> u64 5000000000" --not-- "CLI syntax error"

newtest "uint64 below range"
expectpart "$(echo "u64 100" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 1000 - 10000000000"

newtest "uint64 above range"
expectpart "$(echo "u64 20000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 1000 - 10000000000"

# ---- multiple ranges uint16 range[1:10] range[20:30] ----
newtest "multi range low band valid"
expectpart "$(echo "multi 5" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> multi 5" --not-- "CLI syntax error"

newtest "multi range high band valid"
expectpart "$(echo "multi 25" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> multi 25" --not-- "CLI syntax error"

newtest "multi range gap invalid"
expectpart "$(echo "multi 15" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 1 - 10, 20 - 30"

newtest "multi range overflow type consistency"
expectpart "$(echo "multi 100000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 1 - 10, 20 - 30" --not-- "out of range: 0 - 65535"

# ---- multiple ranges signed int16 range[-30:-20] range[20:30] ----
newtest "imulti negative band valid"
expectpart "$(echo "imulti -25" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> imulti -25" --not-- "CLI syntax error"

newtest "imulti gap invalid"
expectpart "$(echo "imulti 0" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: -30 - -20, 20 - 30"

# ---- decimal64 range[1.0:10.0] ----
newtest "dec64 valid"
expectpart "$(echo "d0 5.5" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> d0 5.5" --not-- "CLI syntax error"

newtest "dec64 below range"
expectpart "$(echo "d0 0.5" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 1.00 - 10.00"

newtest "dec64 above range"
expectpart "$(echo "d0 20.0" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 1.00 - 10.00"

# ---- string length[3:5] ----
newtest "string length valid"
expectpart "$(echo "slen abcd" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> slen abcd" --not-- "CLI syntax error"

newtest "string too short"
expectpart "$(echo "slen ab" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "String length 2 out of range: 3 - 5"

newtest "string too long"
expectpart "$(echo "slen abcdef" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "String length 6 out of range: 3 - 5"

newtest "endtest"
endtest

rm -rf $dir
