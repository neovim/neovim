#!/usr/bin/env python3

import os
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


fname = sys.argv[1]
try:
  filt = sys.argv[2]
except IndexError:
  filt = lambda entry: True
else:
  _filt = filt
  filt = lambda entry: eval(_filt, globals(), {'entry': entry})

poswidth = len(str(os.stat(fname).st_size or 1000))


class FullEntry(dict):
  def __init__(self, val):
    self.__dict__.update(val)


with open(fname, 'rb') as fp:
  unpacker = msgpack.Unpacker(file_like=fp, read_size=1)
  max_type = max(typ.value for typ in EntryTypes)
  while True:
    try:
      pos = fp.tell()
      typ = unpacker.unpack()
    except msgpack.OutOfData:
      break
    else:
      timestamp = unpacker.unpack()
      time = datetime.fromtimestamp(timestamp)
      length = unpacker.unpack()
      if typ > max_type:
        entry = fp.read(length)
        typ = EntryTypes.Unknown
      else:
        entry = unpacker.unpack()
        typ = EntryTypes(typ)
      full_entry = FullEntry({
        'value': entry,
        'timestamp': timestamp,
        'time': time,
        'length': length,
        'pos': pos,
        'type': typ,
      })
      if not filt(full_entry):
        continue
      print('%*u %13s %s %5u %r' % (
        poswidth, pos, typ.name, time.isoformat(), length, mnormalize(entry)))
