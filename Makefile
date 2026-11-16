# Personal immortal training dummy for Magic Tattoos testing.
# make / make live   builds and copies into the Skyrim Data folder
# make build         builds into dist/ only
# make package       builds the Nexus release zip under dist/
# make uninstall-live  removes it from Data
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.PHONY: all live build package uninstall-live

all: live

live build package uninstall-live:
	bash build.sh $@
