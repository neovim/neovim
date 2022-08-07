// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <limits.h>
#include <stdlib.h>

#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vimscript.h"
#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/eval.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ops.h"
#include "nvim/strings.h"
#include "nvim/vim.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vimscript.c.generated.h"
#endif

/// Executes Vimscript (multiline block of Ex commands), like anonymous
/// |:source|.
///
/// Unlike |nvim_command()| this function supports heredocs, script-scope (s:),
/// etc.
///
/// On execution error: fails with VimL error, updates v:errmsg.
///
/// @see |execute()|
/// @see |nvim_command()|
/// @see |nvim_cmd()|
///
/// @param src      Vimscript code
/// @param output   Capture and return all (non-error, non-shell |:!|) output
/// @param[out] err Error details (Vim error), if any
/// @return Output (non-error, non-shell |:!|) if `output` is true,
///         else empty string.
String nvim_exec(uint64_t channel_id, String src, Boolean output, Error *err)
  FUNC_API_SINCE(7)
{
  const int save_msg_silent = msg_silent;
  garray_T *const save_capture_ga = capture_ga;
  garray_T capture_local;
  if (output) {
    ga_init(&capture_local, 1, 80);
    capture_ga = &capture_local;
  }

  try_start();
  if (output) {
    msg_silent++;
  }

  const sctx_T save_current_sctx = api_set_sctx(channel_id);

  do_source_str(src.data, "nvim_exec()");
  if (output) {
    capture_ga = save_capture_ga;
    msg_silent = save_msg_silent;
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
/// On execution error: fails with VimL error, updates v:errmsg.
///
/// Prefer using |nvim_cmd()| or |nvim_exec()| over this. To evaluate multiple lines of Vim script
/// or an Ex command directly, use |nvim_exec()|. To construct an Ex command using a structured
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

/// Evaluates a VimL |expression|.
/// Dictionaries and Lists are recursively expanded.
///
/// On execution error: fails with VimL error, updates v:errmsg.
///
/// @param expr     VimL expression string
/// @param[out] err Error details, if any
/// @return         Evaluation result or expanded object
Object nvim_eval(String expr, Error *err)
  FUNC_API_SINCE(1)
{
  static int recursive = 0;  // recursion depth
  Object rv = OBJECT_INIT;

  TRY_WRAP({
    // Initialize `force_abort`  and `suppress_errthrow` at the top level.
    if (!recursive) {
      force_abort = false;
      suppress_errthrow = false;
      current_exception = NULL;
      // `did_emsg` is set by emsg(), which cancels execution.
      did_emsg = false;
    }
    recursive++;
    try_start();

    typval_T rettv;
    int ok = eval0(expr.data, &rettv, NULL, true);

    if (!try_end(err)) {
      if (ok == FAIL) {
        // Should never happen, try_end() should get the error. #8371
        api_set_error(err, kErrorTypeException,
                      "Failed to evaluate expression: '%.*s'", 256, expr.data);
      } else {
        rv = vim_to_object(&rettv);
      }
    }

    tv_clear(&rettv);
    recursive--;
  });

  return rv;
}

/// Calls a VimL function.
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

  TRY_WRAP({
    // Initialize `force_abort`  and `suppress_errthrow` at the top level.
    if (!recursive) {
      force_abort = false;
      suppress_errthrow = false;
      current_exception = NULL;
      // `did_emsg` is set by emsg(), which cancels execution.
      did_emsg = false;
    }
    recursive++;
    try_start();
    typval_T rettv;
    funcexe_T funcexe = FUNCEXE_INIT;
    funcexe.firstline = curwin->w_cursor.lnum;
    funcexe.lastline = curwin->w_cursor.lnum;
    funcexe.evaluate = true;
    funcexe.selfdict = self;
    // call_func() retval is deceptive, ignore it.  Instead we set `msg_list`
    // (see above) to capture abort-causing non-exception errors.
    (void)call_func(fn.data, (int)fn.size, &rettv, (int)args.size,
                    vim_args, &funcexe);
    if (!try_end(err)) {
      rv = vim_to_object(&rettv);
    }
    tv_clear(&rettv);
    recursive--;
  });

free_vim_args:
  while (i > 0) {
    tv_clear(&vim_args[--i]);
  }

  return rv;
}

/// Calls a VimL function with the given arguments.
///
/// On execution error: fails with VimL error, updates v:errmsg.
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

/// Calls a VimL |Dictionary-function| with the given arguments.
///
/// On execution error: fails with VimL error, updates v:errmsg.
///
/// @param dict Dictionary, or String evaluating to a VimL |self| dict
/// @param fn Name of the function defined on the VimL dict
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
    if (eval0(dict.data.string.data, &rettv, NULL, true) == FAIL) {
      api_set_error(err, kErrorTypeException,
                    "Failed to evaluate dict expression");
    }
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
      .size = STRLEN(di->di_tv.vval.v_string),
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

/// Parse a VimL expression.
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
      .value = STRING_OBJ(cstr_to_string(east.err.msg)),
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
      chunk_arr.items[3] = STRING_OBJ(cstr_to_string(chunk.group));
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
        size_t items_size = (size_t)(3  // "type", "start" and "len"
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
          .value = STRING_OBJ(cstr_to_string(east_node_type_tab[node->type])),
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
            .value = STRING_OBJ(cstr_to_string(eltkn_cmp_type_tab[node->data.cmp.type])),
          };
          ret_node->items[ret_node->size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("ccs_strategy"),
            .value = STRING_OBJ(cstr_to_string(ccs_tab[node->data.cmp.ccs])),
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

/// Translates and returns allocated user function name.
static String user_function_name(ufunc_T *fp)
{
  String name;
  const size_t name_len = STRLEN(fp->uf_name);
  if (fp->uf_name[0] == K_SPECIAL) {
    // Replace [ K_SPECIAL KS_EXTRA KE_SNR ] with "<SNR>"
    name.size = name_len + 2;
    name.data = xmalloc(name.size + 1);
    name.data[0] = '<';
    name.data[1] = 'S';
    name.data[2] = 'N';
    name.data[3] = 'R';
    name.data[4] = '>';
    memcpy(name.data + 5, fp->uf_name + 3, name_len - 3);
    name.data[name.size] = '\0';
  } else {
    name.size = name_len;
    name.data = xmalloc(name.size + 1);
    memcpy(name.data, fp->uf_name, name_len);
    name.data[name.size] = '\0';
  }
  return name;
}

/// Takes ownership of name.
static Dictionary user_function_dict(ufunc_T *fp, String name, bool details, bool lines)
{
  Dictionary dict = ARRAY_DICT_INIT;
  size_t dict_size = 2;
  if (details) {
    dict_size += 8;
  }
  if (lines) {
    dict_size += 1;
  }
  kv_resize(dict, dict_size);

  // Function name
  dict.items[dict.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("name"),
    .value = STRING_OBJ(name),
  };
  dict.items[dict.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("type"),
    .value = CSTR_TO_OBJ("user"),
  };

  if (details) {
    // Arguments
    Array args = ARRAY_DICT_INIT;
    if (fp->uf_args.ga_len > 0) {
      kv_resize(args, (size_t)fp->uf_args.ga_len);
      for (int j = 0; j < fp->uf_args.ga_len; j++) {
        Dictionary arg = ARRAY_DICT_INIT;
        kv_resize(arg, 2);
        arg.items[arg.size++] = (KeyValuePair) {
          .key = STATIC_CSTR_TO_STRING("name"),
          .value = CSTR_TO_OBJ((const char *)FUNCARG(fp, j)),
        };
        if (j >= fp->uf_args.ga_len - fp->uf_def_args.ga_len) {
          arg.items[arg.size++] = (KeyValuePair) {
            .key = STATIC_CSTR_TO_STRING("default"),
            .value = CSTR_TO_OBJ(((char **)(fp->uf_def_args.ga_data))
                                 [j - fp->uf_args.ga_len + fp->uf_def_args.ga_len]),
          };
        }
        args.items[args.size++] = DICTIONARY_OBJ(arg);
      }
    }
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("args"),
      .value = ARRAY_OBJ(args),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("varargs"),
      .value = BOOLEAN_OBJ(fp->uf_varargs),
    };

    // Attributes
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("abort"),
      .value = BOOLEAN_OBJ(fp->uf_flags & FC_ABORT),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("range"),
      .value = BOOLEAN_OBJ(fp->uf_flags & FC_RANGE),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("dict"),
      .value = BOOLEAN_OBJ(fp->uf_flags & FC_DICT),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("closure"),
      .value = BOOLEAN_OBJ(fp->uf_flags & FC_CLOSURE),
    };

    // Script
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("sid"),
      .value = INTEGER_OBJ(fp->uf_script_ctx.sc_sid),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("lnum"),
      .value = INTEGER_OBJ(fp->uf_script_ctx.sc_lnum),
    };
  }

  // Source lines
  if (lines) {
    Array array = ARRAY_DICT_INIT;
    if (fp->uf_lines.ga_len > 0) {
      kv_resize(array, (size_t)fp->uf_lines.ga_len);
      for (int j = 0; j < fp->uf_lines.ga_len; j++) {
        const char *line = (const char *)FUNCLINE(fp, j);
        if (line != NULL) {
          kv_push(array, CSTR_TO_OBJ(line));
        } else {
          kv_push(array, STRING_OBJ(STATIC_CSTR_TO_STRING("")));
        }
      }
    }
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("lines"),
      .value = ARRAY_OBJ(array),
    };
  }

  return dict;
}

/// Takes ownership of name.
static Dictionary builtin_function_dict(const EvalFuncDef *fn, String name, bool details)
{
  Dictionary dict = ARRAY_DICT_INIT;
  kv_resize(dict, details ? 7 : 2);

  dict.items[dict.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("name"),
    .value = STRING_OBJ(name),
  };
  dict.items[dict.size++] = (KeyValuePair) {
    .key = STATIC_CSTR_TO_STRING("type"),
    .value = CSTR_TO_OBJ("builtin"),
  };

  if (details) {
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("min_argc"),
      .value = INTEGER_OBJ(fn->min_argc),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("max_argc"),
      .value = INTEGER_OBJ(fn->max_argc),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("base_arg"),
      .value = INTEGER_OBJ(fn->base_arg),
    };
    dict.items[dict.size++] = (KeyValuePair) {
      .key = STATIC_CSTR_TO_STRING("fast"),
      .value = BOOLEAN_OBJ(fn->fast),
    };

    if (fn->argnames != NULL) {
      Array overloads = ARRAY_DICT_INIT;
      Array names = ARRAY_DICT_INIT;
      char buf[64] = { 0 };
      size_t pos = 0;

      // Argument are separated with unit separator (ascii \x1F),
      // overloads with record separator (ascii \x1E).
      for (const char *p = fn->argnames;; p++) {
        if (*p == NUL || *p == '\x1F' || *p == '\x1E') {
          assert(pos < 64);
          buf[pos++] = NUL;
          String str = {
            .data = xmemdupz(buf, pos),
            .size = pos - 1,
          };
          pos = 0;

          if (*p == '\x1F') {  // unit separator: argument separator
            kv_push(names, STRING_OBJ(str));
          } else if (*p == '\x1E') {  // record separator: overload separator
            kv_push(names, STRING_OBJ(str));
            kv_push(overloads, ARRAY_OBJ(names));
            names = (Array)ARRAY_DICT_INIT;
          } else {  // NUL
            kv_push(names, STRING_OBJ(str));
            kv_push(overloads, ARRAY_OBJ(names));
            break;
          }
        } else {
          buf[pos++] = *p;
        }
      }

      dict.items[dict.size++] = (KeyValuePair) {
        .key = STATIC_CSTR_TO_STRING("argnames"),
        .value = ARRAY_OBJ(overloads),
      };
    }
  }

  return dict;
}

/// Lists Vimscript functions.
///
/// @param query    When string gets information about the function under this name.
///                 When dictionary lists functions. The following keys are accepted:
///                 - builtin (boolean, default false) Include builtin functions.
///                 - user    (boolean, default true) Include user functions.
/// @param opts     Options dictionary:
///                 - details (boolean) Include function details.
///                 - lines   (boolean) Include user function lines. Ignored for builtin
///                           functions.
/// @param[out] err Error details, if any
/// @return A dictionary describing a function when {query} is a string, or a map of
///         function names to dictionaries describing them when {query} is a dictionary.
Dictionary nvim_get_functions(Object query, Dictionary opts, Error *err)
  FUNC_API_SINCE(10)
{
  Dictionary rv = ARRAY_DICT_INIT;

  if (query.type != kObjectTypeString && query.type != kObjectTypeDictionary
      && (query.type == kObjectTypeArray && query.data.array.size != 0)) {
    api_set_error(err, kErrorTypeValidation, "query is not a dictionary or string %d", query.type);
    return rv;
  }

  bool details = false;
  bool lines = false;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("details", k.data)) {
      if (v->type != kObjectTypeBoolean) {
        api_set_error(err, kErrorTypeValidation, "details is not a boolean");
        return rv;
      }
      details = v->data.boolean;
    } else if (strequal("lines", k.data)) {
      if (v->type != kObjectTypeBoolean) {
        api_set_error(err, kErrorTypeValidation, "lines is not a boolean");
        return rv;
      }
      lines = v->data.boolean;
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return rv;
    }
  }

  // Find function
  if (query.type == kObjectTypeString) {
    String name = query.data.string;
    char_u *func_name;
    if (name.size > 7 && memcmp(name.data, "<SNR>", 5) == 0) {
      func_name = xmalloc(name.size - 1);  // resolve "<SNR>" + 1 null byte
      func_name[0] = K_SPECIAL;
      func_name[1] = KS_EXTRA;
      func_name[2] = KE_SNR;
      memcpy(func_name + 3, name.data + 5, name.size - 5);
      func_name[name.size - 2] = '\0';
    } else {
      func_name = (char_u *)string_to_cstr(name);
    }

    // Find builtin function
    if (func_name[0] != K_SPECIAL) {
      const EvalFuncDef *fn = find_internal_func((char *)func_name);
      if (fn != NULL) {
        rv = builtin_function_dict(fn, copy_string(name), details);
        goto theend;
      }
    }

    // Find user function
    ufunc_T *fp = find_func(func_name);
    if (fp != NULL) {
      rv = user_function_dict(fp, user_function_name(fp), details, lines);
      goto theend;
    }

    xfree(func_name);
    api_set_error(err, kErrorTypeException, "No function with this name");
    return rv;

theend:
    xfree(func_name);
    return rv;
  }

  // Parse list options
  bool builtin = false;
  bool user = true;
  if (query.type == kObjectTypeDictionary) {
    Dictionary list = query.data.dictionary;
    for (size_t i = 0; i < list.size; i++) {
      String k = list.items[i].key;
      Object *v = &list.items[i].value;
      if (strequal("builtin", k.data)) {
        if (v->type != kObjectTypeBoolean) {
          api_set_error(err, kErrorTypeValidation, "builtin is not a boolean");
          return rv;
        }
        builtin = v->data.boolean;
      } else if (strequal("user", k.data)) {
        if (v->type != kObjectTypeBoolean) {
          api_set_error(err, kErrorTypeValidation, "user is not a boolean");
          return rv;
        }
        user = v->data.boolean;
      } else {
        api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
        return rv;
      }
    }
  }

  if (!builtin && !user) {
    api_set_error(err, kErrorTypeValidation, "Nothing to list");
    return rv;
  }

  // Preallocate output array
  size_t size = 0;
  if (builtin) {
    size += builtin_functions_len;
  }
  if (user) {
    size += func_hashtab.ht_used;
  }
  kv_resize(rv, size);

  // List builtin functions
  if (builtin) {
    for (const EvalFuncDef *fn = builtin_functions; fn->name != NULL; fn++) {
      String name = cstr_to_string(fn->name);
      KeyValuePair pair = {
        .key = name,
        .value = DICTIONARY_OBJ(builtin_function_dict(fn, copy_string(name), details)),
      };
      kv_push(rv, pair);
    }
  }

  // List user functions
  if (user) {
    int todo = (int)func_hashtab.ht_used;
    for (hashitem_T *hi = func_hashtab.ht_array; todo > 0; hi++) {
      if (HASHITEM_EMPTY(hi)) {
        continue;
      }
      todo--;
      ufunc_T *fp = HI2UF(hi);

      if (isdigit(*fp->uf_name) || *fp->uf_name == '<') {  // func_name_refcount
        continue;
      }

      String name = user_function_name(fp);
      Dictionary dict = user_function_dict(fp, copy_string(name), details, lines);
      KeyValuePair pair = {
        .key = name,
        .value = DICTIONARY_OBJ(dict),
      };
      kv_push(rv, pair);
    }
  }

  return rv;
}
