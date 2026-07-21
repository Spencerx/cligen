#
# Makefile for CLIgen AFL fuzzing
#
# ***** BEGIN LICENSE BLOCK *****
#
# Copyright (C) 2026 Olof Hagsand
#
# This file is part of CLIgen.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ***** END LICENSE BLOCK *****
#
# CLIgen must be built with the AFL compiler before running; see README.md.
#
# Usage (from this directory):
#   make run SPEC=specs/commands.cli INPUT="show version"
#   make clean

SPEC  ?= specs/commands.cli
INPUT ?= show

.PHONY: all run clean

all:
	@echo "No build step needed — build CLIgen with afl-gcc first (see README.md)."
	@echo "Then: make run SPEC=specs/commands.cli INPUT=\"show version\""

run:
	./runfuzz.sh $(SPEC) "$(INPUT)"

clean:
	rm -rf input output
