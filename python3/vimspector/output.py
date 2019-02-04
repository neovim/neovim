# vimspector - A multi-language debugging system for Vim
# Copyright 2018 Ben Jackson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from vimspector import utils

import vim
import json


class TabBuffer( object ):
  def __init__( self, buf, index ):
    self.buf = buf
    self.index = index
    self.flag = False
    self.job = None


BUFFER_MAP = {
  'console': 'Console',
  'stdout': 'Console',
  'stderr': 'stderr',
  'telemetry': 'Telemetry',
}


def CategoryToBuffer( category ):
  return BUFFER_MAP.get( category, category )


class OutputView( object ):
  def __init__( self, connection, window ):
    self._window = window
    self._connection = connection
    self._buffers = {}

    for b in set( BUFFER_MAP.values() ):
      self._CreateBuffer( b )

    self._CreateBuffer(
      'Vimspector',
      file_name = vim.eval( 'expand( "~/.vimspector.log" )' ) )

    self._ShowOutput( 'Console' )

  def ServerEcho( self, text ):
    self._Print( 'server', text.splitlines() )

  def OnOutput( self, event ):
    category = CategoryToBuffer( event.get( 'category' ) or 'output' )
    text_lines = event[ 'output' ].splitlines()
    if 'data' in event:
      text_lines.extend( json.dumps( event[ 'data' ],
                                     indent = 2 ).splitlines() )

    self._Print( category, text_lines )

  def _Print( self, category, text_lines ):
    if category not in self._buffers:
      self._CreateBuffer( category )

    buf = self._buffers[ category ].buf

    with utils.ModifiableScratchBuffer( buf ):
      utils.AppendToBuffer( buf, text_lines )

    self._ToggleFlag( category, True )

    # Scroll the buffer
    with utils.RestoreCurrentWindow():
      with utils.RestoreCurrentBuffer( self._window ):
        self._ShowOutput( category )

  def ConnectionClosed( self ):
    self._connection = None

  def Reset( self ):
    self.Clear()

  def Clear( self ):
    for buf in self._buffers:
      vim.command( 'bwipeout! {0}'.format( self._buffers[ buf ].buf.name ) )

    if 'Vimspector' in self._buffers:
      if self._buffers[ 'Vimspector' ].job is not None:
        utils.TerminateJob( self._buffers[ 'Vimspector' ].job )

    self._buffers.clear()

  def _ShowOutput( self, category ):
    vim.current.window = self._window
    vim.command( 'bu {0}'.format( self._buffers[ category ].buf.name ) )
    vim.command( 'normal G' )

  def ShowOutput( self, category ):
    self._ToggleFlag( category, False )
    self._ShowOutput( category )

  def Evaluate( self, frame, expression ):
    if not frame:
      return

    console = self._buffers[ 'Console' ].buf
    utils.AppendToBuffer( console, 'Evaluating: ' + expression )

    def print_result( message ):
      utils.AppendToBuffer( console,
                            'Evaluated: ' + expression )

      result = message[ 'body' ][ 'result' ]
      if result is None:
        result = 'null'

      utils.AppendToBuffer( console, '  Result: ' + result )

    self._connection.DoRequest( print_result, {
      'command': 'evaluate',
      'arguments': {
        'expression': expression,
        'context': 'repl',
        'frameId': frame[ 'id' ],
      }
    } )

  def _ToggleFlag( self, category, flag ):
    if self._buffers[ category ].flag != flag:
      self._buffers[ category ].flag = flag
      with utils.RestoreCurrentWindow():
        vim.current.window = self._window
        self._RenderWinBar( category )

  def _CreateBuffer( self, category, file_name = None ):
    with utils.RestoreCurrentWindow():
      vim.current.window = self._window

      with utils.RestoreCurrentBuffer( self._window ):

        if file_name is not None:
          tab_buffer = TabBuffer( utils.BufferForFile( file_name ),
                                  len( self._buffers ) )
          tab_buffer.job = utils.SetUpTailBuffer( tab_buffer.buf, file_name )
          self._buffers[ category ] = tab_buffer
        else:
          vim.command( 'enew' )
          tab_buffer = TabBuffer( vim.current.buffer, len( self._buffers ) )
          self._buffers[ category ] = tab_buffer
          if category == 'Console':
            utils.SetUpPromptBuffer( tab_buffer.buf,
                                     'vimspector.Console',
                                     '> ',
                                     'vimspector#EvaluateConsole',
                                     hidden=True )
          else:
            utils.SetUpHiddenBuffer(
              tab_buffer.buf,
              'vimspector.Output:{0}'.format( category ) )

        self._RenderWinBar( category )

  def _RenderWinBar( self, category ):
    tab_buffer = self._buffers[ category ]

    try:
      if tab_buffer.flag:
        vim.command( 'nunmenu WinBar.{}'.format( utils.Escape( category ) ) )
      else:
        vim.command( 'nunmenu WinBar.{}*'.format( utils.Escape( category ) ) )
    except vim.error as e:
      # E329 means the menu doesn't exist; ignore that.
      if 'E329' not in str( e ):
        raise

    vim.command( "nnoremenu  1.{0} WinBar.{1}{2} "
                 ":call vimspector#ShowOutput( '{1}' )<CR>".format(
                   tab_buffer.index,
                   utils.Escape( category ),
                   '*' if tab_buffer.flag else '' ) )
