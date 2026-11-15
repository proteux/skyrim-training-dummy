# Personal immortal training dummy for Magic Tattoos testing.
# make / make live   builds and copies into the Skyrim Data folder
# make build         builds into dist/ only
# make uninstall-live  removes it from Data
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.PHONY: all live build uninstall-live

all: live

live build uninstall-live:
	bash build.sh $@
