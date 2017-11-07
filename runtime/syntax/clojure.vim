" Vim syntax file
" Language:     Clojure
" Authors:      Toralf Wittner <toralf.wittner@gmail.com>
"               modified by Meikel Brandmeyer <mb@kotka.de>
" URL:          http://kotka.de/projects/clojure/vimclojure.html
"
" Contributors: Joel Holdbrooks <cjholdbrooks@gmail.com> (Regexp support, bug fixes)
"
" Maintainer:   Sung Pae <self@sungpae.com>
" URL:          https://github.com/guns/vim-clojure-static
" License:      Same as Vim
" Last Change:  18 July 2016

if exists("b:current_syntax")
	finish
endif

let s:cpo_sav = &cpo
set cpo&vim

if has("folding") && exists("g:clojure_fold") && g:clojure_fold > 0
	setlocal foldmethod=syntax
endif

" -*- KEYWORDS -*-
" Generated from https://github.com/guns/vim-clojure-static/blob/vim-release-011/clj/src/vim_clojure_static/generate.clj
" Clojure version 1.8.0
let s:clojure_syntax_keywords = {
    \   'clojureBoolean': ["false","true"]
    \ , 'clojureCond': ["case","clojure.core/case","clojure.core/cond","clojure.core/cond->","clojure.core/cond->>","clojure.core/condp","clojure.core/if-let","clojure.core/if-not","clojure.core/if-some","clojure.core/when","clojure.core/when-first","clojure.core/when-let","clojure.core/when-not","clojure.core/when-some","cond","cond->","cond->>","condp","if-let","if-not","if-some","when","when-first","when-let","when-not","when-some"]
    \ , 'clojureConstant': ["nil"]
    \ , 'clojureDefine': ["clojure.core/definline","clojure.core/definterface","clojure.core/defmacro","clojure.core/defmethod","clojure.core/defmulti","clojure.core/defn","clojure.core/defn-","clojure.core/defonce","clojure.core/defprotocol","clojure.core/defrecord","clojure.core/defstruct","clojure.core/deftype","definline","definterface","defmacro","defmethod","defmulti","defn","defn-","defonce","defprotocol","defrecord","defstruct","deftype"]
    \ , 'clojureException': ["catch","finally","throw","try"]
    \ , 'clojureFunc': ["*","*'","+","+'","-","-'","->ArrayChunk","->Eduction","->Vec","->VecNode","->VecSeq","-cache-protocol-fn","-reset-methods","/","<","<=","=","==",">",">=","Throwable->map","accessor","aclone","add-classpath","add-watch","agent","agent-error","agent-errors","aget","alength","alias","all-ns","alter","alter-meta!","alter-var-root","ancestors","apply","array-map","aset","aset-boolean","aset-byte","aset-char","aset-double","aset-float","aset-int","aset-long","aset-short","assoc","assoc!","assoc-in","associative?","atom","await","await-for","await1","bases","bean","bigdec","bigint","biginteger","bit-and","bit-and-not","bit-clear","bit-flip","bit-not","bit-or","bit-set","bit-shift-left","bit-shift-right","bit-test","bit-xor","boolean","boolean-array","booleans","bound-fn*","bound?","butlast","byte","byte-array","bytes","cast","cat","char","char-array","char?","chars","chunk","chunk-append","chunk-buffer","chunk-cons","chunk-first","chunk-next","chunk-rest","chunked-seq?","class","class?","clear-agent-errors","clojure-version","clojure.core/*","clojure.core/*'","clojure.core/+","clojure.core/+'","clojure.core/-","clojure.core/-'","clojure.core/->ArrayChunk","clojure.core/->Eduction","clojure.core/->Vec","clojure.core/->VecNode","clojure.core/->VecSeq","clojure.core/-cache-protocol-fn","clojure.core/-reset-methods","clojure.core//","clojure.core/<","clojure.core/<=","clojure.core/=","clojure.core/==","clojure.core/>","clojure.core/>=","clojure.core/Throwable->map","clojure.core/accessor","clojure.core/aclone","clojure.core/add-classpath","clojure.core/add-watch","clojure.core/agent","clojure.core/agent-error","clojure.core/agent-errors","clojure.core/aget","clojure.core/alength","clojure.core/alias","clojure.core/all-ns","clojure.core/alter","clojure.core/alter-meta!","clojure.core/alter-var-root","clojure.core/ancestors","clojure.core/apply","clojure.core/array-map","clojure.core/aset","clojure.core/aset-boolean","clojure.core/aset-byte","clojure.core/aset-char","clojure.core/aset-double","clojure.core/aset-float","clojure.core/aset-int","clojure.core/aset-long","clojure.core/aset-short","clojure.core/assoc","clojure.core/assoc!","clojure.core/assoc-in","clojure.core/associative?","clojure.core/atom","clojure.core/await","clojure.core/await-for","clojure.core/await1","clojure.core/bases","clojure.core/bean","clojure.core/bigdec","clojure.core/bigint","clojure.core/biginteger","clojure.core/bit-and","clojure.core/bit-and-not","clojure.core/bit-clear","clojure.core/bit-flip","clojure.core/bit-not","clojure.core/bit-or","clojure.core/bit-set","clojure.core/bit-shift-left","clojure.core/bit-shift-right","clojure.core/bit-test","clojure.core/bit-xor","clojure.core/boolean","clojure.core/boolean-array","clojure.core/booleans","clojure.core/bound-fn*","clojure.core/bound?","clojure.core/butlast","clojure.core/byte","clojure.core/byte-array","clojure.core/bytes","clojure.core/cast","clojure.core/cat","clojure.core/char","clojure.core/char-array","clojure.core/char?","clojure.core/chars","clojure.core/chunk","clojure.core/chunk-append","clojure.core/chunk-buffer","clojure.core/chunk-cons","clojure.core/chunk-first","clojure.core/chunk-next","clojure.core/chunk-rest","clojure.core/chunked-seq?","clojure.core/class","clojure.core/class?","clojure.core/clear-agent-errors","clojure.core/clojure-version","clojure.core/coll?","clojure.core/commute","clojure.core/comp","clojure.core/comparator","clojure.core/compare","clojure.core/compare-and-set!","clojure.core/compile","clojure.core/complement","clojure.core/completing","clojure.core/concat","clojure.core/conj","clojure.core/conj!","clojure.core/cons","clojure.core/constantly","clojure.core/construct-proxy","clojure.core/contains?","clojure.core/count","clojure.core/counted?","clojure.core/create-ns","clojure.core/create-struct","clojure.core/cycle","clojure.core/dec","clojure.core/dec'","clojure.core/decimal?","clojure.core/dedupe","clojure.core/delay?","clojure.core/deliver","clojure.core/denominator","clojure.core/deref","clojure.core/derive","clojure.core/descendants","clojure.core/destructure","clojure.core/disj","clojure.core/disj!","clojure.core/dissoc","clojure.core/dissoc!","clojure.core/distinct","clojure.core/distinct?","clojure.core/doall","clojure.core/dorun","clojure.core/double","clojure.core/double-array","clojure.core/doubles","clojure.core/drop","clojure.core/drop-last","clojure.core/drop-while","clojure.core/eduction","clojure.core/empty","clojure.core/empty?","clojure.core/ensure","clojure.core/ensure-reduced","clojure.core/enumeration-seq","clojure.core/error-handler","clojure.core/error-mode","clojure.core/eval","clojure.core/even?","clojure.core/every-pred","clojure.core/every?","clojure.core/ex-data","clojure.core/ex-info","clojure.core/extend","clojure.core/extenders","clojure.core/extends?","clojure.core/false?","clojure.core/ffirst","clojure.core/file-seq","clojure.core/filter","clojure.core/filterv","clojure.core/find","clojure.core/find-keyword","clojure.core/find-ns","clojure.core/find-protocol-impl","clojure.core/find-protocol-method","clojure.core/find-var","clojure.core/first","clojure.core/flatten","clojure.core/float","clojure.core/float-array","clojure.core/float?","clojure.core/floats","clojure.core/flush","clojure.core/fn?","clojure.core/fnext","clojure.core/fnil","clojure.core/force","clojure.core/format","clojure.core/frequencies","clojure.core/future-call","clojure.core/future-cancel","clojure.core/future-cancelled?","clojure.core/future-done?","clojure.core/future?","clojure.core/gensym","clojure.core/get","clojure.core/get-in","clojure.core/get-method","clojure.core/get-proxy-class","clojure.core/get-thread-bindings","clojure.core/get-validator","clojure.core/group-by","clojure.core/hash","clojure.core/hash-combine","clojure.core/hash-map","clojure.core/hash-ordered-coll","clojure.core/hash-set","clojure.core/hash-unordered-coll","clojure.core/identical?","clojure.core/identity","clojure.core/ifn?","clojure.core/in-ns","clojure.core/inc","clojure.core/inc'","clojure.core/init-proxy","clojure.core/instance?","clojure.core/int","clojure.core/int-array","clojure.core/integer?","clojure.core/interleave","clojure.core/intern","clojure.core/interpose","clojure.core/into","clojure.core/into-array","clojure.core/ints","clojure.core/isa?","clojure.core/iterate","clojure.core/iterator-seq","clojure.core/juxt","clojure.core/keep","clojure.core/keep-indexed","clojure.core/key","clojure.core/keys","clojure.core/keyword","clojure.core/keyword?","clojure.core/last","clojure.core/line-seq","clojure.core/list","clojure.core/list*","clojure.core/list?","clojure.core/load","clojure.core/load-file","clojure.core/load-reader","clojure.core/load-string","clojure.core/loaded-libs","clojure.core/long","clojure.core/long-array","clojure.core/longs","clojure.core/macroexpand","clojure.core/macroexpand-1","clojure.core/make-array","clojure.core/make-hierarchy","clojure.core/map","clojure.core/map-entry?","clojure.core/map-indexed","clojure.core/map?","clojure.core/mapcat","clojure.core/mapv","clojure.core/max","clojure.core/max-key","clojure.core/memoize","clojure.core/merge","clojure.core/merge-with","clojure.core/meta","clojure.core/method-sig","clojure.core/methods","clojure.core/min","clojure.core/min-key","clojure.core/mix-collection-hash","clojure.core/mod","clojure.core/munge","clojure.core/name","clojure.core/namespace","clojure.core/namespace-munge","clojure.core/neg?","clojure.core/newline","clojure.core/next","clojure.core/nfirst","clojure.core/nil?","clojure.core/nnext","clojure.core/not","clojure.core/not-any?","clojure.core/not-empty","clojure.core/not-every?","clojure.core/not=","clojure.core/ns-aliases","clojure.core/ns-imports","clojure.core/ns-interns","clojure.core/ns-map","clojure.core/ns-name","clojure.core/ns-publics","clojure.core/ns-refers","clojure.core/ns-resolve","clojure.core/ns-unalias","clojure.core/ns-unmap","clojure.core/nth","clojure.core/nthnext","clojure.core/nthrest","clojure.core/num","clojure.core/number?","clojure.core/numerator","clojure.core/object-array","clojure.core/odd?","clojure.core/parents","clojure.core/partial","clojure.core/partition","clojure.core/partition-all","clojure.core/partition-by","clojure.core/pcalls","clojure.core/peek","clojure.core/persistent!","clojure.core/pmap","clojure.core/pop","clojure.core/pop!","clojure.core/pop-thread-bindings","clojure.core/pos?","clojure.core/pr","clojure.core/pr-str","clojure.core/prefer-method","clojure.core/prefers","clojure.core/print","clojure.core/print-ctor","clojure.core/print-dup","clojure.core/print-method","clojure.core/print-simple","clojure.core/print-str","clojure.core/printf","clojure.core/println","clojure.core/println-str","clojure.core/prn","clojure.core/prn-str","clojure.core/promise","clojure.core/proxy-call-with-super","clojure.core/proxy-mappings","clojure.core/proxy-name","clojure.core/push-thread-bindings","clojure.core/quot","clojure.core/rand","clojure.core/rand-int","clojure.core/rand-nth","clojure.core/random-sample","clojure.core/range","clojure.core/ratio?","clojure.core/rational?","clojure.core/rationalize","clojure.core/re-find","clojure.core/re-groups","clojure.core/re-matcher","clojure.core/re-matches","clojure.core/re-pattern","clojure.core/re-seq","clojure.core/read","clojure.core/read-line","clojure.core/read-string","clojure.core/reader-conditional","clojure.core/reader-conditional?","clojure.core/realized?","clojure.core/record?","clojure.core/reduce","clojure.core/reduce-kv","clojure.core/reduced","clojure.core/reduced?","clojure.core/reductions","clojure.core/ref","clojure.core/ref-history-count","clojure.core/ref-max-history","clojure.core/ref-min-history","clojure.core/ref-set","clojure.core/refer","clojure.core/release-pending-sends","clojure.core/rem","clojure.core/remove","clojure.core/remove-all-methods","clojure.core/remove-method","clojure.core/remove-ns","clojure.core/remove-watch","clojure.core/repeat","clojure.core/repeatedly","clojure.core/replace","clojure.core/replicate","clojure.core/require","clojure.core/reset!","clojure.core/reset-meta!","clojure.core/resolve","clojure.core/rest","clojure.core/restart-agent","clojure.core/resultset-seq","clojure.core/reverse","clojure.core/reversible?","clojure.core/rseq","clojure.core/rsubseq","clojure.core/run!","clojure.core/satisfies?","clojure.core/second","clojure.core/select-keys","clojure.core/send","clojure.core/send-off","clojure.core/send-via","clojure.core/seq","clojure.core/seq?","clojure.core/seque","clojure.core/sequence","clojure.core/sequential?","clojure.core/set","clojure.core/set-agent-send-executor!","clojure.core/set-agent-send-off-executor!","clojure.core/set-error-handler!","clojure.core/set-error-mode!","clojure.core/set-validator!","clojure.core/set?","clojure.core/short","clojure.core/short-array","clojure.core/shorts","clojure.core/shuffle","clojure.core/shutdown-agents","clojure.core/slurp","clojure.core/some","clojure.core/some-fn","clojure.core/some?","clojure.core/sort","clojure.core/sort-by","clojure.core/sorted-map","clojure.core/sorted-map-by","clojure.core/sorted-set","clojure.core/sorted-set-by","clojure.core/sorted?","clojure.core/special-symbol?","clojure.core/spit","clojure.core/split-at","clojure.core/split-with","clojure.core/str","clojure.core/string?","clojure.core/struct","clojure.core/struct-map","clojure.core/subs","clojure.core/subseq","clojure.core/subvec","clojure.core/supers","clojure.core/swap!","clojure.core/symbol","clojure.core/symbol?","clojure.core/tagged-literal","clojure.core/tagged-literal?","clojure.core/take","clojure.core/take-last","clojure.core/take-nth","clojure.core/take-while","clojure.core/test","clojure.core/the-ns","clojure.core/thread-bound?","clojure.core/to-array","clojure.core/to-array-2d","clojure.core/trampoline","clojure.core/transduce","clojure.core/transient","clojure.core/tree-seq","clojure.core/true?","clojure.core/type","clojure.core/unchecked-add","clojure.core/unchecked-add-int","clojure.core/unchecked-byte","clojure.core/unchecked-char","clojure.core/unchecked-dec","clojure.core/unchecked-dec-int","clojure.core/unchecked-divide-int","clojure.core/unchecked-double","clojure.core/unchecked-float","clojure.core/unchecked-inc","clojure.core/unchecked-inc-int","clojure.core/unchecked-int","clojure.core/unchecked-long","clojure.core/unchecked-multiply","clojure.core/unchecked-multiply-int","clojure.core/unchecked-negate","clojure.core/unchecked-negate-int","clojure.core/unchecked-remainder-int","clojure.core/unchecked-short","clojure.core/unchecked-subtract","clojure.core/unchecked-subtract-int","clojure.core/underive","clojure.core/unreduced","clojure.core/unsigned-bit-shift-right","clojure.core/update","clojure.core/update-in","clojure.core/update-proxy","clojure.core/use","clojure.core/val","clojure.core/vals","clojure.core/var-get","clojure.core/var-set","clojure.core/var?","clojure.core/vary-meta","clojure.core/vec","clojure.core/vector","clojure.core/vector-of","clojure.core/vector?","clojure.core/volatile!","clojure.core/volatile?","clojure.core/vreset!","clojure.core/with-bindings*","clojure.core/with-meta","clojure.core/with-redefs-fn","clojure.core/xml-seq","clojure.core/zero?","clojure.core/zipmap","coll?","commute","comp","comparator","compare","compare-and-set!","compile","complement","completing","concat","conj","conj!","cons","constantly","construct-proxy","contains?","count","counted?","create-ns","create-struct","cycle","dec","dec'","decimal?","dedupe","delay?","deliver","denominator","deref","derive","descendants","destructure","disj","disj!","dissoc","dissoc!","distinct","distinct?","doall","dorun","double","double-array","doubles","drop","drop-last","drop-while","eduction","empty","empty?","ensure","ensure-reduced","enumeration-seq","error-handler","error-mode","eval","even?","every-pred","every?","ex-data","ex-info","extend","extenders","extends?","false?","ffirst","file-seq","filter","filterv","find","find-keyword","find-ns","find-protocol-impl","find-protocol-method","find-var","first","flatten","float","float-array","float?","floats","flush","fn?","fnext","fnil","force","format","frequencies","future-call","future-cancel","future-cancelled?","future-done?","future?","gensym","get","get-in","get-method","get-proxy-class","get-thread-bindings","get-validator","group-by","hash","hash-combine","hash-map","hash-ordered-coll","hash-set","hash-unordered-coll","identical?","identity","ifn?","in-ns","inc","inc'","init-proxy","instance?","int","int-array","integer?","interleave","intern","interpose","into","into-array","ints","isa?","iterate","iterator-seq","juxt","keep","keep-indexed","key","keys","keyword","keyword?","last","line-seq","list","list*","list?","load","load-file","load-reader","load-string","loaded-libs","long","long-array","longs","macroexpand","macroexpand-1","make-array","make-hierarchy","map","map-entry?","map-indexed","map?","mapcat","mapv","max","max-key","memoize","merge","merge-with","meta","method-sig","methods","min","min-key","mix-collection-hash","mod","munge","name","namespace","namespace-munge","neg?","newline","next","nfirst","nil?","nnext","not","not-any?","not-empty","not-every?","not=","ns-aliases","ns-imports","ns-interns","ns-map","ns-name","ns-publics","ns-refers","ns-resolve","ns-unalias","ns-unmap","nth","nthnext","nthrest","num","number?","numerator","object-array","odd?","parents","partial","partition","partition-all","partition-by","pcalls","peek","persistent!","pmap","pop","pop!","pop-thread-bindings","pos?","pr","pr-str","prefer-method","prefers","print","print-ctor","print-dup","print-method","print-simple","print-str","printf","println","println-str","prn","prn-str","promise","proxy-call-with-super","proxy-mappings","proxy-name","push-thread-bindings","quot","rand","rand-int","rand-nth","random-sample","range","ratio?","rational?","rationalize","re-find","re-groups","re-matcher","re-matches","re-pattern","re-seq","read","read-line","read-string","reader-conditional","reader-conditional?","realized?","record?","reduce","reduce-kv","reduced","reduced?","reductions","ref","ref-history-count","ref-max-history","ref-min-history","ref-set","refer","release-pending-sends","rem","remove","remove-all-methods","remove-method","remove-ns","remove-watch","repeat","repeatedly","replace","replicate","require","reset!","reset-meta!","resolve","rest","restart-agent","resultset-seq","reverse","reversible?","rseq","rsubseq","run!","satisfies?","second","select-keys","send","send-off","send-via","seq","seq?","seque","sequence","sequential?","set","set-agent-send-executor!","set-agent-send-off-executor!","set-error-handler!","set-error-mode!","set-validator!","set?","short","short-array","shorts","shuffle","shutdown-agents","slurp","some","some-fn","some?","sort","sort-by","sorted-map","sorted-map-by","sorted-set","sorted-set-by","sorted?","special-symbol?","spit","split-at","split-with","str","string?","struct","struct-map","subs","subseq","subvec","supers","swap!","symbol","symbol?","tagged-literal","tagged-literal?","take","take-last","take-nth","take-while","test","the-ns","thread-bound?","to-array","to-array-2d","trampoline","transduce","transient","tree-seq","true?","type","unchecked-add","unchecked-add-int","unchecked-byte","unchecked-char","unchecked-dec","unchecked-dec-int","unchecked-divide-int","unchecked-double","unchecked-float","unchecked-inc","unchecked-inc-int","unchecked-int","unchecked-long","unchecked-multiply","unchecked-multiply-int","unchecked-negate","unchecked-negate-int","unchecked-remainder-int","unchecked-short","unchecked-subtract","unchecked-subtract-int","underive","unreduced","unsigned-bit-shift-right","update","update-in","update-proxy","use","val","vals","var-get","var-set","var?","vary-meta","vec","vector","vector-of","vector?","volatile!","volatile?","vreset!","with-bindings*","with-meta","with-redefs-fn","xml-seq","zero?","zipmap"]
    \ , 'clojureMacro': ["->","->>","..","amap","and","areduce","as->","assert","binding","bound-fn","clojure.core/->","clojure.core/->>","clojure.core/..","clojure.core/amap","clojure.core/and","clojure.core/areduce","clojure.core/as->","clojure.core/assert","clojure.core/binding","clojure.core/bound-fn","clojure.core/comment","clojure.core/declare","clojure.core/delay","clojure.core/dosync","clojure.core/doto","clojure.core/extend-protocol","clojure.core/extend-type","clojure.core/for","clojure.core/future","clojure.core/gen-class","clojure.core/gen-interface","clojure.core/import","clojure.core/io!","clojure.core/lazy-cat","clojure.core/lazy-seq","clojure.core/letfn","clojure.core/locking","clojure.core/memfn","clojure.core/ns","clojure.core/or","clojure.core/proxy","clojure.core/proxy-super","clojure.core/pvalues","clojure.core/refer-clojure","clojure.core/reify","clojure.core/some->","clojure.core/some->>","clojure.core/sync","clojure.core/time","clojure.core/vswap!","clojure.core/with-bindings","clojure.core/with-in-str","clojure.core/with-loading-context","clojure.core/with-local-vars","clojure.core/with-open","clojure.core/with-out-str","clojure.core/with-precision","clojure.core/with-redefs","comment","declare","delay","dosync","doto","extend-protocol","extend-type","for","future","gen-class","gen-interface","import","io!","lazy-cat","lazy-seq","letfn","locking","memfn","ns","or","proxy","proxy-super","pvalues","refer-clojure","reify","some->","some->>","sync","time","vswap!","with-bindings","with-in-str","with-loading-context","with-local-vars","with-open","with-out-str","with-precision","with-redefs"]
    \ , 'clojureRepeat': ["clojure.core/doseq","clojure.core/dotimes","clojure.core/while","doseq","dotimes","while"]
    \ , 'clojureSpecial': [".","clojure.core/fn","clojure.core/let","clojure.core/loop","def","do","fn","if","let","loop","monitor-enter","monitor-exit","new","quote","recur","set!","var"]
    \ , 'clojureVariable': ["*1","*2","*3","*agent*","*allow-unresolved-vars*","*assert*","*clojure-version*","*command-line-args*","*compile-files*","*compile-path*","*compiler-options*","*data-readers*","*default-data-reader-fn*","*e","*err*","*file*","*flush-on-newline*","*fn-loader*","*in*","*math-context*","*ns*","*out*","*print-dup*","*print-length*","*print-level*","*print-meta*","*print-readably*","*read-eval*","*source-path*","*suppress-read*","*unchecked-math*","*use-context-classloader*","*verbose-defrecords*","*warn-on-reflection*","EMPTY-NODE","char-escape-string","char-name-string","clojure.core/*1","clojure.core/*2","clojure.core/*3","clojure.core/*agent*","clojure.core/*allow-unresolved-vars*","clojure.core/*assert*","clojure.core/*clojure-version*","clojure.core/*command-line-args*","clojure.core/*compile-files*","clojure.core/*compile-path*","clojure.core/*compiler-options*","clojure.core/*data-readers*","clojure.core/*default-data-reader-fn*","clojure.core/*e","clojure.core/*err*","clojure.core/*file*","clojure.core/*flush-on-newline*","clojure.core/*fn-loader*","clojure.core/*in*","clojure.core/*math-context*","clojure.core/*ns*","clojure.core/*out*","clojure.core/*print-dup*","clojure.core/*print-length*","clojure.core/*print-level*","clojure.core/*print-meta*","clojure.core/*print-readably*","clojure.core/*read-eval*","clojure.core/*source-path*","clojure.core/*suppress-read*","clojure.core/*unchecked-math*","clojure.core/*use-context-classloader*","clojure.core/*verbose-defrecords*","clojure.core/*warn-on-reflection*","clojure.core/EMPTY-NODE","clojure.core/char-escape-string","clojure.core/char-name-string","clojure.core/default-data-readers","clojure.core/primitives-classnames","clojure.core/unquote","clojure.core/unquote-splicing","default-data-readers","primitives-classnames","unquote","unquote-splicing"]
    \ }

function! s:syntax_keyword(dict)
	for key in keys(a:dict)
		execute 'syntax keyword' key join(a:dict[key], ' ')
	endfor
endfunction

if exists('b:clojure_syntax_without_core_keywords') && b:clojure_syntax_without_core_keywords
	" Only match language specials and primitives
	for s:key in ['clojureBoolean', 'clojureConstant', 'clojureException', 'clojureSpecial']
		execute 'syntax keyword' s:key join(s:clojure_syntax_keywords[s:key], ' ')
	endfor
else
	call s:syntax_keyword(s:clojure_syntax_keywords)
endif

if exists('g:clojure_syntax_keywords')
	call s:syntax_keyword(g:clojure_syntax_keywords)
endif

if exists('b:clojure_syntax_keywords')
	call s:syntax_keyword(b:clojure_syntax_keywords)
endif

unlet! s:key
delfunction s:syntax_keyword

" Keywords are symbols:
"   static Pattern symbolPat = Pattern.compile("[:]?([\\D&&[^/]].*/)?([\\D&&[^/]][^/]*)");
" But they:
"   * Must not end in a : or /
"   * Must not have two adjacent colons except at the beginning
"   * Must not contain any reader metacharacters except for ' and #
syntax match clojureKeyword "\v<:{1,2}%([^ \n\r\t()\[\]{}";@^`~\\%/]+/)*[^ \n\r\t()\[\]{}";@^`~\\%/]+:@<!>"

syntax match clojureStringEscape "\v\\%([\\btnfr"]|u\x{4}|[0-3]\o{2}|\o{1,2})" contained

syntax region clojureString matchgroup=clojureStringDelimiter start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=clojureStringEscape,@Spell

syntax match clojureCharacter "\\."
syntax match clojureCharacter "\\o\%([0-3]\o\{2\}\|\o\{1,2\}\)"
syntax match clojureCharacter "\\u\x\{4\}"
syntax match clojureCharacter "\\space"
syntax match clojureCharacter "\\tab"
syntax match clojureCharacter "\\newline"
syntax match clojureCharacter "\\return"
syntax match clojureCharacter "\\backspace"
syntax match clojureCharacter "\\formfeed"

syntax match clojureSymbol "\v%([a-zA-Z!$&*_+=|<.>?-]|[^\x00-\x7F])+%(:?%([a-zA-Z0-9!#$%&*_+=|'<.>/?-]|[^\x00-\x7F]))*[#:]@<!"

let s:radix_chars = "0123456789abcdefghijklmnopqrstuvwxyz"
for s:radix in range(2, 36)
	execute 'syntax match clojureNumber "\v\c<[-+]?' . s:radix . 'r[' . strpart(s:radix_chars, 0, s:radix) . ']+>"'
endfor
unlet! s:radix_chars s:radix

syntax match clojureNumber "\v<[-+]?%(0\o*|0x\x+|[1-9]\d*)N?>"
syntax match clojureNumber "\v<[-+]?%(0|[1-9]\d*|%(0|[1-9]\d*)\.\d*)%(M|[eE][-+]?\d+)?>"
syntax match clojureNumber "\v<[-+]?%(0|[1-9]\d*)/%(0|[1-9]\d*)>"

syntax match clojureVarArg "&"

syntax match clojureQuote "'"
syntax match clojureQuote "`"
syntax match clojureUnquote "\~"
syntax match clojureUnquote "\~@"
syntax match clojureMeta "\^"
syntax match clojureDeref "@"
syntax match clojureDispatch "\v#[\^'=<_]?"

" Clojure permits no more than 20 anonymous params.
syntax match clojureAnonArg "%\(20\|1\d\|[1-9]\|&\)\?"

syntax match  clojureRegexpEscape "\v\\%([\\tnrfae.()\[\]{}^$*?+]|c\u|0[0-3]?\o{1,2}|x%(\x{2}|\{\x{1,6}\})|u\x{4})" contained display
syntax region clojureRegexpQuoted start=/\\Q/ms=e+1 skip=/\\\\\|\\"/ end=/\\E/me=s-1 end=/"/me=s-1 contained
syntax region clojureRegexpQuote  start=/\\Q/       skip=/\\\\\|\\"/ end=/\\E/       end=/"/me=s-1 contains=clojureRegexpQuoted keepend contained

" -*- CHARACTER PROPERTY CLASSES -*-
" Generated from https://github.com/guns/vim-clojure-static/blob/vim-release-011/clj/src/vim_clojure_static/generate.clj
" Java version 1.8.0_92
syntax match clojureRegexpPosixCharClass "\v\\[pP]\{%(Cntrl|A%(l%(pha|num)|SCII)|Space|Graph|Upper|P%(rint|unct)|Blank|XDigit|Digit|Lower)\}" contained display
syntax match clojureRegexpJavaCharClass "\v\\[pP]\{java%(Whitespace|JavaIdentifier%(Part|Start)|SpaceChar|Mirrored|TitleCase|I%(SOControl|de%(ographic|ntifierIgnorable))|D%(efined|igit)|U%(pperCase|nicodeIdentifier%(Part|Start))|L%(etter%(OrDigit)?|owerCase)|Alphabetic)\}" contained display
syntax match clojureRegexpUnicodeCharClass "\v\\[pP]\{\cIs%(l%(owercase|etter)|hex%(digit|_digit)|w%(hite%(_space|space)|ord)|noncharacter%(_code_point|codepoint)|p%(rint|unctuation)|ideographic|graph|a%(l%(num|phabetic)|ssigned)|uppercase|join%(control|_control)|titlecase|blank|digit|control)\}" contained display
syntax match clojureRegexpUnicodeCharClass "\v\\[pP][NSCMZPL]" contained display
syntax match clojureRegexpUnicodeCharClass "\v\\[pP]\{%(N[dlo]?|P[dcifeos]?|C[ncfos]?|M[nce]?|Z[lsp]?|S[mcko]?|L[muCDlto]?)\}" contained display
syntax match clojureRegexpUnicodeCharClass "\v\\[pP]\{%(Is|gc\=|general_category\=)?%(N[dlo]?|P[dcifeos]?|C[ncfos]?|M[nce]?|Z[lsp]?|S[mcko]?|L[muCDlto]?)\}" contained display
syntax match clojureRegexpUnicodeCharClass "\v\\[pP]\{\c%(Is|sc\=|script\=)%(l%(epc%(ha)?|y%([dc]i%(an)?)|a%(t%(n|in)|na|oo?)|i%(n%(b|ear_b)|mbu?|su))|p%(rti|lrd|h%(oenician|li|ag%(s_pa)?|nx))|vaii?|d%(srt|e%(seret|va%(nagari)?))|g%(lag%(olitic)?|eor%(gian)?|oth%(ic)?|re%(k|ek)|u%(j%(arati|r)|r%(u|mukhi)))|u%(gar%(itic)?|nknown)|a%(r%(ab%(ic)?|m%([ni]|enian))|v%(st|estan))|e%(thi%(opic)?|gyp%(tian_hieroglyphs)?)|z%(inh|yyy|zzz)|r%(un%(ic|r)|ejang|jng)|s%(inh%(ala)?|h%(rd|a%(vian|rada|w))|a%(ur%(ashtra)?|m%(r|aritan)|rb)|y%(r%(c|iac)|lo%(ti_nagri)?)|und%(anese)?|ora%(_sompeng)?)|i%(n%(scriptional_pa%(rthian|hlavi)|herited)|mperial_aramaic|tal)|b%(eng%(ali)?|a%(t%(ak|k)|li%(nese)?|mum?)|ra%(i%(lle)?|h%(mi)?)|opo%(mofo)?|u%(gi%(nese)?|h%(d|id)))|o%(g%(am|ham)|r%(iya|kh|ya)|sma%(nya)?|l%(d_%(south_arabian|persian|italic|turkic)|ck|_chiki))|k%(h%(m%(r|er)|ar%(oshthi)?)|nda|a%(li|n%(a|nada)|takana|yah_li|ithi)|thi)|m%(a%(nd%(aic)?|layalam)|lym|y%(anmar|mr)|tei|e%(r%(c|o%(itic_%(hieroglyphs|cursive))?)|etei_mayek)|ong%(olian)?|iao)|yi%(ii)?|x%(peo|sux)|n%(ew_tai_lue|koo?)|h%(ira%(gana)?|an%([io]|unoo|g%(ul)?)?|ebr%(ew)?)|c%(y%(priot|r%(l|illic))|a%(km|n%(adian_aboriginal|s)|ri%(an)?)|prt|h%(er%(okee)?|a%(m|kma))|uneiform|o%(pt%(ic)?|mmon))|t%(elu%(gu)?|i%(finagh|b%(t|etan))|ha%(i|a%(na)?)|a%(i_%(le|tham|viet)|g%(alog|b%(anwa)?)|vt|kri?|l[ue]|m%(il|l))|fng|glg)|java%(nese)?)\}" contained display
syntax match clojureRegexpUnicodeCharClass "\v\\[pP]\{\c%(In|blk\=|block\=)%(javanese|h%(a%(lfwidth%( and fullwidth forms|andfullwidthforms|_and_fullwidth_forms)|n%(unoo|gul%(compatibilityjamo|syllables|jamo%(extended\-[ab])?|_%(syllables|jamo%(_extended_[ab])?|compatibility_jamo)| %(syllables|compatibility jamo|jamo%( extended\-[ab])?))))|i%(ragana|gh%( %(private use surrogates|surrogates)|_%(private_use_surrogates|surrogates)|surrogates|privateusesurrogates))|ebrew)|i%(pa%([ _]extensions|extensions)|deographic%( description characters|_description_characters|descriptioncharacters)|nscriptional%(%([ _]pa%(rthian|hlavi))|pa%(rthian|hlavi))|mperial%(aramaic|[_ ]aramaic))|l%(e%(tterlike%([_ ]symbols|symbols)|pcha)|ow%([_ ]surrogates|surrogates)|i%(mbu|near%(_b_%(ideograms|syllabary)|b%(ideograms|syllabary)| b %(ideograms|syllabary))|su)|a%(tin%(extended%(additional|\-[dacb])| extended%( additional|\-[dacb])|\-1%(supplement| supplement)|_%(extended_%([dcb]|a%(dditional)?)|1_supplement))|o)|y[cd]ian)|b%(u%(ginese|hid)|ra%(hmi|ille%(patterns|[_ ]patterns))|o%(x%([ _]drawing|drawing)|pomofo%([ _]extended|extended)?)|lock%([ _]elements|elements)|yzantine%( musical symbols|musicalsymbols|_musical_symbols)|engali|a%(linese|mum%(supplement|[ _]supplement)?|tak|sic%([ _]latin|latin)))|e%(gyptian%([ _]hieroglyphs|hieroglyphs)|moticons|nclosed%( %(cjk letters and months|ideographic supplement|alphanumeric%( supplement|s))|cjklettersandmonths|_%(ideographic_supplement|alphanumeric%(_supplement|s)|cjk_letters_and_months)|alphanumerics%(upplement)?|ideographicsupplement)|thiopic%(supplement|_%(supplement|extended%(_a)?)| %(supplement|extended%(\-a)?)|extended%(\-a)?)?)|k%(h%(aroshthi|mer%([_ ]symbols|symbols)?)|a%(takana%(_phonetic_extensions|phoneticextensions| phonetic extensions)?|n%(gxi%([_ ]radicals|radicals)|a%(supplement|[ _]supplement)|bun|nada)|ithi|yah%([ _]li|li)))|m%(i%(ao|scellaneous%(technical|symbols%(and%(pictographs|arrows))?|mathematicalsymbols\-[ab]| %(technical|mathematical symbols\-[ab]|symbols%( and %(pictographs|arrows))?)|_%(technical|symbols%(_and_%(pictographs|arrows))?|mathematical_symbols_[ab])))|usical%([_ ]symbols|symbols)|e%(etei%(mayek%(extensions)?|_mayek%(_extensions)?| mayek%( extensions)?)|roitic%(hieroglyphs|%([_ ]%(hieroglyphs|cursive))|cursive))|a%(ndaic|hjong%([ _]tiles|tiles)|layalam|thematical%(alphanumericsymbols| %(alphanumeric symbols|operators)|_%(alphanumeric_symbols|operators)|operators))|yanmar%(extended\-a|_extended_a| extended\-a)?|o%(difier%(_tone_letters| tone letters|toneletters)|ngolian))|r%(u%(nic|mi%(numeralsymbols| numeral symbols|_numeral_symbols))|ejang)|n%(umber%(forms|[ _]forms)|ko|ew%(_tai_lue|tailue| tai lue))|c%(o%(ntrol%(pictures|[ _]pictures)|m%(bining%(diacriticalmarks%(supplement|forsymbols)?|halfmarks| %(diacritical marks%( %(supplement|for symbols))?|half marks|marks for symbols)|marksforsymbols|_%(marks_for_symbols|half_marks|diacritical_marks%(_supplement)?))|mon%(_indic_number_forms|indicnumberforms| indic number forms))|ptic|unting%( rod numerals|_rod_numerals|rodnumerals))|y%(rillic%(extended\-[ab]|_%(extended_[ab]|supplementary)|supplement%(ary)?| %(extended\-[ab]|supplement%(ary)?))?|priot%(syllabary|[ _]syllabary))|u%(rrency%([_ ]symbols|symbols)|neiform%(_numbers_and_punctuation|numbersandpunctuation| numbers and punctuation)?)|h%(a%(m|kma)|erokee)|arian|jk%(s%(ymbolsandpunctuation|trokes)|compatibility%(forms|ideographs%(supplement)?)?|radicalssupplement| %(compatibility%( %(ideographs%( supplement)?|forms))?|radicals supplement|unified ideographs%( extension [dacb])?|s%(ymbols and punctuation|trokes))|_%(s%(trokes|ymbols_and_punctuation)|radicals_supplement|compatibility%(_%(forms|ideographs%(_supplement)?))?|unified_ideographs%(_extension_[dacb])?)|unifiedideographs%(extension[dacb])?))|d%(e%(seret|vanagari%([ _]extended|extended)?)|ingbats|omino%([ _]tiles|tiles))|yi%(syllables|%([_ ]%(syllables|radicals))|radicals|jing%(hexagramsymbols| hexagram symbols|_hexagram_symbols))|s%(mall%( form variants|formvariants|_form_variants)|p%(acing%(_modifier_letters| modifier letters|modifierletters)|ecials)|ora%(sompeng|[ _]sompeng)|ha%(vian|rada)|a%(maritan|urashtra)|inhala|y%(riac|loti%([_ ]nagri|nagri))|u%(ndanese%(supplement|[ _]supplement)?|p%(erscripts%(_and_subscripts|andsubscripts| and subscripts)|plementa%(ry%(_private_use_area_[ab]|privateusearea\-[ab]| private use area\-[ab])|l%(_%(arrows_[ab]|mathematical_operators|punctuation)| %(mathematical operators|punctuation|arrows\-[ab])|mathematicaloperators|punctuation|arrows\-[ab])))|rrogates_area))|p%(h%(o%(enician|netic%( extensions%( supplement)?|extensions%(supplement)?|_extensions%(_supplement)?))|a%(istos%([ _]disc|disc)|gs[_\-]pa))|laying%(cards|[_ ]cards)|rivate%(usearea| use area|_use_area))|o%(smanya|l%([ _]chiki|d%( %(south arabian|persian|italic|turkic)|southarabian|_%(south_arabian|persian|italic|turkic)|persian|italic|turkic)|chiki)|riya|ptical%( character recognition|_character_recognition|characterrecognition)|gham)|g%(u%(jarati|rmukhi)|othic|lagolitic|e%(o%(rgian%(supplement|[ _]supplement)?|metric%(shapes|[ _]shapes))|neral%([_ ]punctuation|punctuation))|reek%( %(and coptic|extended)|andcoptic|_extended|extended)?)|t%(i%(betan|finagh)|elugu|ransport%( and map symbols|_and_map_symbols|andmapsymbols)|a%(mil|kri|i%(xuanjingsymbols|_%(le|xuan_jing_symbols|tham|viet)|le| %(xuan jing symbols|le|tham|viet)|tham|viet)|g%(alog|s|banwa))|ha%(i|ana))|a%(l%(chemical%([_ ]symbols|symbols)|phabetic%( presentation forms|_presentation_forms|presentationforms))|r%(menian|abic%(extended\-a|mathematicalalphabeticsymbols|supplement|_%(presentation_forms_[ab]|supplement|extended_a|mathematical_alphabetic_symbols)| %(extended\-a|mathematical alphabetic symbols|supplement|presentation forms\-[ab])|presentationforms\-[ab])?|rows)|ncient%(_%(greek_%(musical_notation|numbers)|symbols)|greek%(numbers|musicalnotation)| %(greek %(numbers|musical notation)|symbols)|symbols)|egean%(numbers|[ _]numbers)|vestan)|u%(garitic|nified%(canadianaboriginalsyllabics%(extended)?|_canadian_aboriginal_syllabics%(_extended)?| canadian aboriginal syllabics%( extended)?))|v%(a%(i|riation%( selectors%( supplement)?|selectors%(supplement)?|_selectors%(_supplement)?))|e%(rtical%(forms|[ _]forms)|dic%([ _]extensions|extensions))))\}" contained display

syntax match   clojureRegexpPredefinedCharClass "\v%(\\[dDsSwW]|\.)" contained display
syntax cluster clojureRegexpCharPropertyClasses contains=clojureRegexpPosixCharClass,clojureRegexpJavaCharClass,clojureRegexpUnicodeCharClass
syntax cluster clojureRegexpCharClasses         contains=clojureRegexpPredefinedCharClass,clojureRegexpCharClass,@clojureRegexpCharPropertyClasses
syntax region  clojureRegexpCharClass           start="\[" skip=/\\\\\|\\]/ end="]" contained contains=clojureRegexpPredefinedCharClass,@clojureRegexpCharPropertyClasses
syntax match   clojureRegexpBoundary            "\\[bBAGZz]" contained display
syntax match   clojureRegexpBoundary            "[$^]" contained display
syntax match   clojureRegexpQuantifier          "[?*+][?+]\=" contained display
syntax match   clojureRegexpQuantifier          "\v\{\d+%(,|,\d+)?}\??" contained display
syntax match   clojureRegexpOr                  "|" contained display
syntax match   clojureRegexpBackRef             "\v\\%([1-9]\d*|k\<[a-zA-Z]+\>)" contained display

" Mode modifiers, mode-modified spans, lookaround, regular and atomic
" grouping, and named-capturing.
syntax match clojureRegexpMod "\v\(@<=\?:" contained display
syntax match clojureRegexpMod "\v\(@<=\?[xdsmiuU]*-?[xdsmiuU]+:?" contained display
syntax match clojureRegexpMod "\v\(@<=\?%(\<?[=!]|\>)" contained display
syntax match clojureRegexpMod "\v\(@<=\?\<[a-zA-Z]+\>" contained display

syntax region clojureRegexpGroup start="(" skip=/\\\\\|\\)/ end=")" matchgroup=clojureRegexpGroup contained contains=clojureRegexpMod,clojureRegexpQuantifier,clojureRegexpBoundary,clojureRegexpEscape,@clojureRegexpCharClasses
syntax region clojureRegexp start=/\#"/ skip=/\\\\\|\\"/ end=/"/ contains=@clojureRegexpCharClasses,clojureRegexpEscape,clojureRegexpQuote,clojureRegexpBoundary,clojureRegexpQuantifier,clojureRegexpOr,clojureRegexpBackRef,clojureRegexpGroup keepend

syntax keyword clojureCommentTodo contained FIXME XXX TODO FIXME: XXX: TODO:

syntax match clojureComment ";.*$" contains=clojureCommentTodo,@Spell
syntax match clojureComment "#!.*$"

" -*- TOP CLUSTER -*-
" Generated from https://github.com/guns/vim-clojure-static/blob/vim-release-011/clj/src/vim_clojure_static/generate.clj
syntax cluster clojureTop contains=@Spell,clojureAnonArg,clojureBoolean,clojureCharacter,clojureComment,clojureCond,clojureConstant,clojureDefine,clojureDeref,clojureDispatch,clojureError,clojureException,clojureFunc,clojureKeyword,clojureMacro,clojureMap,clojureMeta,clojureNumber,clojureQuote,clojureRegexp,clojureRepeat,clojureSexp,clojureSpecial,clojureString,clojureSymbol,clojureUnquote,clojureVarArg,clojureVariable,clojureVector

syntax region clojureSexp   matchgroup=clojureParen start="("  end=")" contains=@clojureTop fold
syntax region clojureVector matchgroup=clojureParen start="\[" end="]" contains=@clojureTop fold
syntax region clojureMap    matchgroup=clojureParen start="{"  end="}" contains=@clojureTop fold

" Highlight superfluous closing parens, brackets and braces.
syntax match clojureError "]\|}\|)"

syntax sync fromstart

highlight default link clojureConstant                  Constant
highlight default link clojureBoolean                   Boolean
highlight default link clojureCharacter                 Character
highlight default link clojureKeyword                   Keyword
highlight default link clojureNumber                    Number
highlight default link clojureString                    String
highlight default link clojureStringDelimiter           String
highlight default link clojureStringEscape              Character

highlight default link clojureRegexp                    Constant
highlight default link clojureRegexpEscape              Character
highlight default link clojureRegexpCharClass           SpecialChar
highlight default link clojureRegexpPosixCharClass      clojureRegexpCharClass
highlight default link clojureRegexpJavaCharClass       clojureRegexpCharClass
highlight default link clojureRegexpUnicodeCharClass    clojureRegexpCharClass
highlight default link clojureRegexpPredefinedCharClass clojureRegexpCharClass
highlight default link clojureRegexpBoundary            SpecialChar
highlight default link clojureRegexpQuantifier          SpecialChar
highlight default link clojureRegexpMod                 SpecialChar
highlight default link clojureRegexpOr                  SpecialChar
highlight default link clojureRegexpBackRef             SpecialChar
highlight default link clojureRegexpGroup               clojureRegexp
highlight default link clojureRegexpQuoted              clojureString
highlight default link clojureRegexpQuote               clojureRegexpBoundary

highlight default link clojureVariable                  Identifier
highlight default link clojureCond                      Conditional
highlight default link clojureDefine                    Define
highlight default link clojureException                 Exception
highlight default link clojureFunc                      Function
highlight default link clojureMacro                     Macro
highlight default link clojureRepeat                    Repeat

highlight default link clojureSpecial                   Special
highlight default link clojureVarArg                    Special
highlight default link clojureQuote                     SpecialChar
highlight default link clojureUnquote                   SpecialChar
highlight default link clojureMeta                      SpecialChar
highlight default link clojureDeref                     SpecialChar
highlight default link clojureAnonArg                   SpecialChar
highlight default link clojureDispatch                  SpecialChar

highlight default link clojureComment                   Comment
highlight default link clojureCommentTodo               Todo

highlight default link clojureError                     Error

highlight default link clojureParen                     Delimiter

let b:current_syntax = "clojure"

let &cpo = s:cpo_sav
unlet! s:cpo_sav

" vim:sts=8:sw=8:ts=8:noet
