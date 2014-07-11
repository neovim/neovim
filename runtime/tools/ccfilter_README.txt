COMPILING AND INSTALLING:
=========================

To compile ccfilter, you can just do a plain:
    cc ccfilter.c -o ccfilter
Though, it may be wise to have your default compiler defined,
so you would normally compile it with one of the following:
    cc -D_GCC     ccfilter.c -o ccfilter
    cc -D_AIX     ccfilter.c -o ccfilter
    cc -D_ATT     ccfilter.c -o ccfilter
    cc -D_IRIX    ccfilter.c -o ccfilter
    cc -D_SOLARIS ccfilter.c -o ccfilter
    cc -D_HPUX    ccfilter.c -o ccfilter
You can then copy ccfilter to its target destination (i.e: /usr/local/bin).
The man page ccfilter.1 has to be copied to somewhere in your MANPATH,
under a man1 directory (i.e: /usr/local/man/man1).


SUPPORTED COMPILERS/PORTING NOTES:
==================================

The supported formats for the different compilers are described below:
In this section, meta-names are used as place-holders in the line
formats: <FILE> <ROW> <COL> <SEVERITY> <REASON> <>
The <> denotes ignored text.
Line formats are delimited by the ^ (caret) symbol.

0)  Special case: "gmake directory change" lines:
    Lines with a format like:
      ^gmake[<NUM>]: Entering directory `<DIR>'^
    are used to follow the directory changes during the make process,
    providing in the <FILE> part, a relative (if possible) directory
    path to the erroneous file.


1)  GCC:
    Recognized lines are of the format:
    - ^In file included from <FILE>:<ROW>:^
      Line following this one is used as <REASON>
      <SEVERITY> is always 'e' (error)
      <COL> is always '0'

    - ^<FILE>:<ROW>:<REASON>^
      <SEVERITY> is always 'e' (error)
      <COL> is always '0'


2)  AIX:
    Recognized lines are of the format:
    - ^"<FILE>", line <ROW>.<COL>: <> (<SEVERITY>) <REASON>",


3)  HPUX:
    Recognized lines are of the format:
    - ^cc: "<FILE>", line <ROW>: <SEVERITY>: <REASON>^
      <COL> is always '0'


4)  SOLARIS:
    Recognized lines are of the format:
    - ^"<FILE>", line <ROW>: warning: <REASON>^
      This assumes <SEVERITY> is "W"
      <COL> is always '0'

    - ^"<FILE>", line <ROW>: <REASON>^
      This assumes <SEVERITY> is "E"
      <COL> is always '0'


5)  ATT / NCR:
    Recognized lines are of the format:
    - ^<SEVERITY> "<FILE>",L<ROW>/C<COL><>:<REASON>^
			 or
    - ^<SEVERITY> "<FILE>",L<ROW>/C<COL>:<REASON>^
      Following lines beginning with a pipe (|) are continuation
      lines, and are therefore appended to the <REASON>

    - ^<SEVERITY> "<FILE>",L<ROW>:<REASON>^
      <COL> is '0'
      Following lines beginning with a pipe (|) are continuation
      lines, and are therefore appended to the <REASON>


6)  SGI-IRIX:
    Recognized lines are of the format:
    - ^cfe: <SEVERITY>: <FILE>: <ROW>: <REASON>^
			 or
      ^cfe: <SEVERITY>: <FILE>, line <ROW>: <REASON>^
      Following lines beginning with a dash (-) are "column-bar"
      that end with a caret in the column of the error. These lines
      are analyzed to generate the <COL>.
