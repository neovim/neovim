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

import vim
from functools import partial

from vimspector import utils


class VariablesView( object ):
  def __init__( self, connection, buf ):
    self._buf = buf
    self._connection = connection
    self._line_to_variable = {}

    # This is actually the tree (scopes are alwyas the root)
    #  it's just a list of DAP scope dicts, with one magic key (_variables)
    #  _variables is a list of DAP variable with the same magic key
    #
    # If _variables is present, then we have requested and should display the
    # children. Otherwise, we haven't or shouldn't.
    self._scopes = []

    # This is basically the same as scopes, but the top level is an "expression"
    self._watches = []

    vim.current.buffer = buf
    vim.command(
      'nnoremap <buffer> <CR> :call vimspector#ExpandVariable()<CR>' )

    utils.SetUpScratchBuffer( self._buf )

  def Clear( self ):
    with utils.ModifiableScratchBuffer( self._buf ):
      self._buf[:] = None

  def LoadScopes( self, frame ):
    def scopes_consumer( message ):
      self._scopes = []
      for scope in message[ 'body' ][ 'scopes' ]:
        self._scopes.append( scope )
        self._connection.DoRequest( partial( self._ConsumeVariables, scope ), {
          'command': 'variables',
          'arguments': {
            'variablesReference': scope[ 'variablesReference' ]
          },
        } )

      self._DrawScopesAndWatches()

    self._connection.DoRequest( scopes_consumer, {
      'command': 'scopes',
      'arguments': {
        'frameId': frame[ 'id' ]
      },
    } )

  def AddWatch( self, frame, expression ):
    watch = {
        'expression': expression,
        'frameId': frame[ 'id' ],
        'context': 'watch',
    }
    self._watches.append( watch )
    self.EvaluateWatches()

  def EvaluateWatches( self ):
    for watch in self._watches:
      self._connection.DoRequest( partial( self._UpdateWatchExpression,
                                           watch ), {
        'command': 'evaluate',
        'arguments': watch,
      } )

  def _UpdateWatchExpression( self, watch, message ):
    watch[ 'result' ] = message[ 'body' ]
    if 'variablesReference' in watch[ 'result' ]:
      self._connection.DoRequest(
        partial( self._ConsumeVariables, watch[ 'result' ] ), {
          'command': 'variables',
          'arguments': {
            'variablesReference': watch[ 'result' ][ 'variablesReference' ]
          },
        } )

    self._DrawScopesAndWatches()

  def ExpandVariable( self ):
    if vim.current.window.buffer != self._buf:
      return

    current_line = vim.current.window.cursor[ 0 ]
    if current_line not in self._line_to_variable:
      return

    variable = self._line_to_variable[ current_line ]
    if '_variables' in variable:
      del variable[ '_variables' ]
      self._DrawScopesAndWatches()
    else:
      self._connection.DoRequest( partial( self._ConsumeVariables, variable ), {
        'command': 'variables',
        'arguments': {
          'variablesReference': variable[ 'variablesReference' ]
        },
      } )

  def _DrawVariables( self, variables, indent ):
    for variable in variables:
      self._buf.append(
        '{indent}{icon} {name} ({type_}): {value}'.format(
          indent = ' ' * indent,
          icon = '+' if ( variable[ 'variablesReference' ] > 0 and
                          '_variables' not in variable ) else '-',
          name = variable[ 'name' ],
          type_ = variable.get( 'type', '<unknown type>' ),
          value = variable[ 'value' ] ).split( '\n' ) )
      self._line_to_variable[ len( self._buf ) ] = variable

      if '_variables' in variable:
        self._DrawVariables( variable[ '_variables' ], indent + 2 )

  def _DrawScopesAndWatches( self ):
    self._line_to_variable = {}
    with utils.RestoreCursorPosition():
      with utils.ModifiableScratchBuffer( self._buf ):
        self._buf[:] = None
        for scope in self._scopes:
          self._buf.append( 'Scope: ' + scope[ 'name' ] )
          if '_variables' in scope:
            indent = 2
            self._DrawVariables( scope[ '_variables' ], indent )

        self._buf.append( 'Watches: ----' )
        for watch in self._watches:
          self._buf.append( 'Expression: ' + watch[ 'expression' ] )
          if 'result' in watch:
            result = watch[ 'result' ]
            line =  '  Result: ' + result[ 'result' ]
            self._buf.append( line.split( '\n' ) )
            if '_variables' in result:
              indent = 4
              self._DrawVariables( result[ '_variables' ], indent )

  def _ConsumeVariables( self, parent, message ):
    for variable in message[ 'body' ][ 'variables' ]:
      if '_variables' not in parent:
        parent[ '_variables' ] = []

      parent[ '_variables' ].append( variable )

    self._DrawScopesAndWatches()
