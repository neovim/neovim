# vimspector - A multi-language debugging system for Vim
# Copyright 2019 Ben Jackson
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

from collections import defaultdict

import vim
import functools


class ProjectBreakpoints( object ):
  def __init__( self ):
    self._connection = None

    # These are the user-entered breakpoints.
    self._line_breakpoints = defaultdict( list )
    self._func_breakpoints = []

    self._next_sign_id = 1

    # TODO: Change to sign_define ?
    vim.command( 'sign define vimspectorBP text==> texthl=Error' )
    vim.command( 'sign define vimspectorBPDisabled text=!> texthl=Warning' )


  def ConnectionUp( self, connection ):
    self._connection = connection


  def ConnectionClosed( self ):
    self._connection = None

    # for each breakpoint:
      # clear its resolved status


  def ListBreakpoints( self ):
    # FIXME: Handling of breakpoints is a mess, split between _codeView and this
    # object. This makes no sense and should be centralised so that we don't
    # have this duplication and bug factory.
    qf = []
    if self._connection and self._codeView:
      qf = self._codeView.BreakpointsAsQuickFix()
    else:
      for file_name, breakpoints in self._line_breakpoints.items():
        for bp in breakpoints:
          qf.append( {
            'filename': file_name,
            'lnum': bp[ 'line' ],
            'col': 1,
            'type': 'L',
            'valid': 1 if bp[ 'state' ] == 'ENABLED' else 0,
            'text': "Line breakpoint - {}".format(
              bp[ 'state' ] )
          } )
      # I think this shows that the qf list is not right for this.
      for bp in self._func_breakpoints:
        qf.append( {
          'filename': '',
          'lnum': 1,
          'col': 1,
          'type': 'F',
          'valid': 1,
          'text': "Function breakpoint: {}".format( bp[ 'function' ] ),
        } )

    vim.eval( 'setqflist( {} )'.format( json.dumps( qf ) ) )

  def ToggleBreakpoint( self ):
    line, column = vim.current.window.cursor
    file_name = vim.current.buffer.name

    if not file_name:
      return

    found_bp = False
    for index, bp in enumerate( self._line_breakpoints[ file_name]  ):
      if bp[ 'line' ] == line:
        found_bp = True
        if bp[ 'state' ] == 'ENABLED':
          bp[ 'state' ] = 'DISABLED'
        else:
          if 'sign_id' in bp:
            vim.command( 'sign unplace {0} group=VimspectorBP'.format(
              bp[ 'sign_id' ] ) )
          del self._line_breakpoints[ file_name ][ index ]

    if not found_bp:
      self._line_breakpoints[ file_name ].append( {
        'state': 'ENABLED',
        'line': line,
        # 'sign_id': <filled in when placed>,
        #
        # Used by other breakpoint types:
        # 'condition': ...,
        # 'hitCondition': ...,
        # 'logMessage': ...
      } )

    self.UpdateUI()

  def AddFunctionBreakpoint( self, function ):
    self._func_breakpoints.append( {
        'state': 'ENABLED',
        'function': function,
    } )

    # TODO: We don't really have aanything to update here, but if we're going to
    # have a UI list of them we should update that at this point
    self.UpdateUI()


  def UpdateUI( self ):
    if self._connection:
      self.SendBreakpoints()
    else:
      self._ShowBreakpoints()

  def SendBreakpoints( self, handler ):
    for file_name, line_breakpoints in self._line_breakpoints.items():
      breakpoints = []
      for bp in line_breakpoints:
        if bp[ 'state' ] != 'ENABLED':
          continue

        if 'sign_id' in bp:
          vim.command( 'sign unplace {0} group=VimspectorBP'.format(
            bp[ 'sign_id' ] ) )
          del bp[ 'sign_id' ]

        breakpoints.append( { 'line': bp[ 'line' ] } )

      source = {
        'name': os.path.basename( file_name ),
        'path': file_name,
      }

      self._connection.DoRequest(
        functools.partial( self._UpdateBreakpoints, source ),
        {
          'command': 'setBreakpoints',
          'arguments': {
            'source': source,
            'breakpoints': breakpoints,
          },
          'sourceModified': False, # TODO: We can actually check this
        }
      )

    self._connection.DoRequest(
      functools.partial( self._UpdateBreakpoints, None ),
      {
        'command': 'setFunctionBreakpoints',
        'arguments': {
          'breakpoints': [
            { 'name': bp[ 'function' ] }
            for bp in self._func_breakpoints if bp[ 'state' ] == 'ENABLED'
          ],
        }
      }
    )

  def _ShowBreakpoints( self ):
    for file_name, line_breakpoints in self._line_breakpoints.items():
      for bp in line_breakpoints:
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0} group=VimspectorBP '.format(
            bp[ 'sign_id' ] ) )
        else:
          bp[ 'sign_id' ] = self._next_sign_id
          self._next_sign_id += 1

        vim.command(
          'sign place {0} group=VimspectorBP line={1} name={2} file={3}'.format(
            bp[ 'sign_id' ] ,
            bp[ 'line' ],
            'vimspectorBP' if bp[ 'state' ] == 'ENABLED'
                           else 'vimspectorBPDisabled',
            file_name ) )
