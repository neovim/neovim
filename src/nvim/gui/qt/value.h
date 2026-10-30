// A value as Nvim gives it to the GUI (an event's arguments, a payload from
// Lua), copied out of the bridge's (gui/bridge.h) to live on the GUI's
// thread; and back, for the Lua the GUI runs.
#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <variant>
#include <vector>

struct GuiValue;

namespace biscide::mp {

struct Value;
using Array = std::vector<Value>;
using Map = std::vector<std::pair<Value, Value>>;

struct Value {
  std::variant<std::monostate, bool, int64_t, uint64_t, double, std::string, Array, Map> v;

  Value() = default;
  Value(std::nullptr_t) {}
  Value(bool b) : v(b) {}
  Value(int i) : v(static_cast<int64_t>(i)) {}
  Value(int64_t i) : v(i) {}
  Value(uint64_t u) : v(u) {}
  Value(double d) : v(d) {}
  Value(const char* s) : v(std::string(s)) {}
  Value(std::string s) : v(std::move(s)) {}
  Value(Array a) : v(std::move(a)) {}
  Value(Map m) : v(std::move(m)) {}

  bool is_nil() const { return std::holds_alternative<std::monostate>(v); }
  /// An integer.
  std::optional<int64_t> as_int() const;
  std::optional<bool> as_bool() const;
  const std::string* as_str() const { return std::get_if<std::string>(&v); }
  const Array* as_array() const { return std::get_if<Array>(&v); }
  const Map* as_map() const { return std::get_if<Map>(&v); }
  /// A map's value under a string key.
  const Value* get(const std::string& key) const;
  /// An array's element.
  const Value* at(size_t i) const;

  int64_t int_or(int64_t d) const { return as_int().value_or(d); }
  std::string str_or(const std::string& d = {}) const { auto s = as_str(); return s ? *s : d; }
};

/// The bridge's value (gui/bridge.h) as a Value, copied.
Value from_bridge(const struct ::GuiValue& v);

}  // namespace biscide::mp
