/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * Copyright (C) 2002-2022 Németh László
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * Hunspell is based on MySpell which is Copyright (C) 2002 Kevin Hendricks.
 *
 * Contributor(s): David Einstein, Davide Prina, Giuseppe Modugno,
 * Gianluca Turconi, Simon Brouwer, Noll János, Bíró Árpád,
 * Goldman Eleonóra, Sarlós Tamás, Bencsáth Boldizsár, Halácsy Péter,
 * Dvornik László, Gefferth András, Nagy Viktor, Varga Dániel, Chris Halls,
 * Rene Engelhard, Bram Moolenaar, Dafydd Jones, Harri Pitkänen
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#ifndef HTYPES_HXX_
#define HTYPES_HXX_

#define ROTATE_LEN 5

#define ROTATE(v, q) \
  (v) = ((v) << (q)) | (((v) >> (32 - q)) & ((1 << (q)) - 1));

// hentry options
#define H_OPT (1 << 0)          // is there optional morphological data?
#define H_OPT_ALIASM (1 << 1)   // using alias compression?
#define H_OPT_PHON (1 << 2)     // is there ph: field in the morphological data?
#define H_OPT_INITCAP (1 << 3)  // is dictionary word capitalized?

// see also csutil.hxx
#define HENTRY_WORD(h) &(h->word[0])

// approx. number  of user defined words
#define USERWORD 1000

#if __cplusplus >= 201103L || (defined(_MSC_VER) && _MSC_VER >= 1900)
#  define HUNSPELL_THREAD_LOCAL thread_local
#else
#  define HUNSPELL_THREAD_LOCAL static
#endif

struct hentry {
  unsigned short blen;   // word length in bytes
  unsigned short clen;   // word length in characters (different for UTF-8 enc.)
  short alen;            // length of affix flag vector
  unsigned short* astr;  // affix flag vector
  struct hentry* next;   // next word with same hash code
  struct hentry* next_homonym;  // next homonym word (with same hash code)
  char var;      // bit vector of H_OPT hentry options
  char word[1];  // variable-length word (8-bit or UTF-8 encoding)
};

#endif
