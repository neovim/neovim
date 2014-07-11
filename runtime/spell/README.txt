The spell files included here are in Vim's special format.  You can't edit
them.  See ":help spell" for more information.


COPYRIGHT

The files used as input for the spell files come from the OpenOffice.org spell
files.  Most of them go under the LGPL or a similar license.

Copyright notices for specific languages are in README_??.txt.  Note that the
files for different regions are merged, both to save space and to make it
possible to highlight words for another region different from bad words.

Most of the soundslike mappings come from Aspell ??_phonet.dat files:
ftp://ftp.gnu.org/gnu/aspell/dict/.  Most go under the GPL or LGPL copyright.


GENERATING .SPL FILES

This involves downloading the files from the OpenOffice.org server, applying a
patch and running Vim to generate the .spl file.  To do this all in one go use
the Aap program (www.a-a-p.org).  It's simple to install, it only requires
Python.

Before generating spell files, verify your system has the required locale
support.  Source the check_locales.vim script to find out.  If something is
missing, see LOCALE below.


You can also do it manually:
1. Fetch the right spell file from:
   http://ftp.services.openoffice.org/pub/OpenOffice.org/contrib/dictionaries

2. Unzip the archive:
	unzip LL_RR.zip

3. Apply the patch:
	patch < LL_RR.diff

4. If the language has multiple regions do the above for each region.  E.g.,
   for English there are five regions: US, CA, AU, NZ and GB.

5. Run Vim and execute ":mkspell".  Make sure you do this with the correct
   locale, that influences the upper/lower case letters and word characters.
   On Unix it's something like:
   	env LANG=en_US.UTF-8 vim
	mkspell! en en_US en_AU en_CA en_GB en_NZ

6. Repeat step 5 for other locales.  For English you could generate a spell
   file for latin1, utf-8 and ASCII.  ASCII only makes sense for languages
   that have very few words with non-ASCII letters.

Now you understand why I prefer using the Aap recipe :-).


MAINTAINING A LANGUAGE

Every language should have a maintainer.  His tasks are to track the changes
in the OpenOffice.org spell files and make updated patches.  Words that
haven't been added/removed from the OpenOffice lists can also be handled by
the patches.

It is important to keep the version of the .dic and .aff files that you
started with.  When OpenOffice brings out new versions of these files you can
find out what changed and take over these changes in your patch.  When there
are very many changes you can do it the other way around: re-apply the changes
for Vim to the new versions of the .dic and .aff files.

This procedure should work well:

1. Obtain the zip archive with the .aff and .dic files.  Unpack it as
   explained above and copy (don't rename!) the .aff and .dic files to
   .orig.aff and .orig.dic.  Using the Aap recipe should work, it will make
   the copies for you.

2. Tweak the .aff and .dic files to generate the perfect .spl file.  Don't
   change too much, the OpenOffice people are not stupid.  However, you may
   want to remove obvious mistakes.  And remove single-letter words that
   aren't really words, they mess up the suggestions (English has this
   problem).  You can use the "fixdup.vim" Vim script to find duplicate words.

3. Make the diff file.  "aap diff" will do this for you.  If a diff would be
   too big you might consider writing a Vim script to do systematic changes.
   Do check that someone else can reproduce building the spell file.  Send the
   result to Bram for inclusion in the distribution.  Bram will generate the
   .spl file and upload it to the ftp server (if he can't generate it you will
   have to send him the .spl file too).

4. When OpenOffice makes a new zip file available you need to update the
   patch.  "aap check" should do most of the work for you: if there are
   changes the .new.dic and .new.aff files will appear.  You can now figure
   out the differences with .orig.dic and .orig.aff, adjust the .dic and .aff
   files and finally move the .new.dic to .orig.dic and .new.aff to .orig.aff.

5. Repeat step 4. regularly.


LOCALE

For proper spell file generation the required locale must be installed.
Otherwise Vim doesn't know what are letters and upper-lower case differences.
Modern systems use UTF-8, but we also generate spell files for 8-bit locales
for users with older systems.

On Ubuntu the default is to only support locales for your own language.  To
add others you need to do this:
	sudo vim /var/lib/locales/supported.d/local
	    Add needed lines from /usr/share/i18n/SUPPORTED
	sudo dpkg-reconfigure locales

When using the check_locales.vim script, you need to exit Vim and restart it
to pickup the newly installed locales.
