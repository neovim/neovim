#!/usr/bin/env python3

import sys

from collections import defaultdict
from enum import Enum


class ListAllocState(Enum):
  '''Allocation state, used to determine when list allocation was finished.'''
  just_created = ('allocating_known_amount', 'allocating_unknown_amount')
  '''ListHistory object was just created.'''
  allocating_known_amount = ('alloc_known_interrupted', 'alloc_known_finished')
  '''Currently in process of appending a known amount of items.'''
  allocating_unknown_amount = ('alloc_unknown_interrupted',
                               'unsure_allocating_unknown_amount')
  '''Currently in process of appending an unknown amount of items.

  This process may be interrupted by any action which is not an append to the 
  same list. This state may occur when “allocating” any negative amount of 
  elements, except for lists with kListLenUnknown length argument at allocation.
  '''
  unsure_allocating_unknown_amount = ('alloc_unsure_interrupted',)
  '''Like ``allocating_known_amount`` state, but after action involving *other* 
  list.

  This state is interrupted by any action on the same list which is not an 
  append.
  '''
  alloc_known_interrupted = (0,)
  '''Sequence of appends when processing known amount of items was interrupted.

  This state occurs only if sequnce of appends was interrupted before all 
  elements which were supposed to be appended were appended.
  '''
  alloc_known_finished = (1,)
  '''Sequence of appends when processing known amount of items was interrupted.

  This state occurs only if sequnce of appends proceeded until list was filled.
  '''
  alloc_unknown_interrupted = (2,)
  '''Sequence of appends when processing unknown amount of items was 
  interrupted.

  This state occurs only if sequence of appends was interrupted with non-append 
  action on the *same* list.
  '''
  alloc_unsure_interrupted = (3,)
  '''Sequence of appends when processing unknown amount of items was 
  interrupted.

  This state occurs only if sequence of appends was interrupted with non-append 
  action on the *other* list and then with non-append action on the same list.
  '''
  alloc_unknown = (4,)
  '''Amount of elements which will be allocated is not known in advance.'''
  alloc_static = (5,)
  '''Using static list.'''


class ListAllocLengthType(Enum):
  '''Class representing list allocation type
  '''
  alloc_known = (0,)
  '''Allocating known amount of elements.'''
  alloc_unknown = (1,)
  '''Allocating unknown amount of elements.

  See kListLenUnknown constant documentation for details.
  '''
  alloc_should_know = (2,)
  '''Allocating unknown amount of elments which should actually be known.

  See kListLenShouldKnow constant documentation for details.
  '''
  alloc_may_know = (3,)
  '''Allocating unknown amount of elments which may actually be known.

  See kListLenMayKnow constant documentation for details.
  '''


LIST_ACTIONS_MAP = {}
'''Dictionary mapping log actions to :class:`ListHistoryEntry` descendants.

Is populated by :class:`ListHistoryEntryMeta` class.
'''


class ListHistoryEntryMeta(type):
  '''Metaclass for ListHistoryEntry and descendants

  Used to populate a dictionary mapping actions to ListHistoryEntry descendants.
  '''
  def __new__(cls, name, bases, dct):
    ret = type.__new__(cls, name, bases, dct)
    if ret.action is not None:
      LIST_ACTIONS_MAP[ret.action] = ret
    return ret


class ListHistoryEntry(metaclass=ListHistoryEntryMeta):
  '''Class representing individual history entry

  Supposed to only provide a base class and not to be used directly.

  :param int length:
    List length.
  :param int arg1:
    First additional number.
  :param int arg2:
    Second additional number.
  '''

  action = None
  '''Action which creates history entry.'''

  def __init__(self, length, arg1, arg2):
    raise NotImplementedError()

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    By default only appends self to :attr:`ListHistory.history` and alters alloc 
    states.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    lhist.history.append(self)
    if lhist.alloc_state == ListAllocState.allocating_known_amount:
      lhist.alloc_state = ListAllocState.alloc_known_interrupted
    elif lhist.alloc_state == ListAllocState.allocating_unknown_amount:
      lhist.alloc_state = ListAllocState.alloc_unknown_interrupted
    elif lhist.alloc_state == ListAllocState.unsure_allocating_unknown_amount:
      lhist.alloc_state = ListAllocState.alloc_unsure_interrupted


class ListLenHistoryEntry(ListHistoryEntry):
  '''Class representing list length query

  :param int len:
    List length.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''

  action = 'len'

  def __init__(self, length, arg1, arg2):
    assert(arg1 == 0)
    assert(arg2 == 0)
    self.length = length
    '''Actual list length.'''


class ListFirstHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_first` query

  :param int len:
    List length.
  :param int arg1:
    First entry.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'first'

  def __init__(self, length, arg1, arg2):
    assert(arg2 == 0)
    self.length = length
    '''List length.'''
    self.first_entry = arg1
    '''Address of the first list entry.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally checks whether first entry in 
    :attr:`ListHistory.entries` is valid.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListFirstHistoryEntry, self).modhist(lhist)
    lhist.check_length(self.length)
    if self.first_entry != 0:
      if lhist.entries_valid:
        assert(lhist.entries[0] == self.first_entry)
      else:
        lhist.entries[0] = self.first_entry
    else:
      assert(lhist.length == 0)


class ListLastHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_last` query

  :param int len:
    List length.
  :param int arg1:
    Last entry.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'last'

  def __init__(self, length, arg1, arg2):
    assert(arg2 == 0)
    self.length = length
    '''List length.'''
    self.last_entry = arg1
    '''Address of the last list entry.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally checks whether last entry in 
    :attr:`ListHistory.entries` is valid.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListLastHistoryEntry, self).modhist(lhist)
    lhist.check_length(self.length)
    if self.last_entry != 0:
      if lhist.entries_valid:
        assert(lhist.entries[-1] == self.last_entry)
      else:
        lhist.entries[0] = self.first_entry
    else:
      assert(lhist.length == 0)


class ListIterHistoryEntry(ListHistoryEntry):
  '''Class representing start of TV_LIST_ITER cycle

  :param int len:
    List length.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'iter'

  def __init__(self, length, arg1, arg2):
    assert(arg1 == 0)
    assert(arg2 == 0)
    self.length = length
    '''Actual list length.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally checks whether :attr:`ListHistory.length` is valid.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    if not (lhist.history and lhist.history[-1].action == 'sort'):
      lhist.check_length(self.length)
    super(ListIterHistoryEntry, self).modhist(lhist)


class ListIterConstHistoryEntry(ListIterHistoryEntry):
  '''Class representing start of TV_LIST_ITER_CONST cycle

  :param int len:
    List length.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'iterconst'

  def __init__(self, length, arg1, arg2):
    assert(arg1 == 0)
    assert(arg2 == 0)
    self.length = length
    '''Actual list length.'''


class ListAllocHistoryEntry(ListHistoryEntry):
  '''Class representing allocation of a list

  :param int len:
    Unused, must be zero.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Allocation length.
  '''
  action = 'alloc'

  def __init__(self, length, arg1, arg2):
    assert(length == 0)
    assert(arg1 == 0)
    self.length = arg2 if arg2 < 0x8000000000000000 else None
    '''Assumed list length after allocation was performed.'''
    self.length_type = ({
      0xFFFFFFFFFFFFFFFF: ListAllocLengthType.alloc_unknown,
      0xFFFFFFFFFFFFFFFE: ListAllocLengthType.alloc_should_know,
      0xFFFFFFFFFFFFFFFD: ListAllocLengthType.alloc_may_know,
    }.get(arg2, ListAllocLengthType.alloc_known))
    '''Allocation type, see :class:`ListAllocLengthType` for details.
    '''
    assert(self.length is None
           or self.length_type is ListAllocLengthType.alloc_known)

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally initializes :attr:`ListHistory.alloc_todo` and 
    :attr:`ListHistory.alloc_state`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListAllocHistoryEntry, self).modhist(lhist)
    lhist.length = 0
    lhist.alloc_todo = self.length
    if self.length_type == ListAllocLengthType.alloc_known:
      lhist.alloc_state = ListAllocState.allocating_known_amount
      if self.length == 0:
        lhist.alloc_state = ListAllocState.alloc_known_finished
    elif (
      self.length_type == ListAllocLengthType.alloc_should_know
      or self.length_type == ListAllocLengthType.alloc_may_know
    ):
      lhist.alloc_state = ListAllocState.allocating_unknown_amount
    elif self.length_type == ListAllocLengthType.alloc_unknown:
      lhist.alloc_state = ListAllocState.alloc_unknown
    else:
      assert(False)


class ListS10InitHistoryEntry(ListHistoryEntry):
  '''Class representing initialization of a static list with 10 entries

  :param int len:
    Unused, must be ten.
  :param int arg1:
    Address of the first list entry.
  :param int arg2:
    Address of the last list entry.
  '''
  action = 's10init'

  def __init__(self, length, arg1, arg2):
    assert(length == 10)
    self.first_entry = arg1
    '''Address of the first list entry.'''
    self.last_entry = arg2
    '''Address of the last list entry.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally initializes :attr:`ListHistory.entries`, 
    :attr:`ListHistory.length` and :attr:`ListHistory.alloc_state`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListS10InitHistoryEntry, self).modhist(lhist)
    lhist.length = 10
    lhist.alloc_state = ListAllocState.alloc_static
    step = (self.last_entry - self.first_entry) // (lhist.length - 1)
    lhist.entries = list(range(self.first_entry, self.last_entry, step))


class ListSInitHistoryEntry(ListHistoryEntry):
  '''Class representing initialization of a static list

  This one without number of entries specified as they are initialized 
  elsewhere.

  :param int len:
    Unused, must be zero.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'sinit'

  def __init__(self, length, arg1, arg2):
    assert(length == 0)
    assert(arg1 == 0)
    assert(arg2 == 0)

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally initializes :attr:`ListHistory.alloc_state`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListSInitHistoryEntry, self).modhist(lhist)
    lhist.alloc_state = ListAllocState.alloc_static


class ListFreeContentsHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_free_contents` function call

  :param int len:
    List length before it was freed.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'freecont'

  def __init__(self, length, arg1, arg2):
    assert(arg1 == 0)
    assert(arg2 == 0)
    self.length = length
    '''List length before it was freed.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally resets :attr:`ListHistory.length`, 
    :attr:`ListHistory.entries` and :attr:`ListHistory.cached_idx`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListFreeContentsHistoryEntry, self).modhist(lhist)
    lhist.length = 0
    lhist.entries.clear()
    lhist.cached_idx = None


class ListFreeListHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_free_list` function call

  :param int len:
    List length when it was freed.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'freelist'

  def __init__(self, length, arg1, arg2):
    assert(arg1 == 0)
    assert(arg2 == 0)
    self.length = length
    '''List length when it was freed.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally sets :attr:`ListHistory.destroyed`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListFreeListHistoryEntry, self).modhist(lhist)
    lhist.destroyed = True


class ListDropItemsHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_drop_items` call

  This one is used just before entries are dropped.

  :param int len:
    List length before drop.
  :param int arg1:
    First entry to drop.
  :param int arg2:
    Last entry to drop.
  '''
  action = 'drop'

  def __init__(self, length, arg1, arg2):
    self.length = length
    '''List length before drop.'''
    self.first_entry = arg1
    '''Address of the first dropped list entry.'''
    self.last_entry = arg2
    '''Address of the last dropped list entry.'''
    self.drop_size = None
    '''Drop size, if entries were found successfully.

    Populated in :meth:`modhist`.
    '''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally modifies :attr:`ListHistory.entries` and 
    :attr:`ListHistory.length`, also clears :attr:`ListHistory.cached_idx`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListDropItemsHistoryEntry, self).modhist(lhist)
    lhist.cached_idx = None
    try:
      first_idx = lhist.entries.index(self.first_entry)
      last_idx = lhist.entries.index(self.last_entry)
    except ValueError:
      if lhist.entries_valid:
        raise
      if self.first_entry == self.last_entry:
        lhist.length = self.length - 1
        if lhist.entries:
          lhist.entries.pop()
        lhist.check_length(self.length)
    else:
      assert(first_idx <= last_idx)
      lhist.entries[first_idx:last_idx + 1] = ()
      self.drop_size = last_idx - first_idx + 1
      lhist.length -= self.drop_size


class ListAfterDropItemsHistoryEntry(ListHistoryEntry):
  '''Class representing end of :c:func:`tv_list_drop_items` call

  This one is used just after entries were dropped.

  :param int len:
    List length after drop.
  :param int arg1:
    First list entry after drop.
  :param int arg2:
    Last list entry after drop.
  '''
  action = 'afterdrop'

  def __init__(self, length, arg1, arg2):
    self.length = length
    '''List length after drop.'''
    self.first_entry = arg1
    '''Address of the first list entry after drop.'''
    self.last_entry = arg2
    '''Address of the last list entry after drop.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally checks :attr:`ListHistory.entries` and 
    :attr:`ListHistory.length`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListAfterDropItemsHistoryEntry, self).modhist(lhist)
    if lhist.entries_valid:
      assert(self.length == lhist.length)
      if self.first_entry == 0:
        assert(self.last_entry == 0)
        assert(self.length == 0)
        assert(len(lhist.entries) == 0)
      else:
        assert(self.first_entry == lhist.entries[0])
        assert(self.last_entry == lhist.entries[-1])
    else:
      lhist.check_length(self.length)


class ListRemoveItemsHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_remove_items` call

  This one is used just before entries are removed.

  :param int len:
    List length before removal.
  :param int arg1:
    First entry to remove.
  :param int arg2:
    Last entry to remove.
  '''
  action = 'remove'

  def __init__(self, length, arg1, arg2):
    self.length = length
    '''List length before removal.'''
    self.first_entry = arg1
    '''Address of the first removed list entry.'''
    self.last_entry = arg2
    '''Address of the last removed list entry.'''


class ListMoveItemsHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_move_items` call

  This one is used just before entries are removed.

  :param int len:
    List length before move.
  :param int arg1:
    First entry to move.
  :param int arg2:
    Last entry to move.
  '''
  action = 'move'

  last_moved_items = []
  '''Last moved items.

  List used as a global variable in order to communicate between subsequent 
  :class:`ListMoveItemsHistoryEntry` and :class:`ListAfterMoveItemsHistoryEntry` 
  calls.
  '''

  def __init__(self, length, arg1, arg2):
    self.length = length
    '''List length before move.'''
    self.first_entry = arg1
    '''Address of the first moved list entry.'''
    self.last_entry = arg2
    '''Address of the last moved list entry.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally saves moved entries in a global to be used in 
    :class:`ListAfterMoveItemsHistoryEntry`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListMoveItemsHistoryEntry, self).modhist(lhist)
    first_idx = lhist.entries.index(self.first_entry)
    last_idx = lhist.entries.index(self.last_entry)
    assert(first_idx <= last_idx)
    self.last_moved_items.append(lhist.entries[first_idx:last_idx + 1])


class ListAfterMoveItemsHistoryEntry(ListMoveItemsHistoryEntry):
  '''Class representing end of :c:func:`tv_list_move_items` call

  This one is used just after entries were removed and document which list they 
  were moved to.

  :param int len:
    List length.
  :param int arg1:
    First target list entry.
  :param int arg2:
    Last target list entry.
  '''
  action = 'movetgt'

  def __init__(self, length, arg1, arg2):
    self.length = length
    '''Target list length.'''
    self.first_entry = arg1
    '''Address of the first target list entry.'''
    self.last_entry = arg2
    '''Address of the last target list entry.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally appends moved entries from a global and verifies that 
    :attr:`ListHistory.length` and :attr:`ListHistory.entries` match 
    expectations.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    # Do not use super() here, need a grandparent.
    ListHistoryEntry.modhist(self, lhist)
    last_moved_items = self.last_moved_items.pop()
    lhist.entries += last_moved_items
    lhist.length += len(last_moved_items)
    assert(lhist.entries)
    assert(lhist.length == self.length)
    assert(lhist.entries[0] == self.first_entry)
    assert(lhist.entries[-1] == self.last_entry)


class ListInsertHistoryEntry(ListHistoryEntry):
  '''Class representing entry insertion to a location other then the end

  :param int len:
    List length after insertion.
  :param int arg1:
    Inserted entry.
  :param int arg2:
    Entry to insert before.
  '''
  action = 'insert'

  def __init__(self, length, arg1, arg2):
    self.length = length
    '''List length after insertion.'''
    self.inserted_entry = arg1
    '''Address of the inserted list entry.'''
    self.next_entry = arg2
    '''Address of the list entry before which to insert.'''
    self.entry_idx = None
    '''Index of the list entry to insert before, if found.

    Populated in :meth:`modhist`.
    '''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally inserts entry to :attr:`ListHistory.entries`, adjusts 
    :attr:`ListHistory.length` and verifies it, also adjusts 
    :attr:`ListHistory.cached_idx`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListInsertHistoryEntry, self).modhist(lhist)
    try:
      idx = lhist.entries.index(self.next_entry)
    except IndexError:
      if lhist.entries_valid:
        raise
      lhist.length += 1
      lhist.entries.append(None)
    else:
      self.entry_idx = idx
      if lhist.cached_idx is not None:
        if idx == 0:
          lhist.cached_idx += 1
        else:
          lhist.cached_idx = None
      lhist.entries.insert(idx, self.inserted_entry)
      lhist.length += 1
      assert(lhist.length == self.length)


class ListAppendHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_append` call

  :param int len:
    List length before appending.
  :param int arg1:
    Appended entry.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'append'

  def __init__(self, length, arg1, arg2):
    assert(arg2 == 0)
    self.length = length
    '''List length before appending.'''
    self.appended_entry = arg1
    '''Address of the appended list entry.'''
    self.allocating = None
    '''True if append is believed to belong to list “allocation”.

    Populated below in :meth:`modhist`.
    '''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one appends history entry to :attr:`ListHistory.history`, appends entry 
    to :attr:`ListHistory.entries` and processes 
    :attr:`ListHistory.alloc_state`, :attr:`ListHistory.alloc_len` and 
    :attr:`ListHistory.alloc_todo`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    # Do not use super() here, parent does unwanted things with alloc_* 
    # attributes.
    lhist.history.append(self)
    lhist.entries.append(self.appended_entry)
    lhist.length += 1
    if lhist.alloc_state in (
      ListAllocState.allocating_unknown_amount,
      ListAllocState.unsure_allocating_unknown_amount,
    ):
      lhist.alloc_len += 1
      self.allocating = True
    elif lhist.alloc_state is ListAllocState.allocating_known_amount:
      lhist.alloc_todo -= 1
      lhist.alloc_len += 1
      self.allocating = True
      if not lhist.alloc_todo:
        lhist.alloc_state = ListAllocState.alloc_known_finished
    else:
      self.allocating = False
    lhist.check_length(self.length + 1)


class ListReverseHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_reverse` function call

  :param int len:
    List length.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'reverse'

  def __init__(self, length, arg1, arg2):
    assert(arg1 == 0)
    assert(arg2 == 0)
    self.length = length
    '''List length.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally reverses entries in :attr:`ListHistory.entries`, 
    verifies :attr:`ListHistory.length` and alters 
    :attr:`ListHistory.cached_idx`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListReverseHistoryEntry, self).modhist(lhist)
    lhist.check_length(self.length)
    lhist.entries.reverse()
    if lhist.cached_idx is not None:
      lhist.cached_idx = lhist.length - lhist.cached_idx - 1


class ListSortHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_item_sort` function call

  :param int len:
    List length.
  :param int arg1:
    Unused, must be zero.
  :param int arg2:
    Unused, must be zero.
  '''
  action = 'sort'

  def __init__(self, length, arg1, arg2):
    assert(arg1 == 0)
    assert(arg2 == 0)
    self.length = length
    '''List length.'''

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally drops entries from :attr:`ListHistory.entries`, 
    verifies :attr:`ListHistory.length` and sets it to zero. 
    :attr:`ListHistory.entries` will be in any case populated by appending. Also 
    unsets :attr:`ListHistory.cached_idx`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListSortHistoryEntry, self).modhist(lhist)
    if lhist.entries_valid:
      assert(lhist.length == self.length)
    else:
      lhist.entries_valid = True
    lhist.entries.clear()
    lhist.length = 0
    lhist.cached_idx = None


class ListFindHistoryEntry(ListHistoryEntry):
  '''Class representing :c:func:`tv_list_find` query

  :param int len:
    List length.
  :param int arg1:
    Found entry.
  :param int arg2:
    Normalized index.
  '''
  action = 'find'

  def __init__(self, length, arg1, arg2):
    self.length = length
    '''List length.'''
    self.entry = arg1
    '''Address of the found list entry.'''
    self.index = arg2
    '''Normalized index which was seeked for.'''
    self.cached_idx = None
    '''Index which was cached at the time find action occurred.

    May be ``None`` if no cache is present.

    Populated below in :meth:`modhist`.
    '''
    assert(0 <= self.index < self.length)

  def modhist(self, lhist):
    '''Modify ListHistory according to the entry specifics

    This one additionally sets :attr:`ListHistory.cached_idx` and verifies 
    :attr:`ListHistory.length` and :attr:`ListHistory.entries`.

    :param ListHistory lhist:
      :class:`ListHistory` instance to modify.
    '''
    super(ListFindHistoryEntry, self).modhist(lhist)
    self.cached_idx = lhist.cached_idx
    lhist.check_length(self.length)
    if lhist.entries_valid:
      assert(lhist.entries[self.index] == self.entry)
    else:
      lhist.entries[self.index] = self.entry
    lhist.cached_idx = self.index


class ListHistory:
  '''Class representing a history of individual list

  :param int address:
    List address.
  :param int dupcnt:
    Number of lists with the same address.
  :param bool alloc_point_known:
    True if alloc/sinit/s10init action was the one introducing list.
  '''

  def __init__(self, address, dupcnt, alloc_point_known):
    self.address = address
    '''List address, integer.'''
    self.dupcnt = dupcnt
    '''Number of lists with the same address encountered so far, integer.'''
    self.length = 0
    '''Assumed list length.'''
    self.maxlength = float('-inf')
    '''Maximal length list ever encountered in its lifetime.'''
    self.minlength = None
    '''Minimal length list ever encountered after “allocation” was finished.'''
    self.destroyed = False
    '''True if list was already freed, False otherwise.

    Allows determining when to allocate a new object with increased 
    :attr:`dupcnt`.
    '''
    self.history = []
    '''List usage history, contains :class:`ListHistoryEntry` objects.'''
    self.cached_idx = None
    '''Index which is supposed to be currently cached one.'''
    self.alloc_len = 0
    '''Allocated len based on a sequence of appends just after alloc.

    May be different from the length got out of the alloc log entry.
    '''
    self.alloc_state = ListAllocState.just_created
    '''List alloc state, :class:`ListAllocState`.'''
    self.alloc_todo = None
    '''Number of list items still to allocate.'''
    self.entries = []
    '''List of list entries addresses in order they apper in the class.'''
    self.entries_valid = alloc_point_known
    '''Specifies whether :attr:`entries` is valid, as well as some other 
    attributes.'''

  def add(self, pline):
    '''Add one history line

    :param ParsedLine pline:
      History line to add.
    '''
    ActionClass = LIST_ACTIONS_MAP[pline.action]
    hline = ActionClass(pline.length, pline.arg1, pline.arg2)
    hline.modhist(self)
    if self.length > self.maxlength:
      self.maxlength = self.length
    if self.alloc_state in {
      ListAllocState.alloc_known_interrupted,
      ListAllocState.alloc_known_finished,
      ListAllocState.alloc_unknown_interrupted,
      ListAllocState.alloc_unsure_interrupted,
    }:
      if self.minlength is None or self.minlength > self.length:
        self.minlength = self.length

  def check_length(self, length):
    '''Verify or adjust :attr:`entries` and :attr:`length`

    Adjustment happens when :attr:`entries_valid` is false, otherwise it does 
    verification.

    :param int length:
      Length :attr:`entries` is supposed to have, also recorded in 
      :attr:`length`.
    '''
    if self.entries_valid:
      assert(self.length == length)
      assert(len(self.entries) == length)
    else:
      self.length = length
      if len(self.entries) > length:
        self.entries[length:] = ()
      elif len(self.entries) < length:
        self.entries += [None] * (length - len(self.entries))
      if length == 0:
        assert(not self.entries)
        self.entries_valid = True


class ParsedLine:
  '''Class representing parsed line without attaching specific meaning to args

  :param str line:
    Line to parse. Assumed format::

      {act}: l:{addr}[{len}] 1:{arg1} 2:{arg2}

    where ``{act}`` is left-aligned action performed on list, ``{addr}`` is list
    address represented as a zero-padded 64-bit hexadecimal integer, ``{len}`` 
    is list length represented as 8 decimal digits (zero-padded) and ``{arg1}`` 
    and ``{arg2}`` are 64-bit zero-padded hexadecimal integers with meaning 
    specific to an action.
  '''
  def __init__(self, action, address, length, arg1, arg2):
    self.action = action
    '''Action performed on list.'''
    self.address = address
    '''List address.'''
    self.length = length
    '''List length.'''
    self.arg1 = arg1
    '''First additional logged number.'''
    self.arg2 = arg2
    '''Second additional logged number.'''

  @classmethod
  def parse(cls, line):
    '''Parse one line of a log file

    Does most of a job of :func:`parseline` without adding parsed line to any 
    history or converting it into :class:`ListHistoryEntry` descendant.
    '''
    line = line[:-1]
    action, rest = line.partition(': ')[::2]
    action = action.rstrip(' ')
    addrlen, arg1, arg2 = rest.split(' ')
    address, length = addrlen[:-1].split('[')
    address = int(address[2:], 16)
    length = int(length, 10)
    arg1 = int(arg1[2:], 16)
    arg2 = int(arg2[2:], 16)
    return cls(action, address, length, arg1, arg2)

  def __repr__(self):
    return '{}({!r}, 0x{:016x}, {}, {}, {})'.format(
      self.__class__.__name__, self.action, self.address, self.length,
      self.arg1, self.arg2)


class ListSessionHistory:
  '''Class representing history of an entire Neovim session
  '''

  def __init__(self):
    self.listhist = defaultdict(list)
    '''Dictionary with histories of individual lists.

    Each dictionary uses list addresses as keys and lists of 
    :class:`ListHistory` objects as values. Order of actions upon different 
    lists is not kept.

    .. note:: Due to the fact that after freeing a list another one may be 
              allocated with the same address there is a list of 
              :class:`ListHistory` objects and not a single one.
    '''


  def parseline(self, line):
    '''Parse one line of a log file

    Line is assumed to come from iterating over a file, meaning that it must 
    have trailing newline.

    :param str line:
      Line to parse. See :class:`ParsedLine` for more details.

    :return: Last modified :class:`ListHistory`.
    '''
    pline = ParsedLine.parse(line)
    lhistlist = self.listhist[pline.address]
    if (
      not lhistlist
      or lhistlist[-1].destroyed
      or pline.action in ('sinit', 's10init')
    ):
      lhist = ListHistory(pline.address, len(lhistlist),
                          pline.action in ('alloc', 'sinit', 's10init'))
      lhistlist.append(lhist)
    else:
      lhist = lhistlist[-1]
    lhist.add(pline)
    return lhist

  def parsefile(self, fp):
    '''Parse the whole file

    :param file fp:
      File opened for reading in text mode.
    '''
    prev_lhist = None
    for line in fp:
      lhist = self.parseline(line)
      if prev_lhist is not lhist and prev_lhist:
        if prev_lhist.alloc_state is ListAllocState.allocating_unknown_amount:
          prev_lhist.alloc_state = (
            ListAllocState.unsure_allocating_unknown_amount)
      prev_lhist = lhist


def main(args):
  if args[0] == '--help':
    print('Usage: parselog.py log_fname')
    return 0
  lses = ListSessionHistory()
  with open(args[0], 'r') as fp:
    lses.parsefile(fp)
  # FIXME: Do something with results
  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
