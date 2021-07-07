#!/usr/bin/env python


class TestClass( object ):
  def __init__( self, value ):
    self._var = value
    try:
      self.DoSomething()
    except ValueError:
      pass

  def DoSomething( self ):
    for i in range( 0, 100 ):
      if i < self._var:
        print( '{0} is less than the value'.format( i ) )
      else:
        print( '{0} might be more'.format( i ) )

    raise ValueError( 'Done' )


def Main():
  t = TestClass( 18 )

  t._var = 99
  t.DoSomething()


Main()
