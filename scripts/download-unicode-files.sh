#!/bin/sh

set -e

files="UnicodeData.txt CaseFolding.txt EastAsianWidth.txt"

UNIDIR_DEFAULT=unicode
DOWNLOAD_URL_BASE_DEFAULT='http://unicode.org/Public/UNIDATA'

if test x$1 = 'x--help' ; then
  echo 'Usage:'
  echo "  $0[ TARGET_DIRECTORY[ URL_BASE]]"
  echo
  echo "Downloads files $files to TARGET_DIRECTORY."
  echo "Each file is downloaded from URL_BASE/\$filename."
  echo
  echo "Default target directory is $PWD/${UNIDIR_DEFAULT}."
  echo "Default URL base is ${DOWNLOAD_URL_BASE_DEFAULT}."
fi

UNIDIR=${1:-$UNIDIR_DEFAULT}
DOWNLOAD_URL_BASE=${2:-$DOWNLOAD_URL_BASE_DEFAULT}

for filename in $files ; do
  curl -o "$UNIDIR/$filename" "$DOWNLOAD_URL_BASE/$filename"
  (
    cd "$UNIDIR"
    git add $filename
  )
done

(
  cd "$UNIDIR"
  git commit -m "Update unicode files" -- $files
)
