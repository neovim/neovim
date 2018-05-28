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


class OutputView( object ):
  def __init__( self, window ):
    self._window = window
    self._buffers = {}

    self._CreateBuffer( 'stdout' )
    self.ShowOutput( 'stdout' )

  def OnOutput( self, event ):
    category = event[ 'category' ]
    if category not in self._buffers:
      self._CreateBuffer( category )

    with utils.ModifiableScratchBuffer( self._buffers[ category ] ):
      self._buffers[ category ].append( event[ 'output' ].splitlines() )

  def Clear( self ):
    for buf in self._buffers:
      self._buffers[ buf ] = None

  def ShowOutput( self, category ):
    vim.current.window = self._window
    vim.command( 'bu {0}'.format( self._buffers[ category ].name ) )

  def _CreateBuffer( self, category ):
    with utils.RestorCurrentWindow():
      vim.current.window = self._window

      vim.command( 'enew' )
      self._buffers[ category ] = vim.current.buffer
      self._buffers[ category ].append( category + '-----' )

      utils.SetUpHiddenBuffer( self._buffers[ category ],
                               'vimspector.Output:{0}'.format( category ) )

      vim.command( "nnoremenu WinBar.{0} "
                   ":call vimspector#ShowOutput( '{0}' )<CR>".format(
                     utils.Escape( category ) ) )
