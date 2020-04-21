import os
import re
import subprocess
import sys

script_path = os.path.abspath(__file__)
base_dir = os.path.dirname(os.path.dirname(script_path))
lua2dox_filter = os.path.join(base_dir, "scripts", "lua2dox_filter")


def filter_source(filename):
    name, extension = os.path.splitext(filename)
    if extension == ".lua":
        p = subprocess.run([lua2dox_filter, filename], stdout=subprocess.PIPE)
        op = "?" if 0 != p.returncode else p.stdout.decode("utf-8")
        print(op)
    else:
        """Filters the source to fix macros that confuse Doxygen."""
        with open(filename, "rt") as fp:
            print(
                re.sub(
                    r"^(ArrayOf|DictionaryOf)(\(.*?\))",
                    lambda m: m.group(1) + "_".join(re.split(r"[^\w]+", m.group(2))),
                    fp.read(),
                    flags=re.M,
                )
            )


if __name__ == "__main__":
    if len(sys.argv) > 2:
        print("Only one file can be passed at a time.")
        print("\t", sys.argv)
        sys.exit(1)
    elif len(sys.argv) == 1:
        print("One file is required to be passed.")
        sys.exit(1)

    filter_source(sys.argv[1])
