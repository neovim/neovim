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
/*
 * Copyright 2002 Kevin B. Hendricks, Stratford, Ontario, Canada
 * And Contributors.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * 3. All modifications to the source code must be clearly marked as
 *    such.  Binary redistributions based on modified source code
 *    must be clearly marked as modified versions in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY KEVIN B. HENDRICKS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * KEVIN B. HENDRICKS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef SUGGESTMGR_HXX_
#define SUGGESTMGR_HXX_

#define MAX_ROOTS 100
#define MAX_WORDS 100
#define MAX_GUESS 200
#define MAXNGRAMSUGS 4
#define MAXPHONSUGS 2
#define MAXCOMPOUNDSUGS 3

#define NGRAM_LONGER_WORSE (1 << 0)
#define NGRAM_ANY_MISMATCH (1 << 1)
#define NGRAM_LOWERING (1 << 2)
#define NGRAM_WEIGHTED (1 << 3)

#include "atypes.hxx"
#include "affixmgr.hxx"
#include "hashmgr.hxx"
#include "langnum.hxx"

enum { LCS_UP, LCS_LEFT, LCS_UPLEFT };

class SuggestMgr {
 private:
  std::string ckey;
  size_t ckeyl;
  std::vector<w_char> ckey_utf;

  std::string ctry;
  size_t ctryl;
  std::vector<w_char> ctry_utf;
  bool lang_with_dash_usage;

  AffixMgr* pAMgr;
  unsigned int maxSug;
  struct cs_info* csconv;
  int utf8;
  int langnum;
  int nosplitsugs;
  int maxngramsugs;
  int maxcpdsugs;
  int complexprefixes;

 public:
  SuggestMgr(const std::string& tryme, unsigned int maxn, AffixMgr* aptr);
  SuggestMgr(const SuggestMgr&) = delete;
  SuggestMgr& operator=(const SuggestMgr&) = delete;
  ~SuggestMgr();

  bool suggest(std::vector<std::string>& slst, const std::string& word, int* onlycmpdsug,
          // for testing compound words formed from 3 or more words:
          // if test_simplesug == true, suggest() doesn't suggest compound words,
          // and it returns with true at the first suggestion found
          bool test_simplesug = false);
  void ngsuggest(std::vector<std::string>& slst, const char* word, const std::vector<HashMgr*>& rHMgr, int captype);

  std::string suggest_morph(const std::string& word);
  std::string suggest_gen(const std::vector<std::string>& pl, const std::string& pattern);

 private:
  void testsug(std::vector<std::string>& wlst,
               const std::string& candidate,
               int cpdsuggest,
               int* timer,
               clock_t* timelimit,
               int& info);
  int checkword(const std::string& word, int, int*, clock_t*);
  int check_forbidden(const std::string&);

  void capchars(std::vector<std::string>&, const std::string&, int, int&);
  int replchars(std::vector<std::string>&, const std::string&, int, int&);
  int doubletwochars(std::vector<std::string>&, const std::string&, int, int&);
  int forgotchar(std::vector<std::string>&, const std::string&, int, int&);
  int swapchar(std::vector<std::string>&, const std::string&, int, int&);
  int longswapchar(std::vector<std::string>&, const std::string&, int, int&);
  int movechar(std::vector<std::string>&, const std::string&, int, int&);
  int extrachar(std::vector<std::string>&, const std::string&, int, int&);
  int badcharkey(std::vector<std::string>&, const std::string&, int, int&);
  int badchar(std::vector<std::string>&, const std::string&, int, int&);
  bool twowords(std::vector<std::string>&, const std::string&, int, bool);

  void capchars_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int doubletwochars_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int forgotchar_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int extrachar_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int badcharkey_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int badchar_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int swapchar_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int longswapchar_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);
  int movechar_utf(std::vector<std::string>&, const std::vector<w_char>&, int, int&);

  int mapchars(std::vector<std::string>&, const std::string&, int, int&);
  int map_related(const std::string&,
                  std::string&,
                  size_t,
                  std::vector<std::string>& wlst,
                  int,
                  const std::vector<mapentry>&,
                  int*,
                  clock_t*,
                  int depth,
                  int& info);
  int ngram(int n, const std::vector<w_char>& su1,
            const std::vector<w_char>& su2, int opt);
  int ngram(int n, const std::string& s1, const std::string& s2, int opt);
  int mystrlen(const char* word);
  int leftcommonsubstring(const std::vector<w_char>& su1,
                          const std::vector<w_char>& su2);
  int leftcommonsubstring(const char* s1, const char* s2);
  int commoncharacterpositions(const char* s1, const char* s2, int* is_swap);
  void bubblesort(char** rwd, char** rwd2, int* rsc, int n);
  char* lcs(const char* s, const char* s2, int* l1, int* l2);
  int lcslen(const char* s, const char* s2);
  int lcslen(const std::string& s, const std::string& s2);
  std::string suggest_hentry_gen(hentry* rv, const char* pattern);
};

#endif
