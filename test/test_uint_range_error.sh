#!/usr/bin/env bash

# Magic line must be first in script (see README.md)
s="$_" ; . ./lib.sh || if [ "$s" = $0 ]; then exit 0; else return 0; fi

fspec=$dir/spec.cli

cat > $fspec <<EOF
  prompt="cli> ";              # Assignment of prompt
  comment="#";                 # Same comment as in syntax
  treename="urange";           # Name of syntax (used when referencing)

  u8  <v:uint8>, callback();
  u16 <v:uint16>, callback();
  u32 <v:uint32>, callback();
  u64 <v:uint64>, callback();
EOF

newtest "$cligen_file -f $fspec"

newtest "uint8 valid"
expectpart "$(echo "u8 200" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> u8 200" --not-- "CLI syntax error"

newtest "uint8 out of uint8 range"
expectpart "$(echo "u8 300" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 0 - 255" --not-- "out of range: 0 - 18446744073709551615"

newtest "uint8 overflow uint64 shows uint8 range"
expectpart "$(echo "u8 99999999999999999999" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 0 - 255" --not-- "out of range: 0 - 18446744073709551615"

newtest "uint16 valid"
expectpart "$(echo "u16 50000" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> u16 50000" --not-- "CLI syntax error"

newtest "uint16 out of uint16 range"
expectpart "$(echo "u16 99999" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 0 - 65535" --not-- "out of range: 0 - 18446744073709551615"

newtest "uint16 overflow uint64 shows uint16 range"
expectpart "$(echo "u16 99999999999999999999" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 0 - 65535" --not-- "out of range: 0 - 18446744073709551615"

newtest "uint32 valid"
expectpart "$(echo "u32 3000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "cli> u32 3000000000" --not-- "CLI syntax error"

newtest "uint32 out of uint32 range"
expectpart "$(echo "u32 5000000000" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 0 - 4294967295" --not-- "out of range: 0 - 18446744073709551615"

newtest "uint32 overflow uint64 shows uint32 range"
expectpart "$(echo "u32 99999999999999999999" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 0 - 4294967295" --not-- "out of range: 0 - 18446744073709551615"

newtest "uint64 overflow"
expectpart "$(echo "u64 99999999999999999999" | $cligen_file -f $fspec 2> /dev/null)" 0 "CLI syntax error" "out of range: 0 - 18446744073709551615"

# A range[] constraint must report the same spec-range message for every value
# that violates it, whether the value fits the base type (300 > 100) or overflows
# it (1000 > 255). Previously the broad-type parse was truncated by cv_validate's
# type accessor, so 300->44 wrongly passed and 1000->232 wrongly failed, giving
# two different messages ("0 - 255" vs "5 - 100").
fspec2=$dir/spec2.cli
cat > $fspec2 <<EOF
  prompt="cli> ";
  treename="rrange";
  val <x:uint8 range[5:100]>, callback();
EOF

newtest "ranged uint8 valid in range"
expectpart "$(echo "val 50" | $cligen_file -f $fspec2 2> /dev/null)" 0 "cli> val 50" --not-- "CLI syntax error"

newtest "ranged uint8 below range"
expectpart "$(echo "val 3" | $cligen_file -f $fspec2 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100"

newtest "ranged uint8 above range within type"
expectpart "$(echo "val 200" | $cligen_file -f $fspec2 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100"

newtest "ranged uint8 above range and above type (300)"
expectpart "$(echo "val 300" | $cligen_file -f $fspec2 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100" --not-- "out of range: 0 - 255"

newtest "ranged uint8 above range and above type (1000) same message as 300"
expectpart "$(echo "val 1000" | $cligen_file -f $fspec2 2> /dev/null)" 0 "CLI syntax error" "out of range: 5 - 100" --not-- "out of range: 0 - 255"

newtest "endtest"
endtest

rm -rf $dir
