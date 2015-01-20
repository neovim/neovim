#
# Makefile for the Vim documentation on Unix
#
# If you get "don't know how to make scratch", first run make in the source
# directory.  Or remove the include below.

AWK = awk

# Set to $(VIMTARGET) when executed from src/Makefile.
VIMEXE = vim

DOCS = \
	arabic.txt \
	autocmd.txt \
	change.txt \
	cmdline.txt \
	debug.txt \
	debugger.txt \
	develop.txt \
	diff.txt \
	digraph.txt \
	editing.txt \
	eval.txt \
	remote_plugin.txt \
	farsi.txt \
	filetype.txt \
	fold.txt \
	ft_ada.txt \
	ft_sql.txt \
	gui.txt \
	gui_w32.txt \
	gui_x11.txt \
	hebrew.txt \
	help.txt \
	helphelp.txt \
	howto.txt \
	if_cscop.txt \
	if_lua.txt \
	if_mzsch.txt \
	if_perl.txt \
	if_pyth.txt \
	if_ruby.txt \
	if_tcl.txt \
	indent.txt \
	index.txt \
	insert.txt \
	intro.txt \
	job_control.txt \
	map.txt \
	mbyte.txt \
	message.txt \
	mlang.txt \
	motion.txt \
	msgpack_rpc.txt \
	nvim_clipboard.txt \
	nvim_intro.txt \
	nvim_provider.txt \
	nvim_python.txt \
	options.txt \
	os_dos.txt \
	os_mac.txt \
	os_unix.txt \
	os_win32.txt \
	pattern.txt \
	pi_getscript.txt \
	pi_gzip.txt \
	pi_netrw.txt \
	pi_paren.txt \
	pi_spec.txt \
	pi_tar.txt \
	pi_vimball.txt \
	pi_zip.txt \
	print.txt \
	quickfix.txt \
	quickref.txt \
	quotes.txt \
	recover.txt \
	remote.txt \
	repeat.txt \
	rileft.txt \
	russian.txt \
	scroll.txt \
	sign.txt \
	spell.txt \
	sponsor.txt \
	starting.txt \
	syntax.txt \
	tabpage.txt \
	tagsrch.txt \
	term.txt \
	tips.txt \
	todo.txt \
	uganda.txt \
	undo.txt \
	usr_01.txt \
	usr_02.txt \
	usr_03.txt \
	usr_04.txt \
	usr_05.txt \
	usr_06.txt \
	usr_07.txt \
	usr_08.txt \
	usr_09.txt \
	usr_10.txt \
	usr_11.txt \
	usr_12.txt \
	usr_20.txt \
	usr_21.txt \
	usr_22.txt \
	usr_23.txt \
	usr_24.txt \
	usr_25.txt \
	usr_26.txt \
	usr_27.txt \
	usr_28.txt \
	usr_29.txt \
	usr_30.txt \
	usr_31.txt \
	usr_32.txt \
	usr_40.txt \
	usr_41.txt \
	usr_42.txt \
	usr_43.txt \
	usr_44.txt \
	usr_45.txt \
	usr_90.txt \
	usr_toc.txt \
	various.txt \
	vi_diff.txt \
	visual.txt \
	windows.txt

HTMLS = \
	arabic.html \
	autocmd.html \
	change.html \
	cmdline.html \
	debug.html \
	debugger.html \
	develop.html \
	diff.html \
	digraph.html \
	editing.html \
	eval.html \
	remote_plugin.html \
	farsi.html \
	filetype.html \
	fold.html \
	ft_ada.html \
	ft_sql.html \
	gui.html \
	gui_w32.html \
	gui_x11.html \
	hebrew.html \
	helphelp.html \
	howto.html \
	if_cscop.html \
	if_lua.html \
	if_mzsch.html \
	if_perl.html \
	if_pyth.html \
	if_ruby.html \
	if_tcl.html \
	indent.html \
	index.html \
	insert.html \
	intro.html \
	job_control.html \
	map.html \
	mbyte.html \
	message.html \
	mlang.html \
	motion.html \
	msgpack_rpc.html \
	nvim_clipboard.html \
	nvim_intro.html \
	nvim_provider.html \
	nvim_python.html \
	options.html \
	os_dos.html \
	os_mac.html \
	os_unix.html \
	os_win32.html \
	pattern.html \
	pi_getscript.html \
	pi_gzip.html \
	pi_netrw.html \
	pi_paren.html \
	pi_spec.html \
	pi_tar.html \
	pi_vimball.html \
	pi_zip.html \
	print.html \
	quickfix.html \
	quickref.html \
	quotes.html \
	recover.html \
	remote.html \
	repeat.html \
	rileft.html \
	russian.html \
	scroll.html \
	sign.html \
	spell.html \
	sponsor.html \
	starting.html \
	syntax.html \
	tabpage.html \
	tags.html \
	tagsrch.html \
	term.html \
	tips.html \
	todo.html \
	uganda.html \
	undo.html \
	usr_01.html \
	usr_02.html \
	usr_03.html \
	usr_04.html \
	usr_05.html \
	usr_06.html \
	usr_07.html \
	usr_08.html \
	usr_09.html \
	usr_10.html \
	usr_11.html \
	usr_12.html \
	usr_20.html \
	usr_21.html \
	usr_22.html \
	usr_23.html \
	usr_24.html \
	usr_25.html \
	usr_26.html \
	usr_27.html \
	usr_28.html \
	usr_29.html \
	usr_30.html \
	usr_31.html \
	usr_32.html \
	usr_40.html \
	usr_41.html \
	usr_42.html \
	usr_43.html \
	usr_44.html \
	usr_45.html \
	usr_90.html \
	usr_toc.html \
	various.html \
	vi_diff.html \
	vimindex.html \
	visual.html \
	windows.html

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

