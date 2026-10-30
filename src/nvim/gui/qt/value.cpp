#include "value.h"

#include "nvim/gui/bridge.h"

namespace biscide::mp {

std::optional<int64_t> Value::as_int() const {
  if (auto i = std::get_if<int64_t>(&v)) return *i;
  if (auto u = std::get_if<uint64_t>(&v)) return static_cast<int64_t>(*u);
  if (auto d = std::get_if<double>(&v)) return static_cast<int64_t>(*d);
  return std::nullopt;
}

std::optional<bool> Value::as_bool() const {
  if (auto b = std::get_if<bool>(&v)) return *b;
  return std::nullopt;
}

const Value* Value::get(const std::string& key) const {
  auto m = as_map();
  if (!m) return nullptr;
  for (auto& [k, val] : *m)
    if (auto s = k.as_str(); s && *s == key) return &val;
  return nullptr;
}

const Value* Value::at(size_t i) const {
  auto a = as_array();
  return a && i < a->size() ? &(*a)[i] : nullptr;
}

Value from_bridge(const GuiValue& g) {
  switch (g.type) {
    case kGuiBool: return g.data.boolean;
    case kGuiInt: return static_cast<int64_t>(g.data.integer);
    case kGuiFloat: return g.data.floating;
    case kGuiString: return std::string(g.data.string.data, g.data.string.size);
    case kGuiArray: {
      Array a;
      a.reserve(g.data.array.size);
      for (size_t i = 0; i < g.data.array.size; i++) a.push_back(from_bridge(g.data.array.items[i]));
      return a;
    }
    case kGuiMap: {
      Map m;
      m.reserve(g.data.map.size);
      for (size_t i = 0; i < g.data.map.size; i++)
        m.emplace_back(from_bridge(g.data.map.items[i].key), from_bridge(g.data.map.items[i].value));
      return m;
    }
    default: return {};
  }
}

}  // namespace biscide::mp
