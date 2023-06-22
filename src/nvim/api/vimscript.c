// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vimscript.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/globals.h"
#include "nvim/memory.h"
#include "nvim/pos.h"
#include "nvim/runtime.h"
#include "nvim/vim.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vimscript.c.generated.h"
#endif

/// Executes Vimscript (multiline block of Ex commands), like anonymous
/// |:source|.
///
/// Unlike |nvim_command()| this function supports heredocs, script-scope (s:),
/// etc.
///
/// On execution error: fails with Vimscript error, updates v:errmsg.
///
/// @see |execute()|
/// @see |nvim_command()|
/// @see |nvim_cmd()|
///
/// @param src      Vimscript code
/// @param opts  Optional parameters.
///           - output: (boolean, default false) Whether to capture and return
///                     all (non-error, non-shell |:!|) output.
/// @param[out] err Error details (Vim error), if any
/// @return Dictionary containing information about execution, with these keys:
///       - output: (string|nil) Output if `opts.output` is true.
Dictionary nvim_exec2(uint64_t channel_id, String src, Dict(exec_opts) *opts, Error *err)
  FUNC_API_SINCE(11)
{
  Dictionary result = ARRAY_DICT_INIT;

  String output = exec_impl(channel_id, src, opts, err);
  if (ERROR_SET(err)) {
    return result;
  }

  if (HAS_KEY(opts->output) && api_object_to_bool(opts->output, "opts.output", false, err)) {
    PUT(result, "output", STRING_OBJ(output));
  }

  return result;
}

String exec_impl(uint64_t channel_id, String src, Dict(exec_opts) *opts, Error *err)
{
  Boolean output = api_object_to_bool(opts->output, "opts.output", false, err);

  const int save_msg_silent = msg_silent;
  garray_T *const save_capture_ga = capture_ga;
  const int save_msg_col = msg_col;
  garray_T capture_local;
  if (output) {
    ga_init(&capture_local, 1, 80);
    capture_ga = &capture_local;
  }

  try_start();
  if (output) {
    msg_silent++;
    msg_col = 0;  // prevent leading spaces
  }

  const sctx_T save_current_sctx = api_set_sctx(channel_id);

  do_source_str(src.data, "nvim_exec2()");
  if (output) {
    capture_ga = save_capture_ga;
    msg_silent = save_msg_silent;
    // Put msg_col back where it was, since nothing should have been written.
    msg_col = save_msg_col;
  }

  current_sctx = save_current_sctx;
  try_end(err);

  if (ERROR_SET(err)) {
    goto theend;
  }

  if (output && capture_local.ga_len > 1) {
    String s = (String){
      .data = capture_local.ga_data,
      .size = (size_t)capture_local.ga_len,
    };
    // redir usually (except :echon) prepends a newline.
    if (s.data[0] == '\n') {
      memmove(s.data, s.data + 1, s.size - 1);
      s.data[s.size - 1] = '\0';
      s.size = s.size - 1;
    }
    return s;  // Caller will free the memory.
  }
theend:
  if (output) {
    ga_clear(&capture_local);
  }
  return (String)STRING_INIT;
}

/// Executes an Ex command.
///
/// On execution error: fails with Vimscript error, updates v:errmsg.
///
/// Prefer using |nvim_cmd()| or |nvim_exec2()| over this. To evaluate multiple lines of Vim script
/// or an Ex command directly, use |nvim_exec2()|. To construct an Ex command using a structured
/// format and then execute it, use |nvim_cmd()|. To modify an Ex command before evaluating it, use
/// |nvim_parse_cmd()| in conjunction with |nvim_cmd()|.
///
/// @param command  Ex command string
/// @param[out] err Error details (Vim error), if any
void nvim_command(String command, Error *err)
  FUNC_API_SINCE(1)
{
  try_start();
  do_cmdline_cmd(command.data);
  try_end(err);
}

/// Evaluates a Vimscript |expression|.
/// Dictionaries and Lists are recursively expanded.
///
/// On execution error: fails with Vimscript error, updates v:errmsg.
///
/// @param expr     Vimscript expression string
/// @param[out] err Error details, if any
/// @return         Evaluation result or expanded object
Object nvim_eval(String expr, Error *err)
  FUNC_API_SINCE(1)
{
  static int recursive = 0;  // recursion depth
  Object rv = OBJECT_INIT;

  // Initialize `force_abort`  and `suppress_errthrow` at the top level.
  if (!recursive) {
    force_abort = false;
    suppress_errthrow = false;
    did_throw = false;
    // `did_emsg` is set by emsg(), which cancels execution.
    did_emsg = false;
  }

  recursive++;

  typval_T rettv;
  int ok;

  TRY_WRAP(err, {
    ok = eval0(expr.data, &rettv, NULL, &EVALARG_EVALUATE);
    clear_evalarg(&EVALARG_EVALUATE, NULL);
  });

  if (!ERROR_SET(err)) {
    if (ok == FAIL) {
      // Should never happen, try_end() (in TRY_WRAP) should get the error. #8371
      api_set_error(err, kErrorTypeException,
                    "Failed to evaluate expression: '%.*s'", 256, expr.data);
    } else {
      rv = vim_to_object(&rettv);
    }
  }

  tv_clear(&rettv);
  recursive--;

  return rv;
}

/// Calls a Vimscript function.
///
/// @param fn Function name
/// @param args Function arguments
/// @param self `self` dict, or NULL for non-dict functions
/// @param[out] err Error details, if any
/// @return Result of the function call
static Object _call_function(String fn, Array args, dict_T *self, Error *err)
{
  static int recursive = 0;  // recursion depth
  Object rv = OBJECT_INIT;

  if (args.size > MAX_FUNC_ARGS) {
    api_set_error(err, kErrorTypeValidation,
                  "Function called with too many arguments");
    return rv;
  }

  // Convert the arguments in args from Object to typval_T values
  typval_T vim_args[MAX_FUNC_ARGS + 1];
  size_t i = 0;  // also used for freeing the variables
  for (; i < args.size; i++) {
    if (!object_to_vim(args.items[i], &vim_args[i], err)) {
      goto free_vim_args;
    }
  }

  // Initialize `force_abort`  and `suppress_errthrow` at the top level.
  if (!recursive) {
    force_abort = false;
    suppress_errthrow = false;
    did_throw = false;
    // `did_emsg` is set by emsg(), which cancels execution.
    did_emsg = false;
  }
  recursive++;

  typval_T rettv;
  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = true;
  funcexe.fe_selfdict = self;

  TRY_WRAP(err, {
    // call_func() retval is deceptive, ignore it.  Instead we set `msg_list`
    // (see above) to capture abort-causing non-exception errors.
    (void)call_func(fn.data, (int)fn.size, &rettv, (int)args.size,
                    vim_args, &funcexe);
  });

  if (!ERROR_SET(err)) {
    rv = vim_to_object(&rettv);
  }

  tv_clear(&rettv);
  recursive--;

free_vim_args:
  while (i > 0) {
    tv_clear(&vim_args[--i]);
  }

  return rv;
}

/// Calls a Vimscript function with the given arguments.
///
/// On execution error: fails with Vimscript error, updates v:errmsg.
///
/// @param fn       Function to call
/// @param args     Function arguments packed in an Array
/// @param[out] err Error details, if any
/// @return Result of the function call
Object nvim_call_function(String fn, Array args, Error *err)
  FUNC_API_SINCE(1)
{
  return _call_function(fn, args, NULL, err);
}

/// Calls a Vimscript |Dictionary-function| with the given arguments.
///
/// On execution error: fails with Vimscript error, updates v:errmsg.
///
/// @param dict Dictionary, or String evaluating to a Vimscript |self| dict
/// @param fn Name of the function defined on the Vimscript dict
/// @param args Function arguments packed in an Array
/// @param[out] err Error details, if any
/// @return Result of the function call
Object nvim_call_dict_function(Object dict, String fn, Array args, Error *err)
  FUNC_API_SINCE(4)
{
  Object rv = OBJECT_INIT;

  typval_T rettv;
  bool mustfree = false;
  switch (dict.type) {
  case kObjectTypeString:
    try_start();
    if (eval0(dict.data.string.data, &rettv, NULL, &EVALARG_EVALUATE) == FAIL) {
      api_set_error(err, kErrorTypeException,
                    "Failed to evaluate dict expression");
    }
    clear_evalarg(&EVALARG_EVALUATE, NULL);
    if (try_end(err)) {
      return rv;
    }
    // Evaluation of the string arg created a new dict or increased the
    // refcount of a dict. Not necessary for a RPC dict.
    mustfree = true;
    break;
  case kObjectTypeDictionary:
    if (!object_to_vim(dict, &rettv, err)) {
      goto end;
    }
    break;
  default:
    api_set_error(err, kErrorTypeValidation,
                  "dict argument type must be String or Dictionary");
    return rv;
  }
  dict_T *self_dict = rettv.vval.v_dict;
  if (rettv.v_type != VAR_DICT || !self_dict) {
    api_set_error(err, kErrorTypeValidation, "dict not found");
    goto end;
  }

  if (fn.data && fn.size > 0 && dict.type != kObjectTypeDictionary) {
    dictitem_T *const di = tv_dict_find(self_dict, fn.data, (ptrdiff_t)fn.size);
    if (di == NULL) {
      api_set_error(err, kErrorTypeValidation, "Not found: %s", fn.data);
      goto end;
    }
    if (di->di_tv.v_type == VAR_PARTIAL) {
      api_set_error(err, kErrorTypeValidation,
                    "partial function not supported");
      goto end;
    }
    if (di->di_tv.v_type != VAR_FUNC) {
      api_set_error(err, kErrorTypeValidation, "Not a function: %s", fn.data);
      goto end;
    }
    fn = (String) {
      .data = di->di_tv.vval.v_string,
      .size = strlen(di->di_tv.vval.v_string),
    };
  }

  if (!fn.data || fn.size < 1) {
    api_set_error(err, kErrorTypeValidation, "Invalid (empty) function name");
    goto end;
  }

  rv = _call_function(fn, args, self_dict, err);
end:
  if (mustfree) {
    tv_clear(&rettv);
  }

  return rv;
}

typedef struct {
  ExprASTNode **node_p;
  Object *ret_node_p;
} ExprASTConvStackItem;

/// @cond DOXYGEN_NOT_A_FUNCTION
typedef kvec_withinit_t(ExprASTConvStackItem, 16) ExprASTConvStack;
/// @endcond

/// Parse a Vimscript expression.
///
/// @param[in]  expr  Expression to parse. Always treated as a single line.
/// @param[in]  flags Flags:
///                    - "m" if multiple expressions in a row are allowed (only
///                      the first one will be parsed),
///                    - "E" if EOC tokens are not allowed (determines whether
///                      they will stop parsing process or be recognized as an
///                      operator/space, though also yielding an error).
///                    - "l" when needing to start parsing with lvalues for
///                      ":let" or ":for".
///                    Common flag sets:
///                    - "m" to parse like for ":echo".
///                    - "E" to parse like for "<C-r>=".
///                    - empty string for ":call".
///                    - "lm" to parse for ":let".
/// @param[in]  highlight  If true, return value will also include "highlight"
///                        key containing array of 4-tuples (arrays) (Integer,
///                        Integer, Integer, String), where first three numbers
///                        define the highlighted region and represent line,
///                        starting column and ending column (latter exclusive:
///                        one should highlight region [start_col, end_col)).
///
/// @return
///      - AST: top-level dictionary with these keys:
///        - "error": Dictionary with error, present only if parser saw some
///                 error. Contains the following keys:
///          - "message": String, error message in printf format, translated.
///                       Must contain exactly one "%.*s".
///          - "arg": String, error message argument.
///        - "len": Amount of bytes successfully parsed. With flags equal to ""
///                 that should be equal to the length of expr string.
///                 (“Successfully parsed” here means “participated in AST
///                  creation”, not “till the first error”.)
///        - "ast": AST, either nil or a dictionary with these keys:
///          - "type": node type, one of the value names from ExprASTNodeType
///                    stringified without "kExprNode" prefix.
///          - "start": a pair [line, column] describing where node is "started"
///                     where "line" is always 0 (will not be 0 if you will be
///                     using nvim_parse_viml() on e.g. ":let", but that is not
///                     present yet). Both elements are Integers.
///          - "len": “length” of the node. This and "start" are there for
///                   debugging purposes primary (debugging parser and providing
///                   debug information).
///          - "children": a list of nodes described in top/"ast". There always
///                        is zero, one or two children, key will not be present
///                        if node has no children. Maximum number of children
///                        may be found in node_maxchildren array.
///      - Local values (present only for certain nodes):
///        - "scope": a single Integer, specifies scope for "Option" and
///                   "PlainIdentifier" nodes. For "Option" it is one of
///                   ExprOptScope values, for "PlainIdentifier" it is one of
///                   ExprVarScope values.
///        - "ident": identifier (without scope, if any), present for "Option",
///                   "PlainIdentifier", "PlainKey" and "Environment" nodes.
///        - "name": Integer, register name (one character) or -1. Only present
///                for "Register" nodes.
///        - "cmp_type": String, comparison type, one of the value names from
///                      ExprComparisonType, stringified without "kExprCmp"
///                      prefix. Only present for "Comparison" nodes.
///        - "ccs_strategy": String, case comparison strategy, one of the
///                          value names from ExprCaseCompareStrategy,
///                          stringified without "kCCStrategy" prefix. Only
///                          present for "Comparison" nodes.
///        - "augmentation": String, augmentation type for "Assignment" nodes.
///                          Is either an empty string, "Add", "Subtract" or
///                          "Concat" for "=", "+=", "-=" or ".=" respectively.
///        - "invert": Boolean, true if result of comparison needs to be
///                    inverted. Only present for "Comparison" nodes.
///        - "ivalue": Integer, integer value for "Integer" nodes.
///        - "fvalue": Float, floating-point value for "Float" nodes.
///        - "svalue": String, value for "SingleQuotedString" and
///                    "DoubleQuotedString" nodes.
/// @param[out] err Error details, if any
Dictionary nvim_parse_expression(String expr, String flags, Boolean highlight, Error *err)
  FUNC_API_SINCE(4) FUNC_API_FAST
{
  int pflags = 0;
  for (size_t i = 0; i < flags.size; i++) {
    switch (flags.data[i]) {
    case 'm':
      pflags |= kExprFlagsMulti; break;
    case 'E':
      pflags |= kExprFlagsDisallowEOC; break;
    case 'l':
      pflags |= kExprFlagsParseLet; break;
    case NUL:
      api_set_error(err, kErrorTypeValidation, "Invalid flag: '\\0' (%u)",
                    (unsigned)flags.data[i]);
      return (Dictionary)ARRAY_DICT_INIT;
    default:
      api_set_error(err, kErrorTypeValidation, "Invalid flag: '%c' (%u)",
                    flags.data[i], (unsigned)flags.data[i]);
      return (Dictionary)ARRAY_DICT_INIT;
    }
  }
  ParserLine parser_lines[] = {
    {
      .data = expr.data,
      .size = expr.size,
      .allocated = false,
    },
    { NULL, 0, false },
  };
  ParserLine *plines_p = parser_lines;
  ParserHighlight colors;
  kvi_init(colors);
  ParserHighlight *const colors_p = (highlight ? &colors : NULL);
  ParserState pstate;
  viml_parser_init(&pstate, parser_simple_get_line, &plines_p, colors_p);
  ExprAST east = viml_pexpr_parse(&pstate, pflags);

  const size_t ret_size = (2  // "ast", "len"
                           + (size_t)(east.err.msg != NULL)  // "error"
                           + (size_t)highlight  // "highlight"
                           + 0);
  Dictionary ret = {
    .items = xmalloc(ret_size * sizeof(ret.items[0])),
    .size = 0,
    .capacity = ret_size,
  };
  ret.items[ret.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("ast"),
    .value = NIL,
  };
  ret.items[ret.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("len"),
    .value = INTEGER_OBJ((Integer)(pstate.pos.line == 1
                                   ? parser_lines[0].size
                                   : pstate.pos.col)),
  };
  if (east.err.msg != NULL) {
    Dictionary err_dict = {
      .items = xmalloc(2 * sizeof(err_dict.items[0])),
      .size = 2,
      .capacity = 2,
    };
    err_dict.items[0] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("message"),
      .value = CSTR_TO_OBJ(east.err.msg),
    };
    if (east.err.arg == NULL) {
      err_dict.items[1] = (KeyValuePair) {
        .key = STATIC_CSTR_TO_STRING("arg"),
        .value = STRING_OBJ(STRING_INIT),
      };
    } else {
      err_dict.items[1] = (KeyValuePair) {
        .key = STATIC_CSTR_TO_STRING("arg"),
        .value = STRING_OBJ(((String) {
          .data = xmemdupz(east.err.arg, (size_t)east.err.arg_len),
          .size = (size_t)east.err.arg_len,
        })),
      };
    }
    ret.items[ret.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("error"),
      .value = DICTIONARY_OBJ(err_dict),
    };
  }
  if (highlight) {
    Array hl = (Array) {
      .items = xmalloc(kv_size(colors) * sizeof(hl.items[0])),
      .capacity = kv_size(colors),
      .size = kv_size(colors),
    };
    for (size_t i = 0; i < kv_size(colors); i++) {
      const ParserHighlightChunk chunk = kv_A(colors, i);
      Array chunk_arr = (Array) {
        .items = xmalloc(4 * sizeof(chunk_arr.items[0])),
        .capacity = 4,
        .size = 4,
      };
      chunk_arr.items[0] = INTEGER_OBJ((Integer)chunk.start.line);
      chunk_arr.items[1] = INTEGER_OBJ((Integer)chunk.start.col);
      chunk_arr.items[2] = INTEGER_OBJ((Integer)chunk.end_col);
      chunk_arr.items[3] = CSTR_TO_OBJ(chunk.group);
      hl.items[i] = ARRAY_OBJ(chunk_arr);
    }
    ret.items[ret.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("highlight"),
      .value = ARRAY_OBJ(hl),
    };
  }
  kvi_destroy(colors);

  // Walk over the AST, freeing nodes in process.
  ExprASTConvStack ast_conv_stack;
  kvi_init(ast_conv_stack);
  kvi_push(ast_conv_stack, ((ExprASTConvStackItem) {
    .node_p = &east.root,
    .ret_node_p = &ret.items[0].value,
  }));
  while (kv_size(ast_conv_stack)) {
    ExprASTConvStackItem cur_item = kv_last(ast_conv_stack);
    ExprASTNode *const node = *cur_item.node_p;
    if (node == NULL) {
      assert(kv_size(ast_conv_stack) == 1);
      kv_drop(ast_conv_stack, 1);
    } else {
      if (cur_item.ret_node_p->type == kObjectTypeNil) {
        size_t items_size = (size_t)(3  // "type", "start" and "len"  // NOLINT(bugprone-misplaced-widening-cast)
                                     + (node->children != NULL)  // "children"
                                     + (node->type == kExprNodeOption
                                        || node->type == kExprNodePlainIdentifier)  // "scope"
                                     + (node->type == kExprNodeOption
                                        || node->type == kExprNodePlainIdentifier
                                        || node->type == kExprNodePlainKey
                                        || node->type == kExprNodeEnvironment)  // "ident"
                                     + (node->type == kExprNodeRegister)  // "name"
                                     + (3  // "cmp_type", "ccs_strategy", "invert"
                                        * (node->type == kExprNodeComparison))
                                     + (node->type == kExprNodeInteger)  // "ivalue"
                                     + (node->type == kExprNodeFloat)  // "fvalue"
                                     + (node->type == kExprNodeDoubleQuotedString
                                        || node->type == kExprNodeSingleQuotedString)  // "svalue"
                                     + (node->type == kExprNodeAssignment)  // "augmentation"
                                     + 0);
        Dictionary ret_node = {
          .items = xmalloc(items_size * sizeof(ret_node.items[0])),
          .capacity = items_size,
          .size = 0,
        };
        *cur_item.ret_node_p = DICTIONARY_OBJ(ret_node);
      }
      Dictionary *ret_node = &cur_item.ret_node_p->data.dictionary;
      if (node->children != NULL) {
        const size_t num_children = 1 + (node->children->next != NULL);
        Array children_array = {
          .items = xmalloc(num_children * sizeof(children_array.items[0])),
          .capacity = num_children,
          .size = num_children,
        };
        for (size_t i = 0; i < num_children; i++) {
          children_array.items[i] = NIL;
        }
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("children"),
          .value = ARRAY_OBJ(children_array),
        };
        kvi_push(ast_conv_stack, ((ExprASTConvStackItem) {
          .node_p = &node->children,
          .ret_node_p = &children_array.items[0],
        }));
      } else if (node->next != NULL) {
        kvi_push(ast_conv_stack, ((ExprASTConvStackItem) {
          .node_p = &node->next,
          .ret_node_p = cur_item.ret_node_p + 1,
        }));
      } else {
        kv_drop(ast_conv_stack, 1);
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("type"),
          .value = CSTR_TO_OBJ(east_node_type_tab[node->type]),
        };
        Array start_array = {
          .items = xmalloc(2 * sizeof(start_array.items[0])),
          .capacity = 2,
          .size = 2,
        };
        start_array.items[0] = INTEGER_OBJ((Integer)node->start.line);
        start_array.items[1] = INTEGER_OBJ((Integer)node->start.col);
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("start"),
          .value = ARRAY_OBJ(start_array),
        };
        ret_node->items[ret_node->size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("len"),
          .value = INTEGER_OBJ((Integer)node->len),
        };
        switch (node->type) {
        case kExprNodeDoubleQuotedString:
        case kExprNodeSingleQuotedString:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("svalue"),
            .value = STRING_OBJ(((String) {
              .data = node->data.str.value,
              .size = node->data.str.size,
            })),
          };
          break;
        case kExprNodeOption:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("scope"),
            .value = INTEGER_OBJ(node->data.opt.scope),
          };
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("ident"),
            .value = STRING_OBJ(((String) {
              .data = xmemdupz(node->data.opt.ident,
                               node->data.opt.ident_len),
              .size = node->data.opt.ident_len,
            })),
          };
          break;
        case kExprNodePlainIdentifier:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("scope"),
            .value = INTEGER_OBJ(node->data.var.scope),
          };
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("ident"),
            .value = STRING_OBJ(((String) {
              .data = xmemdupz(node->data.var.ident,
                               node->data.var.ident_len),
              .size = node->data.var.ident_len,
            })),
          };
          break;
        case kExprNodePlainKey:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("ident"),
            .value = STRING_OBJ(((String) {
              .data = xmemdupz(node->data.var.ident,
                               node->data.var.ident_len),
              .size = node->data.var.ident_len,
            })),
          };
          break;
        case kExprNodeEnvironment:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("ident"),
            .value = STRING_OBJ(((String) {
              .data = xmemdupz(node->data.env.ident,
                               node->data.env.ident_len),
              .size = node->data.env.ident_len,
            })),
          };
          break;
        case kExprNodeRegister:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("name"),
            .value = INTEGER_OBJ(node->data.reg.name),
          };
          break;
        case kExprNodeComparison:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("cmp_type"),
            .value = CSTR_TO_OBJ(eltkn_cmp_type_tab[node->data.cmp.type]),
          };
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("ccs_strategy"),
            .value = CSTR_TO_OBJ(ccs_tab[node->data.cmp.ccs]),
          };
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("invert"),
            .value = BOOLEAN_OBJ(node->data.cmp.inv),
          };
          break;
        case kExprNodeFloat:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("fvalue"),
            .value = FLOAT_OBJ(node->data.flt.value),
          };
          break;
        case kExprNodeInteger:
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("ivalue"),
            .value = INTEGER_OBJ((Integer)(node->data.num.value > API_INTEGER_MAX
                                           ? API_INTEGER_MAX
                                           : (Integer)node->data.num.value)),
          };
          break;
        case kExprNodeAssignment: {
          const ExprAssignmentType asgn_type = node->data.ass.type;
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("augmentation"),
            .value = STRING_OBJ(asgn_type == kExprAsgnPlain
                                ? (String)STRING_INIT
                                : cstr_to_string(expr_asgn_type_tab[asgn_type])),
          };
          break;
        }
        case kExprNodeMissing:
        case kExprNodeOpMissing:
        case kExprNodeTernary:
        case kExprNodeTernaryValue:
        case kExprNodeSubscript:
        case kExprNodeListLiteral:
        case kExprNodeUnaryPlus:
        case kExprNodeBinaryPlus:
        case kExprNodeNested:
        case kExprNodeCall:
        case kExprNodeComplexIdentifier:
        case kExprNodeUnknownFigure:
        case kExprNodeLambda:
        case kExprNodeDictLiteral:
        case kExprNodeCurlyBracesIdentifier:
        case kExprNodeComma:
        case kExprNodeColon:
        case kExprNodeArrow:
        case kExprNodeConcat:
        case kExprNodeConcatOrSubscript:
        case kExprNodeOr:
        case kExprNodeAnd:
        case kExprNodeUnaryMinus:
        case kExprNodeBinaryMinus:
        case kExprNodeNot:
        case kExprNodeMultiplication:
        case kExprNodeDivision:
        case kExprNodeMod:
          break;
        }
        assert(cur_item.ret_node_p->data.dictionary.size
               == cur_item.ret_node_p->data.dictionary.capacity);
        xfree(*cur_item.node_p);
        *cur_item.node_p = NULL;
      }
    }
  }
  kvi_destroy(ast_conv_stack);

  assert(ret.size == ret.capacity);
  // Should be a no-op actually, leaving it in case non-nodes will need to be
  // freed later.
  viml_pexpr_free_ast(east);
  viml_parser_destroy(&pstate);
  return ret;
}
