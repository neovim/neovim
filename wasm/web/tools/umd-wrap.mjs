// wasm/web/tools/umd-wrap.mjs - wrap a tsc-emitted CommonJS module into a UMD
// module that ALSO sets a browser global.
//
// tsc's own `module: umd` is deprecated (TS 6) and, more importantly, does NOT
// assign a named global -- it only handles CommonJS + AMD. But neovim.js et al.
// must remain loadable as a plain <script> that sets globalThis.<Name> (the
// browser demo + build-site.sh bundle rely on it), AND via require() in Node
// (the tests), AND via importScripts-style classic loads.
//
// So the build compiles the TS source to a self-contained CommonJS module and
// this tool wraps that body: in a CommonJS host it populates module.exports
// (and real require() serves any sibling imports); in a browser <script> (no
// module/exports) it builds a fresh exports object, hangs it off the global as
// root.<Name>, and serves sibling imports from the globals earlier <script>
// tags set (the --dep map below).
//
//   Usage: node umd-wrap.mjs <in.cjs.js> <out.js> <GlobalName> [--dep <spec>=<Global>]...
//   e.g.   node umd-wrap.mjs dist-lib/neovim-ui-pre.js dist/neovim-ui-pre.js \
//              NeovimUIPre --dep ./neovim-ui.js=NeovimUI
import { readFileSync, writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const deps = {};
const positional = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--dep') {
    const [spec, global] = String(args[++i]).split('=');
    deps[spec] = global;
  } else {
    positional.push(args[i]);
  }
}
const [infile, outfile, globalName] = positional;
if (!infile || !outfile || !globalName) {
  console.error('usage: umd-wrap.mjs <in> <out> <GlobalName> [--dep <spec>=<Global>]...');
  process.exit(1);
}

const body = readFileSync(infile, 'utf8');
const out =
`(function (root, factory) {
  if (typeof module === 'object' && module.exports) { factory(module, module.exports, require); }
  else {
    var deps = ${JSON.stringify(deps)};
    var req = function (spec) {
      if (Object.prototype.hasOwnProperty.call(deps, spec)) { return root[deps[spec]]; }
      throw new Error('umd-wrap: unmapped require(' + spec + ')');
    };
    var m = { exports: {} };
    factory(m, m.exports, req);
    root.${globalName} = m.exports;
  }
})(typeof self !== 'undefined' ? self : typeof globalThis !== 'undefined' ? globalThis : this, function (module, exports, require) {
${body}
});
`;
writeFileSync(outfile, out);
