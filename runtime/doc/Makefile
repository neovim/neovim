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

MANPAGES = \
	manpages/vim.man \
	manpages/vimtutor.man \
	manpages/xxd.man \
	manpages/de/vim-de.man \
	manpages/fr/vim-fr.man \
	manpages/fr/vimtutor-fr.man \
	manpages/fr/xxd-fr.man \
	manpages/pl/vim-pl.man \
	manpages/pl/vimtutor-pl.man \
	manpages/pl/xxd-pl.man \
	manpages/it/vim-it.man \
	manpages/it/vimtutor-it.man \
	manpages/it/xxd-it.man \
	manpages/ru/vim-ru.man \
	manpages/ru/vimtutor-ru.man \
	manpages/ru/xxd-ru.man \
	manpages/ja/vim-ja.man \
	manpages/ja/vimtutor-ja.man \
	manpages/ja/xxd-ja.man

.SUFFIXES:
.SUFFIXES: .c .o .txt .html .1 .man

all: tags manpages html

# Use Vim to generate the tags file.  Can only be used when Vim has been
# compiled and installed.  Supports multiple languages.
vimtags: $(DOCS)
	$(VIMEXE) -u NONE -esX -c "helptags ++t ." -c quit

# Use "doctags" to generate the tags file.  Only works for English!
tags: doctags $(DOCS)
	./doctags $(DOCS) | LANG=C LC_ALL=C sort >tags
	uniq -d -2 tags

doctags: doctags.c
	$(CC) doctags.c -o doctags

manpages: $(MANPAGES)

# OSX groff doesn't support utf-8 as input encoding, so this won't work there.
.1.man:
	groff -k -mandoc -Tutf8 $< | sed -e s/.^H//g > $@

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
	-rm -f doctags *.html tags.ref $(MANPAGES) $(HTMLS) errors.log

