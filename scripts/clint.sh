#!/bin/sh

for file in $(cat clint-files.txt); do
	./clint.py $file
done
