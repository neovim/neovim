#!/bin/env python3
import pynvim
import os
import sys
import time


test_base = sys.argv[-1]
socket_path = os.path.join(test_base, "socket")
print(f"wait -{socket_path}-")
while os.path.exists(socket_path) is False:
    time.sleep(0.1)

print(f"here {socket_path}")
nvim = pynvim.attach('socket', path=socket_path)

nvim.input(":q<CR>")


#if __name__ == "__main__":
#    pass
