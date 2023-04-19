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

#include <cstdlib>
#include <cstring>
#include <cstdio>

#include "hunzip.hxx"
#include "csutil.hxx"

#define CODELEN 65536
#define BASEBITREC 5000

#define UNCOMPRESSED '\002'
#define MAGIC "hz0"
#define MAGIC_ENCRYPT "hz1"
#define MAGICLEN (sizeof(MAGIC) - 1)

int Hunzip::fail(const char* err, const std::string& par) {
  fprintf(stderr, err, par.c_str());
  return -1;
}

Hunzip::Hunzip(const char* file, const char* key)
    : bufsiz(0), lastbit(0), inc(0), inbits(0), outc(0) {
  in[0] = out[0] = line[0] = '\0';
  filename = file;
  if (getcode(key) == -1)
    bufsiz = -1;
  else
    bufsiz = getbuf();
}

int Hunzip::getcode(const char* key) {
  unsigned char c[2];
  int i, j, n, allocatedbit = BASEBITREC;
  const char* enc = key;

  if (filename.empty())
    return -1;

  myopen(fin, filename.c_str(), std::ios_base::in | std::ios_base::binary);
  if (!fin.is_open())
    return -1;

  // read magic number
  if (!fin.read(in, 3) ||
      !(strncmp(MAGIC, in, MAGICLEN) == 0 ||
        strncmp(MAGIC_ENCRYPT, in, MAGICLEN) == 0)) {
    return fail(MSG_FORMAT, filename);
  }

  // check encryption
  if (strncmp(MAGIC_ENCRYPT, in, MAGICLEN) == 0) {
    unsigned char cs;
    if (!key)
      return fail(MSG_KEY, filename);
    if (!fin.read(reinterpret_cast<char*>(c), 1))
      return fail(MSG_FORMAT, filename);
    for (cs = 0; *enc; enc++)
      cs ^= *enc;
    if (cs != c[0])
      return fail(MSG_KEY, filename);
    enc = key;
  } else
    key = NULL;

  // read record count
  if (!fin.read(reinterpret_cast<char*>(c), 2))
    return fail(MSG_FORMAT, filename);

  if (key) {
    c[0] ^= *enc;
    if (*(++enc) == '\0')
      enc = key;
    c[1] ^= *enc;
  }

  n = ((int)c[0] << 8) + c[1];
  dec.resize(BASEBITREC);
  dec[0].v[0] = 0;
  dec[0].v[1] = 0;

  // read codes
  for (i = 0; i < n; i++) {
    unsigned char l;
    if (!fin.read(reinterpret_cast<char*>(c), 2))
      return fail(MSG_FORMAT, filename);
    if (key) {
      if (*(++enc) == '\0')
        enc = key;
      c[0] ^= *enc;
      if (*(++enc) == '\0')
        enc = key;
      c[1] ^= *enc;
    }
    if (!fin.read(reinterpret_cast<char*>(&l), 1))
      return fail(MSG_FORMAT, filename);
    if (key) {
      if (*(++enc) == '\0')
        enc = key;
      l ^= *enc;
    }
    if (!fin.read(in, (l >> 3) + 1))
      return fail(MSG_FORMAT, filename);
    if (key)
      for (j = 0; j <= (l >> 3); j++) {
        if (*(++enc) == '\0')
          enc = key;
        in[j] ^= *enc;
      }
    int p = 0;
    for (j = 0; j < l; j++) {
      int b = (in[(j >> 3)] & (1 << (7 - (j & 7)))) ? 1 : 0;
      int oldp = p;
      p = dec[p].v[b];
      if (p == 0) {
        lastbit++;
        if (lastbit == allocatedbit) {
          allocatedbit += BASEBITREC;
          dec.resize(allocatedbit);
        }
        dec[lastbit].v[0] = 0;
        dec[lastbit].v[1] = 0;
        dec[oldp].v[b] = lastbit;
        p = lastbit;
      }
    }
    dec[p].c[0] = c[0];
    dec[p].c[1] = c[1];
  }
  return 0;
}

Hunzip::~Hunzip() {
}

int Hunzip::getbuf() {
  int p = 0;
  int o = 0;
  do {
    if (inc == 0) {
      fin.read(in, BUFSIZE);
      inbits = int(fin.gcount() << 3);
    }
    for (; inc < inbits; inc++) {
      int b = (in[inc >> 3] & (1 << (7 - (inc & 7)))) ? 1 : 0;
      int oldp = p;
      p = dec[p].v[b];
      if (p == 0) {
        if (oldp == lastbit) {
          fin.close();
          // add last odd byte
          if (dec[lastbit].c[0])
            out[o++] = dec[lastbit].c[1];
          return o;
        }
        out[o++] = dec[oldp].c[0];
        out[o++] = dec[oldp].c[1];
        if (o == BUFSIZE)
          return o;
        p = dec[p].v[b];
      }
    }
    inc = 0;
  } while (inbits == BUFSIZE * 8);
  return fail(MSG_FORMAT, filename);
}

bool Hunzip::is_open() {
  return fin.is_open();
}

bool Hunzip::getline(std::string& dest) {
  char linebuf[BUFSIZE];
  int l = 0, eol = 0, left = 0, right = 0;
  if (bufsiz == -1)
    return false;
  while (l < bufsiz && !eol) {
    linebuf[l++] = out[outc];
    switch (out[outc]) {
      case '\t':
        break;
      case 31: {  // escape
        if (++outc == bufsiz) {
          bufsiz = getbuf();
          outc = 0;
        }
        linebuf[l - 1] = out[outc];
        break;
      }
      case ' ':
        break;
      default:
        if (((unsigned char)out[outc]) < 47) {
          if (out[outc] > 32) {
            right = out[outc] - 31;
            if (++outc == bufsiz) {
              bufsiz = getbuf();
              outc = 0;
            }
          }
          if (out[outc] == 30)
            left = 9;
          else
            left = out[outc];
          linebuf[l - 1] = '\n';
          eol = 1;
        }
    }
    if (++outc == bufsiz) {
      outc = 0;
      bufsiz = fin.is_open() ? getbuf() : -1;
    }
  }
  if (right)
    strcpy(linebuf + l - 1, line + strlen(line) - right - 1);
  else
    linebuf[l] = '\0';
  strcpy(line + left, linebuf);
  dest.assign(line);
  return true;
}
