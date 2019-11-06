try:
  from ycmd.extra_conf_support import IgnoreExtraConf
except ImportError:
  IgnoreExtraConf = None

import os.path as p

PATH_TO_THIS_DIR = p.dirname( p.abspath( __file__ ) )


def Settings( **kwargs ):
  if kwargs[ 'language' ] == 'json':
    return {
      'ls': {
        'json': {
          'schemas': [
            {
              'fileMatch': [ '.vimspector.json' ],
              'url':
                f'file://{PATH_TO_THIS_DIR}/docs/schema/vimspector.schema.json'
            },
            {
              'fileMatch': [ '.gadgets.json', '.gadgets.d/*.json' ],
              'url':
                f'file://{PATH_TO_THIS_DIR}/docs/schema/gadgets.schema.json'
            }
          ]
        }
      }
    }

  if IgnoreExtraConf:
    raise IgnoreExtraConf()

  return None
