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

#ifndef LANGNUM_HXX_
#define LANGNUM_HXX_

/*
 language numbers for language specific codes
 see https://wiki.openoffice.org/w/index.php?title=Languages&oldid=230199
*/

enum {
  LANG_ar = 96,
  LANG_az = 100,  // custom number
  LANG_bg = 41,
  LANG_ca = 37,
  LANG_crh = 102, // custom number
  LANG_cs = 42,
  LANG_da = 45,
  LANG_de = 49,
  LANG_el = 30,
  LANG_en = 01,
  LANG_es = 34,
  LANG_eu = 10,
  LANG_fr = 02,
  LANG_gl = 38,
  LANG_hr = 78,
  LANG_hu = 36,
  LANG_it = 39,
  LANG_la = 99,   // custom number
  LANG_lv = 101,  // custom number
  LANG_nl = 31,
  LANG_pl = 48,
  LANG_pt = 03,
  LANG_ru = 07,
  LANG_sv = 50,
  LANG_tr = 90,
  LANG_uk = 80,
  LANG_xx = 999
};

#endif
