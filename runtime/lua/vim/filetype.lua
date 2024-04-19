local api = vim.api
local fn = vim.fn

local M = {}

--- @alias vim.filetype.mapfn fun(path:string,bufnr:integer, ...):string?, fun(b:integer)?
--- @alias vim.filetype.maptbl {[1]:string|vim.filetype.mapfn, [2]:{priority:integer}}
--- @alias vim.filetype.mapping.value string|vim.filetype.mapfn|vim.filetype.maptbl
--- @alias vim.filetype.mapping table<string,vim.filetype.mapping.value>

--- @param ft string|vim.filetype.mapfn
--- @param opts? {priority:integer}
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

-- Filetypes based on file extension
---@diagnostic disable: unused-local
--- @type vim.filetype.mapping
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
  lst = detect.asm,
  mac = detect.asm,
  asn1 = 'asn',
  asn = 'asn',
  asp = detect.asp,
  astro = 'astro',
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
  qc = 'c',
  cabal = 'cabal',
  cairo = 'cairo',
  capnp = 'capnp',
  cdc = 'cdc',
  cdl = 'cdl',
  toc = detect_line1('\\contentsline', 'tex', 'cdrtoc'),
  cfc = 'cf',
  cfm = 'cf',
  cfi = 'cf',
  hgrc = 'cfg',
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
  lib = 'cobol',
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
  gleam = 'gleam',
  glsl = 'glsl',
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
  j73 = 'jovial',
  jov = 'jovial',
  jovial = 'jovial',
  properties = 'jproperties',
  jq = 'jq',
  slnf = 'json',
  json = 'json',
  jsonp = 'json',
  geojson = 'json',
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
  mk = 'make',
  mak = 'make',
  dsp = 'make',
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
  comp = 'mason',
  mason = 'mason',
  master = 'master',
  mas = 'master',
  demo = 'maxima',
  dm1 = 'maxima',
  dm2 = 'maxima',
  dm3 = 'maxima',
  dmt = 'maxima',
  wxm = 'maxima',
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
  mmp = 'mmp',
  mms = detect.mms,
  DEF = 'modula2',
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
  ncf = 'ncf',
  nginx = 'nginx',
  nim = 'nim',
  nims = 'nim',
  nimble = 'nim',
  ninja = 'ninja',
  nix = 'nix',
  norg = 'norg',
  nqc = 'nqc',
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
  ebuild = detect.bash,
  eclass = detect.bash,
  env = detect.sh,
  ksh = detect.ksh,
  sh = detect.sh,
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
  quark = 'supercollider',
  sface = 'surface',
  svelte = 'svelte',
  svg = 'svg',
  swift = 'swift',
  swig = 'swig',
  swg = 'swig',
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
  out = 'tex',
  thm = 'tex',
  eps_tex = 'tex',
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
      local root = fn.fnamemodify(path, ':r')
      return M.match({ buf = bufnr, filename = root })
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

--- @type vim.filetype.mapping
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
  ['GNUmakefile.am'] = 'automake',
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
  ['/.icewm/menu'] = 'icemenu',
  ['.indent.pro'] = 'indent',
  indentrc = 'indent',
  inittab = 'inittab',
  ['ipf.conf'] = 'ipfilter',
  ['ipf6.conf'] = 'ipfilter',
  ['ipf.rules'] = 'ipfilter',
  ['.node_repl_history'] = 'javascript',
  ['Pipfile.lock'] = 'json',
  ['.firebaserc'] = 'json',
  ['.prettierrc'] = 'json',
  ['.stylelintrc'] = 'json',
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
  Kconfig = 'kconfig',
  ['Kconfig.debug'] = 'kconfig',
  ['Config.in'] = 'kconfig',
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
  ['.mysql_history'] = 'mysql',
  ['/etc/nanorc'] = 'nanorc',
  Neomuttrc = 'neomuttrc',
  ['.netrc'] = 'netrc',
  NEWS = detect.news,
  ['.ocamlinit'] = 'ocaml',
  ['.octaverc'] = 'octave',
  octaverc = 'octave',
  ['octave.conf'] = 'octave',
  opam = 'opam',
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
  README = 'text',
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
local detect_apache = starsetf('apache')
local detect_muttrc = starsetf('muttrc')
local detect_neomuttrc = starsetf('neomuttrc')

--- @type vim.filetype.mapping
local pattern = {
  -- BEGIN PATTERN
  ['.*/etc/a2ps/.*%.cfg'] = 'a2ps',
  ['.*/etc/a2ps%.cfg'] = 'a2ps',
  ['.*/usr/share/alsa/alsa%.conf'] = 'alsaconf',
  ['.*/etc/asound%.conf'] = 'alsaconf',
  ['.*/etc/apache2/sites%-.*/.*%.com'] = 'apache',
  ['.*/etc/httpd/.*%.conf'] = 'apache',
  ['.*/etc/apache2/.*%.conf.*'] = detect_apache,
  ['.*/etc/apache2/conf%..*/.*'] = detect_apache,
  ['.*/etc/apache2/mods%-.*/.*'] = detect_apache,
  ['.*/etc/apache2/sites%-.*/.*'] = detect_apache,
  ['access%.conf.*'] = detect_apache,
  ['apache%.conf.*'] = detect_apache,
  ['apache2%.conf.*'] = detect_apache,
  ['httpd%.conf.*'] = detect_apache,
  ['srm%.conf.*'] = detect_apache,
  ['.*/etc/httpd/conf%..*/.*'] = detect_apache,
  ['.*/etc/httpd/conf%.d/.*%.conf.*'] = detect_apache,
  ['.*/etc/httpd/mods%-.*/.*'] = detect_apache,
  ['.*/etc/httpd/sites%-.*/.*'] = detect_apache,
  ['.*/etc/proftpd/.*%.conf.*'] = starsetf('apachestyle'),
  ['.*/etc/proftpd/conf%..*/.*'] = starsetf('apachestyle'),
  ['proftpd%.conf.*'] = starsetf('apachestyle'),
  ['.*asterisk/.*%.conf.*'] = starsetf('asterisk'),
  ['.*asterisk.*/.*voicemail%.conf.*'] = starsetf('asteriskvm'),
  ['.*/%.aptitude/config'] = 'aptconf',
  ['.*%.[aA]'] = detect.asm,
  ['.*%.[sS]'] = detect.asm,
  ['[mM]akefile%.am'] = 'automake',
  ['.*/bind/db%..*'] = starsetf('bindzone'),
  ['.*/named/db%..*'] = starsetf('bindzone'),
  ['.*/build/conf/.*%.conf'] = 'bitbake',
  ['.*/meta/conf/.*%.conf'] = 'bitbake',
  ['.*/meta%-.*/conf/.*%.conf'] = 'bitbake',
  ['.*%.blade%.php'] = 'blade',
  ['bzr_log%..*'] = 'bzr',
  ['.*enlightenment/.*%.cfg'] = 'c',
  ['.*/%.cabal/config'] = 'cabalconfig',
  ['.*/cabal/config'] = 'cabalconfig',
  ['cabal%.project%..*'] = starsetf('cabalproject'),
  ['.*/%.calendar/.*'] = starsetf('calendar'),
  ['.*/share/calendar/.*/calendar%..*'] = starsetf('calendar'),
  ['.*/share/calendar/calendar%..*'] = starsetf('calendar'),
  ['sgml%.catalog.*'] = starsetf('catalog'),
  ['.*/etc/defaults/cdrdao'] = 'cdrdaoconf',
  ['.*/etc/cdrdao%.conf'] = 'cdrdaoconf',
  ['.*/etc/default/cdrdao'] = 'cdrdaoconf',
  ['.*hgrc'] = 'cfg',
  ['.*%.[Cc][Ff][Gg]'] = {
    detect.cfg,
    -- Decrease priority to avoid conflicts with more specific patterns
    -- such as '.*/etc/a2ps/.*%.cfg', '.*enlightenment/.*%.cfg', etc.
    { priority = -1 },
  },
  ['[cC]hange[lL]og.*'] = starsetf(detect.changelog),
  ['.*%.%.ch'] = 'chill',
  ['.*/etc/translate%-shell'] = 'clojure',
  ['.*%.cmake%.in'] = 'cmake',
  -- */cmus/rc and */.cmus/rc
  ['.*/%.?cmus/rc'] = 'cmusrc',
  -- */cmus/*.theme and */.cmus/*.theme
  ['.*/%.?cmus/.*%.theme'] = 'cmusrc',
  ['.*/%.cmus/autosave'] = 'cmusrc',
  ['.*/%.cmus/command%-history'] = 'cmusrc',
  ['.*/etc/hostname%..*'] = starsetf('config'),
  ['crontab%..*'] = starsetf('crontab'),
  ['.*/etc/cron%.d/.*'] = starsetf('crontab'),
  ['%.cshrc.*'] = detect.csh,
  ['%.login.*'] = detect.csh,
  ['cvs%d+'] = 'cvs',
  ['.*%.[Dd][Aa][Tt]'] = detect.dat,
  ['.*/debian/patches/.*'] = detect.dep3patch,
  ['.*/etc/dnsmasq%.d/.*'] = starsetf('dnsmasq'),
  ['Containerfile%..*'] = starsetf('dockerfile'),
  ['Dockerfile%..*'] = starsetf('dockerfile'),
  ['.*/etc/yum%.repos%.d/.*'] = starsetf('dosini'),
  ['drac%..*'] = starsetf('dracula'),
  ['.*/debian/changelog'] = 'debchangelog',
  ['.*/debian/control'] = 'debcontrol',
  ['.*/debian/copyright'] = 'debcopyright',
  ['.*/etc/apt/sources%.list%.d/.*%.list'] = 'debsources',
  ['.*/etc/apt/sources%.list'] = 'debsources',
  ['.*/etc/apt/sources%.list%.d/.*%.sources'] = 'deb822sources',
  ['.*%.directory'] = 'desktop',
  ['.*%.desktop'] = 'desktop',
  ['dictd.*%.conf'] = 'dictdconf',
  ['.*/etc/DIR_COLORS'] = 'dircolors',
  ['.*/etc/dnsmasq%.conf'] = 'dnsmasq',
  ['php%.ini%-.*'] = 'dosini',
  ['.*/%.aws/config'] = 'confini',
  ['.*/%.aws/credentials'] = 'confini',
  ['.*/etc/yum%.conf'] = 'dosini',
  ['.*/lxqt/.*%.conf'] = 'dosini',
  ['.*/screengrab/.*%.conf'] = 'dosini',
  ['.*/bpython/config'] = 'dosini',
  ['.*/mypy/config'] = 'dosini',
  ['.*/flatpak/repo/config'] = 'dosini',
  ['.*lvs'] = 'dracula',
  ['.*lpe'] = 'dracula',
  ['.*/dtrace/.*%.d'] = 'dtrace',
  ['.*esmtprc'] = 'esmtprc',
  ['.*Eterm/.*%.cfg'] = 'eterm',
  ['.*s6.*/up'] = 'execline',
  ['.*s6.*/down'] = 'execline',
  ['.*s6.*/run'] = 'execline',
  ['.*s6.*/finish'] = 'execline',
  ['s6%-.*'] = 'execline',
  ['[a-zA-Z0-9].*Dict'] = detect.foam,
  ['[a-zA-Z0-9].*Dict%..*'] = detect.foam,
  ['[a-zA-Z].*Properties'] = detect.foam,
  ['[a-zA-Z].*Properties%..*'] = detect.foam,
  ['.*Transport%..*'] = detect.foam,
  ['.*/constant/g'] = detect.foam,
  ['.*/0/.*'] = detect.foam,
  ['.*/0%.orig/.*'] = detect.foam,
  ['.*/%.fvwm/.*'] = starsetf('fvwm'),
  ['.*fvwmrc.*'] = starsetf(detect.fvwm_v1),
  ['.*fvwm95.*%.hook'] = starsetf(detect.fvwm_v1),
  ['.*fvwm2rc.*'] = starsetf(detect.fvwm_v2),
  ['.*/tmp/lltmp.*'] = starsetf('gedcom'),
  ['.*/etc/gitconfig%.d/.*'] = starsetf('gitconfig'),
  ['.*/gitolite%-admin/conf/.*'] = starsetf('gitolite'),
  ['tmac%..*'] = starsetf('nroff'),
  ['.*/%.gitconfig%.d/.*'] = starsetf('gitconfig'),
  ['.*%.git/.*'] = {
    detect.git,
    -- Decrease priority to run after simple pattern checks
    { priority = -1 },
  },
  ['.*%.git/modules/.*/config'] = 'gitconfig',
  ['.*%.git/modules/config'] = 'gitconfig',
  ['.*%.git/config'] = 'gitconfig',
  ['.*/etc/gitconfig'] = 'gitconfig',
  ['.*/%.config/git/config'] = 'gitconfig',
  ['.*%.git/config%.worktree'] = 'gitconfig',
  ['.*%.git/worktrees/.*/config%.worktree'] = 'gitconfig',
  ['${XDG_CONFIG_HOME}/git/config'] = 'gitconfig',
  ['.*%.git/info/attributes'] = 'gitattributes',
  ['.*/etc/gitattributes'] = 'gitattributes',
  ['.*/%.config/git/attributes'] = 'gitattributes',
  ['${XDG_CONFIG_HOME}/git/attributes'] = 'gitattributes',
  ['.*%.git/info/exclude'] = 'gitignore',
  ['.*/%.config/git/ignore'] = 'gitignore',
  ['${XDG_CONFIG_HOME}/git/ignore'] = 'gitignore',
  ['%.gitsendemail%.msg%.......'] = 'gitsendemail',
  ['gkrellmrc_.'] = 'gkrellmrc',
  ['.*/usr/.*/gnupg/options%.skel'] = 'gpg',
  ['.*/%.gnupg/options'] = 'gpg',
  ['.*/%.gnupg/gpg%.conf'] = 'gpg',
  ['${GNUPGHOME}/options'] = 'gpg',
  ['${GNUPGHOME}/gpg%.conf'] = 'gpg',
  ['.*/etc/group'] = 'group',
  ['.*/etc/gshadow'] = 'group',
  ['.*/etc/group%.edit'] = 'group',
  ['.*/var/backups/gshadow%.bak'] = 'group',
  ['.*/etc/group%-'] = 'group',
  ['.*/etc/gshadow%-'] = 'group',
  ['.*/var/backups/group%.bak'] = 'group',
  ['.*/etc/gshadow%.edit'] = 'group',
  ['.*/boot/grub/grub%.conf'] = 'grub',
  ['.*/boot/grub/menu%.lst'] = 'grub',
  ['.*/etc/grub%.conf'] = 'grub',
  -- gtkrc* and .gtkrc*
  ['%.?gtkrc.*'] = starsetf('gtkrc'),
  ['${VIMRUNTIME}/doc/.*%.txt'] = 'help',
  ['hg%-editor%-.*%.txt'] = 'hgcommit',
  ['.*/etc/host%.conf'] = 'hostconf',
  ['.*/etc/hosts%.deny'] = 'hostsaccess',
  ['.*/etc/hosts%.allow'] = 'hostsaccess',
  ['.*%.html%.m4'] = 'htmlm4',
  ['.*/%.i3/config'] = 'i3config',
  ['.*/i3/config'] = 'i3config',
  ['.*/%.icewm/menu'] = 'icemenu',
  ['.*/etc/initng/.*/.*%.i'] = 'initng',
  ['JAM.*%..*'] = starsetf('jam'),
  ['Prl.*%..*'] = starsetf('jam'),
  ['.*%.properties_..'] = 'jproperties',
  ['.*%.properties_.._..'] = 'jproperties',
  ['org%.eclipse%..*%.prefs'] = 'jproperties',
  ['.*%.properties_.._.._.*'] = starsetf('jproperties'),
  ['[jt]sconfig.*%.json'] = 'jsonc',
  ['[jJ]ustfile'] = 'just',
  ['Kconfig%..*'] = starsetf('kconfig'),
  ['Config%.in%..*'] = starsetf('kconfig'),
  ['.*%.[Ss][Uu][Bb]'] = 'krl',
  ['lilo%.conf.*'] = starsetf('lilo'),
  ['.*/etc/logcheck/.*%.d.*/.*'] = starsetf('logcheck'),
  ['.*/ldscripts/.*'] = 'ld',
  ['.*lftp/rc'] = 'lftp',
  ['.*/%.libao'] = 'libao',
  ['.*/etc/libao%.conf'] = 'libao',
  ['.*/etc/.*limits%.conf'] = 'limits',
  ['.*/etc/limits'] = 'limits',
  ['.*/etc/.*limits%.d/.*%.conf'] = 'limits',
  ['.*/supertux2/config'] = 'lisp',
  ['.*/LiteStep/.*/.*%.rc'] = 'litestep',
  ['.*/etc/login%.access'] = 'loginaccess',
  ['.*/etc/login%.defs'] = 'logindefs',
  ['%.letter%.%d+'] = 'mail',
  ['%.article%.%d+'] = 'mail',
  ['/tmp/SLRN[0-9A-Z.]+'] = 'mail',
  ['ae%d+%.txt'] = 'mail',
  ['pico%.%d+'] = 'mail',
  ['mutt%-.*%-%w+'] = 'mail',
  ['muttng%-.*%-%w+'] = 'mail',
  ['neomutt%-.*%-%w+'] = 'mail',
  ['mutt' .. string.rep('[%w_-]', 6)] = 'mail',
  ['neomutt' .. string.rep('[%w_-]', 6)] = 'mail',
  ['snd%.%d+'] = 'mail',
  ['reportbug%-.*'] = starsetf('mail'),
  ['.*/etc/mail/aliases'] = 'mailaliases',
  ['.*/etc/aliases'] = 'mailaliases',
  ['.*[mM]akefile'] = 'make',
  ['[mM]akefile.*'] = starsetf('make'),
  ['.*/etc/man%.conf'] = 'manconf',
  ['.*/log/auth'] = 'messages',
  ['.*/log/cron'] = 'messages',
  ['.*/log/daemon'] = 'messages',
  ['.*/log/debug'] = 'messages',
  ['.*/log/kern'] = 'messages',
  ['.*/log/lpr'] = 'messages',
  ['.*/log/mail'] = 'messages',
  ['.*/log/messages'] = 'messages',
  ['.*/log/news/news'] = 'messages',
  ['.*/log/syslog'] = 'messages',
  ['.*/log/user'] = 'messages',
  ['.*/log/auth%.log'] = 'messages',
  ['.*/log/cron%.log'] = 'messages',
  ['.*/log/daemon%.log'] = 'messages',
  ['.*/log/debug%.log'] = 'messages',
  ['.*/log/kern%.log'] = 'messages',
  ['.*/log/lpr%.log'] = 'messages',
  ['.*/log/mail%.log'] = 'messages',
  ['.*/log/messages%.log'] = 'messages',
  ['.*/log/news/news%.log'] = 'messages',
  ['.*/log/syslog%.log'] = 'messages',
  ['.*/log/user%.log'] = 'messages',
  ['.*/log/auth%.err'] = 'messages',
  ['.*/log/cron%.err'] = 'messages',
  ['.*/log/daemon%.err'] = 'messages',
  ['.*/log/debug%.err'] = 'messages',
  ['.*/log/kern%.err'] = 'messages',
  ['.*/log/lpr%.err'] = 'messages',
  ['.*/log/mail%.err'] = 'messages',
  ['.*/log/messages%.err'] = 'messages',
  ['.*/log/news/news%.err'] = 'messages',
  ['.*/log/syslog%.err'] = 'messages',
  ['.*/log/user%.err'] = 'messages',
  ['.*/log/auth%.info'] = 'messages',
  ['.*/log/cron%.info'] = 'messages',
  ['.*/log/daemon%.info'] = 'messages',
  ['.*/log/debug%.info'] = 'messages',
  ['.*/log/kern%.info'] = 'messages',
  ['.*/log/lpr%.info'] = 'messages',
  ['.*/log/mail%.info'] = 'messages',
  ['.*/log/messages%.info'] = 'messages',
  ['.*/log/news/news%.info'] = 'messages',
  ['.*/log/syslog%.info'] = 'messages',
  ['.*/log/user%.info'] = 'messages',
  ['.*/log/auth%.warn'] = 'messages',
  ['.*/log/cron%.warn'] = 'messages',
  ['.*/log/daemon%.warn'] = 'messages',
  ['.*/log/debug%.warn'] = 'messages',
  ['.*/log/kern%.warn'] = 'messages',
  ['.*/log/lpr%.warn'] = 'messages',
  ['.*/log/mail%.warn'] = 'messages',
  ['.*/log/messages%.warn'] = 'messages',
  ['.*/log/news/news%.warn'] = 'messages',
  ['.*/log/syslog%.warn'] = 'messages',
  ['.*/log/user%.warn'] = 'messages',
  ['.*/log/auth%.crit'] = 'messages',
  ['.*/log/cron%.crit'] = 'messages',
  ['.*/log/daemon%.crit'] = 'messages',
  ['.*/log/debug%.crit'] = 'messages',
  ['.*/log/kern%.crit'] = 'messages',
  ['.*/log/lpr%.crit'] = 'messages',
  ['.*/log/mail%.crit'] = 'messages',
  ['.*/log/messages%.crit'] = 'messages',
  ['.*/log/news/news%.crit'] = 'messages',
  ['.*/log/syslog%.crit'] = 'messages',
  ['.*/log/user%.crit'] = 'messages',
  ['.*/log/auth%.notice'] = 'messages',
  ['.*/log/cron%.notice'] = 'messages',
  ['.*/log/daemon%.notice'] = 'messages',
  ['.*/log/debug%.notice'] = 'messages',
  ['.*/log/kern%.notice'] = 'messages',
  ['.*/log/lpr%.notice'] = 'messages',
  ['.*/log/mail%.notice'] = 'messages',
  ['.*/log/messages%.notice'] = 'messages',
  ['.*/log/news/news%.notice'] = 'messages',
  ['.*/log/syslog%.notice'] = 'messages',
  ['.*/log/user%.notice'] = 'messages',
  ['.*%.[Mm][Oo][Dd]'] = detect.mod,
  ['.*/etc/modules%.conf'] = 'modconf',
  ['.*/etc/conf%.modules'] = 'modconf',
  ['.*/etc/modules'] = 'modconf',
  ['.*/etc/modprobe%..*'] = starsetf('modconf'),
  ['.*/etc/modutils/.*'] = starsetf(function(path, bufnr)
    if fn.executable(fn.expand(path)) ~= 1 then
      return 'modconf'
    end
  end),
  ['.*%.[mi][3g]'] = 'modula3',
  ['Muttrc'] = 'muttrc',
  ['Muttngrc'] = 'muttrc',
  ['.*/etc/Muttrc%.d/.*'] = starsetf('muttrc'),
  ['.*/%.mplayer/config'] = 'mplayerconf',
  ['Muttrc.*'] = detect_muttrc,
  ['Muttngrc.*'] = detect_muttrc,
  -- muttrc* and .muttrc*
  ['%.?muttrc.*'] = detect_muttrc,
  -- muttngrc* and .muttngrc*
  ['%.?muttngrc.*'] = detect_muttrc,
  ['.*/%.mutt/muttrc.*'] = detect_muttrc,
  ['.*/%.muttng/muttrc.*'] = detect_muttrc,
  ['.*/%.muttng/muttngrc.*'] = detect_muttrc,
  ['rndc.*%.conf'] = 'named',
  ['rndc.*%.key'] = 'named',
  ['named.*%.conf'] = 'named',
  ['.*/etc/nanorc'] = 'nanorc',
  ['.*%.NS[ACGLMNPS]'] = 'natural',
  ['Neomuttrc.*'] = detect_neomuttrc,
  -- neomuttrc* and .neomuttrc*
  ['%.?neomuttrc.*'] = detect_neomuttrc,
  ['.*/%.neomutt/neomuttrc.*'] = detect_neomuttrc,
  ['nginx.*%.conf'] = 'nginx',
  ['.*/etc/nginx/.*'] = 'nginx',
  ['.*nginx%.conf'] = 'nginx',
  ['.*/nginx/.*%.conf'] = 'nginx',
  ['.*/usr/local/nginx/conf/.*'] = 'nginx',
  ['.*%.[1-9]'] = detect.nroff,
  ['.*%.ml%.cppo'] = 'ocaml',
  ['.*%.mli%.cppo'] = 'ocaml',
  ['.*/octave/history'] = 'octave',
  ['.*%.opam%.template'] = 'opam',
  ['.*/openvpn/.*/.*%.conf'] = 'openvpn',
  ['.*%.[Oo][Pp][Ll]'] = 'opl',
  ['.*/etc/pam%.conf'] = 'pamconf',
  ['.*/etc/pam%.d/.*'] = starsetf('pamconf'),
  ['.*/etc/passwd%-'] = 'passwd',
  ['.*/etc/shadow'] = 'passwd',
  ['.*/etc/shadow%.edit'] = 'passwd',
  ['.*/var/backups/shadow%.bak'] = 'passwd',
  ['.*/var/backups/passwd%.bak'] = 'passwd',
  ['.*/etc/passwd'] = 'passwd',
  ['.*/etc/passwd%.edit'] = 'passwd',
  ['.*/etc/shadow%-'] = 'passwd',
  ['%.?gitolite%.rc'] = 'perl',
  ['example%.gitolite%.rc'] = 'perl',
  ['.*%.php%d'] = 'php',
  ['.*/%.pinforc'] = 'pinfo',
  ['.*/etc/pinforc'] = 'pinfo',
  ['.*%.[Pp][Rr][Gg]'] = detect.prg,
  ['.*/etc/protocols'] = 'protocols',
  ['.*printcap.*'] = starsetf(function(path, bufnr)
    return require('vim.filetype.detect').printcap('print')
  end),
  ['.*baseq[2-3]/.*%.cfg'] = 'quake',
  ['.*quake[1-3]/.*%.cfg'] = 'quake',
  ['.*id1/.*%.cfg'] = 'quake',
  ['.*/queries/.*%.scm'] = 'query', -- treesitter queries (Neovim only)
  ['.*,v'] = 'rcs',
  ['%.reminders.*'] = starsetf('remind'),
  ['.*%-requirements%.txt'] = 'requirements',
  ['requirements/.*%.txt'] = 'requirements',
  ['requires/.*%.txt'] = 'requirements',
  ['[rR]akefile.*'] = starsetf('ruby'),
  ['[rR]antfile'] = 'ruby',
  ['[rR]akefile'] = 'ruby',
  ['.*/etc/sensors%.d/[^.].*'] = starsetf('sensors'),
  ['.*/etc/sensors%.conf'] = 'sensors',
  ['.*/etc/sensors3%.conf'] = 'sensors',
  ['.*/etc/services'] = 'services',
  ['.*/etc/serial%.conf'] = 'setserial',
  ['.*/etc/udev/cdsymlinks%.conf'] = 'sh',
  ['.*/neofetch/config%.conf'] = 'sh',
  ['%.bash[_%-]aliases'] = detect.bash,
  ['%.bash[_%-]history'] = detect.bash,
  ['%.bash[_%-]logout'] = detect.bash,
  ['%.bash[_%-]profile'] = detect.bash,
  ['%.kshrc.*'] = detect.ksh,
  ['%.profile.*'] = detect.sh,
  ['.*/etc/profile'] = detect.sh,
  ['bash%-fc[%-%.].*'] = detect.bash,
  ['%.tcshrc.*'] = detect.tcsh,
  ['.*/etc/sudoers%.d/.*'] = starsetf('sudoers'),
  ['.*%._sst%.meta'] = 'sisu',
  ['.*%.%-sst%.meta'] = 'sisu',
  ['.*%.sst%.meta'] = 'sisu',
  ['.*/etc/slp%.conf'] = 'slpconf',
  ['.*/etc/slp%.reg'] = 'slpreg',
  ['.*/etc/slp%.spi'] = 'slpspi',
  ['.*/etc/ssh/ssh_config%.d/.*%.conf'] = 'sshconfig',
  ['.*/%.ssh/config'] = 'sshconfig',
  ['.*/%.ssh/.*%.conf'] = 'sshconfig',
  ['.*/etc/ssh/sshd_config%.d/.*%.conf'] = 'sshdconfig',
  ['.*%.[Ss][Rr][Cc]'] = detect.src,
  ['.*/etc/sudoers'] = 'sudoers',
  ['svn%-commit.*%.tmp'] = 'svn',
  ['.*/sway/config'] = 'swayconfig',
  ['.*/%.sway/config'] = 'swayconfig',
  ['.*%.swift%.gyb'] = 'swiftgyb',
  ['.*%.[Ss][Yy][Ss]'] = detect.sys,
  ['.*/etc/sysctl%.conf'] = 'sysctl',
  ['.*/etc/sysctl%.d/.*%.conf'] = 'sysctl',
  ['.*/systemd/.*%.automount'] = 'systemd',
  ['.*/systemd/.*%.dnssd'] = 'systemd',
  ['.*/systemd/.*%.link'] = 'systemd',
  ['.*/systemd/.*%.mount'] = 'systemd',
  ['.*/systemd/.*%.netdev'] = 'systemd',
  ['.*/systemd/.*%.network'] = 'systemd',
  ['.*/systemd/.*%.nspawn'] = 'systemd',
  ['.*/systemd/.*%.path'] = 'systemd',
  ['.*/systemd/.*%.service'] = 'systemd',
  ['.*/systemd/.*%.slice'] = 'systemd',
  ['.*/systemd/.*%.socket'] = 'systemd',
  ['.*/systemd/.*%.swap'] = 'systemd',
  ['.*/systemd/.*%.target'] = 'systemd',
  ['.*/systemd/.*%.timer'] = 'systemd',
  ['.*/etc/systemd/.*%.conf%.d/.*%.conf'] = 'systemd',
  ['.*/%.config/systemd/user/.*%.d/.*%.conf'] = 'systemd',
  ['.*/etc/systemd/system/.*%.d/.*%.conf'] = 'systemd',
  ['.*/etc/systemd/system/.*%.d/%.#.*'] = 'systemd',
  ['.*/etc/systemd/system/%.#.*'] = 'systemd',
  ['.*/%.config/systemd/user/.*%.d/%.#.*'] = 'systemd',
  ['.*/%.config/systemd/user/%.#.*'] = 'systemd',
  ['.*termcap.*'] = starsetf(function(path, bufnr)
    return require('vim.filetype.detect').printcap('term')
  end),
  ['.*/tex/latex/.*%.cfg'] = 'tex',
  ['.*%.t%.html'] = 'tilde',
  ['%.?tmux.*%.conf'] = 'tmux',
  ['%.?tmux.*%.conf.*'] = { 'tmux', { priority = -1 } },
  ['.*/%.cargo/config'] = 'toml',
  ['.*/%.cargo/credentials'] = 'toml',
  ['.*/etc/udev/udev%.conf'] = 'udevconf',
  ['.*/etc/udev/permissions%.d/.*%.permissions'] = 'udevperm',
  ['.*/etc/updatedb%.conf'] = 'updatedb',
  ['.*/%.init/.*%.override'] = 'upstart',
  ['.*/usr/share/upstart/.*%.conf'] = 'upstart',
  ['.*/%.config/upstart/.*%.override'] = 'upstart',
  ['.*/etc/init/.*%.conf'] = 'upstart',
  ['.*/etc/init/.*%.override'] = 'upstart',
  ['.*/%.config/upstart/.*%.conf'] = 'upstart',
  ['.*/%.init/.*%.conf'] = 'upstart',
  ['.*/usr/share/upstart/.*%.override'] = 'upstart',
  ['.*%.[Ll][Oo][Gg]'] = detect.log,
  ['.*/etc/config/.*'] = starsetf(detect.uci),
  ['.*%.vhdl_[0-9].*'] = starsetf('vhdl'),
  ['.*%.ws[fc]'] = 'wsh',
  ['.*/Xresources/.*'] = starsetf('xdefaults'),
  ['.*/app%-defaults/.*'] = starsetf('xdefaults'),
  ['.*/etc/xinetd%.conf'] = 'xinetd',
  ['.*/usr/share/X11/xkb/compat/.*'] = starsetf('xkb'),
  ['.*/usr/share/X11/xkb/geometry/.*'] = starsetf('xkb'),
  ['.*/usr/share/X11/xkb/keycodes/.*'] = starsetf('xkb'),
  ['.*/usr/share/X11/xkb/symbols/.*'] = starsetf('xkb'),
  ['.*/usr/share/X11/xkb/types/.*'] = starsetf('xkb'),
  ['.*/etc/blkid%.tab'] = 'xml',
  ['.*/etc/blkid%.tab%.old'] = 'xml',
  ['.*%.vbproj%.user'] = 'xml',
  ['.*%.fsproj%.user'] = 'xml',
  ['.*%.csproj%.user'] = 'xml',
  ['.*/etc/xdg/menus/.*%.menu'] = 'xml',
  ['.*Xmodmap'] = 'xmodmap',
  ['.*/etc/zprofile'] = 'zsh',
  ['.*vimrc.*'] = starsetf('vim'),
  ['Xresources.*'] = starsetf('xdefaults'),
  ['.*/etc/xinetd%.d/.*'] = starsetf('xinetd'),
  ['.*xmodmap.*'] = starsetf('xmodmap'),
  ['.*/xorg%.conf%.d/.*%.conf'] = detect.xfree86_v4,
  -- Increase priority to run before the pattern below
  ['XF86Config%-4.*'] = starsetf(detect.xfree86_v4, { priority = -math.huge + 1 }),
  ['XF86Config.*'] = starsetf(detect.xfree86_v3),
  ['.*/%.bundle/config'] = 'yaml',
  ['%.zcompdump.*'] = starsetf('zsh'),
  -- .zlog* and zlog*
  ['%.?zlog.*'] = starsetf('zsh'),
  -- .zsh* and zsh*
  ['%.?zsh.*'] = starsetf('zsh'),
  -- Ignored extension
  ['.*~'] = function(path, bufnr)
    local short = path:gsub('~+$', '', 1)
    if path ~= short and short ~= '' then
      return M.match({ buf = bufnr, filename = fn.fnameescape(short) })
    end
  end,
  -- END PATTERN
}
-- luacheck: pop
-- luacheck: pop

--- @param t vim.filetype.mapping
--- @return vim.filetype.mapping[]
local function sort_by_priority(t)
  local sorted = {} --- @type vim.filetype.mapping[]
  for k, v in pairs(t) do
    local ft = type(v) == 'table' and v[1] or v
    assert(
      type(ft) == 'string' or type(ft) == 'function',
      'Expected string or function for filetype'
    )

    local opts = (type(v) == 'table' and type(v[2]) == 'table') and v[2] or {}
    if not opts.priority then
      opts.priority = 0
    end
    table.insert(sorted, { [k] = { ft, opts } })
  end
  table.sort(sorted, function(a, b)
    return a[next(a)][2].priority > b[next(b)][2].priority
  end)
  return sorted
end

local pattern_sorted = sort_by_priority(pattern)

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
---     ['README.(%a+)$'] = function(path, bufnr, ext)
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
---       priority = -math.huge,
---       function(path, bufnr)
---         local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
---         if vim.regex([[^#!.*\\<mine\\>]]):match_str(content) ~= nil then
---           return 'mine'
---         elseif vim.regex([[\\<drawing\\>]]):match_str(content) ~= nil then
---           return 'drawing'
---         end
---       end,
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
    pattern[normalize_path(k, true)] = v
  end

  if filetypes.pattern then
    pattern_sorted = sort_by_priority(pattern)
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

--- Lookup table/cache for patterns that contain an environment variable pattern, e.g. ${SOME_VAR}.
--- @type table<string,boolean>
local expand_env_lookup = {}

--- @param name string
--- @param path string
--- @param tail string
--- @param pat string
--- @return string|false?
local function match_pattern(name, path, tail, pat)
  if expand_env_lookup[pat] == nil then
    expand_env_lookup[pat] = pat:find('%${') ~= nil
  end
  if expand_env_lookup[pat] then
    local return_early --- @type true?
    --- @type string
    pat = pat:gsub('%${(%S-)}', function(env)
      -- If an environment variable is present in the pattern but not set, there is no match
      if not vim.env[env] then
        return_early = true
        return nil
      end
      return vim.pesc(vim.env[env])
    end)
    if return_early then
      return false
    end
  end

  -- If the pattern contains a / match against the full path, otherwise just the tail
  local fullpat = '^' .. pat .. '$'

  if pat:find('/') then
    -- Similar to |autocmd-pattern|, if the pattern contains a '/' then check for a match against
    -- both the short file name (as typed) and the full file name (after expanding to full path
    -- and resolving symlinks)
    return (name:match(fullpat) or path:match(fullpat))
  end

  return (tail:match(fullpat))
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
    local j = 1
    for i, v in ipairs(pattern_sorted) do
      local k = next(v)
      local opts = v[k][2]
      if opts.priority < 0 then
        j = i
        break
      end

      local filetype = v[k][1]
      local matches = match_pattern(name, path, tail, k)
      if matches then
        ft, on_detect = dispatch(filetype, path, bufnr, matches)
        if ft then
          return ft, on_detect
        end
      end
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
    for i = j, #pattern_sorted do
      local v = pattern_sorted[i]
      local k = next(v)

      local filetype = v[k][1]
      local matches = match_pattern(name, path, tail, k)
      if matches then
        ft, on_detect = dispatch(filetype, path, bufnr, matches)
        if ft then
          return ft, on_detect
        end
      end
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
--- @param filetype string Filetype
--- @param option string Option name
--- @return string|boolean|integer: Option value
function M.get_option(filetype, option)
  return require('vim.filetype.options').get_option(filetype, option)
end

return M
