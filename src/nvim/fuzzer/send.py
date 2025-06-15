#!/bin/env python3
import pynvim
import string
import os
import sys
import time
#import psutil
#
#def monitor_ppid():
#    while True:
#        ppid = os.getppid()
#        if not psutil.pid_exists(ppid):
#            os._exit(0)
#        time.sleep(0.1)




def prepare(test_base, fuzzer_bin):
    assert os.path.exists(fuzzer_bin), f"{fuzzer_bin} don't exists"
    socket_path = os.path.join(test_base, "socket")

    while not os.path.exists(socket_path):
        time.sleep(0.1)

    assert os.path.exists(socket_path)
    print(f"use nvim --remote-ui --server {socket_path} for debugging")
    nvim = pynvim.attach("socket", path=socket_path)

    fuzzer_input = open(fuzzer_bin, "rb").read()
    return nvim, fuzzer_input


def fuzzer_to_input(fuzzer_input: bytes):
    printable = set(ord(x) for x in string.printable)

    # following code taken from neovim-qt input
    other_mapping = [
        "Up",
        "Down",
        "Left",
        "Right",
        "F1",
        "F2",
        "F3",
        "F4",
        "F5",
        "F6",
        "F7",
        "F8",
        "F9",
        "BS",
        "Del",
        "Insert",
        "Home",
        "End",
        "PageUp",
        "PageDown",
        "Enter",
        "Tab",
        "Esc",
        "Bslash",
        "Space",
        "C-",
        "S-",
        "A-",
    ]

    assert len(printable) + len(other_mapping) <= 128, "key mapping can't exceed 128"

    ret = []
    for b in fuzzer_input:
        if b in printable:
            ret.append(chr(b))
            ret.append(0.1)
        else:
            # fail into other mapping
            printable_in_range = [x for x in printable if x <= b]
            other_mapping_idx = b - len(printable_in_range)
            print(f"{other_mapping_idx}, {len(other_mapping)}",flush=True)
            idx = other_mapping_idx % len(other_mapping)
            ret.append(other_mapping[idx])
            ret.append((other_mapping_idx - idx) * 0.01)

    return ret
    # return [":q!<CR>"]


def force_quite_cmd():
    return ["<Esc>", 1, "<C-c>", 1, ":qall!<CR>", 1] * 3


def send_commands(nvim, cmds):
    for command_or_sleep in cmds:
        if isinstance(command_or_sleep, str):
            nvim.input(command_or_sleep)
        else:
            time.sleep(command_or_sleep)


if __name__ == "__main__":
    test_base, fuzz_bin = sys.argv[-2], sys.argv[-1]

    nvim, fuzzer_input = prepare(test_base, fuzz_bin)
    print(f"fuzzer input is '{fuzzer_input.hex()}'")
    test_cmds = fuzzer_to_input(fuzzer_input)

    print(f"test_cmds: {test_cmds}")
    try:
        send_commands(nvim, test_cmds)
    except Exception as e:
        print(f"Exception: {e}")

    if os.getenv("SKIP_CLEANUP") is None:
        print("force exit")
        try:
            # pdb.set_trace()
            send_commands(nvim, force_quite_cmd())
        except Exception as e:
            print(f"Exception: {e}")
