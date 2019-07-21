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
import os
import logging

import json
from vimspector import utils


class ProjectBreakpoints( object ):
  def __init__( self ):
    self._connection = None
    self._logger = logging.getLogger( __name__ )
    utils.SetUpLogging( self._logger )

    # These are the user-entered breakpoints.
    self._line_breakpoints = defaultdict( list )
    self._func_breakpoints = []
    self._exceptionBreakpoints = None

    # FIXME: Remove this. Remove breakpoints nonesense from code.py
    self._breakpoints_handler = None
    self._server_capabilities = {}

    self._next_sign_id = 1

    # TODO: Change to sign_define ?
    vim.command( 'sign define vimspectorBP text==> texthl=Error' )
    vim.command( 'sign define vimspectorBPDisabled text=!> texthl=Warning' )


  def ConnectionUp( self, connection ):
    self._connection = connection


  def SetServerCapabilities( self, server_capabilities ):
    self._server_capabilities = server_capabilities


  def ConnectionClosed( self ):
    self._breakpoints_handler = None
    self._exceptionBreakpoints = None
    self._server_capabilities = {}
    self._connection = None
    self.UpdateUI()

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

  def ClearBreakpoints( self ):
    # These are the user-entered breakpoints.
    for file_name, breakpoints in self._line_breakpoints.items():
      for bp in breakpoints:
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0} group=VimspectorBP'.format(
            bp[ 'sign_id' ] ) )

    self._line_breakpoints = defaultdict( list )
    self._func_breakpoints = []
    self._exceptionBreakpoints = None

    self.UpdateUI()

  def ToggleBreakpoint( self ):
    line, column = vim.current.window.cursor
    file_name = vim.current.buffer.name

    if not file_name:
      return

    found_bp = False
    for index, bp in enumerate( self._line_breakpoints[ file_name ] ):
      if bp[ 'line' ] == line:
        found_bp = True
        if bp[ 'state' ] == 'ENABLED':
          bp[ 'state' ] = 'DISABLED'
        else:
          if 'sign_id' in bp:
            vim.command( 'sign unplace {0} group=VimspectorBP'.format(
              bp[ 'sign_id' ] ) )
          del self._line_breakpoints[ file_name ][ index ]

    self._logger.debug( "Toggle found bp at {}:{} ? {}".format(
      file_name,
      line,
      found_bp ) )

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


  def SetBreakpointsHandler( self, handler ):
    # FIXME: Remove this temporary compat .layer
    self._breakpoints_handler = handler


  def SendBreakpoints( self ):
    if not self._breakpoints_handler:
      def handler( source, msg ):
        return self._ShowBreakpoints()

      assert False
    else:
      handler = self._breakpoints_handler

    for file_name, line_breakpoints in self._line_breakpoints.items():
      breakpoints = []
      for bp in line_breakpoints:
        if 'sign_id' in bp:
          vim.command( 'sign unplace {0} group=VimspectorBP'.format(
            bp[ 'sign_id' ] ) )
          del bp[ 'sign_id' ]

        if bp[ 'state' ] != 'ENABLED':
          continue

        breakpoints.append( { 'line': bp[ 'line' ] } )

      source = {
        'name': os.path.basename( file_name ),
        'path': file_name,
      }

      self._connection.DoRequest(
        lambda msg: handler( source, msg ),
        {
          'command': 'setBreakpoints',
          'arguments': {
            'source': source,
            'breakpoints': breakpoints,
          },
          'sourceModified': False, # TODO: We can actually check this
        }
      )

    if self._server_capabilities.get( 'supportsFunctionBreakpoints' ):
      self._connection.DoRequest(
        lambda msg: handler( None, msg ),
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

    if self._exceptionBreakpoints is None:
      self._SetUpExceptionBreakpoints()

    if self._exceptionBreakpoints:
      self._connection.DoRequest(
        None, # There is nothing on the response to this
        {
          'command': 'setExceptionBreakpoints',
          'arguments': self._exceptionBreakpoints
        }
      )


  def _SetUpExceptionBreakpoints( self ):
    exceptionBreakpointFilters = self._server_capabilities.get(
        'exceptionBreakpointFilters',
        [] )

    if exceptionBreakpointFilters or not self._server_capabilities.get(
      'supportsConfigurationDoneRequest' ):
      exceptionFilters = []
      if exceptionBreakpointFilters:
        for f in exceptionBreakpointFilters:
          response = utils.AskForInput(
            "Enable exception filter '{}'? (Y/N)".format( f[ 'label' ] ) )

          if response == 'Y':
            exceptionFilters.append( f[ 'filter' ] )
          elif not response and f.get( 'default' ):
            exceptionFilters.append( f[ 'filter' ] )

      self._exceptionBreakpoints = {
        'filters': exceptionFilters
      }

      if self._server_capabilities.get( 'supportsExceptionOptions' ):
        # FIXME Sigh. The python debug adapter requires this
        #       key to exist. Even though it is optional.
        break_mode = utils.SelectFromList( 'When to break on exception?',
                                           [ 'never',
                                             'always',
                                             'unhandled',
                                             'userHandled' ] )

        if not break_mode:
          break_mode = 'unhandled'

        path = [ { 'nagate': True, 'names': [ 'DO_NOT_MATCH' ] } ]
        self._exceptionBreakpoints[ 'exceptionOptions' ] = [ {
          'path': path,
          'breakMode': break_mode
        } ]

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
