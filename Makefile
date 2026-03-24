# Use the utility to get official project files from xlog.asd
LISP_FILES := $(shell asdf-deps xlog)

.PHONY: all test count-lines clean

# Default target just ensures the library compiles
all:
	sbcl --disable-debugger \
	     --eval "(asdf:load-system :xlog)" \
	     --quit

# 1) Compiles the system and 2) executes (xlog:test-log-file)
test:
	@echo "Compiling and running xlog:test-log-file..."
	sbcl --disable-debugger \
	     --eval "(asdf:load-system :xlog)" \
	     --eval "(xlog:test-log-file)" \
	     --quit

# Metrics for the official library files 
count-lines:
	@echo "Project Metrics for xlog (Version $(shell sbcl --noinform --disable-debugger --eval '(asdf:load-system :xlog)' --eval '(format t "~A" (xlog:xlog-version))' --quit)):"
	@wc -l $(LISP_FILES)

# Clean up FASLs to prevent M1/M4 architecture conflicts
clean:
	@echo "Cleaning ASDF cache for xlog..."
	rm -rf ~/.cache/common-lisp/sbcl-*-macosx-arm64$(shell pwd)
