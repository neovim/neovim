#
# Makefile for the Vim documentation on Unix
#
# If you get "don't know how to make scratch", first run make in the source
# directory.  Or remove the include below.

AWK = awk

DOCS = $(wildcard *.txt)
HTMLS = $(DOCS:.txt=.html)

.SUFFIXES:
.SUFFIXES: .c .o .txt .html

# Awk version of .txt to .html conversion.
html: noerrors vimindex.html $(HTMLS)
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
	-rm -f *.html tags.ref $(HTMLS) errors.log tags

