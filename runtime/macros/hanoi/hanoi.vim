set remap
set noterse
set wrapscan
" to set the height of the tower, change the digit in the following
" two lines to the height you want (select from 1 to 9)
map t 7
map! t 7
map L 1G/tX/^0$P1GJ$An$BGC0e$X0E0F$X/T@f@h$A1GJ@f0l$Xn$PU
map g IL

map J /^0[^t]*$
map X x
map P p
map U L
map A "fyl
map B "hyl
map C "fp
map e "fy2l
map E "hp
map F "hy2l

" initialisations:
" KM	cleanup buffer
" Y	create tower of desired height
" NOQ	copy it and inster a T
" NO	copy this one
" S	change last char into a $
" R	change last char in previous line into a n
" T	insert two lines containing a zero
" V	add a last line containing a backslash
map I KMYNOQNOSkRTV

"create empty line
map K 1Go

"delete to end of file
map M dG

"yank one line
map N yy

"put
map O p

"delete more than height-of-tower characters
map q tllD

"create a tower of desired height
map Y o0123456789Z0q

"insert a T in column 1
map Q 0iT

"substitute last character with a n
map R $rn

"substitute last character with a $
map S $r$

"insert two lines containing a zero
map T ko00

"add a backslash at the end
map V Go/
