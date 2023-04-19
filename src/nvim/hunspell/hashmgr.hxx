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

#ifndef HASHMGR_HXX_
#define HASHMGR_HXX_

#include <cstdio>
#include <string>
#include <vector>

#include "htypes.hxx"
#include "filemgr.hxx"
#include "w_char.hxx"

enum flag { FLAG_CHAR, FLAG_LONG, FLAG_NUM, FLAG_UNI };

// morphological description of a dictionary item can contain
// arbitrary number "ph:" (MORPH_PHON) fields to store typical
// phonetic or other misspellings of that word.
// ratio of lines/lines with "ph:" in the dic file: 1/MORPH_PHON_RATIO
#define MORPH_PHON_RATIO 500

class HashMgr {
  std::vector<struct hentry*> tableptr;
  flag flag_mode;
  int complexprefixes;
  int utf8;
  unsigned short forbiddenword;
  int langnum;
  std::string enc;
  std::string lang;
  struct cs_info* csconv;
  std::string ignorechars;
  std::vector<w_char> ignorechars_utf16;
  std::vector<unsigned short*> aliasf; // flag vector `compression' with aliases
  std::vector<unsigned short> aliasflen;
  std::vector<char*> aliasm; // morphological desciption `compression' with aliases
  // reptable created from REP table of aff file and from "ph:" fields
  // of the dic file. It contains phonetic and other common misspellings
  // (letters, letter groups and words) for better suggestions
  std::vector<replentry> reptable;

 public:
  HashMgr(const char* tpath, const char* apath, const char* key = NULL);
  ~HashMgr();

  struct hentry* lookup(const char* word, size_t len) const;
  int hash(const char* word, size_t len) const;
  struct hentry* walk_hashtable(int& col, struct hentry* hp) const;

  int add(const std::string& word);
  int add_with_flags(const std::string& word, const std::string& flags, const std::string& desc = NULL);
  int add_with_affix(const std::string& word, const std::string& pattern);
  int remove(const std::string& word);
  int decode_flags(unsigned short** result, const std::string& flags, FileMgr* af) const;
  bool decode_flags(std::vector<unsigned short>& result, const std::string& flags, FileMgr* af) const;
  unsigned short decode_flag(const std::string& flag) const;
  std::string encode_flag(unsigned short flag) const;
  int is_aliasf() const;
  int get_aliasf(int index, unsigned short** fvec, FileMgr* af) const;
  int is_aliasm() const;
  char* get_aliasm(int index) const;
  const std::vector<replentry>& get_reptable() const;

 private:
  int get_clen_and_captype(const std::string& word, int* captype);
  int get_clen_and_captype(const std::string& word, int* captype, std::vector<w_char> &workbuf);
  int load_tables(const char* tpath, const char* key);
  int add_word(const std::string& word,
               int wcl,
               unsigned short* ap,
               int al,
               const std::string* desc,
               bool onlyupcase,
               int captype);
  int load_config(const char* affpath, const char* key);
  bool parse_aliasf(const std::string& line, FileMgr* af);
  int add_hidden_capitalized_word(const std::string& word,
                                  int wcl,
                                  unsigned short* flags,
                                  int al,
                                  const std::string* dp,
                                  int captype);
  bool parse_aliasm(const std::string& line, FileMgr* af);
  bool parse_reptable(const std::string& line, FileMgr* af);
  void remove_forbidden_flag(const std::string& word);
  void free_table();
  void free_flag(unsigned short* astr, int alen);
};

#endif
