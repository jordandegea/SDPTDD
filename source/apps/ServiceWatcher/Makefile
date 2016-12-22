OUTPUT_TAR=../code/files/service_watcher.tar.xz
DEPENDENCIES=$(wildcard *) $(wildcard *.*)
BASENAME=$(shell basename `pwd`)

all: ../$(OUTPUT_TAR)

../$(OUTPUT_TAR): $(DEPENDENCIES)
	cd .. && tar cJvf $(OUTPUT_TAR) $(^:%=$(BASENAME)/%)

.PHONY: all