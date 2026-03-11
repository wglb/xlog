.PHONY: all test clean

all: test

test:
	sbcl --non-interactive --eval '(ql:quickload :xlog)' --eval '(in-package #:xlog)' --eval '(test-log-file)'
	touch test

clean:
	rm -f test original.log inner.log
