#!/bin/env python3
import pynvim
import string
import os
import sys
import time





def prepare(test_base):
    fuzzer_bin = os.path.join(test_base, "fuzzer.input")
    assert os.path.exists(fuzzer_bin), f"{fuzzer_bin} don't exists"
    socket_path = os.path.join(test_base, "socket")
    print(f"use nvim --remote {socket_path} for debugging")
    nvim = pynvim.attach('socket', path=socket_path)
    
    
    fuzzer_input = open(fuzzer_bin,'rb').read()
    return nvim, fuzzer_input

def fuzzer_to_input(fuzzer_input:bytes):

    printable= set(ord(x) for x in string.printable)

    # following code taken from neovim-qt input
    other_mapping = [
        "Up" ,
        "Down" ,
        "Left" ,
        "Right" ,
        "F1" ,
        "F2" ,
        "F3" ,
        "F4" ,
        "F5" ,
        "F6" ,
        "F7" ,
        "F8" ,
        "F9" ,
        "BS" ,
        "Del" ,
        "Insert" ,
        "Home" ,
        "End" ,
        "PageUp" ,
        "PageDown" ,
        "Enter" ,
        "Tab" ,
        "Esc" ,
        "Bslash" ,
        "Space" ,
        "C-",
        "S-",
        "A-"
    ]

    assert len(printable) + len(other_mapping) <= 128, "key mapping can't exceed 128"

    ret = []
    for b in fuzzer_input:
        if b in printable:
            ret.append(chr(b))
            ret.append(0.1)
        else:
            # fail into other mapping
            printable_in_range = [x for x in printable if x<= b]
            other_mapping_idx = b - len(printable_in_range)
            ret.append(other_mapping[other_mapping_idx])
            ret.append(0.1)


    #return ret
    return [":q!<CR>"]


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
    print(f"fuzzer input is '{fuzzer_input.hex()}'")
    test_cmds= fuzzer_to_input(fuzzer_input)

    try:
        send_commands(nvim, test_cmds)
    except Exception as e:
        print(f"Exception: {e}")

    print("force exit")
    try:
        send_commands(nvim, force_quite_cmd())
    except Exception as e:
        print(f"Exception: {e}")

