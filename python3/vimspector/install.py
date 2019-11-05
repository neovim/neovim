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

import platform
import os


def GetOS():
  if platform.system() == 'Darwin':
    return 'macos'
  elif platform.system() == 'Windows':
    return 'windows'
  else:
    return 'linux'


def GetGadgetDir( vimspector_base, OS ):
  return os.path.join( os.path.abspath( vimspector_base ), 'gadgets', OS )


def GetGadgetConfigFile( vimspector_base ):
  return os.path.join( GetGadgetDir( vimspector_base, GetOS() ),
                       '.gadgets.json' )


def GetGadgetConfigDir( vimspector_base ):
  return os.path.join( GetGadgetDir( vimspector_base, GetOS() ),
                       '.gadgets.d' )
