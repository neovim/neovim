" Macros to play Conway's Game of Life in vi
" Version 1.0m: edges wrap
" by Eli-the-Bearded Benjamin Elijah Griffin <vim@eli.users.panix.com>
" Sept 1996
" This file may be free distributed so long as these credits remain unchanged.
"
" Modified by Bram Moolenaar (Bram@vim.org), 1996 Sept 10
" - Made it quite a bit faster, but now needs search patterns in the text
" - Changed the order of mappings to top-down.
" - Made "g" run the whole thing, "C" run one generation.
" - Added support for any uppercase character instead of 'X'
"
" Rules:
"   If a germ has 0 or 1 live neighbors it dies of loneliness
"   If a germ has 2 or 3 live neighbors it survives
"   If a germ has 4 to 8 live neighbors it dies of starvation
"   If an empty box has 3 live neighbors a new germ is born
"
"   A new born germ is an "A".	Every generation it gets older: B, C, etc.
"   A germ dies of old age when it reaches "Z".
"
" Notice the rules do not mention edges. This version has the edges wrap
" around. I have an earlier version that offers the option of live edges or
" dead edges. Email me if you are interested. -Eli-
"
" Note: This is slow!  One generation may take up to ten minutes (depends on
" your computer and the vi version).
"
" Quite a lot of the messy stuff is to work around the vi error "Can't yank
" inside global/macro".  Still doesn't work for all versions of vi.
"
" To use these macros:
"
" vi		start vi/vim
"
" :so life.mac	Source this file
"
" g		'g'o!  runs everything until interrupted: "IR".
"
" I		Initialize everything. A board will be drawn at the end
"		of the current buffer. All line references in these macros
"		are relative to the end of the file and playing the game
"		can be done safely with any file as the current buffer.
"
"	Change the left field with spaces and uppercase letters to suit
"	your taste.
"
" C		'C'ompute one generation.
" +		idem, time running one generation.
" R		'R'un 'C'ompute until interrupted.
" i<nr><Esc>z	Make a number the only thing on the current line and use
"		'z' to time that many generations.
"
" Time to run 30 generations on my 233 AMD K6 (FreeBSD 3.0):
"   vim   5.4 xterm	51 sec
"   gvim  5.4 Athena	42 sec
"   gvim  5.4 Motif	42 sec
"   gvim  5.4 GTK	50 sec
"   nvi   1.79 xterm	58 sec
"   vi	  3.7 xterm	2 min 30 sec
"   Elvis 2.1 xterm	7 min 50 sec
"   Elvis 2.1 X11	6 min 31 sec
"
" Time to run 30 generations on my 850 AMD Duron (FreeBSD 4.2):
"   vim   5.8   xterm    21 sec
"   vim   6.0   xterm    24 sec
"   vim   6.0   Motif    32 sec
"   nvi   1.79  xterm	 29 sec
"   vi    3.7   xterm    32 sec
"   elvis 2.1.4 xterm    34 sec
"
" And now the macros, more or less in top-down order.
"
"  ----- macros that can be used by the human -----
"
" 'g'o: 'I'nitialize and then 'R'un 'C'ompute recursively (used by the human)
map g IR
"
"
" 'R'un 'C'ompute recursively (used by the human and 'g'o)
map R CV
" work around "tail recursion" problem in vi, "V" == "R".
map V R
"
"
" 'I'nitialize the board (used by the human and 'g'o)
map I G)0)0)0)0)1)0)0)2)0)0)0)0,ok,-11k,-,R,IIN
"
"
" 'C'ompute next generation (used by the human and others)
map C T>>>>>>>>B&
"
"
" Time running one generation (used by the human)
map + <1C<2
"
"
" Time running N generations, where N is the number on the current line.
" (used by the human)
map z ,^,&,*,&<1,*<2
"
"  ----- END of macros that can be used by the human -----
"
"  ----- Initialisation -----
"
map ,- :s/./-/g
map ,o oPut 'X's in the left box, then hit 'C' or 'R'
map ,R 03stop
"
" Write a new line (used by 'I'nitialize board)
map )0 o-                    --....................--....................-
map )1 o-        VIM         --....................--....................-
map )2 o-       LIVES        --....................--....................-
"
"
" Initialisation of the pattern/command to execute for working out a square.
" Pattern is: "#<germ><count>"
" where <germ>   is " " if the current germ is dead, "X" when living.
"       <count>  is the number of living neighbours (including current germ)
"                expressed in X's
"
map ,Il8 O#XXXXXXXXXX .`a22lr 
map ,Id8 o# XXXXXXXX .`a22lr 
map ,Il7 o#XXXXXXXXX .`a22lr 
map ,Id7 o# XXXXXXX .`a22lr 
map ,Il6 o#XXXXXXXX .`a22lr 
map ,Id6 o# XXXXXX .`a22lr 
map ,Il5 o#XXXXXXX .`a22lr 
map ,Id5 o# XXXXX .`a22lr 
map ,Il4 o#XXXXXX .`a22lr 
map ,Id4 o# XXXX .`a22lr 
map ,Il3 o#XXXXX .,a
map ,Id3 o# XXX .`a22lrA
map ,Il2 o#XXXX .,a
map ,Id2 o# XX .`a22lr 
map ,Il1 o#XXX .`a22lr 
map ,Id1 o# X .`a22lr 
map ,Il0 o#XX .`a22lr 
map ,Id0 o#  .`a22lr 
"
" Patterns used to replace a germ with it's next generation
map ,Iaa o=AB =BC =CD =DE =EF =FG =GH =HI =IJ =JK =KL =LM =MN =NO =OP =PQ =QR
map ,Iab o=RS =ST =TU =UV =VW =WX =XY =YZ =Z 
"
" Insert the searched patterns above the board
map ,IIN G?^top,Il8,Id8,Il7,Id7,Il6,Id6,Il5,Id5,Il4,Id4,Il3,Id3,Il2,Id2,Il1,Id1,Il0,Id0,Iaa,Iab
"
"  ----- END of Initialisation -----
"
"  ----- Work out one line -----
"
" Work out 'T'op line (used by show next)
map T G,c2k,!9k,@,#j>2k,$j
"
" Work out 'B'ottom line (used by show next)
map B ,%k>,$
"
" Work out a line (used by show next, work out top and bottom lines)
map > 0 LWWWWWWWWWWWWWWWWWW,rj
"
" Refresh board (used by show next)
map & :%s/^\(-[ A-Z]*-\)\(-[ A-Z]*-\)\(-[.]*-\)$/\2\3\3/
"
"
" Work around vi multiple yank/put in a single macro limitation
" (used by work out top and/or bottom line)
map ,$ dd
map ,% "cp
map ,! "byy
map ,@ "cyy
map ,# "bP
map ,c c$
"
"  ----- END of Work out one line -----
"
"  ----- Work out one square -----
"
" The next three work out a square: put all nine chars around the current
" character on the bottom line (the bottom line must be empty when starting).
"
" 'W'ork out a center square (used by work out line)
map W makh,3`ah,3`ajh,3(
"
"
" Work out a 'L'eft square (used by work out line)
map L makf-h,1`ak,2`af-h,1`a,2`ajf-h,1`aj,2(
"
"
" Work out a 'R'ight square (used by work out line)
map ,r makh,2`akF-l,1`ah,2`aF-l,1`ajh,2`ajF-l,1(
"
" 'M'ove a character to the end of the file (used by all work out square
" macros)
"
map ,1 y G$p
map ,2 2y G$p
map ,3 3y G$p
"
"
"  ----- END of Work out one square -----
"
"  ----- Work out one germ -----
"
" Generate an edit command that depends on the number of living in the last
" line, and then run the edit command. (used by work out square).
" Leaves the cursor on the next character to be processed.
"
map ( ,s,i,X0i?^#A 0,df.l,Y21h
"
" Delete 's'paces (deads);
" The number of remaining characters is the number of living neighbours.
map ,s :.g/ /s///g
"
" Insert current character in the last line
map ,i `ay GP
"
" Replace any uppercase letter with 'X';
map ,X :.g/[A-Z]/s//X/g
"
" Delete and execute the rest of the line
map ,d "qd$@q
"
" Yank and execute the rest of the line
map ,Y "qy$@q
"
" Yank the character under the cursor
map ,j y 
"
" Put the current cut buffer after the cursor
map ,m p
"
" Delete the character under the cursor
map ,n x
"
" Replace a character by it's next, A --> B,  B --> C, etc.
map ,a `a,jGi?=,ma0,dll,j`a21l,ml,nh
"
"  ----- END of Work out one germ -----
"
"  ----- timing macros  -----
"
" Get current date (used by time a generation)
map << :r!date
map <1 G?^topO<<
map <2 G?^topk<<
"
"
" Turn number on current line into edit command (used by time N generations)
map ,^ AiC
"
"
" Delete current line and save current line (used by time N generations)
map ,& 0"gd$
"
"
" Run saved line (used by time N generations)
map ,* @g
"
"  ----- END of timing macros  -----
"
" End of the macros.
