#!/bin/env python3
import pynvim
import os
import sys
import time





def prepare(test_base):
    fuzzer_bin = os.path.join(test_base, "fuzzer.input")
    assert os.path.exists(fuzzer_bin), f"{fuzzer_bin} don't exists"
    socket_path = os.path.join(test_base, "socket")
    nvim = pynvim.attach('socket', path=socket_path)
    
    
    fuzzer_input = open(fuzzer_bin,'rb').read()
    return nvim, fuzzer_input

def fuzzer_to_input(fuzzer_to_input):
    return [":q<CR>"]


def force_quite_cmd():
    return [
        "C-c",
        1,
    ] * 3 + [':q<CR>']


def send_commands(nvim, cmds):
    for command_or_sleep in cmds:
        if isinstance(command_or_sleep, str):
            nvim.input(command_or_sleep)
        else:
            time.sleep(command_or_sleep)

if __name__ == "__main__":
    test_base = sys.argv[-1]

    nvim, fuzzer_input = prepare(test_base)
    print(f"fuzzer is '{fuzzer_input.hex()}'")
    test_cmds= fuzzer_to_input(fuzzer_input)

    try:
        send_commands(nvim, test_cmds)
    except Exception as e:
        print(f"Exception: {e}")

    try:
        send_commands(nvim, force_quite_cmd())
    except Exception as e:
        print(f"Exception: {e}")

