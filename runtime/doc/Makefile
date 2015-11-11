#
# Makefile for the Vim documentation on Unix
#
# If you get "don't know how to make scratch", first run make in the source
# directory.  Or remove the include below.

AWK = awk

# Set to $(VIMTARGET) when executed from src/Makefile.
VIMEXE = vim

DOCS = $(wildcard *.txt)
HTMLS = $(DOCS:.txt=.html)

.SUFFIXES:
.SUFFIXES: .c .o .txt .html

all: tags html

# Use Vim to generate the tags file.  Can only be used when Vim has been
# compiled and installed.  Supports multiple languages.
vimtags: $(DOCS)
	$(VIMEXE) -u NONE -es -c "helptags ++t ." -c quit

# Use "doctags" to generate the tags file.  Only works for English!
tags: doctags $(DOCS)
	./doctags $(DOCS) | LANG=C LC_ALL=C sort >tags
	uniq -d -2 tags

doctags: doctags.c
	$(CC) doctags.c -o doctags

# Awk version of .txt to .html conversion.
html: noerrors tags $(HTMLS)
	@if test -f errors.log; then cat errors.log; fi

noerrors:
	-rm -f errors.log

$(HTMLS): tags.ref

.txt.html:
	$(AWK) -f makehtml.awk $< >$@

# index.html is the starting point for HTML, but for the help files it is
# help.txt.  Therefore use vimindex.html for index.txt.
index.html: help.txt
	$(AWK) -f makehtml.awk help.txt >index.html

vimindex.html: index.txt
	$(AWK) -f makehtml.awk index.txt >vimindex.html

tags.ref tags.html: tags
	$(AWK) -f maketags.awk tags >tags.html

clean:
	-rm -f doctags *.html tags.ref $(HTMLS) errors.log

