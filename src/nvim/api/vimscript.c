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

#define IS_USER_CMDIDX(idx) ((int)(idx) < 0)

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

/// Parse command line.
///
/// Doesn't check the validity of command arguments.
///
/// @param str       Command line string to parse. Cannot contain "\n".
/// @param opts      Optional parameters. Reserved for future use.
/// @param[out] err  Error details, if any.
/// @return Dictionary containing command information, with these keys:
///         - cmd: (string) Command name.
///         - range: (array) Command <range>. Can have 0-2 elements depending on how many items the
///                          range contains. Has no elements if command doesn't accept a range or if
///                          no range was specified, one element if only a single range item was
///                          specified and two elements if both range items were specified.
///         - count: (number) Any |<count>| that was supplied to the command. -1 if command cannot
///                           take a count.
///         - reg: (number) The optional command |<register>|, if specified. Empty string if not
///                         specified or if command cannot take a register.
///         - bang: (boolean) Whether command contains a |<bang>| (!) modifier.
///         - args: (array) Command arguments.
///         - addr: (string) Value of |:command-addr|. Uses short name.
///         - nargs: (string) Value of |:command-nargs|.
///         - nextcmd: (string) Next command if there are multiple commands separated by a |:bar|.
///                             Empty if there isn't a next command.
///         - magic: (dictionary) Which characters have special meaning in the command arguments.
///             - file: (boolean) The command expands filenames. Which means characters such as "%",
///                               "#" and wildcards are expanded.
///             - bar: (boolean) The "|" character is treated as a command separator and the double
///                              quote character (\") is treated as the start of a comment.
///         - mods: (dictionary) |:command-modifiers|.
///             - silent: (boolean) |:silent|.
///             - emsg_silent: (boolean) |:silent!|.
///             - sandbox: (boolean) |:sandbox|.
///             - noautocmd: (boolean) |:noautocmd|.
///             - browse: (boolean) |:browse|.
///             - confirm: (boolean) |:confirm|.
///             - hide: (boolean) |:hide|.
///             - keepalt: (boolean) |:keepalt|.
///             - keepjumps: (boolean) |:keepjumps|.
///             - keepmarks: (boolean) |:keepmarks|.
///             - keeppatterns: (boolean) |:keeppatterns|.
///             - lockmarks: (boolean) |:lockmarks|.
///             - noswapfile: (boolean) |:noswapfile|.
///             - tab: (integer) |:tab|.
///             - verbose: (integer) |:verbose|. -1 when omitted.
///             - vertical: (boolean) |:vertical|.
///             - split: (string) Split modifier string, is an empty string when there's no split
///                               modifier. If there is a split modifier it can be one of:
///               - "aboveleft": |:aboveleft|.
///               - "belowright": |:belowright|.
///               - "topleft": |:topleft|.
///               - "botright": |:botright|.
Dictionary nvim_parse_cmd(String str, Dictionary opts, Error *err)
  FUNC_API_SINCE(10) FUNC_API_FAST
{
  Dictionary result = ARRAY_DICT_INIT;

  if (opts.size > 0) {
    api_set_error(err, kErrorTypeValidation, "opts dict isn't empty");
    return result;
  }

  // Parse command line
  exarg_T ea;
  CmdParseInfo cmdinfo;
  char *cmdline = string_to_cstr(str);
  char *errormsg = NULL;

  if (!parse_cmdline(cmdline, &ea, &cmdinfo, &errormsg)) {
    if (errormsg != NULL) {
      api_set_error(err, kErrorTypeException, "Error while parsing command line: %s", errormsg);
    } else {
      api_set_error(err, kErrorTypeException, "Error while parsing command line");
    }
    goto end;
  }

  // Parse arguments
  Array args = ARRAY_DICT_INIT;
  size_t length = STRLEN(ea.arg);

  // For nargs = 1 or '?', pass the entire argument list as a single argument,
  // otherwise split arguments by whitespace.
  if (ea.argt & EX_NOSPC) {
    if (*ea.arg != NUL) {
      ADD(args, STRING_OBJ(cstrn_to_string((char *)ea.arg, length)));
    }
  } else {
    size_t end = 0;
    size_t len = 0;
    char *buf = xcalloc(length, sizeof(char));
    bool done = false;

    while (!done) {
      done = uc_split_args_iter(ea.arg, length, &end, buf, &len);
      if (len > 0) {
        ADD(args, STRING_OBJ(cstrn_to_string(buf, len)));
      }
    }

    xfree(buf);
  }

  ucmd_T *cmd = NULL;
  if (ea.cmdidx == CMD_USER) {
    cmd = USER_CMD(ea.useridx);
  } else if (ea.cmdidx == CMD_USER_BUF) {
    cmd = USER_CMD_GA(&curbuf->b_ucmds, ea.useridx);
  }

  if (cmd != NULL) {
    PUT(result, "cmd", CSTR_TO_OBJ((char *)cmd->uc_name));
  } else {
    PUT(result, "cmd", CSTR_TO_OBJ((char *)get_command_name(NULL, ea.cmdidx)));
  }

  if ((ea.argt & EX_RANGE) && ea.addr_count > 0) {
    Array range = ARRAY_DICT_INIT;
    if (ea.addr_count > 1) {
      ADD(range, INTEGER_OBJ(ea.line1));
    }
    ADD(range, INTEGER_OBJ(ea.line2));
    PUT(result, "range", ARRAY_OBJ(range));
  } else {
    PUT(result, "range", ARRAY_OBJ(ARRAY_DICT_INIT));
  }

  if (ea.argt & EX_COUNT) {
    if (ea.addr_count > 0) {
      PUT(result, "count", INTEGER_OBJ(ea.line2));
    } else if (cmd != NULL) {
      PUT(result, "count", INTEGER_OBJ(cmd->uc_def));
    } else {
      PUT(result, "count", INTEGER_OBJ(0));
    }
  } else {
    PUT(result, "count", INTEGER_OBJ(-1));
  }

  char reg[2];
  reg[0] = (char)ea.regname;
  reg[1] = '\0';
  PUT(result, "reg", CSTR_TO_OBJ(reg));

  PUT(result, "bang", BOOLEAN_OBJ(ea.forceit));
  PUT(result, "args", ARRAY_OBJ(args));

  char nargs[2];
  if (ea.argt & EX_EXTRA) {
    if (ea.argt & EX_NOSPC) {
      if (ea.argt & EX_NEEDARG) {
        nargs[0] = '1';
      } else {
        nargs[0] = '?';
      }
    } else if (ea.argt & EX_NEEDARG) {
      nargs[0] = '+';
    } else {
      nargs[0] = '*';
    }
  } else {
    nargs[0] = '0';
  }
  nargs[1] = '\0';
  PUT(result, "nargs", CSTR_TO_OBJ(nargs));

  const char *addr;
  switch (ea.addr_type) {
  case ADDR_LINES:
    addr = "line";
    break;
  case ADDR_ARGUMENTS:
    addr = "arg";
    break;
  case ADDR_BUFFERS:
    addr = "buf";
    break;
  case ADDR_LOADED_BUFFERS:
    addr = "load";
    break;
  case ADDR_WINDOWS:
    addr = "win";
    break;
  case ADDR_TABS:
    addr = "tab";
    break;
  case ADDR_QUICKFIX:
    addr = "qf";
    break;
  case ADDR_NONE:
    addr = "none";
    break;
  default:
    addr = "?";
    break;
  }
  PUT(result, "addr", CSTR_TO_OBJ(addr));
  PUT(result, "nextcmd", CSTR_TO_OBJ((char *)ea.nextcmd));

  Dictionary mods = ARRAY_DICT_INIT;
  PUT(mods, "silent", BOOLEAN_OBJ(cmdinfo.silent));
  PUT(mods, "emsg_silent", BOOLEAN_OBJ(cmdinfo.emsg_silent));
  PUT(mods, "sandbox", BOOLEAN_OBJ(cmdinfo.sandbox));
  PUT(mods, "noautocmd", BOOLEAN_OBJ(cmdinfo.noautocmd));
  PUT(mods, "tab", INTEGER_OBJ(cmdinfo.cmdmod.tab));
  PUT(mods, "verbose", INTEGER_OBJ(cmdinfo.verbose));
  PUT(mods, "browse", BOOLEAN_OBJ(cmdinfo.cmdmod.browse));
  PUT(mods, "confirm", BOOLEAN_OBJ(cmdinfo.cmdmod.confirm));
  PUT(mods, "hide", BOOLEAN_OBJ(cmdinfo.cmdmod.hide));
  PUT(mods, "keepalt", BOOLEAN_OBJ(cmdinfo.cmdmod.keepalt));
  PUT(mods, "keepjumps", BOOLEAN_OBJ(cmdinfo.cmdmod.keepjumps));
  PUT(mods, "keepmarks", BOOLEAN_OBJ(cmdinfo.cmdmod.keepmarks));
  PUT(mods, "keeppatterns", BOOLEAN_OBJ(cmdinfo.cmdmod.keeppatterns));
  PUT(mods, "lockmarks", BOOLEAN_OBJ(cmdinfo.cmdmod.lockmarks));
  PUT(mods, "noswapfile", BOOLEAN_OBJ(cmdinfo.cmdmod.noswapfile));
  PUT(mods, "vertical", BOOLEAN_OBJ(cmdinfo.cmdmod.split & WSP_VERT));

  const char *split;
  if (cmdinfo.cmdmod.split & WSP_BOT) {
    split = "botright";
  } else if (cmdinfo.cmdmod.split & WSP_TOP) {
    split = "topleft";
  } else if (cmdinfo.cmdmod.split & WSP_BELOW) {
    split = "belowright";
  } else if (cmdinfo.cmdmod.split & WSP_ABOVE) {
    split = "aboveleft";
  } else {
    split = "";
  }
  PUT(mods, "split", CSTR_TO_OBJ(split));

  PUT(result, "mods", DICTIONARY_OBJ(mods));

  Dictionary magic = ARRAY_DICT_INIT;
  PUT(magic, "file", BOOLEAN_OBJ(cmdinfo.magic.file));
  PUT(magic, "bar", BOOLEAN_OBJ(cmdinfo.magic.bar));
  PUT(result, "magic", DICTIONARY_OBJ(magic));
end:
  xfree(cmdline);
  return result;
}

/// Executes an Ex command.
///
/// Unlike |nvim_command()| this command takes a structured Dictionary instead of a String. This
/// allows for easier construction and manipulation of an Ex command. This also allows for things
/// such as having spaces inside a command argument, expanding filenames in a command that otherwise
/// doesn't expand filenames, etc.
///
/// On execution error: fails with VimL error, updates v:errmsg.
///
/// @see |nvim_exec()|
/// @see |nvim_command()|
///
/// @param cmd       Command to execute. Must be a Dictionary that can contain the same values as
///                  the return value of |nvim_parse_cmd()| except "addr", "nargs" and "nextcmd"
///                  which are ignored if provided. All values except for "cmd" are optional.
/// @param opts      Optional parameters.
///                  - output: (boolean, default false) Whether to return command output.
/// @param[out] err  Error details, if any.
/// @return Command output (non-error, non-shell |:!|) if `output` is true, else empty string.
String nvim_cmd(uint64_t channel_id, Dict(cmd) *cmd, Dict(cmd_opts) *opts, Error *err)
  FUNC_API_SINCE(10)
{
  exarg_T ea;
  memset(&ea, 0, sizeof(ea));
  ea.verbose_save = -1;
  ea.save_msg_silent = -1;

  CmdParseInfo cmdinfo;
  memset(&cmdinfo, 0, sizeof(cmdinfo));
  cmdinfo.verbose = -1;

  char *cmdline = NULL;
  char *cmdname = NULL;
  char **args = NULL;
  size_t argc = 0;

  String retv = (String)STRING_INIT;

#define OBJ_TO_BOOL(var, value, default, varname) \
  do { \
    var = api_object_to_bool(value, varname, default, err); \
    if (ERROR_SET(err)) { \
      goto end; \
    } \
  } while (0)

#define VALIDATION_ERROR(...) \
  do { \
    api_set_error(err, kErrorTypeValidation, __VA_ARGS__); \
    goto end; \
  } while (0)

  bool output;
  OBJ_TO_BOOL(output, opts->output, false, "'output'");

  // First, parse the command name and check if it exists and is valid.
  if (!HAS_KEY(cmd->cmd) || cmd->cmd.type != kObjectTypeString
      || cmd->cmd.data.string.data[0] == NUL) {
    VALIDATION_ERROR("'cmd' must be a non-empty String");
  }

  cmdname = string_to_cstr(cmd->cmd.data.string);
  ea.cmd = cmdname;

  char *p = find_ex_command(&ea, NULL);

  // If this looks like an undefined user command and there are CmdUndefined
  // autocommands defined, trigger the matching autocommands.
  if (p != NULL && ea.cmdidx == CMD_SIZE && ASCII_ISUPPER(*ea.cmd)
      && has_event(EVENT_CMDUNDEFINED)) {
    p = xstrdup(cmdname);
    int ret = apply_autocmds(EVENT_CMDUNDEFINED, p, p, true, NULL);
    xfree(p);
    // If the autocommands did something and didn't cause an error, try
    // finding the command again.
    p = (ret && !aborting()) ? find_ex_command(&ea, NULL) : ea.cmd;
  }

  if (p == NULL || ea.cmdidx == CMD_SIZE) {
    VALIDATION_ERROR("Command not found: %s", cmdname);
  }
  if (is_cmd_ni(ea.cmdidx)) {
    VALIDATION_ERROR("Command not implemented: %s", cmdname);
  }

  // Get the command flags so that we can know what type of arguments the command uses.
  // Not required for a user command since `find_ex_command` already deals with it in that case.
  if (!IS_USER_CMDIDX(ea.cmdidx)) {
    ea.argt = get_cmd_argt(ea.cmdidx);
  }

  // Parse command arguments since it's needed to get the command address type.
  if (HAS_KEY(cmd->args)) {
    if (cmd->args.type != kObjectTypeArray) {
      VALIDATION_ERROR("'args' must be an Array");
    }
    // Check if every argument is valid
    for (size_t i = 0; i < cmd->args.data.array.size; i++) {
      Object elem = cmd->args.data.array.items[i];
      if (elem.type != kObjectTypeString) {
        VALIDATION_ERROR("Command argument must be a String");
      } else if (string_iswhite(elem.data.string)) {
        VALIDATION_ERROR("Command argument must have non-whitespace characters");
      }
    }

    argc = cmd->args.data.array.size;
    bool argc_valid;

    // Check if correct number of arguments is used.
    switch (ea.argt & (EX_EXTRA | EX_NOSPC | EX_NEEDARG)) {
    case EX_EXTRA | EX_NOSPC | EX_NEEDARG:
      argc_valid = argc == 1;
      break;
    case EX_EXTRA | EX_NOSPC:
      argc_valid = argc <= 1;
      break;
    case EX_EXTRA | EX_NEEDARG:
      argc_valid = argc >= 1;
      break;
    case EX_EXTRA:
      argc_valid = true;
      break;
    default:
      argc_valid = argc == 0;
      break;
    }

    if (!argc_valid) {
      argc = 0;  // Ensure that args array isn't erroneously freed at the end.
      VALIDATION_ERROR("Incorrect number of arguments supplied");
    }

    if (argc != 0) {
      args = xcalloc(argc, sizeof(char *));

      for (size_t i = 0; i < argc; i++) {
        args[i] = string_to_cstr(cmd->args.data.array.items[i].data.string);
      }
    }
  }

  // Simply pass the first argument (if it exists) as the arg pointer to `set_cmd_addr_type()`
  // since it only ever checks the first argument.
  set_cmd_addr_type(&ea, argc > 0 ? (char_u *)args[0] : NULL);

  if (HAS_KEY(cmd->range)) {
    if (!(ea.argt & EX_RANGE)) {
      VALIDATION_ERROR("Command cannot accept a range");
    } else if (cmd->range.type != kObjectTypeArray) {
      VALIDATION_ERROR("'range' must be an Array");
    } else if (cmd->range.data.array.size > 2) {
      VALIDATION_ERROR("'range' cannot contain more than two elements");
    }

    Array range = cmd->range.data.array;
    ea.addr_count = (int)range.size;

    for (size_t i = 0; i < range.size; i++) {
      Object elem = range.items[i];
      if (elem.type != kObjectTypeInteger || elem.data.integer < 0) {
        VALIDATION_ERROR("'range' element must be a non-negative Integer");
      }
    }

    if (range.size > 0) {
      ea.line1 = range.items[0].data.integer;
      ea.line2 = range.items[range.size - 1].data.integer;
    }

    if (invalid_range(&ea) != NULL) {
      VALIDATION_ERROR("Invalid range provided");
    }
  }
  if (ea.addr_count == 0) {
    if (ea.argt & EX_DFLALL) {
      set_cmd_dflall_range(&ea);  // Default range for range=%
    } else {
      ea.line1 = ea.line2 = get_cmd_default_range(&ea);  // Default range.

      if (ea.addr_type == ADDR_OTHER) {
        // Default is 1, not cursor.
        ea.line2 = 1;
      }
    }
  }

  if (HAS_KEY(cmd->count)) {
    if (!(ea.argt & EX_COUNT)) {
      VALIDATION_ERROR("Command cannot accept a count");
    } else if (cmd->count.type != kObjectTypeInteger || cmd->count.data.integer < 0) {
      VALIDATION_ERROR("'count' must be a non-negative Integer");
    }
    set_cmd_count(&ea, cmd->count.data.integer, true);
  }

  if (HAS_KEY(cmd->reg)) {
    if (!(ea.argt & EX_REGSTR)) {
      VALIDATION_ERROR("Command cannot accept a register");
    } else if (cmd->reg.type != kObjectTypeString || cmd->reg.data.string.size != 1) {
      VALIDATION_ERROR("'reg' must be a single character");
    }
    char regname = cmd->reg.data.string.data[0];
    if (regname == '=') {
      VALIDATION_ERROR("Cannot use register \"=");
    } else if (!valid_yank_reg(regname, ea.cmdidx != CMD_put && !IS_USER_CMDIDX(ea.cmdidx))) {
      VALIDATION_ERROR("Invalid register: \"%c", regname);
    }
    ea.regname = (uint8_t)regname;
  }

  OBJ_TO_BOOL(ea.forceit, cmd->bang, false, "'bang'");
  if (ea.forceit && !(ea.argt & EX_BANG)) {
    VALIDATION_ERROR("Command cannot accept a bang");
  }

  if (HAS_KEY(cmd->magic)) {
    if (cmd->magic.type != kObjectTypeDictionary) {
      VALIDATION_ERROR("'magic' must be a Dictionary");
    }

    Dict(cmd_magic) magic = { 0 };
    if (!api_dict_to_keydict(&magic, KeyDict_cmd_magic_get_field,
                             cmd->magic.data.dictionary, err)) {
      goto end;
    }

    OBJ_TO_BOOL(cmdinfo.magic.file, magic.file, ea.argt & EX_XFILE, "'magic.file'");
    OBJ_TO_BOOL(cmdinfo.magic.bar, magic.bar, ea.argt & EX_TRLBAR, "'magic.bar'");
  } else {
    cmdinfo.magic.file = ea.argt & EX_XFILE;
    cmdinfo.magic.bar = ea.argt & EX_TRLBAR;
  }

  if (HAS_KEY(cmd->mods)) {
    if (cmd->mods.type != kObjectTypeDictionary) {
      VALIDATION_ERROR("'mods' must be a Dictionary");
    }

    Dict(cmd_mods) mods = { 0 };
    if (!api_dict_to_keydict(&mods, KeyDict_cmd_mods_get_field, cmd->mods.data.dictionary, err)) {
      goto end;
    }

    if (HAS_KEY(mods.tab)) {
      if (mods.tab.type != kObjectTypeInteger || mods.tab.data.integer < 0) {
        VALIDATION_ERROR("'mods.tab' must be a non-negative Integer");
      }
      cmdinfo.cmdmod.tab = (int)mods.tab.data.integer + 1;
    }

    if (HAS_KEY(mods.verbose)) {
      if (mods.verbose.type != kObjectTypeInteger || mods.verbose.data.integer <= 0) {
        VALIDATION_ERROR("'mods.verbose' must be a non-negative Integer");
      }
      cmdinfo.verbose = mods.verbose.data.integer;
    }

    bool vertical;
    OBJ_TO_BOOL(vertical, mods.vertical, false, "'mods.vertical'");
    cmdinfo.cmdmod.split |= (vertical ? WSP_VERT : 0);

    if (HAS_KEY(mods.split)) {
      if (mods.split.type != kObjectTypeString) {
        VALIDATION_ERROR("'mods.split' must be a String");
      }

      if (STRCMP(mods.split.data.string.data, "aboveleft") == 0
          || STRCMP(mods.split.data.string.data, "leftabove") == 0) {
        cmdinfo.cmdmod.split |= WSP_ABOVE;
      } else if (STRCMP(mods.split.data.string.data, "belowright") == 0
                 || STRCMP(mods.split.data.string.data, "rightbelow") == 0) {
        cmdinfo.cmdmod.split |= WSP_BELOW;
      } else if (STRCMP(mods.split.data.string.data, "topleft") == 0) {
        cmdinfo.cmdmod.split |= WSP_TOP;
      } else if (STRCMP(mods.split.data.string.data, "botright") == 0) {
        cmdinfo.cmdmod.split |= WSP_BOT;
      } else {
        VALIDATION_ERROR("Invalid value for 'mods.split'");
      }
    }

    OBJ_TO_BOOL(cmdinfo.silent, mods.silent, false, "'mods.silent'");
    OBJ_TO_BOOL(cmdinfo.emsg_silent, mods.emsg_silent, false, "'mods.emsg_silent'");
    OBJ_TO_BOOL(cmdinfo.sandbox, mods.sandbox, false, "'mods.sandbox'");
    OBJ_TO_BOOL(cmdinfo.noautocmd, mods.noautocmd, false, "'mods.noautocmd'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.browse, mods.browse, false, "'mods.browse'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.confirm, mods.confirm, false, "'mods.confirm'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.hide, mods.hide, false, "'mods.hide'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.keepalt, mods.keepalt, false, "'mods.keepalt'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.keepjumps, mods.keepjumps, false, "'mods.keepjumps'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.keepmarks, mods.keepmarks, false, "'mods.keepmarks'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.keeppatterns, mods.keeppatterns, false, "'mods.keeppatterns'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.lockmarks, mods.lockmarks, false, "'mods.lockmarks'");
    OBJ_TO_BOOL(cmdinfo.cmdmod.noswapfile, mods.noswapfile, false, "'mods.noswapfile'");

    if (cmdinfo.sandbox && !(ea.argt & EX_SBOXOK)) {
      VALIDATION_ERROR("Command cannot be run in sandbox");
    }
  }

  // Finally, build the command line string that will be stored inside ea.cmdlinep.
  // This also sets the values of ea.cmd, ea.arg, ea.args and ea.arglens.
  build_cmdline_str(&cmdline, &ea, &cmdinfo, args, argc);
  ea.cmdlinep = &cmdline;

  garray_T capture_local;
  const int save_msg_silent = msg_silent;
  garray_T * const save_capture_ga = capture_ga;

  if (output) {
    ga_init(&capture_local, 1, 80);
    capture_ga = &capture_local;
  }

  TRY_WRAP({
    try_start();
    if (output) {
      msg_silent++;
    }

    WITH_SCRIPT_CONTEXT(channel_id, {
      execute_cmd(&ea, &cmdinfo);
    });

    if (output) {
      capture_ga = save_capture_ga;
      msg_silent = save_msg_silent;
    }

    try_end(err);
  });

  if (ERROR_SET(err)) {
    goto clear_ga;
  }

  if (output && capture_local.ga_len > 1) {
    retv = (String){
      .data = capture_local.ga_data,
      .size = (size_t)capture_local.ga_len,
    };
    // redir usually (except :echon) prepends a newline.
    if (retv.data[0] == '\n') {
      memmove(retv.data, retv.data + 1, retv.size - 1);
      retv.data[retv.size - 1] = '\0';
      retv.size = retv.size - 1;
    }
    goto end;
  }
clear_ga:
  if (output) {
    ga_clear(&capture_local);
  }
end:
  xfree(cmdline);
  xfree(cmdname);
  xfree(ea.args);
  xfree(ea.arglens);
  for (size_t i = 0; i < argc; i++) {
    xfree(args[i]);
  }
  xfree(args);

  return retv;

#undef OBJ_TO_BOOL
#undef VALIDATION_ERROR
}
