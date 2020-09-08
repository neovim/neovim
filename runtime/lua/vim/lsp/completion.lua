local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'

--[==[
see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion

export interface CompletionItem {
    /**
     * The label of this completion item. By default
     * also the text that is inserted when selecting
     * this completion.
     */
    label: string;

    /**
     * The kind of this completion item. Based of the kind
     * an icon is chosen by the editor. The standardized set
     * of available values is defined in `CompletionItemKind`.
     */
    kind?: number;

    TODO: Handle tags
    /**
     * Tags for this completion item.
     *
     * @since 3.15.0
     */
    tags?: CompletionItemTag[];

    /**
     * A human-readable string with additional information
     * about this item, like type or symbol information.
     */
    detail?: string;

    /**
     * A human-readable string that represents a doc-comment.
     */
    documentation?: string | MarkupContent;

    TODO: Handle preselect.
    /**
     * Select this item when showing.
     *
     * *Note* that only one completion item can be selected and that the
     * tool / client decides which item that is. The rule is that the *first*
     * item of those that match best is selected.
     */
    preselect?: boolean;

    /**
     * A string that should be used when comparing this item
     * with other items. When `falsy` the label is used.
     */
    sortText?: string;

    /**
     * A string that should be used when filtering a set of
     * completion items. When `falsy` the label is used.
     */
    filterText?: string;

    /**
     * A string that should be inserted into a document when selecting
     * this completion. When `falsy` the label is used.
     *
     * The `insertText` is subject to interpretation by the client side.
     * Some tools might not take the string literally. For example
     * VS Code when code complete is requested in this example `con<cursor position>`
     * and a completion item with an `insertText` of `console` is provided it
     * will only insert `sole`. Therefore it is recommended to use `textEdit` instead
     * since it avoids additional client side interpretation.
     */
    insertText?: string;

    /**
     * The format of the insert text. The format applies to both the `insertText` property
     * and the `newText` property of a provided `textEdit`. If omitted defaults to
     * `InsertTextFormat.PlainText`.
     */
    insertTextFormat?: InsertTextFormat;

    /**
     * An edit which is applied to a document when selecting this completion. When an edit is provided the value of
     * `insertText` is ignored.
     *
     * *Note:* The range of the edit must be a single line range and it must contain the position at which completion
     * has been requested.
     */
    textEdit?: TextEdit;

    TODO: Handle additionalTextEdits
    /**
     * An optional array of additional text edits that are applied when
     * selecting this completion. Edits must not overlap (including the same insert position)
     * with the main edit nor with themselves.
     *
     * Additional text edits should be used to change text unrelated to the current cursor position
     * (for example adding an import statement at the top of the file if the completion item will
     * insert an unqualified type).
     */
    additionalTextEdits?: TextEdit[];

    TODO: Handle commitCharacters
    /**
     * An optional set of characters that when pressed while this completion is active will accept it first and
     * then type that character. *Note* that all commit characters should have `length=1` and that superfluous
     * characters will be ignored.
     */
    commitCharacters?: string[];

    TODO: Handle command
    /**
     * An optional command that is executed *after* inserting this completion. *Note* that
     * additional modifications to the current document should be described with the
     * additionalTextEdits-property.
     */
    command?: Command;

    TODO: Handle data
    /**
     * A data entry field that is preserved on a completion item between
     * a completion and a completion resolve request.
     */
    data?: any
}
--]==]

local completion = {}

--- Extract the completion items from a `textDocument/completion` request
--@param result (table) The result of a `textDocument/completion` request
--@returns (table) CompletionItem[]
function completion.extract_completion_items(result)
  if type(result) == 'table' and result.items then
    -- `CompletionList`
    return result.items
  elseif result ~= nil then
    -- `CompletionItem[]`
    return result
  else
    -- result is `null`
    return {}
  end
end

--- Sorts by CompletionItem.sortText.
--@note: This sorts in-place.
function completion.sort_completion_items(items)
  -- TODO: perhaps we don't handle `falsy` values well here.

  table.sort(items, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)

  return items
end

--- Some language servers return complementary candidates whose prefixes do not
--- match are also returned. So we exclude completion candidates whose prefix
--- does not match.
function completion.remove_unmatch_completion_items(items, prefix)
  return vim.tbl_filter(function(item)
    local word = item.filterText or completion.get_completion_word(item, prefix)
    return vim.startswith(word, prefix)
  end, items)
end

--- Returns text that should be inserted when selecting completion item.
---
--- The precedence is as follows:
---     textEdit.newText > insertText > label
function completion.get_completion_word(item, prefix)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil then
    local start_range = item.textEdit.range["start"]
    local end_range = item.textEdit.range["end"]
    local newText = item.textEdit.newText
    if start_range.line == end_range.line and start_range.character == end_range.character then
      newText = prefix .. newText
    end

    if protocol.InsertTextFormat.PlainText == item.insertTextFormat then
      return newText
    else
      return util.parse_snippet(newText)
    end
  elseif item.insertText ~= nil then
    if protocol.InsertTextFormat.PlainText == item.insertTextFormat then
      return item.insertText
    else
      return util.parse_snippet(item.insertText)
    end
  else
    return item.label or ''
  end
end


-- Private


--- Acording to LSP spec, if the client set `completionItemKind.valueSet`,
--- the client must handle it properly even if it receives a value outside the
--- specification.
---
--@param completion_item_kind (`vim.lsp.protocol.completionItemKind`)
--@returns (`vim.lsp.protocol.completionItemKind`)
function completion._get_completion_item_kind_name(completion_item_kind)
  return protocol.CompletionItemKind[completion_item_kind] or "Unknown"
end

--- Turns the result of a `textDocument/completion` request into vim-compatible
--- |complete-items|.
---
--@param result The result of a `textDocument/completion` call, e.g. from
---|vim.lsp.buf.completion()|, which may be one of `CompletionItem[]`,
--- `CompletionList` or `null`
--@param prefix (string) the prefix to filter the completion items
--@returns { matches = complete-items table, incomplete = bool }
--@see |complete-items|
function completion.completion_list_to_complete_items(result, prefix)
  local items = completion.extract_completion_items(result)
  if vim.tbl_isempty(items) then
    return {}
  end

  items = completion.remove_unmatch_completion_items(items, prefix)
  items = completion.sort_completion_items(items)

  local matches = {}

  for _, completion_item in ipairs(items) do
    local info = ' '
    local documentation = completion_item.documentation
    if documentation then
      if type(documentation) == 'string' and documentation ~= '' then
        info = documentation
      elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
        info = documentation.value
      -- else
        -- TODO(ashkan) Validation handling here?
      end
    end

    local word = completion.get_completion_word(completion_item, prefix)
    table.insert(matches, {
      word = word,
      abbr = completion_item.label,
      kind = completion._get_completion_item_kind_name(completion_item.kind),
      menu = completion_item.detail or '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = {
        nvim = {
          lsp = {
            completion_item = completion_item
          }
        }
      },
    })
  end

  return matches
end


return completion
