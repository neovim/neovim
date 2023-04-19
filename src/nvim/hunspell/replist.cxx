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

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits>

#include "replist.hxx"
#include "csutil.hxx"

RepList::RepList(int n) {
  dat.reserve(std::min(n, 16384));
}

RepList::~RepList() {
  for (auto& i : dat) {
    delete i;
  }
}

int RepList::find(const char* word) {
  int p1 = 0;
  int p2 = dat.size() - 1;
  int ret = -1;
  while (p1 <= p2) {
    int m = ((unsigned)p1 + (unsigned)p2) >> 1;
    int c = strncmp(word, dat[m]->pattern.c_str(), dat[m]->pattern.size());
    if (c < 0)
      p2 = m - 1;
    else if (c > 0)
      p1 = m + 1;
    else {      // scan in the right half for a longer match
      ret = m;
      p1 = m + 1;
    }
  }
  return ret;
}

std::string RepList::replace(const size_t wordlen, int ind, bool atstart) {
  int type = atstart ? 1 : 0;
  if (wordlen == dat[ind]->pattern.size())
    type = atstart ? 3 : 2;
  while (type && dat[ind]->outstrings[type].empty())
    type = (type == 2 && !atstart) ? 0 : type - 1;
  return dat[ind]->outstrings[type];
}

int RepList::add(const std::string& in_pat1, const std::string& pat2) {
  if (in_pat1.empty() || pat2.empty()) {
    return 1;
  }
  // analyse word context
  int type = 0;
  std::string pat1(in_pat1);
  if (pat1[0] == '_') {
    pat1.erase(0, 1);
    type = 1;
  }
  if (!pat1.empty() && pat1[pat1.size() - 1] == '_') {
    type = type + 2;
    pat1.erase(pat1.size() - 1);
  }
  mystrrep(pat1, "_", " ");

  // find existing entry
  int m = find(pat1.c_str());
  if (m >= 0 && dat[m]->pattern == pat1) {
    // since already used
    dat[m]->outstrings[type] = pat2;
    mystrrep(dat[m]->outstrings[type], "_", " ");
    return 0;
  }

  // make a new entry if none exists
  replentry* r = new replentry;
  if (r == NULL)
    return 1;
  r->pattern = pat1;
  r->outstrings[type] = pat2;
  mystrrep(r->outstrings[type], "_", " ");
  dat.push_back(r);
  // sort to the right place in the list
  size_t i;
  for (i = dat.size() - 1; i > 0; --i) {
    if (strcmp(r->pattern.c_str(), dat[i - 1]->pattern.c_str()) < 0) {
      dat[i] = dat[i - 1];
    } else
      break;
  }
  dat[i] = r;
  return 0;
}

bool RepList::conv(const std::string& in_word, std::string& dest) {
  dest.clear();

  const size_t wordlen = in_word.size();
  const char* word = in_word.c_str();

  bool change = false;
  for (size_t i = 0; i < wordlen; ++i) {
    int n = find(word + i);

    bool empty = n < 0;
    if (empty) {
      dest.push_back(word[i]);
      continue;
    }

    std::string l = replace(wordlen - i, n, i == 0);
    if (l.empty()) {
      dest.push_back(word[i]);
      continue;
    }

    dest.append(l);
    if (!dat[n]->pattern.empty()) {
      i += dat[n]->pattern.size() - 1;
    }
    change = true;
  }

  return change;
}

bool RepList::check_against_breaktable(const std::vector<std::string>& breaktable) const {
  for (const auto i : dat) {
    for (auto& outstring : i->outstrings) {
      for (const auto& str : breaktable) {
        if (outstring.find(str) != std::string::npos) {
          return false;
        }
      }
    }
  }

  return true;
}
