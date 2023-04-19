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

#ifndef ATYPES_HXX_
#define ATYPES_HXX_

#ifndef HUNSPELL_WARNING
#include <stdio.h>
#ifdef HUNSPELL_WARNING_ON
#define HUNSPELL_WARNING fprintf
#else
// empty inline function to switch off warnings (instead of the C99 standard
// variadic macros)
static inline void HUNSPELL_WARNING(FILE*, const char*, ...) {}
#endif
#endif

// HUNSTEM def.
#define HUNSTEM

#include "w_char.hxx"
#include <algorithm>
#include <string>
#include <vector>

#define SETSIZE 256
#define CONTSIZE 65536

// AffEntry options
#define aeXPRODUCT (1 << 0)
#define aeUTF8 (1 << 1)
#define aeALIASF (1 << 2)
#define aeALIASM (1 << 3)
#define aeLONGCOND (1 << 4)

// compound options
#define IN_CPD_NOT 0
#define IN_CPD_BEGIN 1
#define IN_CPD_END 2
#define IN_CPD_OTHER 3

// info options
#define SPELL_COMPOUND (1 << 0)    // the result is a compound word
#define SPELL_FORBIDDEN (1 << 1)
#define SPELL_ALLCAP (1 << 2)
#define SPELL_NOCAP (1 << 3)
#define SPELL_INITCAP (1 << 4)
#define SPELL_ORIGCAP (1 << 5)
#define SPELL_WARN (1 << 6)
#define SPELL_COMPOUND_2 (1 << 7)  // permit only 2 dictionary words in the compound

#define MINCPDLEN 3
#define MAXCOMPOUND 10
#define MAXCONDLEN 20
#define MAXCONDLEN_1 (MAXCONDLEN - sizeof(char*))

#define MAXACC 1000

#define FLAG unsigned short
#define FLAG_NULL 0x00
#define FREE_FLAG(a) a = 0

#define TESTAFF(a, b, c) (std::binary_search(a, a + c, b))

// timelimit: max. ~1/4 sec (process time on Linux) for
// for a suggestion, including max. ~/10 sec for a case
// sensitive plain or compound word suggestion, within
// ~1/20 sec long time consuming suggestion functions
#define TIMELIMIT_GLOBAL (CLOCKS_PER_SEC / 4)
#define TIMELIMIT_SUGGESTION (CLOCKS_PER_SEC / 10)
#define TIMELIMIT (CLOCKS_PER_SEC / 20)
#define MINTIMER 100
#define MAXPLUSTIMER 100

struct guessword {
  char* word;
  bool allow;
  char* orig;
  guessword()
    : word(nullptr)
    , allow(false)
    , orig(nullptr)
  {
  }
};

typedef std::vector<std::string> mapentry;
typedef std::vector<FLAG> flagentry;

struct patentry {
  std::string pattern;
  std::string pattern2;
  std::string pattern3;
  FLAG cond;
  FLAG cond2;
  patentry()
    : cond(FLAG_NULL)
    , cond2(FLAG_NULL) {
  }
};

#endif
