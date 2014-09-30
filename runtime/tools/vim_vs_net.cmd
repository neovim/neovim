@rem
@rem To use this with Visual Studio .Net
@rem Tools->External Tools...
@rem Add
@rem      Title     - Vim
@rem      Command   - d:\files\util\vim_vs_net.cmd
@rem      Arguments - +$(CurLine) $(ItemPath)
@rem      Init Dir  - Empty
@rem
@rem Courtesy of Brian Sturk
@rem
@rem --remote-silent +%1 is a command +954, move ahead 954 lines
@rem --remote-silent %2 full path to file
@rem In Vim
@rem    :h --remote-silent for more details
@rem
@rem --servername VS_NET
@rem This will create a new instance of vim called VS_NET.  So if you
open
@rem multiple files from VS, they will use the same instance of Vim.
@rem This allows you to have multiple copies of Vim running, but you can
@rem control which one has VS files in it.
@rem
start /b gvim.exe --servername VS_NET --remote-silent "%1"  "%2"
