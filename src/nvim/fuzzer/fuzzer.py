import pynvim
import subprocess

process = subprocess.Popen(["nvim","--embed","--headless","--listen", "/tmp/nvim.sock"])

nvim = pynvim.attach('socket', path='/tmp/nvim.sock')
