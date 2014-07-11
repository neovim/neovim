#!/bin/sh
#
# Spell a file & generate the syntax statements necessary to
# highlight in vim.  Based on a program from Krishna Gadepalli
# <krishna@stdavids.picker.com>.
#
# I use the following mappings (in .vimrc):
#
#	noremap <F8> :so `vimspell.sh %`<CR><CR>
#	noremap <F7> :syntax clear SpellErrors<CR>
#
# Neil Schemenauer <nascheme@ucalgary.ca>
# March 1999
# updated 2008 Jul 17 by Bram
#
# Safe method for the temp file by Javier Fernández-Sanguino_Peña

INFILE=$1
tmp="${TMPDIR-/tmp}"
OUTFILE=`mktemp -t vimspellXXXXXX || tempfile -p vimspell || echo none`
# If the standard commands failed then create the file
# since we cannot create a directory (we cannot remove it on exit)
# create a file in the safest way possible.
if test "$OUTFILE" = none; then
        OUTFILE=$tmp/vimspell$$
	[ -e $OUTFILE ] && { echo "Cannot use temporary file $OUTFILE, it already exists!"; exit 1 ; } 
        (umask 077; touch $OUTFILE)
fi
# Note the copy of vimspell cannot be deleted on exit since it is
# used by vim, otherwise it should do this:
# trap "rm -f $OUTFILE" 0 1 2 3 9 11 13 15


#
# local spellings
#
LOCAL_DICT=${LOCAL_DICT-$HOME/local/lib/local_dict}

if [ -f $LOCAL_DICT ]
then
	SPELL_ARGS="+$LOCAL_DICT"
fi

spell $SPELL_ARGS $INFILE | sort -u |
awk '
      {
	printf "syntax match SpellErrors \"\\<%s\\>\"\n", $0 ;
      }

END   {
	printf "highlight link SpellErrors ErrorMsg\n\n" ;
      }
' > $OUTFILE
echo "!rm $OUTFILE" >> $OUTFILE
echo $OUTFILE
