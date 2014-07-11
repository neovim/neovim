#!/bin/sh
# enable DEC locator input model on remote terminal
printf  "\033[1;2'z\033[1;3'{\c"
vim "$@"
# disable DEC locator input model on remote terminal
printf  "\033[2;4'{\033[0'z\c"
