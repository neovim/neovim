#!/usr/bin/env python3

import codecs
import enum
import os
import sys
from datetime import datetime
from enum import Enum
from functools import reduce

import msgpack


class EntryTypes(Enum):
    """
    An Enum for the entry types.
    """

    def _generate_next_value_(name, start, count, last_values):
        """
        Overriding the count value to start 
        from -1.
        """
        return count - 1

    UNKNOWN = enum.auto()
    MISSING = enum.auto()
    HEADER = enum.auto()
    SEARCH_PATTERN = enum.auto()
    SUB_STRING = enum.auto()
    HISTORY_ENTRY = enum.auto()
    REGISTER = enum.auto()
    VARIABLE = enum.auto()
    GLOBAL_MARK = enum.auto()
    JUMP = enum.auto()
    BUFFER_LIST = enum.auto()
    LOCAL_MARK = enum.auto()
    CHANGE = enum.auto()


def strtrans_errors(e: UnicodeDecodeError) -> tuple:
    """
    Responds to UnicodeDecodeErrors.

    Parameters:
        e: UnicodeDecodeError to respond to.
    """
    if not isinstance(e, UnicodeDecodeError):
        raise NotImplementedError(
            f"Don't know how to handle {e.__class__.__name__} error"
        )
    
    def callback(a, b):
        return a * 0x100 + b

    lst = list(e.object[e.start : e.end])
    return (
        "<{0:x}>".format(
            reduce(callback, lst)
        ),
        e.end,
    )


codecs.register_error("strtrans", strtrans_errors)


def idfunc(o):
    """
    Boilerplate callback to return same object.
    """
    return o


class CharInt(int):
    """
    A specialized CharInt class for slightly 
    different __repr__ output.
    """
    def __repr__(self):
        return super(CharInt, self).__repr__() + f" ('{chr(self)}')"  


C_TABLE = {
    bytes: lambda s: s.decode("utf-8", "strtrans"),
    dict: lambda d: dict((mnormalize(k), mnormalize(v)) for k, v in d.items()),
    list: lambda l: list(mnormalize(i) for i in l),
    int: lambda n: CharInt(n) if 0x20 <= n <= 0x7E else n,
}


def mnormalize(o):
    """
    mnormalizes given object.
    """
    return C_TABLE.get(type(o), idfunc)(o)


def _handle_cli_args(number: int, message: str) -> None:
    """
    A function to handle CLI arguments.
    """

    max_index = len(sys.argv) - 1

    if number > max_index:
        raise SystemExit(f"Error: {message}")
    
    return sys.argv[number]


def _handle_filt(number: int) -> None:
    """
    Handles filt.
    """
    try:
        filt = sys.argv[number]
    except IndexError:
        def filt(*args):
            return True
    else:
        _filt = filt

        def filt(entry):
            return eval(_filt, globals(), {"entry": entry})  # noqa

    return filt


class FullEntry(dict):
    """
    Custom FullEntry dictionary subclass.
    """
    def __init__(self, val):
        self.__dict__.update(val)


class Script:
    """
    A script class to handle the script.
    """

    def __init__(self) -> None:
        self.fname = _handle_cli_args(1, "Must pass in file.")
        self.filt = _handle_filt(2)
        self.pos_width = len(str(os.stat(self.fname).st_size or 1000))

    def _unpack(self):
        """
        Unpacks file.
        """
        with open(self.fname, "rb") as fp:
            unpacker = msgpack.Unpacker(file_like=fp, read_size=1)
            max_type = max(typ.value for typ in EntryTypes)

        return fp, unpacker, max_type

    def _loop(self, fp, unpacker, max_type) -> None:
        """
        Every iteration of the script.
        """

        try:
            pos = fp.tell()
            typ = unpacker.unpack()
        except msgpack.OutOfData:
            raise SystemExit
        else:
            timestamp = unpacker.unpack()
            time = datetime.fromtimestamp(timestamp)
            length = unpacker.unpack()
            if typ > max_type:
                entry = fp.read(length)
                typ = EntryTypes.UNKNOWN
            else:
                entry = unpacker.unpack()
                typ = EntryTypes(typ)

            full_entry = FullEntry(
                {
                    "value": entry,
                    "timestamp": timestamp,
                    "time": time,
                    "length": length,
                    "pos": pos,
                    "type": typ,
                }
            )

            if not self.filt(full_entry):
                return
            print(
                "%*u %13s %s %5u %r"
                % (self.pos_width, pos, typ.name, time.isoformat(), length, mnormalize(entry))
            )



    def run(self) -> None:
        """
        Runs the script.
        """
        fp, unpacker, max_type = self._unpack()
            
        while True:
            self._loop(fp, unpacker, max_type)


def main():
    script = Script()
    script.run()

main()
