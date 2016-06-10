#!/bin/bash


for cpatch in testpatches/new/*
do
  git apply --whitespace=nowarn $cpatch

  echo -e "\n$cpatch"
  

  make clean 1> /dev/null 2>/dev/null
  make 1> /dev/null 2>/dev/null

  TEST_FILE=test/functional/legacy/030_fileformats_spec.lua make functionaltest > luatest.out 2>&1

  git checkout -- src
  git checkout -- test

  if [ ! -z "$(grep 'Running functional tests failed' luatest.out)" ];then
    newtest_ok=0
    echo -e "\tFailed"
  else
    echo -e "\tPassed"
    newtest_ok=1
  fi
  
  rm luatest.out
done
