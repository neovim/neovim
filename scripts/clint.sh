#!/bin/sh

for file in $(cat clint-files.txt); do
	./clint.py $file || fail=1
done

if [ -n "$fail" ]; then
	exit 1
fi
