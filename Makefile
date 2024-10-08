REG_DIR := $(shell ./bender path register_interface)
REGTOOL ?= $(REG_DIR)/vendor/lowrisc_opentitan/util/regtool.py

bender:
	wget "https://github.com/pulp-platform/bender/releases/download/v0.22.0/bender-0.22.0-x86_64-linux-gnu-centos7.8.2003.tar.gz"
	tar -xvzf bender-0.22.0-x86_64-linux-gnu-centos7.8.2003.tar.gz
	rm bender-0.22.0-x86_64-linux-gnu-centos7.8.2003.tar.gz
	./bender --version | grep -q "bender 0.22.0"


file_list.txt: bender 
	./bender script flist > $@
