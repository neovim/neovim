# Makefile for the Vim message translations.

# TODO make this configurable
# Note: ja.sjis, *.cp1250 and zh_CN.cp936 are only for MS-Windows, they are
# not installed on Unix

LANGUAGES = \
		af \
		ca \
		cs \
		de \
		en_GB \
		eo \
		es \
		fi \
		fr \
		ga \
		it \
		ja \
		ko \
		ko.UTF-8 \
		nb \
		nl \
		no \
		pl \
		pt_BR \
		ru \
		sk \
		sv \
		uk \
		vi \
		zh_CN \
		zh_CN.UTF-8 \
		zh_TW \
		zh_TW.UTF-8

CONVERTED = \
		cs.cp1250 \
		ja.sjis \
		ja.euc-jp \
		pl.cp1250 \
		pl.UTF-8 \
		ru.cp1251 \
		sk.cp1250 \
		uk.cp1251 \
		zh_CN.cp936

MOFILES = \
		af.mo \
		ca.mo \
		cs.mo \
		de.mo \
		en_GB.mo \
		eo.mo \
		es.mo \
		fi.mo \
		fr.mo \
		ga.mo \
		it.mo \
		ja.mo \
		ko.mo \
		ko.UTF-8.mo \
		nb.mo \
		nl.mo \
		no.mo \
		pl.mo \
		pt_BR.mo \
		ru.mo \
		sk.mo \
		sv.mo \
		uk.mo \
		vi.mo \
		zh_CN.UTF-8.mo \
		zh_CN.mo \
		zh_TW.UTF-8.mo \
		zh_TW.mo

MOCONVERTED = \
		cs.cp1250.mo \
		ja.sjis.mo \
		ja.euc-jp.mo \
		pl.cp1250.mo \
		pl.UTF-8.mo \
		ru.cp1251.mo \
		sk.cp1250.mo \
		uk.cp1251.mo \
		zh_CN.cp936.mo

CHECKFILES = \
		af.ck \
		ca.ck \
		cs.ck \
		de.ck \
		en_GB.ck \
		eo.ck \
		es.ck \
		fi.ck \
		fr.ck \
		ga.ck \
		it.ck \
		ja.ck \
		ko.ck \
		ko.UTF-8.ck \
		nb.ck \
		nl.ck \
		no.ck \
		pl.ck \
		pt_BR.ck \
		ru.ck \
		sk.ck \
		sv.ck \
		uk.ck \
		vi.ck \
		zh_CN.UTF-8.ck \
		zh_CN.ck \
		zh_TW.UTF-8.ck \
		zh_TW.ck \
		cs.cp1250.ck \
		ja.sjis.ck \
		ja.euc-jp.ck \
		pl.cp1250.ck \
		pl.UTF-8.ck \
		ru.cp1251.ck \
		sk.cp1250.ck \
		uk.cp1251.ck \
		zh_CN.cp936.ck

PACKAGE = vim
SHELL = /bin/sh
VIM = ../../build/bin/vim

# The OLD_PO_FILE_INPUT and OLD_PO_FILE_OUTPUT are for the new GNU gettext
# tools 0.10.37, which use a slightly different .po file format that is not
# compatible with Solaris (and old gettext implementations) unless these are
# set.  gettext 0.10.36 will not work!
MSGFMT = OLD_PO_FILE_INPUT=yes msgfmt -v
XGETTEXT = OLD_PO_FILE_INPUT=yes OLD_PO_FILE_OUTPUT=yes xgettext
MSGMERGE = OLD_PO_FILE_INPUT=yes OLD_PO_FILE_OUTPUT=yes msgmerge

.SUFFIXES:
.SUFFIXES: .po .mo .pot .ck
.PHONY: all install uninstall prefixcheck converted check clean checkclean distclean update-po $(LANGUAGES) $(CONVERTED)

.po.mo:
	$(MSGFMT) -o $@ $<

.po.ck:
	$(VIM) -u NONE -e -X -S check.vim -c "if error == 0 | q | endif" -c cq $<
	touch $@

all: $(MOFILES) $(MOCONVERTED)

check: $(CHECKFILES)

install: $(MOFILES) $(MOCONVERTED)
	@$(MAKE) prefixcheck
	for lang in $(LANGUAGES) $(CONVERTED); do \
	  dir=$(LOCALEDIR)/$$lang/; \
	  if test ! -x "$$dir"; then \
	    mkdir $$dir; chmod 755 $$dir; \
	  fi; \
	  dir=$(LOCALEDIR)/$$lang/LC_MESSAGES; \
	  if test ! -x "$$dir"; then \
	    mkdir $$dir; chmod 755 $$dir; \
	  fi; \
	  if test -r $$lang.mo; then \
	    $(INSTALL_DATA) $$lang.mo $$dir/$(PACKAGE).mo; \
	    chmod $(FILEMOD) $$dir/$(PACKAGE).mo; \
	  fi; \
	done

uninstall:
	@$(MAKE) prefixcheck
	for cat in $(MOFILES) $(MOCONVERTED); do \
	  cat=`basename $$cat`; \
	  lang=`echo $$cat | sed 's/\$(CATOBJEXT)$$//'`; \
	  rm -f $(LOCALEDIR)/$$lang/LC_MESSAGES/$(PACKAGE).mo; \
	done

converted: $(MOCONVERTED)

# nl.po was added later, if it does not exist use a file with just a # in it
# (an empty file doesn't work with old msgfmt).
nl.po:
	@( echo \# > nl.po )

# Norwegian/Bokmal: "nb" is an alias for "no".
# Copying the file is not efficient, but I don't know of another way to make
# this work.
nb.po: no.po
	cp no.po nb.po

# Convert ja.po to create ja.sjis.po.  Requires doubling backslashes in the
# second byte.  Don't depend on sjiscorr, it should only be compiled when
# ja.sjis.po is outdated.
ja.sjis.po: ja.po
	@$(MAKE) sjiscorr
	rm -f ja.sjis.po
	iconv -f utf-8 -t cp932 ja.po | ./sjiscorr > ja.sjis.po

sjiscorr: sjiscorr.c
	$(CC) -o sjiscorr sjiscorr.c

ja.euc-jp.po: ja.po
	iconv -f utf-8 -t euc-jp ja.po | \
		sed -e 's/charset=utf-8/charset=euc-jp/' -e 's/# Original translations/# Generated from ja.po, DO NOT EDIT/' > ja.euc-jp.po

# Convert cs.po to create cs.cp1250.po.
cs.cp1250.po: cs.po
	rm -f cs.cp1250.po
	iconv -f iso-8859-2 -t cp1250 cs.po | \
		sed -e 's/charset=ISO-8859-2/charset=cp1250/' -e 's/# Original translations/# Generated from cs.po, DO NOT EDIT/' > cs.cp1250.po

# Convert pl.po to create pl.cp1250.po.
pl.cp1250.po: pl.po
	rm -f pl.cp1250.po
	iconv -f iso-8859-2 -t cp1250 pl.po | \
		sed -e 's/charset=ISO-8859-2/charset=cp1250/' -e 's/# Original translations/# Generated from pl.po, DO NOT EDIT/' > pl.cp1250.po

# Convert pl.po to create pl.UTF-8.po.
pl.UTF-8.po: pl.po
	rm -f pl.UTF-8.po
	iconv -f iso-8859-2 -t utf-8 pl.po | \
		sed -e 's/charset=ISO-8859-2/charset=utf-8/' -e 's/# Original translations/# Generated from pl.po, DO NOT EDIT/' > pl.UTF-8.po

# Convert sk.po to create sk.cp1250.po.
sk.cp1250.po: sk.po
	rm -f sk.cp1250.po
	iconv -f iso-8859-2 -t cp1250 sk.po | \
		sed -e 's/charset=ISO-8859-2/charset=cp1250/' -e 's/# Original translations/# Generated from sk.po, DO NOT EDIT/' > sk.cp1250.po

# Convert zh_CN.po to create zh_CN.cp936.po.
# set 'charset' to gbk to avoid that msfmt generates a warning
zh_CN.cp936.po: zh_CN.po
	rm -f zh_CN.cp936.po
	iconv -f gb2312 -t cp936 zh_CN.po | \
		sed -e 's/charset=gb2312/charset=gbk/' -e 's/# Original translations/# Generated from zh_CN.po, DO NOT EDIT/' > zh_CN.cp936.po

# Convert ko.UTF-8.po to create ko.po.
ko.po: ko.UTF-8.po
	rm -f ko.po
	iconv -f UTF-8 -t euc-kr ko.UTF-8.po | \
		sed -e 's/charset=UTF-8/charset=euc-kr/' \
		    -e 's/# Korean translation for Vim/# Generated from ko.UTF-8.po, DO NOT EDIT/' \
		    > ko.po

# Convert ru.po to create ru.cp1251.po.
ru.cp1251.po: ru.po
	rm -f ru.cp1251.po
	iconv -f utf-8 -t cp1251 ru.po | \
		sed -e 's/charset=utf-8/charset=cp1251/' -e 's/# Original translations/# Generated from ru.po, DO NOT EDIT/' > ru.cp1251.po

# Convert uk.po to create uk.cp1251.po.
uk.cp1251.po: uk.po
	rm -f uk.cp1251.po
	iconv -f utf-8 -t cp1251 uk.po | \
		sed -e 's/charset=utf-8/charset=cp1251/' -e 's/# Original translations/# Generated from uk.po, DO NOT EDIT/' > uk.cp1251.po

prefixcheck:
	@if test "x" = "x$(prefix)"; then \
	  echo "******************************************"; \
	  echo "  please use make from the src directory  "; \
	  echo "******************************************"; \
	  exit 1; \
	fi

clean: checkclean
	rm -f core core.* *.old.po *.mo *.pot sjiscorr

distclean: clean

checkclean:
	rm -f *.ck

$(PACKAGE).pot: ../*.c ../if_perl.xs ../GvimExt/gvimext.cpp ../globals.h ../if_py_both.h
	cd ..; $(XGETTEXT) --default-domain=$(PACKAGE) \
		--add-comments --keyword=_ --keyword=N_ \
		*.c if_perl.xs GvimExt/gvimext.cpp globals.h if_py_both.h
	mv -f ../$(PACKAGE).po $(PACKAGE).pot

update-po: $(LANGUAGES)

# Don't add a dependency here, we only want to update the .po files manually
$(LANGUAGES):
	@$(MAKE) $(PACKAGE).pot
	if test ! -f $@.po.orig; then cp $@.po $@.po.orig; fi
	mv $@.po $@.po.old
	if $(MSGMERGE) $@.po.old $(PACKAGE).pot -o $@.po; then \
	    rm -f $@.po.old; \
	else \
	    echo "msgmerge for $@.po failed!"; mv $@.po.old $@.po; \
	fi
