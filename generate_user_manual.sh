# TODO put it in scripts/
set -e

# TODO first extract the user manual files
nvim -V1 -es --clean +"lua require('src.gen.gen_help_html').gen('typ', './usr_manual', './pdf_docs')" +q

# Make the ToC the starting point of the PDF
mv pdf_docs/usr_toc.typ pdf_docs/user_manual.typ

cat pdf_docs/usr_??.typ >> pdf_docs/user_manual.typ
typst compile pdf_docs/user_manual.typ
