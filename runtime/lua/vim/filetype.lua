local api = vim.api
local fn = vim.fn

local M = {}

--- @alias vim.filetype.mapfn fun(path:string,bufnr:integer, ...):string?, fun(b:integer)?
--- @alias vim.filetype.mapopts { parent: string, priority: number }
--- @alias vim.filetype.maptbl [string|vim.filetype.mapfn, vim.filetype.mapopts]
--- @alias vim.filetype.mapping.value string|vim.filetype.mapfn|vim.filetype.maptbl
--- @alias vim.filetype.mapping table<string,vim.filetype.mapping.value>

--- @param ft string|vim.filetype.mapfn
--- @param opts? vim.filetype.mapopts
--- @return vim.filetype.maptbl
local function starsetf(ft, opts)
  return {
    function(path, bufnr)
      -- Note: when `ft` is a function its return value may be nil.
      local f = type(ft) ~= 'function' and ft or ft(path, bufnr)
      if not vim.g.ft_ignore_pat then
        return f
      end

      local re = vim.regex(vim.g.ft_ignore_pat)
      if not re:match_str(path) then
        return f
      end
    end,
    {
      -- Allow setting "parent" to be reused in closures, but don't have default as it will be
      -- assigned later from grouping
      parent = opts and opts.parent,
      -- Starset matches should have lowest priority by default
      priority = (opts and opts.priority) or -math.huge,
    },
  }
end

---@private
--- Get a line range from the buffer.
---@param bufnr integer The buffer to get the lines from
---@param start_lnum integer|nil The line number of the first line (inclusive, 1-based)
---@param end_lnum integer|nil The line number of the last line (inclusive, 1-based)
---@return string[] # Array of lines
function M._getlines(bufnr, start_lnum, end_lnum)
  if start_lnum then
    return api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum or start_lnum, false)
  end

  -- Return all lines
  return api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

---@private
--- Get a single line from the buffer.
---@param bufnr integer The buffer to get the lines from
---@param start_lnum integer The line number of the first line (inclusive, 1-based)
---@return string
function M._getline(bufnr, start_lnum)
  -- Return a single line
  return api.nvim_buf_get_lines(bufnr, start_lnum - 1, start_lnum, false)[1] or ''
end

---@private
--- Check whether a string matches any of the given Lua patterns.
---
---@param s string? The string to check
---@param patterns string[] A list of Lua patterns
---@return boolean `true` if s matched a pattern, else `false`
function M._findany(s, patterns)
  if not s then
    return false
  end
  for _, v in ipairs(patterns) do
    if s:find(v) then
      return true
    end
  end
  return false
end

---@private
--- Get the next non-whitespace line in the buffer.
---
---@param bufnr integer The buffer to get the line from
---@param start_lnum integer The line number of the first line to start from (inclusive, 1-based)
---@return string|nil The first non-blank line if found or `nil` otherwise
function M._nextnonblank(bufnr, start_lnum)
  for _, line in ipairs(M._getlines(bufnr, start_lnum, -1)) do
    if not line:find('^%s*$') then
      return line
    end
  end
  return nil
end

do
  --- @type table<string,vim.regex>
  local regex_cache = {}

  ---@private
  --- Check whether the given string matches the Vim regex pattern.
  --- @param s string?
  --- @param pattern string
  --- @return boolean
  function M._matchregex(s, pattern)
    if not s then
      return false
    end
    if not regex_cache[pattern] then
      regex_cache[pattern] = vim.regex(pattern)
    end
    return regex_cache[pattern]:match_str(s) ~= nil
  end
end

--- @module 'vim.filetype.detect'
local detect = setmetatable({}, {
  --- @param k string
  --- @param t table<string,function>
  --- @return function
  __index = function(t, k)
    t[k] = function(...)
      return require('vim.filetype.detect')[k](...)
    end
    return t[k]
  end,
})

--- @param ... string|vim.filetype.mapfn
--- @return vim.filetype.mapfn
local function detect_seq(...)
  local candidates = { ... }
  return function(...)
    for _, c in ipairs(candidates) do
      if type(c) == 'string' then
        return c
      end
      if type(c) == 'function' then
        local r = c(...)
        if r then
          return r
        end
      end
    end
  end
end

local function detect_noext(path, bufnr)
  local root = fn.fnamemodify(path, ':r')
  if root == path then
    return
  end
  return M.match({ buf = bufnr, filename = root })
end

--- @param pat string
--- @param a string?
--- @param b string?
--- @return vim.filetype.mapfn
local function detect_line1(pat, a, b)
  return function(_path, bufnr)
    if M._getline(bufnr, 1):find(pat) then
      return a
    end
    return b
  end
end

--- @type vim.filetype.mapfn
local detect_rc = function(path, _bufnr)
  if not path:find('/etc/Muttrc%.d/') then
    return 'rc'
  end
end

-- luacheck: push no unused args
-- luacheck: push ignore 122

-- Filetype detection logic is encoded in three tables:
-- 1. `extension` for literal extension lookup
-- 2. `filename` for literal full path or basename lookup;
-- 3. `pattern` for matching filenames or paths against Lua patterns,
--     optimized for fast lookup.
-- See `:h dev-vimpatch-filetype` for guidance when porting Vim filetype patches.

---@diagnostic disable: unused-local
---@type vim.filetype.mapping
local extension = {
  -- BEGIN EXTENSION
  ['8th'] = '8th',
  a65 = 'a65',
  aap = 'aap',
  abap = 'abap',
  abc = 'abc',
  abl = 'abel',
  wrm = 'acedb',
  ads = 'ada',
  ada = 'ada',
  gpr = 'ada',
  adb = 'ada',
  tdf = 'ahdl',
  aidl = 'aidl',
  aml = 'aml',
  run = 'ampl',
  g4 = 'antlr4',
  scpt = 'applescript',
  ino = 'arduino',
  pde = 'arduino',
  art = 'art',
  asciidoc = 'asciidoc',
  adoc = 'asciidoc',
  asa = function(path, bufnr)
    if vim.g.filetype_asa then
      return vim.g.filetype_asa
    end
    return 'aspvbs'
  end,
  asm = detect.asm,
  s = detect.asm,
  S = detect.asm,
  a = detect.asm,
  A = detect.asm,
  lst = detect.asm,
  mac = detect.asm,
  asn1 = 'asn',
  asn = 'asn',
  asp = detect.asp,
  astro = 'astro',
  asy = 'asy',
  atl = 'atlas',
  as = 'atlas',
  zed = 'authzed',
  ahk = 'autohotkey',
  au3 = 'autoit',
  ave = 'ave',
  gawk = 'awk',
  awk = 'awk',
  ref = 'b',
  imp = 'b',
  mch = 'b',
  bas = detect.bas,
  bass = 'bass',
  bi = detect.bas,
  bm = detect.bas,
  bc = 'bc',
  bdf = 'bdf',
  beancount = 'beancount',
  bib = 'bib',
  com = detect_seq(detect.bindzone, 'dcl'),
  db = detect.bindzone,
  bicep = 'bicep',
  bicepparam = 'bicep',
  zone = 'bindzone',
  bb = 'bitbake',
  bbappend = 'bitbake',
  bbclass = 'bitbake',
  bl = 'blank',
  blp = 'blueprint',
  bp = 'bp',
  bsd = 'bsdl',
  bsdl = 'bsdl',
  bst = 'bst',
  btm = function(path, bufnr)
    return (vim.g.dosbatch_syntax_for_btm and vim.g.dosbatch_syntax_for_btm ~= 0) and 'dosbatch'
      or 'btm'
  end,
  bzl = 'bzl',
  bazel = 'bzl',
  BUILD = 'bzl',
  mdh = 'c',
  epro = 'c',
  qc = 'c',
  cabal = 'cabal',
  cairo = 'cairo',
  capnp = 'capnp',
  cdc = 'cdc',
  cdl = 'cdl',
  toc = detect_line1('\\contentsline', 'tex', 'cdrtoc'),
  cedar = 'cedar',
  cfc = 'cf',
  cfm = 'cf',
  cfi = 'cf',
  hgrc = 'cfg',
  cfg = detect.cfg,
  Cfg = detect.cfg,
  CFG = detect.cfg,
  chf = 'ch',
  chai = 'chaiscript',
  ch = detect.change,
  chs = 'chaskell',
  chatito = 'chatito',
  chopro = 'chordpro',
  crd = 'chordpro',
  crdpro = 'chordpro',
  cho = 'chordpro',
  chordpro = 'chordpro',
  ck = 'chuck',
  eni = 'cl',
  icl = 'clean',
  cljx = 'clojure',
  clj = 'clojure',
  cljc = 'clojure',
  cljs = 'clojure',
  cook = 'cook',
  cmake = 'cmake',
  cmod = 'cmod',
  cob = 'cobol',
  cbl = 'cobol',
  atg = 'coco',
  recipe = 'conaryrecipe',
  ctags = 'conf',
  hook = function(path, bufnr)
    return M._getline(bufnr, 1) == '[Trigger]' and 'confini' or nil
  end,
  nmconnection = 'confini',
  mklx = 'context',
  mkiv = 'context',
  mkii = 'context',
  mkxl = 'context',
  mkvi = 'context',
  control = detect.control,
  copyright = detect.copyright,
  corn = 'corn',
  csh = detect.csh,
  cpon = 'cpon',
  moc = 'cpp',
  hh = 'cpp',
  tlh = 'cpp',
  inl = 'cpp',
  ipp = 'cpp',
  ['c++'] = 'cpp',
  C = 'cpp',
  cxx = 'cpp',
  H = 'cpp',
  tcc = 'cpp',
  hxx = 'cpp',
  hpp = 'cpp',
  ccm = 'cpp',
  cppm = 'cpp',
  cxxm = 'cpp',
  ['c++m'] = 'cpp',
  cpp = detect.cpp,
  cc = detect.cpp,
  cql = 'cqlang',
  crm = 'crm',
  cr = 'crystal',
  csx = 'cs',
  cs = 'cs',
  csc = 'csc',
  csdl = 'csdl',
  cshtml = 'html',
  fdr = 'csp',
  csp = 'csp',
  css = 'css',
  csv = 'csv',
  con = 'cterm',
  feature = 'cucumber',
  cuh = 'cuda',
  cu = 'cuda',
  cue = 'cue',
  pld = 'cupl',
  si = 'cuplsim',
  cyn = 'cynpp',
  cypher = 'cypher',
  dfy = 'dafny',
  dart = 'dart',
  drt = 'dart',
  ds = 'datascript',
  dat = detect.dat,
  Dat = detect.dat,
  DAT = detect.dat,
  dcd = 'dcd',
  decl = detect.decl,
  dec = detect.decl,
  dcl = detect_seq(detect.decl, 'clean'),
  def = detect.def,
  desc = 'desc',
  directory = 'desktop',
  desktop = 'desktop',
  dhall = 'dhall',
  diff = 'diff',
  rej = 'diff',
  Dockerfile = 'dockerfile',
  dockerfile = 'dockerfile',
  bat = 'dosbatch',
  wrap = 'dosini',
  ini = 'dosini',
  INI = 'dosini',
  vbp = 'dosini',
  dot = 'dot',
  gv = 'dot',
  drac = 'dracula',
  drc = 'dracula',
  lvs = 'dracula',
  lpe = 'dracula',
  dsp = detect.dsp,
  dtd = 'dtd',
  d = detect.dtrace,
  dts = 'dts',
  dtsi = 'dts',
  dtso = 'dts',
  its = 'dts',
  keymap = 'dts',
  dylan = 'dylan',
  intr = 'dylanintr',
  lid = 'dylanlid',
  e = detect.e,
  E = detect.e,
  ecd = 'ecd',
  edf = 'edif',
  edif = 'edif',
  edo = 'edif',
  edn = detect.edn,
  eex = 'eelixir',
  leex = 'eelixir',
  am = 'elf',
  exs = 'elixir',
  elm = 'elm',
  lc = 'elsa',
  elv = 'elvish',
  ent = detect.ent,
  epp = 'epuppet',
  erl = 'erlang',
  hrl = 'erlang',
  yaws = 'erlang',
  erb = 'eruby',
  rhtml = 'eruby',
  esdl = 'esdl',
  ec = 'esqlc',
  EC = 'esqlc',
  strl = 'esterel',
  eu = detect.euphoria,
  EU = detect.euphoria,
  ew = detect.euphoria,
  EW = detect.euphoria,
  EX = detect.euphoria,
  exu = detect.euphoria,
  EXU = detect.euphoria,
  exw = detect.euphoria,
  EXW = detect.euphoria,
  ex = detect.ex,
  exp = 'expect',
  f = detect.f,
  factor = 'factor',
  fal = 'falcon',
  fan = 'fan',
  fwt = 'fan',
  lib = 'faust',
  fnl = 'fennel',
  m4gl = 'fgl',
  ['4gl'] = 'fgl',
  ['4gh'] = 'fgl',
  fir = 'firrtl',
  fish = 'fish',
  focexec = 'focexec',
  fex = 'focexec',
  ft = 'forth',
  fth = 'forth',
  ['4th'] = 'forth',
  FOR = 'fortran',
  f77 = 'fortran',
  f03 = 'fortran',
  fortran = 'fortran',
  F95 = 'fortran',
  f90 = 'fortran',
  F03 = 'fortran',
  fpp = 'fortran',
  FTN = 'fortran',
  ftn = 'fortran',
  ['for'] = 'fortran',
  F90 = 'fortran',
  F77 = 'fortran',
  f95 = 'fortran',
  FPP = 'fortran',
  F = 'fortran',
  F08 = 'fortran',
  f08 = 'fortran',
  fpc = 'fpcmake',
  fsl = 'framescript',
  frm = detect.frm,
  fb = 'freebasic',
  fs = detect.fs,
  fsh = 'fsh',
  fsi = 'fsharp',
  fsx = 'fsharp',
  fc = 'func',
  fusion = 'fusion',
  gdb = 'gdb',
  gdmo = 'gdmo',
  mo = 'gdmo',
  tscn = 'gdresource',
  tres = 'gdresource',
  gd = 'gdscript',
  gdshader = 'gdshader',
  shader = 'gdshader',
  ged = 'gedcom',
  gmi = 'gemtext',
  gemini = 'gemtext',
  gift = 'gift',
  prettierignore = 'gitignore',
  gleam = 'gleam',
  vert = 'glsl',
  tesc = 'glsl',
  tese = 'glsl',
  glsl = 'glsl',
  geom = 'glsl',
  frag = 'glsl',
  comp = 'glsl',
  rgen = 'glsl',
  rmiss = 'glsl',
  rchit = 'glsl',
  rahit = 'glsl',
  rint = 'glsl',
  rcall = 'glsl',
  gn = 'gn',
  gni = 'gn',
  gnuplot = 'gnuplot',
  gpi = 'gnuplot',
  go = 'go',
  gp = 'gp',
  gs = 'grads',
  gql = 'graphql',
  graphql = 'graphql',
  graphqls = 'graphql',
  gretl = 'gretl',
  gradle = 'groovy',
  groovy = 'groovy',
  gsp = 'gsp',
  gjs = 'javascript.glimmer',
  gts = 'typescript.glimmer',
  gyp = 'gyp',
  gypi = 'gyp',
  hack = 'hack',
  hackpartial = 'hack',
  haml = 'haml',
  hsm = 'hamster',
  hbs = 'handlebars',
  ha = 'hare',
  ['hs-boot'] = 'haskell',
  hsig = 'haskell',
  hsc = 'haskell',
  hs = 'haskell',
  persistentmodels = 'haskellpersistent',
  ht = 'haste',
  htpp = 'hastepreproc',
  hcl = 'hcl',
  hb = 'hb',
  h = detect.header,
  sum = 'hercules',
  errsum = 'hercules',
  ev = 'hercules',
  vc = 'hercules',
  heex = 'heex',
  hex = 'hex',
  ['a43'] = 'hex',
  ['a90'] = 'hex',
  ['h32'] = 'hex',
  ['h80'] = 'hex',
  ['h86'] = 'hex',
  ihex = 'hex',
  ihe = 'hex',
  ihx = 'hex',
  int = 'hex',
  mcs = 'hex',
  hjson = 'hjson',
  m3u = 'hlsplaylist',
  m3u8 = 'hlsplaylist',
  hog = 'hog',
  hws = 'hollywood',
  hoon = 'hoon',
  cpt = detect.html,
  dtml = detect.html,
  htm = detect.html,
  html = detect.html,
  pt = detect.html,
  shtml = detect.html,
  stm = detect.html,
  htt = 'httest',
  htb = 'httest',
  http = 'http',
  hurl = 'hurl',
  hw = detect.hw,
  module = detect.hw,
  pkg = detect.hw,
  iba = 'ibasic',
  ibi = 'ibasic',
  icn = 'icon',
  idl = detect.idl,
  inc = detect.inc,
  inf = 'inform',
  INF = 'inform',
  ii = 'initng',
  inko = 'inko',
  inp = detect.inp,
  ms = detect_seq(detect.nroff, 'xmath'),
  iss = 'iss',
  mst = 'ist',
  ist = 'ist',
  ijs = 'j',
  JAL = 'jal',
  jal = 'jal',
  jpr = 'jam',
  jpl = 'jam',
  janet = 'janet',
  jav = 'java',
  java = 'java',
  jj = 'javacc',
  jjt = 'javacc',
  es = 'javascript',
  mjs = 'javascript',
  javascript = 'javascript',
  js = 'javascript',
  jsm = 'javascript',
  cjs = 'javascript',
  jsx = 'javascriptreact',
  clp = 'jess',
  jgr = 'jgraph',
  jinja = 'jinja',
  jjdescription = 'jj',
  j73 = 'jovial',
  jov = 'jovial',
  jovial = 'jovial',
  properties = 'jproperties',
  jq = 'jq',
  slnf = 'json',
  json = 'json',
  jsonp = 'json',
  geojson = 'json',
  mcmeta = 'json',
  webmanifest = 'json',
  ipynb = 'json',
  ['jupyterlab-settings'] = 'json',
  ['sublime-project'] = 'json',
  ['sublime-settings'] = 'json',
  ['sublime-workspace'] = 'json',
  ['json-patch'] = 'json',
  bd = 'json',
  bda = 'json',
  xci = 'json',
  json5 = 'json5',
  jsonc = 'jsonc',
  jsonl = 'jsonl',
  jsonnet = 'jsonnet',
  libsonnet = 'jsonnet',
  jsp = 'jsp',
  jl = 'julia',
  just = 'just',
  kdl = 'kdl',
  kv = 'kivy',
  kix = 'kix',
  kts = 'kotlin',
  kt = 'kotlin',
  ktm = 'kotlin',
  sub = 'krl',
  Sub = 'krl',
  SUB = 'krl',
  ks = 'kscript',
  k = 'kwt',
  ACE = 'lace',
  ace = 'lace',
  latte = 'latte',
  lte = 'latte',
  ld = 'ld',
  ldif = 'ldif',
  lean = 'lean',
  journal = 'ledger',
  ldg = 'ledger',
  ledger = 'ledger',
  less = 'less',
  lex = 'lex',
  lxx = 'lex',
  ['l++'] = 'lex',
  l = 'lex',
  lhs = 'lhaskell',
  ll = 'lifelines',
  ly = 'lilypond',
  ily = 'lilypond',
  liquid = 'liquid',
  liq = 'liquidsoap',
  cl = 'lisp',
  L = 'lisp',
  lisp = 'lisp',
  el = 'lisp',
  lsp = 'lisp',
  asd = 'lisp',
  stsg = 'lisp',
  lt = 'lite',
  lite = 'lite',
  livemd = 'livebook',
  log = detect.log,
  Log = detect.log,
  LOG = detect.log,
  lgt = 'logtalk',
  lotos = 'lotos',
  lot = detect_line1('\\contentsline', 'tex', 'lotos'),
  lout = 'lout',
  lou = 'lout',
  ulpc = 'lpc',
  lpc = 'lpc',
  c = detect.lpc,
  lsl = detect.lsl,
  lss = 'lss',
  nse = 'lua',
  rockspec = 'lua',
  lua = 'lua',
  tlu = 'lua',
  luau = 'luau',
  lrc = 'lyrics',
  m = detect.m,
  at = 'm4',
  mc = detect.mc,
  quake = 'm3quake',
  m4 = function(path, bufnr)
    path = path:lower()
    return not (path:find('html%.m4$') or path:find('fvwm2rc')) and 'm4' or nil
  end,
  eml = 'mail',
  mk = detect.make,
  mak = detect.make,
  page = 'mallard',
  map = 'map',
  mws = 'maple',
  mpl = 'maple',
  mv = 'maple',
  mkdn = detect.markdown,
  md = detect.markdown,
  mdwn = detect.markdown,
  mkd = detect.markdown,
  markdown = detect.markdown,
  mdown = detect.markdown,
  mhtml = 'mason',
  mason = 'mason',
  master = 'master',
  mas = 'master',
  demo = 'maxima',
  dm1 = 'maxima',
  dm2 = 'maxima',
  dm3 = 'maxima',
  dmt = 'maxima',
  wxm = 'maxima',
  mw = 'mediawiki',
  wiki = 'mediawiki',
  mel = 'mel',
  mmd = 'mermaid',
  mmdc = 'mermaid',
  mermaid = 'mermaid',
  mf = 'mf',
  mgl = 'mgl',
  mgp = 'mgp',
  my = 'mib',
  mib = 'mib',
  mix = 'mix',
  mixal = 'mix',
  mm = detect.mm,
  nb = 'mma',
  wl = 'mma',
  mmp = 'mmp',
  mms = detect.mms,
  mod = detect.mod,
  Mod = detect.mod,
  MOD = detect.mod,
  DEF = 'modula2',
  m3 = 'modula3',
  i3 = 'modula3',
  mg = 'modula3',
  ig = 'modula3',
  lm3 = 'modula3',
  mojo = 'mojo',
  ['🔥'] = 'mojo', -- 🙄
  ssc = 'monk',
  monk = 'monk',
  tsc = 'monk',
  isc = 'monk',
  moo = 'moo',
  moon = 'moonscript',
  move = 'move',
  mp = 'mp',
  mpiv = detect.mp,
  mpvi = detect.mp,
  mpxl = detect.mp,
  mof = 'msidl',
  odl = 'msidl',
  msql = 'msql',
  mu = 'mupad',
  mush = 'mush',
  mustache = 'mustache',
  mysql = 'mysql',
  n1ql = 'n1ql',
  nql = 'n1ql',
  nanorc = 'nanorc',
  NSA = 'natural',
  NSC = 'natural',
  NSG = 'natural',
  NSL = 'natural',
  NSM = 'natural',
  NSN = 'natural',
  NSP = 'natural',
  NSS = 'natural',
  ncf = 'ncf',
  nginx = 'nginx',
  nim = 'nim',
  nims = 'nim',
  nimble = 'nim',
  ninja = 'ninja',
  nix = 'nix',
  norg = 'norg',
  nqc = 'nqc',
  ['1'] = detect.nroff,
  ['2'] = detect.nroff,
  ['3'] = detect.nroff,
  ['4'] = detect.nroff,
  ['5'] = detect.nroff,
  ['6'] = detect.nroff,
  ['7'] = detect.nroff,
  ['8'] = detect.nroff,
  ['9'] = detect.nroff,
  roff = 'nroff',
  tmac = 'nroff',
  man = 'nroff',
  mom = 'nroff',
  nr = 'nroff',
  tr = 'nroff',
  nsi = 'nsis',
  nsh = 'nsis',
  nu = 'nu',
  obj = 'obj',
  objdump = 'objdump',
  cppobjdump = 'objdump',
  obl = 'obse',
  obse = 'obse',
  oblivion = 'obse',
  obscript = 'obse',
  mlt = 'ocaml',
  mly = 'ocaml',
  mll = 'ocaml',
  mlp = 'ocaml',
  mlip = 'ocaml',
  mli = 'ocaml',
  ml = 'ocaml',
  occ = 'occam',
  odin = 'odin',
  xom = 'omnimark',
  xin = 'omnimark',
  opam = 'opam',
  ['or'] = 'openroad',
  scad = 'openscad',
  ovpn = 'openvpn',
  opl = 'opl',
  opL = 'opl',
  oPl = 'opl',
  oPL = 'opl',
  Opl = 'opl',
  OpL = 'opl',
  OPl = 'opl',
  OPL = 'opl',
  ora = 'ora',
  org = 'org',
  org_archive = 'org',
  pandoc = 'pandoc',
  pdk = 'pandoc',
  pd = 'pandoc',
  pdc = 'pandoc',
  pxsl = 'papp',
  papp = 'papp',
  pxml = 'papp',
  pas = 'pascal',
  lpr = detect_line1('<%?xml', 'xml', 'pascal'),
  dpr = 'pascal',
  txtpb = 'pbtxt',
  textproto = 'pbtxt',
  textpb = 'pbtxt',
  pbtxt = 'pbtxt',
  g = 'pccts',
  pcmk = 'pcmk',
  pdf = 'pdf',
  pem = 'pem',
  cer = 'pem',
  crt = 'pem',
  csr = 'pem',
  plx = 'perl',
  prisma = 'prisma',
  psgi = 'perl',
  al = 'perl',
  ctp = 'php',
  php = 'php',
  phpt = 'php',
  php0 = 'php',
  php1 = 'php',
  php2 = 'php',
  php3 = 'php',
  php4 = 'php',
  php5 = 'php',
  php6 = 'php',
  php7 = 'php',
  php8 = 'php',
  php9 = 'php',
  phtml = 'php',
  theme = 'php',
  pike = 'pike',
  pmod = 'pike',
  rcp = 'pilrc',
  PL = detect.pl,
  pli = 'pli',
  pl1 = 'pli',
  p36 = 'plm',
  plm = 'plm',
  pac = 'plm',
  plp = 'plp',
  pls = 'plsql',
  plsql = 'plsql',
  po = 'po',
  pot = 'po',
  pod = 'pod',
  filter = 'poefilter',
  pk = 'poke',
  pony = 'pony',
  ps = 'postscr',
  epsi = 'postscr',
  afm = 'postscr',
  epsf = 'postscr',
  eps = 'postscr',
  pfa = 'postscr',
  ai = 'postscr',
  pov = 'pov',
  ppd = 'ppd',
  it = 'ppwiz',
  ih = 'ppwiz',
  action = 'privoxy',
  prg = detect.prg,
  Prg = detect.prg,
  PRG = detect.prg,
  pc = 'proc',
  pdb = 'prolog',
  pml = 'promela',
  proto = 'proto',
  prql = 'prql',
  psd1 = 'ps1',
  psm1 = 'ps1',
  ps1 = 'ps1',
  pssc = 'ps1',
  ps1xml = 'ps1xml',
  psf = 'psf',
  psl = 'psl',
  pug = 'pug',
  purs = 'purescript',
  arr = 'pyret',
  pxd = 'pyrex',
  pyx = 'pyrex',
  pyw = 'python',
  py = 'python',
  pyi = 'python',
  ptl = 'python',
  ql = 'ql',
  qll = 'ql',
  qml = 'qml',
  qbs = 'qml',
  qmd = 'quarto',
  R = detect.r,
  rkt = 'racket',
  rktd = 'racket',
  rktl = 'racket',
  rad = 'radiance',
  mat = 'radiance',
  pod6 = 'raku',
  rakudoc = 'raku',
  rakutest = 'raku',
  rakumod = 'raku',
  pm6 = 'raku',
  raku = 'raku',
  t6 = 'raku',
  p6 = 'raku',
  raml = 'raml',
  sysx = 'rapid',
  sysX = 'rapid',
  Sysx = 'rapid',
  SysX = 'rapid',
  SYSX = 'rapid',
  SYSx = 'rapid',
  modx = 'rapid',
  modX = 'rapid',
  Modx = 'rapid',
  ModX = 'rapid',
  MODX = 'rapid',
  MODx = 'rapid',
  rasi = 'rasi',
  rbs = 'rbs',
  rego = 'rego',
  rem = 'remind',
  remind = 'remind',
  pip = 'requirements',
  res = 'rescript',
  resi = 'rescript',
  frt = 'reva',
  testUnit = 'rexx',
  rex = 'rexx',
  orx = 'rexx',
  rexx = 'rexx',
  jrexx = 'rexx',
  rxj = 'rexx',
  rexxj = 'rexx',
  testGroup = 'rexx',
  rxo = 'rexx',
  Rd = 'rhelp',
  rd = 'rhelp',
  rib = 'rib',
  Rmd = 'rmd',
  rmd = 'rmd',
  smd = 'rmd',
  Smd = 'rmd',
  rnc = 'rnc',
  rng = 'rng',
  rnw = 'rnoweb',
  snw = 'rnoweb',
  Rnw = 'rnoweb',
  Snw = 'rnoweb',
  robot = 'robot',
  resource = 'robot',
  roc = 'roc',
  ron = 'ron',
  rsc = 'routeros',
  x = 'rpcgen',
  rpgle = 'rpgle',
  rpgleinc = 'rpgle',
  rpl = 'rpl',
  Srst = 'rrst',
  srst = 'rrst',
  Rrst = 'rrst',
  rrst = 'rrst',
  rst = 'rst',
  rtf = 'rtf',
  rjs = 'ruby',
  rxml = 'ruby',
  rb = 'ruby',
  rant = 'ruby',
  ru = 'ruby',
  rbw = 'ruby',
  gemspec = 'ruby',
  builder = 'ruby',
  rake = 'ruby',
  rs = 'rust',
  sage = 'sage',
  sls = 'salt',
  sas = 'sas',
  sass = 'sass',
  sa = 'sather',
  sbt = 'sbt',
  scala = 'scala',
  ss = 'scheme',
  scm = 'scheme',
  sld = 'scheme',
  sce = 'scilab',
  sci = 'scilab',
  scss = 'scss',
  sd = 'sd',
  sdc = 'sdc',
  pr = 'sdl',
  sdl = 'sdl',
  sed = 'sed',
  sexp = 'sexplib',
  bash = detect.bash,
  bats = detect.bash,
  cygport = detect.bash,
  ebuild = detect.bash,
  eclass = detect.bash,
  env = detect.sh,
  envrc = detect.sh,
  ksh = detect.ksh,
  sh = detect.sh,
  mdd = 'sh',
  sieve = 'sieve',
  siv = 'sieve',
  sig = detect.sig,
  sil = detect.sil,
  sim = 'simula',
  s85 = 'sinda',
  sin = 'sinda',
  ssm = 'sisu',
  sst = 'sisu',
  ssi = 'sisu',
  ['_sst'] = 'sisu',
  ['-sst'] = 'sisu',
  il = 'skill',
  ils = 'skill',
  cdf = 'skill',
  sl = 'slang',
  ice = 'slice',
  slint = 'slint',
  score = 'slrnsc',
  sol = 'solidity',
  smali = 'smali',
  tpl = 'smarty',
  ihlp = 'smcl',
  smcl = 'smcl',
  hlp = 'smcl',
  smith = 'smith',
  smt = 'smith',
  smithy = 'smithy',
  sml = 'sml',
  smk = 'snakemake',
  spt = 'snobol4',
  sno = 'snobol4',
  sln = 'solution',
  sparql = 'sparql',
  rq = 'sparql',
  spec = 'spec',
  spice = 'spice',
  sp = 'spice',
  spd = 'spup',
  spdata = 'spup',
  speedup = 'spup',
  spi = 'spyce',
  spy = 'spyce',
  tyc = 'sql',
  typ = detect.typ,
  pkb = 'sql',
  tyb = 'sql',
  pks = 'sql',
  sqlj = 'sqlj',
  sqi = 'sqr',
  sqr = 'sqr',
  nut = 'squirrel',
  src = detect.src,
  Src = detect.src,
  SRC = detect.src,
  s28 = 'srec',
  s37 = 'srec',
  srec = 'srec',
  mot = 'srec',
  s19 = 'srec',
  srt = 'srt',
  ssa = 'ssa',
  ass = 'ssa',
  st = 'st',
  ipd = 'starlark',
  star = 'starlark',
  starlark = 'starlark',
  imata = 'stata',
  ['do'] = 'stata',
  mata = 'stata',
  ado = 'stata',
  stp = 'stp',
  styl = 'stylus',
  stylus = 'stylus',
  quark = 'supercollider',
  sface = 'surface',
  svelte = 'svelte',
  svg = 'svg',
  swift = 'swift',
  swiftinterface = 'swift',
  swig = 'swig',
  swg = 'swig',
  sys = detect.sys,
  Sys = detect.sys,
  SYS = detect.sys,
  svh = 'systemverilog',
  sv = 'systemverilog',
  cmm = 'trace32',
  t32 = 'trace32',
  td = 'tablegen',
  tak = 'tak',
  tal = 'tal',
  task = 'taskedit',
  tm = 'tcl',
  tcl = 'tcl',
  itk = 'tcl',
  itcl = 'tcl',
  tk = 'tcl',
  jacl = 'tcl',
  tl = 'teal',
  templ = 'templ',
  tmpl = 'template',
  ti = 'terminfo',
  dtx = 'tex',
  ltx = 'tex',
  bbl = 'tex',
  latex = 'tex',
  sty = 'tex',
  pgf = 'tex',
  nlo = 'tex',
  nls = 'tex',
  thm = 'tex',
  eps_tex = 'tex',
  pdf_tex = 'tex',
  pygtex = 'tex',
  pygstyle = 'tex',
  clo = 'tex',
  aux = 'tex',
  brf = 'tex',
  ind = 'tex',
  lof = 'tex',
  loe = 'tex',
  nav = 'tex',
  vrb = 'tex',
  ins = 'tex',
  tikz = 'tex',
  bbx = 'tex',
  cbx = 'tex',
  beamer = 'tex',
  cls = detect.cls,
  texi = 'texinfo',
  txi = 'texinfo',
  texinfo = 'texinfo',
  text = 'text',
  tfvars = 'terraform-vars',
  thrift = 'thrift',
  tla = 'tla',
  tli = 'tli',
  toml = 'toml',
  tpp = 'tpp',
  treetop = 'treetop',
  slt = 'tsalt',
  tsscl = 'tsscl',
  tssgm = 'tssgm',
  tssop = 'tssop',
  tsv = 'tsv',
  tutor = 'tutor',
  twig = 'twig',
  ts = detect_line1('<%?xml', 'xml', 'typescript'),
  mts = 'typescript',
  cts = 'typescript',
  tsx = 'typescriptreact',
  tsp = 'typespec',
  uc = 'uc',
  uit = 'uil',
  uil = 'uil',
  ungram = 'ungrammar',
  u = 'unison',
  uu = 'unison',
  url = 'urlshortcut',
  usd = 'usd',
  usda = 'usd',
  v = detect.v,
  vsh = 'v',
  vv = 'v',
  ctl = 'vb',
  dob = 'vb',
  dsm = 'vb',
  dsr = 'vb',
  pag = 'vb',
  sba = 'vb',
  vb = 'vb',
  vbs = 'vb',
  vba = detect.vba,
  vdf = 'vdf',
  vdmpp = 'vdmpp',
  vpp = 'vdmpp',
  vdmrt = 'vdmrt',
  vdmsl = 'vdmsl',
  vdm = 'vdmsl',
  vto = 'vento',
  vr = 'vera',
  vri = 'vera',
  vrh = 'vera',
  va = 'verilogams',
  vams = 'verilogams',
  vhdl = 'vhdl',
  vst = 'vhdl',
  vhd = 'vhdl',
  hdl = 'vhdl',
  vho = 'vhdl',
  vbe = 'vhdl',
  tape = 'vhs',
  vim = 'vim',
  mar = 'vmasm',
  cm = 'voscm',
  wrl = 'vrml',
  vroom = 'vroom',
  vue = 'vue',
  wast = 'wat',
  wat = 'wat',
  wdl = 'wdl',
  wm = 'webmacro',
  wgsl = 'wgsl',
  wbt = 'winbatch',
  wit = 'wit',
  wml = 'wml',
  wsf = 'wsh',
  wsc = 'wsh',
  wsml = 'wsml',
  ad = 'xdefaults',
  xhtml = 'xhtml',
  xht = 'xhtml',
  msc = 'xmath',
  msf = 'xmath',
  psc1 = 'xml',
  tpm = 'xml',
  xliff = 'xml',
  atom = 'xml',
  xul = 'xml',
  cdxml = 'xml',
  mpd = 'xml',
  rss = 'xml',
  fsproj = 'xml',
  ui = 'xml',
  vbproj = 'xml',
  xlf = 'xml',
  wsdl = 'xml',
  csproj = 'xml',
  wpl = 'xml',
  xmi = 'xml',
  xpr = 'xml',
  xpfm = 'xml',
  spfm = 'xml',
  bxml = 'xml',
  xcu = 'xml',
  xlb = 'xml',
  xlc = 'xml',
  xba = 'xml',
  xpm = detect_line1('XPM2', 'xpm2', 'xpm'),
  xpm2 = 'xpm2',
  xqy = 'xquery',
  xqm = 'xquery',
  xquery = 'xquery',
  xq = 'xquery',
  xql = 'xquery',
  xs = 'xs',
  xsd = 'xsd',
  xsl = 'xslt',
  xslt = 'xslt',
  yy = 'yacc',
  ['y++'] = 'yacc',
  yxx = 'yacc',
  yml = 'yaml',
  yaml = 'yaml',
  eyaml = 'yaml',
  mplstyle = 'yaml',
  yang = 'yang',
  yuck = 'yuck',
  z8a = 'z8a',
  zig = 'zig',
  zon = 'zig',
  ziggy = 'ziggy',
  ['ziggy-schema'] = 'ziggy_schema',
  zu = 'zimbu',
  zut = 'zimbutempl',
  zs = 'zserio',
  zsh = 'zsh',
  zunit = 'zsh',
  ['zsh-theme'] = 'zsh',
  vala = 'vala',
  web = detect.web,
  pl = detect.pl,
  pp = detect.pp,
  i = detect.i,
  w = detect.progress_cweb,
  p = detect.progress_pascal,
  pro = detect_seq(detect.proto, 'idlang'),
  patch = detect.patch,
  r = detect.r,
  rdf = detect.redif,
  rules = detect.rules,
  sc = detect.sc,
  scd = detect.scd,
  tcsh = function(path, bufnr)
    return require('vim.filetype.detect').shell(path, M._getlines(bufnr), 'tcsh')
  end,
  sql = detect.sql,
  zsql = detect.sql,
  tex = detect.tex,
  tf = detect.tf,
  txt = detect.txt,
  xml = detect.xml,
  y = detect.y,
  cmd = detect_line1('^/%*', 'rexx', 'dosbatch'),
  rul = detect.rul,
  cpy = detect_line1('^##', 'python', 'cobol'),
  dsl = detect_line1('^%s*<!', 'dsl', 'structurizr'),
  smil = detect_line1('<%?%s*xml.*%?>', 'xml', 'smil'),
  smi = detect.smi,
  install = detect.install,
  pm = detect.pm,
  me = detect.me,
  reg = detect.reg,
  ttl = detect.ttl,
  rc = detect_rc,
  rch = detect_rc,
  class = detect.class,
  sgml = detect.sgml,
  sgm = detect.sgml,
  t = detect_seq(detect.nroff, detect.perl, 'tads'),
  -- Ignored extensions
  bak = detect_noext,
  ['dpkg-bak'] = detect_noext,
  ['dpkg-dist'] = detect_noext,
  ['dpkg-old'] = detect_noext,
  ['dpkg-new'] = detect_noext,
  ['in'] = function(path, bufnr)
    if vim.fs.basename(path) ~= 'configure.in' then
      return detect_noext(path, bufnr)
    end
  end,
  new = detect_noext,
  old = detect_noext,
  orig = detect_noext,
  pacsave = detect_noext,
  pacnew = detect_noext,
  rpmsave = detect_noext,
  rmpnew = detect_noext,
  -- END EXTENSION
}

---@type vim.filetype.mapping
local filename = {
  -- BEGIN FILENAME
  ['a2psrc'] = 'a2ps',
  ['/etc/a2ps.cfg'] = 'a2ps',
  ['.a2psrc'] = 'a2ps',
  ['.asoundrc'] = 'alsaconf',
  ['/usr/share/alsa/alsa.conf'] = 'alsaconf',
  ['/etc/asound.conf'] = 'alsaconf',
  ['build.xml'] = 'ant',
  ['.htaccess'] = 'apache',
  ['apt.conf'] = 'aptconf',
  ['/.aptitude/config'] = 'aptconf',
  ['=tagging-method'] = 'arch',
  ['.arch-inventory'] = 'arch',
  ['makefile.am'] = 'automake',
  ['Makefile.am'] = 'automake',
  ['GNUmakefile.am'] = 'automake',
  ['.bash_aliases'] = detect.bash,
  ['.bash-aliases'] = detect.bash,
  ['.bash_history'] = detect.bash,
  ['.bash-history'] = detect.bash,
  ['.bash_logout'] = detect.bash,
  ['.bash-logout'] = detect.bash,
  ['.bash_profile'] = detect.bash,
  ['.bash-profile'] = detect.bash,
  ['named.root'] = 'bindzone',
  WORKSPACE = 'bzl',
  ['WORKSPACE.bzlmod'] = 'bzl',
  BUCK = 'bzl',
  BUILD = 'bzl',
  ['cabal.project'] = 'cabalproject',
  ['cabal.config'] = 'cabalconfig',
  calendar = 'calendar',
  catalog = 'catalog',
  ['/etc/cdrdao.conf'] = 'cdrdaoconf',
  ['.cdrdao'] = 'cdrdaoconf',
  ['/etc/default/cdrdao'] = 'cdrdaoconf',
  ['/etc/defaults/cdrdao'] = 'cdrdaoconf',
  ['cfengine.conf'] = 'cfengine',
  cgdbrc = 'cgdbrc',
  ['init.trans'] = 'clojure',
  ['.trans'] = 'clojure',
  ['CMakeLists.txt'] = 'cmake',
  ['CMakeCache.txt'] = 'cmakecache',
  ['.cling_history'] = 'cpp',
  ['.alias'] = detect.csh,
  ['.cshrc'] = detect.csh,
  ['.login'] = detect.csh,
  ['csh.cshrc'] = detect.csh,
  ['csh.login'] = detect.csh,
  ['csh.logout'] = detect.csh,
  ['auto.master'] = 'conf',
  ['texdoc.cnf'] = 'conf',
  ['.x11vncrc'] = 'conf',
  ['.chktexrc'] = 'conf',
  ['.ripgreprc'] = 'conf',
  ripgreprc = 'conf',
  ['.mbsyncrc'] = 'conf',
  ['configure.in'] = 'config',
  ['configure.ac'] = 'config',
  crontab = 'crontab',
  ['.cvsrc'] = 'cvsrc',
  ['/debian/changelog'] = 'debchangelog',
  ['changelog.dch'] = 'debchangelog',
  ['changelog.Debian'] = 'debchangelog',
  ['NEWS.dch'] = 'debchangelog',
  ['NEWS.Debian'] = 'debchangelog',
  ['/debian/control'] = 'debcontrol',
  ['/debian/copyright'] = 'debcopyright',
  ['/etc/apt/sources.list'] = 'debsources',
  ['denyhosts.conf'] = 'denyhosts',
  ['dict.conf'] = 'dictconf',
  ['.dictrc'] = 'dictconf',
  ['/etc/DIR_COLORS'] = 'dircolors',
  ['.dir_colors'] = 'dircolors',
  ['.dircolors'] = 'dircolors',
  ['/etc/dnsmasq.conf'] = 'dnsmasq',
  Containerfile = 'dockerfile',
  dockerfile = 'dockerfile',
  Dockerfile = 'dockerfile',
  npmrc = 'dosini',
  ['/etc/yum.conf'] = 'dosini',
  ['.npmrc'] = 'dosini',
  ['pip.conf'] = 'dosini',
  ['setup.cfg'] = 'dosini',
  ['pudb.cfg'] = 'dosini',
  ['.coveragerc'] = 'dosini',
  ['.pypirc'] = 'dosini',
  ['.pylintrc'] = 'dosini',
  ['pylintrc'] = 'dosini',
  ['.replyrc'] = 'dosini',
  ['.gitlint'] = 'dosini',
  ['.oelint.cfg'] = 'dosini',
  ['psprint.conf'] = 'dosini',
  sofficerc = 'dosini',
  ['mimeapps.list'] = 'dosini',
  ['.wakatime.cfg'] = 'dosini',
  ['nfs.conf'] = 'dosini',
  ['nfsmount.conf'] = 'dosini',
  ['.notmuch-config'] = 'dosini',
  ['pacman.conf'] = 'confini',
  ['paru.conf'] = 'confini',
  ['mpv.conf'] = 'confini',
  dune = 'dune',
  jbuild = 'dune',
  ['dune-workspace'] = 'dune',
  ['dune-project'] = 'dune',
  ['dune-file'] = 'dune',
  Earthfile = 'earthfile',
  ['.editorconfig'] = 'editorconfig',
  ['elinks.conf'] = 'elinks',
  ['mix.lock'] = 'elixir',
  ['filter-rules'] = 'elmfilt',
  ['exim.conf'] = 'exim',
  exports = 'exports',
  ['.fetchmailrc'] = 'fetchmail',
  fvSchemes = detect.foam,
  fvSolution = detect.foam,
  fvConstraints = detect.foam,
  fvModels = detect.foam,
  fstab = 'fstab',
  mtab = 'fstab',
  ['.gdbinit'] = 'gdb',
  gdbinit = 'gdb',
  ['.gdbearlyinit'] = 'gdb',
  gdbearlyinit = 'gdb',
  ['lltxxxxx.txt'] = 'gedcom',
  TAG_EDITMSG = 'gitcommit',
  MERGE_MSG = 'gitcommit',
  COMMIT_EDITMSG = 'gitcommit',
  NOTES_EDITMSG = 'gitcommit',
  EDIT_DESCRIPTION = 'gitcommit',
  ['.gitconfig'] = 'gitconfig',
  ['.gitmodules'] = 'gitconfig',
  ['.gitattributes'] = 'gitattributes',
  ['.gitignore'] = 'gitignore',
  ['gitolite.conf'] = 'gitolite',
  ['git-rebase-todo'] = 'gitrebase',
  gkrellmrc = 'gkrellmrc',
  ['.gnashrc'] = 'gnash',
  ['.gnashpluginrc'] = 'gnash',
  gnashpluginrc = 'gnash',
  gnashrc = 'gnash',
  ['.gnuplot_history'] = 'gnuplot',
  ['goaccess.conf'] = 'goaccess',
  ['go.sum'] = 'gosum',
  ['go.work.sum'] = 'gosum',
  ['go.work'] = 'gowork',
  ['.gprc'] = 'gp',
  ['/.gnupg/gpg.conf'] = 'gpg',
  ['/.gnupg/options'] = 'gpg',
  Jenkinsfile = 'groovy',
  ['/var/backups/gshadow.bak'] = 'group',
  ['/etc/gshadow'] = 'group',
  ['/etc/group-'] = 'group',
  ['/etc/gshadow.edit'] = 'group',
  ['/etc/gshadow-'] = 'group',
  ['/etc/group'] = 'group',
  ['/var/backups/group.bak'] = 'group',
  ['/etc/group.edit'] = 'group',
  ['/boot/grub/menu.lst'] = 'grub',
  ['/etc/grub.conf'] = 'grub',
  ['/boot/grub/grub.conf'] = 'grub',
  ['.gtkrc'] = 'gtkrc',
  gtkrc = 'gtkrc',
  ['snort.conf'] = 'hog',
  ['vision.conf'] = 'hog',
  ['/etc/host.conf'] = 'hostconf',
  ['/etc/hosts.allow'] = 'hostsaccess',
  ['/etc/hosts.deny'] = 'hostsaccess',
  ['hyprland.conf'] = 'hyprlang',
  ['hyprpaper.conf'] = 'hyprlang',
  ['hypridle.conf'] = 'hyprlang',
  ['hyprlock.conf'] = 'hyprlang',
  ['/.icewm/menu'] = 'icemenu',
  ['.indent.pro'] = 'indent',
  indentrc = 'indent',
  inittab = 'inittab',
  ['ipf.conf'] = 'ipfilter',
  ['ipf6.conf'] = 'ipfilter',
  ['ipf.rules'] = 'ipfilter',
  ['.bun_repl_history'] = 'javascript',
  ['.node_repl_history'] = 'javascript',
  ['deno_history.txt'] = 'javascript',
  ['Pipfile.lock'] = 'json',
  ['.firebaserc'] = 'json',
  ['.prettierrc'] = 'json',
  ['.stylelintrc'] = 'json',
  ['.lintstagedrc'] = 'json',
  ['deno.lock'] = 'json',
  ['flake.lock'] = 'json',
  ['.babelrc'] = 'jsonc',
  ['.eslintrc'] = 'jsonc',
  ['.hintrc'] = 'jsonc',
  ['.jscsrc'] = 'jsonc',
  ['.jsfmtrc'] = 'jsonc',
  ['.jshintrc'] = 'jsonc',
  ['.luaurc'] = 'jsonc',
  ['.swrc'] = 'jsonc',
  ['.vsconfig'] = 'jsonc',
  ['.justfile'] = 'just',
  ['justfile'] = 'just',
  ['Justfile'] = 'just',
  Kconfig = 'kconfig',
  ['Kconfig.debug'] = 'kconfig',
  ['Config.in'] = 'kconfig',
  ['ldaprc'] = 'ldapconf',
  ['.ldaprc'] = 'ldapconf',
  ['ldap.conf'] = 'ldapconf',
  ['lftp.conf'] = 'lftp',
  ['.lftprc'] = 'lftp',
  ['/.libao'] = 'libao',
  ['/etc/libao.conf'] = 'libao',
  ['lilo.conf'] = 'lilo',
  ['/etc/limits'] = 'limits',
  ['.emacs'] = 'lisp',
  sbclrc = 'lisp',
  ['.sbclrc'] = 'lisp',
  ['.sawfishrc'] = 'lisp',
  ['/etc/login.access'] = 'loginaccess',
  ['/etc/login.defs'] = 'logindefs',
  ['.lsl'] = detect.lsl,
  ['.busted'] = 'lua',
  ['.luacheckrc'] = 'lua',
  ['.lua_history'] = 'lua',
  ['config.ld'] = 'lua',
  ['rock_manifest'] = 'lua',
  ['lynx.cfg'] = 'lynx',
  ['m3overrides'] = 'm3build',
  ['m3makefile'] = 'm3build',
  ['cm3.cfg'] = 'm3quake',
  ['.m4_history'] = 'm4',
  ['.followup'] = 'mail',
  ['.article'] = 'mail',
  ['.letter'] = 'mail',
  ['/etc/aliases'] = 'mailaliases',
  ['/etc/mail/aliases'] = 'mailaliases',
  mailcap = 'mailcap',
  ['.mailcap'] = 'mailcap',
  Kbuild = 'make',
  ['/etc/man.conf'] = 'manconf',
  ['man.config'] = 'manconf',
  ['maxima-init.mac'] = 'maxima',
  ['meson.build'] = 'meson',
  ['meson.options'] = 'meson',
  ['meson_options.txt'] = 'meson',
  ['/etc/conf.modules'] = 'modconf',
  ['/etc/modules'] = 'modconf',
  ['/etc/modules.conf'] = 'modconf',
  ['/.mplayer/config'] = 'mplayerconf',
  ['mplayer.conf'] = 'mplayerconf',
  mrxvtrc = 'mrxvtrc',
  ['.mrxvtrc'] = 'mrxvtrc',
  ['.msmtprc'] = 'msmtp',
  ['Muttngrc'] = 'muttrc',
  ['Muttrc'] = 'muttrc',
  ['.mysql_history'] = 'mysql',
  ['/etc/nanorc'] = 'nanorc',
  Neomuttrc = 'neomuttrc',
  ['.netrc'] = 'netrc',
  NEWS = detect.news,
  ['.ocamlinit'] = 'ocaml',
  ['.octaverc'] = 'octave',
  octaverc = 'octave',
  ['octave.conf'] = 'octave',
  ['.ondirrc'] = 'ondir',
  opam = 'opam',
  ['opam.locked'] = 'opam',
  ['pacman.log'] = 'pacmanlog',
  ['/etc/pam.conf'] = 'pamconf',
  ['pam_env.conf'] = 'pamenv',
  ['.pam_environment'] = 'pamenv',
  ['/var/backups/passwd.bak'] = 'passwd',
  ['/var/backups/shadow.bak'] = 'passwd',
  ['/etc/passwd'] = 'passwd',
  ['/etc/passwd-'] = 'passwd',
  ['/etc/shadow.edit'] = 'passwd',
  ['/etc/shadow-'] = 'passwd',
  ['/etc/shadow'] = 'passwd',
  ['/etc/passwd.edit'] = 'passwd',
  ['.gitolite.rc'] = 'perl',
  ['gitolite.rc'] = 'perl',
  ['example.gitolite.rc'] = 'perl',
  ['latexmkrc'] = 'perl',
  ['.latexmkrc'] = 'perl',
  ['pf.conf'] = 'pf',
  ['main.cf'] = 'pfmain',
  ['main.cf.proto'] = 'pfmain',
  pinerc = 'pine',
  ['.pinercex'] = 'pine',
  ['.pinerc'] = 'pine',
  pinercex = 'pine',
  ['/etc/pinforc'] = 'pinfo',
  ['/.pinforc'] = 'pinfo',
  ['.povrayrc'] = 'povini',
  printcap = function(path, bufnr)
    return 'ptcap', function(b)
      vim.b[b].ptcap_type = 'print'
    end
  end,
  termcap = function(path, bufnr)
    return 'ptcap', function(b)
      vim.b[b].ptcap_type = 'term'
    end
  end,
  ['.procmailrc'] = 'procmail',
  ['.procmail'] = 'procmail',
  ['indent.pro'] = detect_seq(detect.proto, 'indent'),
  ['/etc/protocols'] = 'protocols',
  INDEX = detect.psf,
  INFO = detect.psf,
  ['MANIFEST.in'] = 'pymanifest',
  ['.pythonstartup'] = 'python',
  ['.pythonrc'] = 'python',
  ['.python_history'] = 'python',
  ['.jline-jython.history'] = 'python',
  SConstruct = 'python',
  qmldir = 'qmldir',
  ['.Rhistory'] = 'r',
  ['.Rprofile'] = 'r',
  Rprofile = 'r',
  ['Rprofile.site'] = 'r',
  ratpoisonrc = 'ratpoison',
  ['.ratpoisonrc'] = 'ratpoison',
  inputrc = 'readline',
  ['.inputrc'] = 'readline',
  ['.reminders'] = 'remind',
  ['requirements.txt'] = 'requirements',
  ['constraints.txt'] = 'requirements',
  ['requirements.in'] = 'requirements',
  ['resolv.conf'] = 'resolv',
  ['robots.txt'] = 'robots',
  Gemfile = 'ruby',
  Puppetfile = 'ruby',
  ['.irbrc'] = 'ruby',
  irbrc = 'ruby',
  ['.irb_history'] = 'ruby',
  irb_history = 'ruby',
  ['rakefile'] = 'ruby',
  ['Rakefile'] = 'ruby',
  ['rantfile'] = 'ruby',
  ['Rantfile'] = 'ruby',
  Vagrantfile = 'ruby',
  ['smb.conf'] = 'samba',
  screenrc = 'screen',
  ['.screenrc'] = 'screen',
  ['/etc/sensors3.conf'] = 'sensors',
  ['/etc/sensors.conf'] = 'sensors',
  ['/etc/services'] = 'services',
  ['/etc/serial.conf'] = 'setserial',
  ['/etc/udev/cdsymlinks.conf'] = 'sh',
  ['.ash_history'] = 'sh',
  ['.devscripts'] = 'sh',
  ['devscripts.conf'] = 'sh',
  ['makepkg.conf'] = 'sh',
  ['.makepkg.conf'] = 'sh',
  ['user-dirs.dirs'] = 'sh',
  ['user-dirs.defaults'] = 'sh',
  ['.xprofile'] = 'sh',
  ['bash.bashrc'] = detect.bash,
  bashrc = detect.bash,
  ['.bashrc'] = detect.bash,
  ['.kshrc'] = detect.ksh,
  ['.profile'] = detect.sh,
  ['/etc/profile'] = detect.sh,
  APKBUILD = detect.bash,
  PKGBUILD = detect.bash,
  ['.tcshrc'] = detect.tcsh,
  ['tcsh.login'] = detect.tcsh,
  ['tcsh.tcshrc'] = detect.tcsh,
  ['/etc/slp.conf'] = 'slpconf',
  ['/etc/slp.reg'] = 'slpreg',
  ['/etc/slp.spi'] = 'slpspi',
  ['.slrnrc'] = 'slrnrc',
  ['sendmail.cf'] = 'sm',
  Snakefile = 'snakemake',
  ['.sqlite_history'] = 'sql',
  ['squid.conf'] = 'squid',
  ['ssh_config'] = 'sshconfig',
  ['sshd_config'] = 'sshdconfig',
  ['/etc/sudoers'] = 'sudoers',
  ['sudoers.tmp'] = 'sudoers',
  ['/etc/sysctl.conf'] = 'sysctl',
  tags = 'tags',
  ['pending.data'] = 'taskdata',
  ['completed.data'] = 'taskdata',
  ['undo.data'] = 'taskdata',
  ['.tclshrc'] = 'tcl',
  ['.wishrc'] = 'tcl',
  ['.tclsh-history'] = 'tcl',
  ['tclsh.rc'] = 'tcl',
  ['.xsctcmdhistory'] = 'tcl',
  ['.xsdbcmdhistory'] = 'tcl',
  ['texmf.cnf'] = 'texmf',
  COPYING = 'text',
  README = detect_seq(detect.haredoc, 'text'),
  LICENSE = 'text',
  AUTHORS = 'text',
  tfrc = 'tf',
  ['.tfrc'] = 'tf',
  ['tidy.conf'] = 'tidy',
  tidyrc = 'tidy',
  ['.tidyrc'] = 'tidy',
  ['.tmux.conf'] = 'tmux',
  ['/.cargo/config'] = 'toml',
  Pipfile = 'toml',
  ['Gopkg.lock'] = 'toml',
  ['/.cargo/credentials'] = 'toml',
  ['Cargo.lock'] = 'toml',
  ['.black'] = 'toml',
  black = detect_line1('tool%.black', 'toml', nil),
  ['trustees.conf'] = 'trustees',
  ['.ts_node_repl_history'] = 'typescript',
  ['/etc/udev/udev.conf'] = 'udevconf',
  ['/etc/updatedb.conf'] = 'updatedb',
  ['fdrupstream.log'] = 'upstreamlog',
  vgrindefs = 'vgrindefs',
  ['.exrc'] = 'vim',
  ['_exrc'] = 'vim',
  ['.netrwhist'] = 'vim',
  ['_viminfo'] = 'viminfo',
  ['.viminfo'] = 'viminfo',
  ['.wgetrc'] = 'wget',
  ['.wget2rc'] = 'wget2',
  wgetrc = 'wget',
  wget2rc = 'wget2',
  ['.wvdialrc'] = 'wvdial',
  ['wvdial.conf'] = 'wvdial',
  ['.XCompose'] = 'xcompose',
  ['Compose'] = 'xcompose',
  ['.Xresources'] = 'xdefaults',
  ['.Xpdefaults'] = 'xdefaults',
  ['xdm-config'] = 'xdefaults',
  ['.Xdefaults'] = 'xdefaults',
  ['xorg.conf'] = detect.xfree86_v4,
  ['xorg.conf-4'] = detect.xfree86_v4,
  ['XF86Config'] = detect.xfree86_v3,
  ['/etc/xinetd.conf'] = 'xinetd',
  fglrxrc = 'xml',
  ['/etc/blkid.tab'] = 'xml',
  ['/etc/blkid.tab.old'] = 'xml',
  ['fonts.conf'] = 'xml',
  ['.clangd'] = 'yaml',
  ['.clang-format'] = 'yaml',
  ['.clang-tidy'] = 'yaml',
  ['yarn.lock'] = 'yaml',
  matplotlibrc = 'yaml',
  zathurarc = 'zathurarc',
  ['/etc/zprofile'] = 'zsh',
  ['.zlogin'] = 'zsh',
  ['.zlogout'] = 'zsh',
  ['.zshrc'] = 'zsh',
  ['.zprofile'] = 'zsh',
  ['.zcompdump'] = 'zsh',
  ['.zsh_history'] = 'zsh',
  ['.zshenv'] = 'zsh',
  ['.zfbfmarks'] = 'zsh',
  -- END FILENAME
}

-- Re-use closures as much as possible
local detect_apache_diretc = starsetf('apache', { parent = '/etc/' })
local detect_apache_dotconf = starsetf('apache', { parent = '%.conf' })
local detect_muttrc = starsetf('muttrc', { parent = 'utt' })
local detect_neomuttrc = starsetf('neomuttrc', { parent = 'utt' })
local detect_xkb = starsetf('xkb', { parent = '/usr/' })

---@type table<string,vim.filetype.mapping>
local pattern = {
  -- BEGIN PATTERN
  ['/debian/'] = {
    ['/debian/changelog$'] = 'debchangelog',
    ['/debian/control$'] = 'debcontrol',
    ['/debian/copyright$'] = 'debcopyright',
    ['/debian/patches/'] = detect.dep3patch,
  },
  ['/etc/'] = {
    ['/etc/a2ps/.*%.cfg$'] = 'a2ps',
    ['/etc/a2ps%.cfg$'] = 'a2ps',
    ['/etc/asound%.conf$'] = 'alsaconf',
    ['/etc/apache2/sites%-.*/.*%.com$'] = 'apache',
    ['/etc/httpd/.*%.conf$'] = 'apache',
    ['/etc/apache2/.*%.conf'] = detect_apache_diretc,
    ['/etc/apache2/conf%..*/'] = detect_apache_diretc,
    ['/etc/apache2/mods%-.*/'] = detect_apache_diretc,
    ['/etc/apache2/sites%-.*/'] = detect_apache_diretc,
    ['/etc/httpd/conf%..*/'] = detect_apache_diretc,
    ['/etc/httpd/conf%.d/.*%.conf'] = detect_apache_diretc,
    ['/etc/httpd/mods%-.*/'] = detect_apache_diretc,
    ['/etc/httpd/sites%-.*/'] = detect_apache_diretc,
    ['/etc/proftpd/.*%.conf'] = starsetf('apachestyle'),
    ['/etc/proftpd/conf%..*/'] = starsetf('apachestyle'),
    ['/etc/cdrdao%.conf$'] = 'cdrdaoconf',
    ['/etc/default/cdrdao$'] = 'cdrdaoconf',
    ['/etc/defaults/cdrdao$'] = 'cdrdaoconf',
    ['/etc/translate%-shell$'] = 'clojure',
    ['/etc/hostname%.'] = starsetf('config'),
    ['/etc/cron%.d/'] = starsetf('crontab'),
    ['/etc/apt/sources%.list%.d/.*%.sources$'] = 'deb822sources',
    ['/etc/apt/sources%.list%.d/.*%.list$'] = 'debsources',
    ['/etc/apt/sources%.list$'] = 'debsources',
    ['/etc/DIR_COLORS$'] = 'dircolors',
    ['/etc/dnsmasq%.conf$'] = 'dnsmasq',
    ['/etc/dnsmasq%.d/'] = starsetf('dnsmasq'),
    ['/etc/yum%.conf$'] = 'dosini',
    ['/etc/yum%.repos%.d/'] = starsetf('dosini'),
    ['/etc/gitconfig%.d/'] = starsetf('gitconfig'),
    ['/etc/gitconfig$'] = 'gitconfig',
    ['/etc/gitattributes$'] = 'gitattributes',
    ['/etc/group$'] = 'group',
    ['/etc/group%-$'] = 'group',
    ['/etc/group%.edit$'] = 'group',
    ['/etc/gshadow%-$'] = 'group',
    ['/etc/gshadow%.edit$'] = 'group',
    ['/etc/gshadow$'] = 'group',
    ['/etc/grub%.conf$'] = 'grub',
    ['/etc/host%.conf$'] = 'hostconf',
    ['/etc/hosts%.allow$'] = 'hostsaccess',
    ['/etc/hosts%.deny$'] = 'hostsaccess',
    ['/etc/initng/.*/.*%.i$'] = 'initng',
    ['/etc/libao%.conf$'] = 'libao',
    ['/etc/.*limits%.conf$'] = 'limits',
    ['/etc/.*limits%.d/.*%.conf$'] = 'limits',
    ['/etc/limits$'] = 'limits',
    ['/etc/logcheck/.*%.d.*/'] = starsetf('logcheck'),
    ['/etc/login%.access$'] = 'loginaccess',
    ['/etc/login%.defs$'] = 'logindefs',
    ['/etc/aliases$'] = 'mailaliases',
    ['/etc/mail/aliases$'] = 'mailaliases',
    ['/etc/man%.conf$'] = 'manconf',
    ['/etc/conf%.modules$'] = 'modconf',
    ['/etc/modprobe%.'] = starsetf('modconf'),
    ['/etc/modules%.conf$'] = 'modconf',
    ['/etc/modules$'] = 'modconf',
    ['/etc/modutils/'] = starsetf(function(path, bufnr)
      if fn.executable(fn.expand(path)) ~= 1 then
        return 'modconf'
      end
    end),
    ['/etc/Muttrc%.d/'] = starsetf('muttrc'),
    ['/etc/nanorc$'] = 'nanorc',
    ['/etc/nginx/'] = 'nginx',
    ['/etc/pam%.conf$'] = 'pamconf',
    ['/etc/pam%.d/'] = starsetf('pamconf'),
    ['/etc/passwd%-$'] = 'passwd',
    ['/etc/shadow$'] = 'passwd',
    ['/etc/shadow%.edit$'] = 'passwd',
    ['/etc/passwd$'] = 'passwd',
    ['/etc/passwd%.edit$'] = 'passwd',
    ['/etc/shadow%-$'] = 'passwd',
    ['/etc/pinforc$'] = 'pinfo',
    ['/etc/protocols$'] = 'protocols',
    ['/etc/sensors%.d/[^.]'] = starsetf('sensors'),
    ['/etc/sensors%.conf$'] = 'sensors',
    ['/etc/sensors3%.conf$'] = 'sensors',
    ['/etc/services$'] = 'services',
    ['/etc/serial%.conf$'] = 'setserial',
    ['/etc/udev/cdsymlinks%.conf$'] = 'sh',
    ['/etc/profile$'] = detect.sh,
    ['/etc/slp%.conf$'] = 'slpconf',
    ['/etc/slp%.reg$'] = 'slpreg',
    ['/etc/slp%.spi$'] = 'slpspi',
    ['/etc/sudoers%.d/'] = starsetf('sudoers'),
    ['/etc/ssh/ssh_config%.d/.*%.conf$'] = 'sshconfig',
    ['/etc/ssh/sshd_config%.d/.*%.conf$'] = 'sshdconfig',
    ['/etc/sudoers$'] = 'sudoers',
    ['/etc/sysctl%.conf$'] = 'sysctl',
    ['/etc/sysctl%.d/.*%.conf$'] = 'sysctl',
    ['/etc/systemd/.*%.conf%.d/.*%.conf$'] = 'systemd',
    ['/etc/systemd/system/.*%.d/.*%.conf$'] = 'systemd',
    ['/etc/systemd/system/.*%.d/%.#'] = 'systemd',
    ['/etc/systemd/system/%.#'] = 'systemd',
    ['/etc/config/'] = starsetf(detect.uci),
    ['/etc/udev/udev%.conf$'] = 'udevconf',
    ['/etc/udev/permissions%.d/.*%.permissions$'] = 'udevperm',
    ['/etc/updatedb%.conf$'] = 'updatedb',
    ['/etc/init/.*%.conf$'] = 'upstart',
    ['/etc/init/.*%.override$'] = 'upstart',
    ['/etc/xinetd%.conf$'] = 'xinetd',
    ['/etc/xinetd%.d/'] = starsetf('xinetd'),
    ['/etc/blkid%.tab%.old$'] = 'xml',
    ['/etc/blkid%.tab$'] = 'xml',
    ['/etc/xdg/menus/.*%.menu$'] = 'xml',
    ['/etc/zprofile$'] = 'zsh',
  },
  ['/log/'] = {
    ['/log/auth%.crit$'] = 'messages',
    ['/log/auth%.err$'] = 'messages',
    ['/log/auth%.info$'] = 'messages',
    ['/log/auth%.log$'] = 'messages',
    ['/log/auth%.notice$'] = 'messages',
    ['/log/auth%.warn$'] = 'messages',
    ['/log/auth$'] = 'messages',
    ['/log/cron%.crit$'] = 'messages',
    ['/log/cron%.err$'] = 'messages',
    ['/log/cron%.info$'] = 'messages',
    ['/log/cron%.log$'] = 'messages',
    ['/log/cron%.notice$'] = 'messages',
    ['/log/cron%.warn$'] = 'messages',
    ['/log/cron$'] = 'messages',
    ['/log/daemon%.crit$'] = 'messages',
    ['/log/daemon%.err$'] = 'messages',
    ['/log/daemon%.info$'] = 'messages',
    ['/log/daemon%.log$'] = 'messages',
    ['/log/daemon%.notice$'] = 'messages',
    ['/log/daemon%.warn$'] = 'messages',
    ['/log/daemon$'] = 'messages',
    ['/log/debug%.crit$'] = 'messages',
    ['/log/debug%.err$'] = 'messages',
    ['/log/debug%.info$'] = 'messages',
    ['/log/debug%.log$'] = 'messages',
    ['/log/debug%.notice$'] = 'messages',
    ['/log/debug%.warn$'] = 'messages',
    ['/log/debug$'] = 'messages',
    ['/log/kern%.crit$'] = 'messages',
    ['/log/kern%.err$'] = 'messages',
    ['/log/kern%.info$'] = 'messages',
    ['/log/kern%.log$'] = 'messages',
    ['/log/kern%.notice$'] = 'messages',
    ['/log/kern%.warn$'] = 'messages',
    ['/log/kern$'] = 'messages',
    ['/log/lpr%.crit$'] = 'messages',
    ['/log/lpr%.err$'] = 'messages',
    ['/log/lpr%.info$'] = 'messages',
    ['/log/lpr%.log$'] = 'messages',
    ['/log/lpr%.notice$'] = 'messages',
    ['/log/lpr%.warn$'] = 'messages',
    ['/log/lpr$'] = 'messages',
    ['/log/mail%.crit$'] = 'messages',
    ['/log/mail%.err$'] = 'messages',
    ['/log/mail%.info$'] = 'messages',
    ['/log/mail%.log$'] = 'messages',
    ['/log/mail%.notice$'] = 'messages',
    ['/log/mail%.warn$'] = 'messages',
    ['/log/mail$'] = 'messages',
    ['/log/messages%.crit$'] = 'messages',
    ['/log/messages%.err$'] = 'messages',
    ['/log/messages%.info$'] = 'messages',
    ['/log/messages%.log$'] = 'messages',
    ['/log/messages%.notice$'] = 'messages',
    ['/log/messages%.warn$'] = 'messages',
    ['/log/messages$'] = 'messages',
    ['/log/news/news%.crit$'] = 'messages',
    ['/log/news/news%.err$'] = 'messages',
    ['/log/news/news%.info$'] = 'messages',
    ['/log/news/news%.log$'] = 'messages',
    ['/log/news/news%.notice$'] = 'messages',
    ['/log/news/news%.warn$'] = 'messages',
    ['/log/news/news$'] = 'messages',
    ['/log/syslog%.crit$'] = 'messages',
    ['/log/syslog%.err$'] = 'messages',
    ['/log/syslog%.info$'] = 'messages',
    ['/log/syslog%.log$'] = 'messages',
    ['/log/syslog%.notice$'] = 'messages',
    ['/log/syslog%.warn$'] = 'messages',
    ['/log/syslog$'] = 'messages',
    ['/log/user%.crit$'] = 'messages',
    ['/log/user%.err$'] = 'messages',
    ['/log/user%.info$'] = 'messages',
    ['/log/user%.log$'] = 'messages',
    ['/log/user%.notice$'] = 'messages',
    ['/log/user%.warn$'] = 'messages',
    ['/log/user$'] = 'messages',
  },
  ['/systemd/'] = {
    ['/%.config/systemd/user/%.#'] = 'systemd',
    ['/%.config/systemd/user/.*%.d/%.#'] = 'systemd',
    ['/%.config/systemd/user/.*%.d/.*%.conf$'] = 'systemd',
    ['/systemd/.*%.automount$'] = 'systemd',
    ['/systemd/.*%.dnssd$'] = 'systemd',
    ['/systemd/.*%.link$'] = 'systemd',
    ['/systemd/.*%.mount$'] = 'systemd',
    ['/systemd/.*%.netdev$'] = 'systemd',
    ['/systemd/.*%.network$'] = 'systemd',
    ['/systemd/.*%.nspawn$'] = 'systemd',
    ['/systemd/.*%.path$'] = 'systemd',
    ['/systemd/.*%.service$'] = 'systemd',
    ['/systemd/.*%.slice$'] = 'systemd',
    ['/systemd/.*%.socket$'] = 'systemd',
    ['/systemd/.*%.swap$'] = 'systemd',
    ['/systemd/.*%.target$'] = 'systemd',
    ['/systemd/.*%.timer$'] = 'systemd',
  },
  ['/usr/'] = {
    ['/usr/share/alsa/alsa%.conf$'] = 'alsaconf',
    ['/usr/.*/gnupg/options%.skel$'] = 'gpg',
    ['/usr/share/upstart/.*%.conf$'] = 'upstart',
    ['/usr/share/upstart/.*%.override$'] = 'upstart',
    ['/usr/share/X11/xkb/compat/'] = detect_xkb,
    ['/usr/share/X11/xkb/geometry/'] = detect_xkb,
    ['/usr/share/X11/xkb/keycodes/'] = detect_xkb,
    ['/usr/share/X11/xkb/symbols/'] = detect_xkb,
    ['/usr/share/X11/xkb/types/'] = detect_xkb,
  },
  ['/var/'] = {
    ['/var/backups/group%.bak$'] = 'group',
    ['/var/backups/gshadow%.bak$'] = 'group',
    ['/var/backups/passwd%.bak$'] = 'passwd',
    ['/var/backups/shadow%.bak$'] = 'passwd',
  },
  ['/conf'] = {
    ['/%.aptitude/config$'] = 'aptconf',
    ['/build/conf/.*%.conf$'] = 'bitbake',
    ['/meta%-.*/conf/.*%.conf$'] = 'bitbake',
    ['/meta/conf/.*%.conf$'] = 'bitbake',
    ['/%.cabal/config$'] = 'cabalconfig',
    ['/cabal/config$'] = 'cabalconfig',
    ['/%.aws/config$'] = 'confini',
    ['/bpython/config$'] = 'dosini',
    ['/flatpak/repo/config$'] = 'dosini',
    ['/mypy/config$'] = 'dosini',
    ['^${HOME}/%.config/notmuch/.*/config$'] = 'dosini',
    ['^${XDG_CONFIG_HOME}/notmuch/.*/config$'] = 'dosini',
    ['^${XDG_CONFIG_HOME}/git/config$'] = 'gitconfig',
    ['%.git/config%.worktree$'] = 'gitconfig',
    ['%.git/config$'] = 'gitconfig',
    ['%.git/modules/.*/config$'] = 'gitconfig',
    ['%.git/modules/config$'] = 'gitconfig',
    ['%.git/worktrees/.*/config%.worktree$'] = 'gitconfig',
    ['/%.config/git/config$'] = 'gitconfig',
    ['/gitolite%-admin/conf/'] = starsetf('gitolite'),
    ['/%.i3/config$'] = 'i3config',
    ['/i3/config$'] = 'i3config',
    ['/supertux2/config$'] = 'lisp',
    ['/%.mplayer/config$'] = 'mplayerconf',
    ['/neofetch/config%.conf$'] = 'sh',
    ['/%.ssh/config$'] = 'sshconfig',
    ['/%.sway/config$'] = 'swayconfig',
    ['/sway/config$'] = 'swayconfig',
    ['/%.cargo/config$'] = 'toml',
    ['/%.bundle/config$'] = 'yaml',
  },
  ['/%.'] = {
    ['/%.aws/credentials$'] = 'confini',
    ['/%.gitconfig%.d/'] = starsetf('gitconfig'),
    ['/%.gnupg/gpg%.conf$'] = 'gpg',
    ['/%.gnupg/options$'] = 'gpg',
    ['/%.icewm/menu$'] = 'icemenu',
    ['/%.libao$'] = 'libao',
    ['/%.pinforc$'] = 'pinfo',
    ['/%.cargo/credentials$'] = 'toml',
    ['/%.init/.*%.override$'] = 'upstart',
  },
  ['calendar/'] = {
    ['/%.calendar/'] = starsetf('calendar'),
    ['/share/calendar/.*/calendar%.'] = starsetf('calendar'),
    ['/share/calendar/calendar%.'] = starsetf('calendar'),
  },
  ['cmus/'] = {
    -- */cmus/*.theme and */.cmus/*.theme
    ['/%.?cmus/.*%.theme$'] = 'cmusrc',
    -- */cmus/rc and */.cmus/rc
    ['/%.?cmus/rc$'] = 'cmusrc',
    ['/%.cmus/autosave$'] = 'cmusrc',
    ['/%.cmus/command%-history$'] = 'cmusrc',
  },
  ['git/'] = {
    ['%.git/'] = {
      detect.git,
      -- Decrease priority to run after simple pattern checks
      { priority = -1 },
    },
    ['^${XDG_CONFIG_HOME}/git/attributes$'] = 'gitattributes',
    ['%.git/info/attributes$'] = 'gitattributes',
    ['/%.config/git/attributes$'] = 'gitattributes',
    ['^${XDG_CONFIG_HOME}/git/ignore$'] = 'gitignore',
    ['%.git/info/exclude$'] = 'gitignore',
    ['/%.config/git/ignore$'] = 'gitignore',
  },
  ['%.cfg'] = {
    ['enlightenment/.*%.cfg$'] = 'c',
    ['Eterm/.*%.cfg$'] = 'eterm',
    ['baseq[2-3]/.*%.cfg$'] = 'quake',
    ['id1/.*%.cfg$'] = 'quake',
    ['quake[1-3]/.*%.cfg$'] = 'quake',
    ['/tex/latex/.*%.cfg$'] = 'tex',
  },
  ['%.conf'] = {
    ['^proftpd%.conf'] = starsetf('apachestyle'),
    ['^access%.conf'] = detect_apache_dotconf,
    ['^apache%.conf'] = detect_apache_dotconf,
    ['^apache2%.conf'] = detect_apache_dotconf,
    ['^httpd%.conf'] = detect_apache_dotconf,
    ['^srm%.conf'] = detect_apache_dotconf,
    ['asterisk/.*%.conf'] = starsetf('asterisk'),
    ['asterisk.*/.*voicemail%.conf'] = starsetf('asteriskvm'),
    ['^dictd.*%.conf$'] = 'dictdconf',
    ['/lxqt/.*%.conf$'] = 'dosini',
    ['/screengrab/.*%.conf$'] = 'dosini',
    ['^${GNUPGHOME}/gpg%.conf$'] = 'gpg',
    ['/boot/grub/grub%.conf$'] = 'grub',
    ['^lilo%.conf'] = starsetf('lilo'),
    ['^named.*%.conf$'] = 'named',
    ['^rndc.*%.conf$'] = 'named',
    ['/openvpn/.*/.*%.conf$'] = 'openvpn',
    ['/%.ssh/.*%.conf$'] = 'sshconfig',
    ['^%.?tmux.*%.conf$'] = 'tmux',
    ['^%.?tmux.*%.conf'] = { 'tmux', { priority = -1 } },
    ['/%.config/upstart/.*%.conf$'] = 'upstart',
    ['/%.config/upstart/.*%.override$'] = 'upstart',
    ['/%.init/.*%.conf$'] = 'upstart',
    ['/xorg%.conf%.d/.*%.conf$'] = detect.xfree86_v4,
  },
  ['sst%.meta'] = {
    ['%.%-sst%.meta$'] = 'sisu',
    ['%._sst%.meta$'] = 'sisu',
    ['%.sst%.meta$'] = 'sisu',
  },
  ['file'] = {
    ['^Containerfile%.'] = starsetf('dockerfile'),
    ['^Dockerfile%.'] = starsetf('dockerfile'),
    ['[mM]akefile$'] = detect.make,
    ['^[mM]akefile'] = starsetf('make'),
    ['^[rR]akefile'] = starsetf('ruby'),
    ['^%.profile'] = detect.sh,
  },
  ['fvwm'] = {
    ['/%.fvwm/'] = starsetf('fvwm'),
    ['fvwmrc'] = starsetf(detect.fvwm_v1),
    ['fvwm95.*%.hook$'] = starsetf(detect.fvwm_v1),
    ['fvwm2rc'] = starsetf(detect.fvwm_v2),
  },
  ['nginx'] = {
    ['/nginx/.*%.conf$'] = 'nginx',
    ['/usr/local/nginx/conf/'] = 'nginx',
    ['nginx%.conf$'] = 'nginx',
    ['^nginx.*%.conf$'] = 'nginx',
  },
  ['require'] = {
    ['%-requirements%.txt$'] = 'requirements',
    ['^requirements/.*%.txt$'] = 'requirements',
    ['^requires/.*%.txt$'] = 'requirements',
  },
  ['s6'] = {
    ['s6.*/down$'] = 'execline',
    ['s6.*/finish$'] = 'execline',
    ['s6.*/run$'] = 'execline',
    ['s6.*/up$'] = 'execline',
    ['^s6%-'] = 'execline',
  },
  ['utt'] = {
    ['^mutt%-.*%-%w+$'] = 'mail',
    ['^mutt' .. string.rep('[%w_-]', 6) .. '$'] = 'mail',
    ['^muttng%-.*%-%w+$'] = 'mail',
    ['^neomutt%-.*%-%w+$'] = 'mail',
    ['^neomutt' .. string.rep('[%w_-]', 6) .. '$'] = 'mail',
    -- muttngrc* and .muttngrc*
    ['^%.?muttngrc'] = detect_muttrc,
    -- muttrc* and .muttrc*
    ['^%.?muttrc'] = detect_muttrc,
    ['/%.mutt/muttrc'] = detect_muttrc,
    ['/%.muttng/muttngrc'] = detect_muttrc,
    ['/%.muttng/muttrc'] = detect_muttrc,
    ['^Muttngrc'] = detect_muttrc,
    ['^Muttrc'] = detect_muttrc,
    -- neomuttrc* and .neomuttrc*
    ['^%.?neomuttrc'] = detect_neomuttrc,
    ['/%.neomutt/neomuttrc'] = detect_neomuttrc,
    ['^Neomuttrc'] = detect_neomuttrc,
  },
  ['^%.'] = {
    ['^%.cshrc'] = detect.csh,
    ['^%.login'] = detect.csh,
    ['^%.notmuch%-config%.'] = 'dosini',
    ['^%.gitsendemail%.msg%.......$'] = 'gitsendemail',
    ['^%.kshrc'] = detect.ksh,
    ['^%.article%.%d+$'] = 'mail',
    ['^%.letter%.%d+$'] = 'mail',
    ['^%.reminders'] = starsetf('remind'),
    ['^%.tcshrc'] = detect.tcsh,
    ['^%.zcompdump'] = starsetf('zsh'),
  },
  ['proj%.user$'] = {
    ['%.csproj%.user$'] = 'xml',
    ['%.fsproj%.user$'] = 'xml',
    ['%.vbproj%.user$'] = 'xml',
  },
  [''] = {
    ['^bash%-fc[%-%.]'] = detect.bash,
    ['/bind/db%.'] = starsetf('bindzone'),
    ['/named/db%.'] = starsetf('bindzone'),
    ['%.blade%.php$'] = 'blade',
    ['^bzr_log%.'] = 'bzr',
    ['^cabal%.project%.'] = starsetf('cabalproject'),
    ['^sgml%.catalog'] = starsetf('catalog'),
    ['hgrc$'] = 'cfg',
    ['^[cC]hange[lL]og'] = starsetf(detect.changelog),
    ['%.%.ch$'] = 'chill',
    ['%.cmake%.in$'] = 'cmake',
    ['^crontab%.'] = starsetf('crontab'),
    ['^cvs%d+$'] = 'cvs',
    ['^php%.ini%-'] = 'dosini',
    ['^drac%.'] = starsetf('dracula'),
    ['/dtrace/.*%.d$'] = 'dtrace',
    ['esmtprc$'] = 'esmtprc',
    ['/0%.orig/'] = detect.foam,
    ['/0/'] = detect.foam,
    ['/constant/g$'] = detect.foam,
    ['Transport%.'] = detect.foam,
    ['^[a-zA-Z0-9].*Dict%.'] = detect.foam,
    ['^[a-zA-Z0-9].*Dict$'] = detect.foam,
    ['^[a-zA-Z].*Properties%.'] = detect.foam,
    ['^[a-zA-Z].*Properties$'] = detect.foam,
    ['/tmp/lltmp'] = starsetf('gedcom'),
    ['^gkrellmrc_.$'] = 'gkrellmrc',
    ['^${GNUPGHOME}/options$'] = 'gpg',
    ['/boot/grub/menu%.lst$'] = 'grub',
    -- gtkrc* and .gtkrc*
    ['^%.?gtkrc'] = starsetf('gtkrc'),
    ['^${VIMRUNTIME}/doc/.*%.txt$'] = 'help',
    ['^hg%-editor%-.*%.txt$'] = 'hgcommit',
    ['%.html%.m4$'] = 'htmlm4',
    ['^JAM.*%.'] = starsetf('jam'),
    ['^Prl.*%.'] = starsetf('jam'),
    ['%.properties_..$'] = 'jproperties',
    ['%.properties_.._..$'] = 'jproperties',
    ['%.properties_.._.._'] = starsetf('jproperties'),
    ['^org%.eclipse%..*%.prefs$'] = 'jproperties',
    ['^[jt]sconfig.*%.json$'] = 'jsonc',
    ['^Config%.in%.'] = starsetf('kconfig'),
    ['^Kconfig%.'] = starsetf('kconfig'),
    ['/ldscripts/'] = 'ld',
    ['lftp/rc$'] = 'lftp',
    ['/LiteStep/.*/.*%.rc$'] = 'litestep',
    ['^/tmp/SLRN[0-9A-Z.]+$'] = 'mail',
    ['^ae%d+%.txt$'] = 'mail',
    ['^pico%.%d+$'] = 'mail',
    ['^reportbug%-'] = starsetf('mail'),
    ['^snd%.%d+$'] = 'mail',
    ['^rndc.*%.key$'] = 'named',
    ['^tmac%.'] = starsetf('nroff'),
    ['%.ml%.cppo$'] = 'ocaml',
    ['%.mli%.cppo$'] = 'ocaml',
    ['/octave/history$'] = 'octave',
    ['%.opam%.locked$'] = 'opam',
    ['%.opam%.template$'] = 'opam',
    ['printcap'] = starsetf(function(path, bufnr)
      return require('vim.filetype.detect').printcap('print')
    end),
    ['/queries/.*%.scm$'] = 'query', -- treesitter queries (Neovim only)
    [',v$'] = 'rcs',
    ['^svn%-commit.*%.tmp$'] = 'svn',
    ['%.swift%.gyb$'] = 'swiftgyb',
    ['termcap'] = starsetf(function(path, bufnr)
      return require('vim.filetype.detect').printcap('term')
    end),
    ['%.t%.html$'] = 'tilde',
    ['%.vhdl_[0-9]'] = starsetf('vhdl'),
    ['vimrc'] = starsetf('vim'),
    ['/Xresources/'] = starsetf('xdefaults'),
    ['/app%-defaults/'] = starsetf('xdefaults'),
    ['^Xresources'] = starsetf('xdefaults'),
    -- Increase priority to run before the pattern below
    ['^XF86Config%-4'] = starsetf(detect.xfree86_v4, { priority = -math.huge + 1 }),
    ['^XF86Config'] = starsetf(detect.xfree86_v3),
    ['Xmodmap$'] = 'xmodmap',
    ['xmodmap'] = starsetf('xmodmap'),
    -- .zlog* and zlog*
    ['^%.?zlog'] = starsetf('zsh'),
    -- .zsh* and zsh*
    ['^%.?zsh'] = starsetf('zsh'),
    -- Ignored extension
    ['~$'] = function(path, bufnr)
      local short = path:gsub('~+$', '', 1)
      if path ~= short and short ~= '' then
        return M.match({ buf = bufnr, filename = fn.fnameescape(short) })
      end
    end,
  },
  -- END PATTERN
}
-- luacheck: pop
-- luacheck: pop

--- Lookup table/cache for patterns
--- @alias vim.filetype.pattern_cache { has_env: boolean, has_slash: boolean }
--- @type table<string,vim.filetype.pattern_cache>
local pattern_lookup = {}

local function compare_by_priority(a, b)
  return a[next(a)][2].priority > b[next(b)][2].priority
end

--- @param pat string
--- @return { has_env: boolean, has_slash: boolean }
local function parse_pattern(pat)
  return { has_env = pat:find('%$%b{}') ~= nil, has_slash = pat:find('/') ~= nil }
end

--- @param t table<string,vim.filetype.mapping>
--- @return vim.filetype.mapping[]
--- @return vim.filetype.mapping[]
local function sort_by_priority(t)
  -- Separate patterns with non-negative and negative priority because they
  -- will be processed separately
  local pos = {} --- @type vim.filetype.mapping[]
  local neg = {} --- @type vim.filetype.mapping[]
  for parent, ft_map in pairs(t) do
    pattern_lookup[parent] = pattern_lookup[parent] or parse_pattern(parent)
    for pat, maptbl in pairs(ft_map) do
      local ft = type(maptbl) == 'table' and maptbl[1] or maptbl
      assert(
        type(ft) == 'string' or type(ft) == 'function',
        'Expected string or function for filetype'
      )

      -- Parse pattern for common data and cache it once
      pattern_lookup[pat] = pattern_lookup[pat] or parse_pattern(pat)

      local opts = (type(maptbl) == 'table' and type(maptbl[2]) == 'table') and maptbl[2] or {}
      opts.parent = opts.parent or parent
      opts.priority = opts.priority or 0

      table.insert(opts.priority >= 0 and pos or neg, { [pat] = { ft, opts } })
    end
  end

  table.sort(pos, compare_by_priority)
  table.sort(neg, compare_by_priority)
  return pos, neg
end

local pattern_sorted_pos, pattern_sorted_neg = sort_by_priority(pattern)

--- @param path string
--- @param as_pattern? true
--- @return string
local function normalize_path(path, as_pattern)
  local normal = path:gsub('\\', '/')
  if normal:find('^~') then
    if as_pattern then
      -- Escape Lua's metacharacters when $HOME is used in a pattern.
      -- The rest of path should already be properly escaped.
      normal = vim.pesc(vim.env.HOME) .. normal:sub(2)
    else
      normal = vim.env.HOME .. normal:sub(2) --- @type string
    end
  end
  return normal
end

--- @class vim.filetype.add.filetypes
--- @inlinedoc
--- @field pattern? vim.filetype.mapping
--- @field extension? vim.filetype.mapping
--- @field filename? vim.filetype.mapping

--- Add new filetype mappings.
---
--- Filetype mappings can be added either by extension or by filename (either
--- the "tail" or the full file path). The full file path is checked first,
--- followed by the file name. If a match is not found using the filename, then
--- the filename is matched against the list of |lua-patterns| (sorted by priority)
--- until a match is found. Lastly, if pattern matching does not find a
--- filetype, then the file extension is used.
---
--- The filetype can be either a string (in which case it is used as the
--- filetype directly) or a function. If a function, it takes the full path and
--- buffer number of the file as arguments (along with captures from the matched
--- pattern, if any) and should return a string that will be used as the
--- buffer's filetype. Optionally, the function can return a second function
--- value which, when called, modifies the state of the buffer. This can be used
--- to, for example, set filetype-specific buffer variables. This function will
--- be called by Nvim before setting the buffer's filetype.
---
--- Filename patterns can specify an optional priority to resolve cases when a
--- file path matches multiple patterns. Higher priorities are matched first.
--- When omitted, the priority defaults to 0.
--- A pattern can contain environment variables of the form "${SOME_VAR}" that will
--- be automatically expanded. If the environment variable is not set, the pattern
--- won't be matched.
---
--- See $VIMRUNTIME/lua/vim/filetype.lua for more examples.
---
--- Example:
---
--- ```lua
--- vim.filetype.add({
---   extension = {
---     foo = 'fooscript',
---     bar = function(path, bufnr)
---       if some_condition() then
---         return 'barscript', function(bufnr)
---           -- Set a buffer variable
---           vim.b[bufnr].barscript_version = 2
---         end
---       end
---       return 'bar'
---     end,
---   },
---   filename = {
---     ['.foorc'] = 'toml',
---     ['/etc/foo/config'] = 'toml',
---   },
---   pattern = {
---     ['.*/etc/foo/.*'] = 'fooscript',
---     -- Using an optional priority
---     ['.*/etc/foo/.*%.conf'] = { 'dosini', { priority = 10 } },
---     -- A pattern containing an environment variable
---     ['${XDG_CONFIG_HOME}/foo/git'] = 'git',
---     ['.*README.(%a+)'] = function(path, bufnr, ext)
---       if ext == 'md' then
---         return 'markdown'
---       elseif ext == 'rst' then
---         return 'rst'
---       end
---     end,
---   },
--- })
--- ```
---
--- To add a fallback match on contents, use
---
--- ```lua
--- vim.filetype.add {
---   pattern = {
---     ['.*'] = {
---       function(path, bufnr)
---         local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
---         if vim.regex([[^#!.*\\<mine\\>]]):match_str(content) ~= nil then
---           return 'mine'
---         elseif vim.regex([[\\<drawing\\>]]):match_str(content) ~= nil then
---           return 'drawing'
---         end
---       end,
---       { priority = -math.huge },
---     },
---   },
--- }
--- ```
---
---@param filetypes vim.filetype.add.filetypes A table containing new filetype maps (see example).
function M.add(filetypes)
  for k, v in pairs(filetypes.extension or {}) do
    extension[k] = v
  end

  for k, v in pairs(filetypes.filename or {}) do
    filename[normalize_path(k)] = v
  end

  for k, v in pairs(filetypes.pattern or {}) do
    -- Add to "match all" parent pattern (might be better to optimize later or document
    -- supplying `opts.parent` directly)
    -- User patterns are assumed to be implicitly anchored (as in Vim)
    pattern['']['^' .. normalize_path(k, true) .. '$'] = v
  end

  if filetypes.pattern then
    -- TODO: full resorting might be expensive with a lot of separate `vim.filetype.add()` calls.
    -- Consider inserting new patterns precisely into already sorted lists of built-in patterns.
    pattern_sorted_pos, pattern_sorted_neg = sort_by_priority(pattern)
  end
end

--- @param ft vim.filetype.mapping.value
--- @param path? string
--- @param bufnr? integer
--- @param ... any
--- @return string?
--- @return fun(b: integer)?
local function dispatch(ft, path, bufnr, ...)
  if type(ft) == 'string' then
    return ft
  end

  if type(ft) ~= 'function' then
    return
  end

  assert(path)

  ---@type string|false?, fun(b: integer)?
  local ft0, on_detect
  if bufnr then
    ft0, on_detect = ft(path, bufnr, ...)
  else
    -- If bufnr is nil (meaning we are matching only against the filename), set it to an invalid
    -- value (-1) and catch any errors from the filetype detection function. If the function tries
    -- to use the buffer then it will fail, but this enables functions which do not need a buffer
    -- to still work.
    local ok
    ok, ft0, on_detect = pcall(ft, path, -1, ...)
    if not ok then
      return
    end
  end

  if not ft0 then
    return
  end

  return ft0, on_detect
end

--- @param pat string
--- @return boolean
--- @return string
local function expand_envvar_pattern(pat)
  local some_env_missing = false
  local expanded = pat:gsub('%${(%S-)}', function(env)
    local val = vim.env[env] --- @type string?
    some_env_missing = some_env_missing or val == nil
    return vim.pesc(val or '')
  end)
  return some_env_missing, expanded
end

--- @param name string
--- @param path string
--- @param tail string
--- @param pat string
--- @param try_all_candidates boolean
--- @return string?
local function match_pattern(name, path, tail, pat, try_all_candidates)
  local pat_cache = pattern_lookup[pat]
  local has_slash = pat_cache.has_slash

  if pat_cache.has_env then
    local some_env_missing, expanded = expand_envvar_pattern(pat)
    -- If any environment variable is present in the pattern but not set, there is no match
    if some_env_missing then
      return nil
    end
    pat, has_slash = expanded, expanded:find('/') ~= nil
  end

  -- Try all possible candidates to make parent patterns not depend on slash presence
  if try_all_candidates then
    return (path:match(pat) or name:match(pat) or tail:match(pat))
  end

  -- If the pattern contains a / match against the full path, otherwise just the tail
  if has_slash then
    -- Similar to |autocmd-pattern|, if the pattern contains a '/' then check for a match against
    -- both the short file name (as typed) and the full file name (after expanding to full path
    -- and resolving symlinks)
    return (name:match(pat) or path:match(pat))
  end

  return (tail:match(pat))
end

--- @param name string
--- @param path string
--- @param tail string
--- @param pattern_sorted vim.filetype.mapping[]
--- @param parent_matches table<string,boolean>
--- @param bufnr integer?
local function match_pattern_sorted(name, path, tail, pattern_sorted, parent_matches, bufnr)
  for i = 1, #pattern_sorted do
    local pat, ft_data = next(pattern_sorted[i])

    local parent = ft_data[2].parent
    local parent_is_matched = parent_matches[parent]
    if parent_is_matched == nil then
      parent_matches[parent] = match_pattern(name, path, tail, parent, true) ~= nil
      parent_is_matched = parent_matches[parent]
    end

    if parent_is_matched then
      local matches = match_pattern(name, path, tail, pat, false)
      if matches then
        local ft, on_detect = dispatch(ft_data[1], path, bufnr, matches)
        if ft then
          return ft, on_detect
        end
      end
    end
  end
end

--- @class vim.filetype.match.args
--- @inlinedoc
---
--- Buffer number to use for matching. Mutually exclusive with {contents}
--- @field buf? integer
---
--- Filename to use for matching. When {buf} is given,
--- defaults to the filename of the given buffer number. The
--- file need not actually exist in the filesystem. When used
--- without {buf} only the name of the file is used for
--- filetype matching. This may result in failure to detect
--- the filetype in cases where the filename alone is not
--- enough to disambiguate the filetype.
--- @field filename? string
---
--- An array of lines representing file contents to use for
--- matching. Can be used with {filename}. Mutually exclusive
--- with {buf}.
--- @field contents? string[]

--- Perform filetype detection.
---
--- The filetype can be detected using one of three methods:
--- 1. Using an existing buffer
--- 2. Using only a file name
--- 3. Using only file contents
---
--- Of these, option 1 provides the most accurate result as it uses both the buffer's filename and
--- (optionally) the buffer contents. Options 2 and 3 can be used without an existing buffer, but
--- may not always provide a match in cases where the filename (or contents) cannot unambiguously
--- determine the filetype.
---
--- Each of the three options is specified using a key to the single argument of this function.
--- Example:
---
--- ```lua
--- -- Using a buffer number
--- vim.filetype.match({ buf = 42 })
---
--- -- Override the filename of the given buffer
--- vim.filetype.match({ buf = 42, filename = 'foo.c' })
---
--- -- Using a filename without a buffer
--- vim.filetype.match({ filename = 'main.lua' })
---
--- -- Using file contents
--- vim.filetype.match({ contents = {'#!/usr/bin/env bash'} })
--- ```
---
---@param args vim.filetype.match.args Table specifying which matching strategy to use.
---                 Accepted keys are:
---@return string|nil # If a match was found, the matched filetype.
---@return function|nil # A function that modifies buffer state when called (for example, to set some
---                     filetype specific buffer variables). The function accepts a buffer number as
---                     its only argument.
function M.match(args)
  vim.validate({
    arg = { args, 't' },
  })

  if not (args.buf or args.filename or args.contents) then
    error('At least one of "buf", "filename", or "contents" must be given')
  end

  local bufnr = args.buf
  local name = args.filename
  local contents = args.contents

  if bufnr and not name then
    name = api.nvim_buf_get_name(bufnr)
  end

  --- @type string?, fun(b: integer)?
  local ft, on_detect

  if name then
    name = normalize_path(name)

    -- First check for the simple case where the full path exists as a key
    local path = fn.fnamemodify(name, ':p')
    ft, on_detect = dispatch(filename[path], path, bufnr)
    if ft then
      return ft, on_detect
    end

    -- Next check against just the file name
    local tail = fn.fnamemodify(name, ':t')
    ft, on_detect = dispatch(filename[tail], path, bufnr)
    if ft then
      return ft, on_detect
    end

    -- Next, check the file path against available patterns with non-negative priority
    -- Cache match results of all parent patterns to improve performance
    local parent_matches = {}
    ft, on_detect =
      match_pattern_sorted(name, path, tail, pattern_sorted_pos, parent_matches, bufnr)
    if ft then
      return ft, on_detect
    end

    -- Next, check file extension
    -- Don't use fnamemodify() with :e modifier here,
    -- as that's empty when there is only an extension.
    local ext = name:match('%.([^.]-)$') or ''
    ft, on_detect = dispatch(extension[ext], path, bufnr)
    if ft then
      return ft, on_detect
    end

    -- Next, check patterns with negative priority
    ft, on_detect =
      match_pattern_sorted(name, path, tail, pattern_sorted_neg, parent_matches, bufnr)
    if ft then
      return ft, on_detect
    end
  end

  -- Finally, check file contents
  if contents or bufnr then
    if contents == nil then
      assert(bufnr)
      if api.nvim_buf_line_count(bufnr) > 101 then
        -- only need first 100 and last line for current checks
        contents = M._getlines(bufnr, 1, 100)
        contents[#contents + 1] = M._getline(bufnr, -1)
      else
        contents = M._getlines(bufnr)
      end
    end

    -- Match based solely on content only if there is any content (for performance)
    if not (#contents == 1 and contents[1] == '') then
      -- If name is nil, catch any errors from the contents filetype detection function.
      -- If the function tries to use the filename that is nil then it will fail,
      -- but this enables checks which do not need a filename to still work.
      local ok
      ok, ft, on_detect = pcall(
        require('vim.filetype.detect').match_contents,
        contents,
        name,
        function(ext)
          return dispatch(extension[ext], name, bufnr)
        end
      )
      if ok then
        return ft, on_detect
      end
    end
  end
end

--- Get the default option value for a {filetype}.
---
--- The returned value is what would be set in a new buffer after 'filetype'
--- is set, meaning it should respect all FileType autocmds and ftplugin files.
---
--- Example:
---
--- ```lua
--- vim.filetype.get_option('vim', 'commentstring')
--- ```
---
--- Note: this uses |nvim_get_option_value()| but caches the result.
--- This means |ftplugin| and |FileType| autocommands are only
--- triggered once and may not reflect later changes.
--- @since 11
--- @param filetype string Filetype
--- @param option string Option name
--- @return string|boolean|integer: Option value
function M.get_option(filetype, option)
  return require('vim.filetype.options').get_option(filetype, option)
end

return M
