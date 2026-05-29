# TODO put it in scripts/
set -e

nvim -V1 -es --clean +"lua require('src.gen.gen_help_html').gen('typ', './usr_manual', './pdf_docs')" +q
cat pdf_docs/usr_*.typ > pdf_docs/user_manual.typ
typst compile pdf_docs/user_manual.typ
