#include "tree_sitter/api.h"
#include "./alloc.h"
#include "./tree_cursor.h"
#include "./language.h"
#include "./tree.h"

typedef struct {
  Subtree parent;
  const TSTree *tree;
  Length position;
  uint32_t child_index;
  uint32_t structural_child_index;
  const TSSymbol *alias_sequence;
} CursorChildIterator;

// CursorChildIterator

static inline CursorChildIterator ts_tree_cursor_iterate_children(const TreeCursor *self) {
  TreeCursorEntry *last_entry = array_back(&self->stack);
  if (ts_subtree_child_count(*last_entry->subtree) == 0) {
    return (CursorChildIterator) {NULL_SUBTREE, self->tree, length_zero(), 0, 0, NULL};
  }
  const TSSymbol *alias_sequence = ts_language_alias_sequence(
    self->tree->language,
    last_entry->subtree->ptr->production_id
  );
  return (CursorChildIterator) {
    .tree = self->tree,
    .parent = *last_entry->subtree,
    .position = last_entry->position,
    .child_index = 0,
    .structural_child_index = 0,
    .alias_sequence = alias_sequence,
  };
}

static inline bool ts_tree_cursor_child_iterator_next(CursorChildIterator *self,
                                                      TreeCursorEntry *result,
                                                      bool *visible) {
  if (!self->parent.ptr || self->child_index == self->parent.ptr->child_count) return false;
  const Subtree *child = &self->parent.ptr->children[self->child_index];
  *result = (TreeCursorEntry) {
    .subtree = child,
    .position = self->position,
    .child_index = self->child_index,
    .structural_child_index = self->structural_child_index,
  };
  *visible = ts_subtree_visible(*child);
  bool extra = ts_subtree_extra(*child);
  if (!extra && self->alias_sequence) {
    *visible |= self->alias_sequence[self->structural_child_index];
    self->structural_child_index++;
  }

  self->position = length_add(self->position, ts_subtree_size(*child));
  self->child_index++;

  if (self->child_index < self->parent.ptr->child_count) {
    Subtree next_child = self->parent.ptr->children[self->child_index];
    self->position = length_add(self->position, ts_subtree_padding(next_child));
  }

  return true;
}

// TSTreeCursor - lifecycle

TSTreeCursor ts_tree_cursor_new(TSNode node) {
  TSTreeCursor self = {NULL, NULL, {0, 0}};
  ts_tree_cursor_init((TreeCursor *)&self, node);
  return self;
}

void ts_tree_cursor_reset(TSTreeCursor *_self, TSNode node) {
  ts_tree_cursor_init((TreeCursor *)_self, node);
}

void ts_tree_cursor_init(TreeCursor *self, TSNode node) {
  self->tree = node.tree;
  array_clear(&self->stack);
  array_push(&self->stack, ((TreeCursorEntry) {
    .subtree = (const Subtree *)node.id,
    .position = {
      ts_node_start_byte(node),
      ts_node_start_point(node)
    },
    .child_index = 0,
    .structural_child_index = 0,
  }));
}

void ts_tree_cursor_delete(TSTreeCursor *_self) {
  TreeCursor *self = (TreeCursor *)_self;
  array_delete(&self->stack);
}

// TSTreeCursor - walking the tree

bool ts_tree_cursor_goto_first_child(TSTreeCursor *_self) {
  TreeCursor *self = (TreeCursor *)_self;

  bool did_descend;
  do {
    did_descend = false;

    bool visible;
    TreeCursorEntry entry;
    CursorChildIterator iterator = ts_tree_cursor_iterate_children(self);
    while (ts_tree_cursor_child_iterator_next(&iterator, &entry, &visible)) {
      if (visible) {
        array_push(&self->stack, entry);
        return true;
      }

      if (ts_subtree_visible_child_count(*entry.subtree) > 0) {
        array_push(&self->stack, entry);
        did_descend = true;
        break;
      }
    }
  } while (did_descend);

  return false;
}

int64_t ts_tree_cursor_goto_first_child_for_byte(TSTreeCursor *_self, uint32_t goal_byte) {
  TreeCursor *self = (TreeCursor *)_self;
  uint32_t initial_size = self->stack.size;
  uint32_t visible_child_index = 0;

  bool did_descend;
  do {
    did_descend = false;

    bool visible;
    TreeCursorEntry entry;
    CursorChildIterator iterator = ts_tree_cursor_iterate_children(self);
    while (ts_tree_cursor_child_iterator_next(&iterator, &entry, &visible)) {
      uint32_t end_byte = entry.position.bytes + ts_subtree_size(*entry.subtree).bytes;
      bool at_goal = end_byte > goal_byte;
      uint32_t visible_child_count = ts_subtree_visible_child_count(*entry.subtree);

      if (at_goal) {
        if (visible) {
          array_push(&self->stack, entry);
          return visible_child_index;
        }

        if (visible_child_count > 0) {
          array_push(&self->stack, entry);
          did_descend = true;
          break;
        }
      } else if (visible) {
        visible_child_index++;
      } else {
        visible_child_index += visible_child_count;
      }
    }
  } while (did_descend);

  if (self->stack.size > initial_size &&
      ts_tree_cursor_goto_next_sibling((TSTreeCursor *)self)) {
    return visible_child_index;
  }

  self->stack.size = initial_size;
  return -1;
}

bool ts_tree_cursor_goto_next_sibling(TSTreeCursor *_self) {
  TreeCursor *self = (TreeCursor *)_self;
  uint32_t initial_size = self->stack.size;

  while (self->stack.size > 1) {
    TreeCursorEntry entry = array_pop(&self->stack);
    CursorChildIterator iterator = ts_tree_cursor_iterate_children(self);
    iterator.child_index = entry.child_index;
    iterator.structural_child_index = entry.structural_child_index;
    iterator.position = entry.position;

    bool visible = false;
    ts_tree_cursor_child_iterator_next(&iterator, &entry, &visible);
    if (visible && self->stack.size + 1 < initial_size) break;

    while (ts_tree_cursor_child_iterator_next(&iterator, &entry, &visible)) {
      if (visible) {
        array_push(&self->stack, entry);
        return true;
      }

      if (ts_subtree_visible_child_count(*entry.subtree)) {
        array_push(&self->stack, entry);
        ts_tree_cursor_goto_first_child(_self);
        return true;
      }
    }
  }

  self->stack.size = initial_size;
  return false;
}

bool ts_tree_cursor_goto_parent(TSTreeCursor *_self) {
  TreeCursor *self = (TreeCursor *)_self;
  for (unsigned i = self->stack.size - 2; i + 1 > 0; i--) {
    TreeCursorEntry *entry = &self->stack.contents[i];
    bool is_aliased = false;
    if (i > 0) {
      TreeCursorEntry *parent_entry = &self->stack.contents[i - 1];
      const TSSymbol *alias_sequence = ts_language_alias_sequence(
        self->tree->language,
        parent_entry->subtree->ptr->production_id
      );
      is_aliased = alias_sequence && alias_sequence[entry->structural_child_index];
    }
    if (ts_subtree_visible(*entry->subtree) || is_aliased) {
      self->stack.size = i + 1;
      return true;
    }
  }
  return false;
}

TSNode ts_tree_cursor_current_node(const TSTreeCursor *_self) {
  const TreeCursor *self = (const TreeCursor *)_self;
  TreeCursorEntry *last_entry = array_back(&self->stack);
  TSSymbol alias_symbol = 0;
  if (self->stack.size > 1) {
    TreeCursorEntry *parent_entry = &self->stack.contents[self->stack.size - 2];
    const TSSymbol *alias_sequence = ts_language_alias_sequence(
      self->tree->language,
      parent_entry->subtree->ptr->production_id
    );
    if (alias_sequence && !ts_subtree_extra(*last_entry->subtree)) {
      alias_symbol = alias_sequence[last_entry->structural_child_index];
    }
  }
  return ts_node_new(
    self->tree,
    last_entry->subtree,
    last_entry->position,
    alias_symbol
  );
}

TSFieldId ts_tree_cursor_current_field_id(const TSTreeCursor *_self) {
  const TreeCursor *self = (const TreeCursor *)_self;

  // Walk up the tree, visiting the current node and its invisible ancestors.
  for (unsigned i = self->stack.size - 1; i > 0; i--) {
    TreeCursorEntry *entry = &self->stack.contents[i];
    TreeCursorEntry *parent_entry = &self->stack.contents[i - 1];

    // Stop walking up when another visible node is found.
    if (i != self->stack.size - 1) {
      if (ts_subtree_visible(*entry->subtree)) break;
      const TSSymbol *alias_sequence = ts_language_alias_sequence(
        self->tree->language,
        parent_entry->subtree->ptr->production_id
      );
      if (alias_sequence && alias_sequence[entry->structural_child_index]) {
        break;
      }
    }

    const TSFieldMapEntry *field_map, *field_map_end;
    ts_language_field_map(
      self->tree->language,
      parent_entry->subtree->ptr->production_id,
      &field_map, &field_map_end
    );

    while (field_map < field_map_end) {
      if (
        !field_map->inherited &&
        field_map->child_index == entry->structural_child_index
      ) return field_map->field_id;
      field_map++;
    }
  }
  return 0;
}

const char *ts_tree_cursor_current_field_name(const TSTreeCursor *_self) {
  TSFieldId id = ts_tree_cursor_current_field_id(_self);
  if (id) {
    const TreeCursor *self = (const TreeCursor *)_self;
    return self->tree->language->field_names[id];
  } else {
    return NULL;
  }
}

TSTreeCursor ts_tree_cursor_copy(const TSTreeCursor *_cursor) {
  const TreeCursor *cursor = (const TreeCursor *)_cursor;
  TSTreeCursor res = {NULL, NULL, {0, 0}};
  TreeCursor *copy = (TreeCursor *)&res;
  copy->tree = cursor->tree;
  array_push_all(&copy->stack, &cursor->stack);
  return res;
}
