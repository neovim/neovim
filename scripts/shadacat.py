#!/usr/bin/env python3.4

import sys
import codecs

from enum import Enum
from datetime import datetime
from functools import reduce

import msgpack


class EntryTypes(Enum):
  Unknown = -1
  Missing = 0
  Header = 1
  SearchPattern = 2
  SubString = 3
  HistoryEntry = 4
  Register = 5
  Variable = 6
  GlobalMark = 7
  Jump = 8
  BufferList = 9
  LocalMark = 10
  Change = 11


def strtrans_errors(e):
  if not isinstance(e, UnicodeDecodeError):
    raise NotImplementedError('don’t know how to handle {0} error'.format(
      e.__class__.__name__))
  return '<{0:x}>'.format(reduce((lambda a, b: a*0x100+b),
                                 list(e.object[e.start:e.end]))), e.end


codecs.register_error('strtrans', strtrans_errors)


def idfunc(o):
    return o


class CharInt(int):
    def __repr__(self):
        return super(CharInt, self).__repr__() + ' (\'%s\')' % chr(self)


ctable = {
    bytes: lambda s: s.decode('utf-8', 'strtrans'),
    dict: lambda d: dict((mnormalize(k), mnormalize(v)) for k, v in d.items()),
    list: lambda l: list(mnormalize(i) for i in l),
    int: lambda n: CharInt(n) if 0x20 <= n <= 0x7E else n,
}


def mnormalize(o):
  return ctable.get(type(o), idfunc)(o)


with open(sys.argv[1], 'rb') as fp:
  unpacker = msgpack.Unpacker(file_like=fp)
  while True:
    try:
      typ = EntryTypes(unpacker.unpack())
    except msgpack.OutOfData:
      break
    else:
      timestamp = unpacker.unpack()
      time = datetime.fromtimestamp(timestamp)
      length = unpacker.unpack()
      entry = unpacker.unpack()
      print('{0:13} {1} {2:5} {3!r}'.format(
        typ.name, time.isoformat(), length, mnormalize(entry)))
