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

/* hunzip: file decompression for sorted dictionaries with optional encryption,
 * algorithm: prefix-suffix encoding and 16-bit Huffman encoding */

#ifndef HUNZIP_HXX_
#define HUNZIP_HXX_

#include "hunvisapi.h"

#include <cstdio>
#include <fstream>
#include <vector>

#define BUFSIZE 65536
#define HZIP_EXTENSION ".hz"

#define MSG_OPEN "error: %s: cannot open\n"
#define MSG_FORMAT "error: %s: not in hzip format\n"
#define MSG_MEMORY "error: %s: missing memory\n"
#define MSG_KEY "error: %s: missing or bad password\n"

struct bit {
  unsigned char c[2];
  int v[2];
};

class LIBHUNSPELL_DLL_EXPORTED Hunzip {
 protected:
  std::string filename;
  std::ifstream fin;
  int bufsiz, lastbit, inc, inbits, outc;
  std::vector<bit> dec;     // code table
  char in[BUFSIZE];         // input buffer
  char out[BUFSIZE + 1];    // Huffman-decoded buffer
  char line[BUFSIZE + 50];  // decoded line
  int getcode(const char* key);
  int getbuf();
  int fail(const char* err, const std::string& par);

 public:
  Hunzip(const char* filename, const char* key = NULL);
  Hunzip(const Hunzip&) = delete;
  Hunzip& operator=(const Hunzip&) = delete;
  ~Hunzip();
  bool is_open();
  bool getline(std::string& dest);
};

#endif
