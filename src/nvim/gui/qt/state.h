// What biscide's plugin tells the UI of the lanes (`rpcnotify(0, "biscide",
// "state", …)`): the declarations shown, their cards' windows, the links to
// the active one, the card cursor, the history.
#pragma once

#include "value.h"

#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace biscide {

struct NodeInfo {
  int64_t id = 0;
  std::string name, short_name, kind, rel, layer;
  int64_t line = 0, lines = 0, used_by = 0, uses = 0;
};

enum class Lane { Prev = 0, UsedBy = 1, File = 2, Uses = 3 };
Lane lane_of(const std::string& column);
const char* lane_name(Lane l);

struct CardInfo {
  std::string key;
  int64_t node = 0;
  Lane lane = Lane::File;
  int64_t win = 0;
  int rows = 1;
  /// The columns before its text (the line numbers, the signs).
  int textoff = 0;
};

struct LinkInfo {
  int64_t node = 0;
  Lane lane = Lane::Uses;
  std::vector<std::string> kinds;
  bool violation = false;
  int row = -1, col = -1;
  /// The row of the active card's window the link starts at (-1: not known).
  int vrow = -1;
  /// Its column as shown there (-1: the byte's).
  int vcol = -1;
};

struct LanesState {
  bool valid = false;  // there are lanes
  bool building = false;
  std::string root, notice;
  int64_t active = 0;
  std::optional<int64_t> prev;
  std::vector<int64_t> file, used_by, uses;
  std::vector<CardInfo> cards;
  std::map<int64_t, NodeInfo> nodes;
  std::vector<LinkInfo> links;
  /// The card cursor: on a card, or on the empty card (`cursor_new`).
  std::optional<std::pair<int64_t, Lane>> cursor;
  bool cursor_new = false;
  std::vector<std::string> history;
  int history_at = 0;
  int64_t new_win = 0;
  int new_rows = 3;
  int64_t centre = 0, focus = 0;
  /// The key of the card the camera follows (the card cursor's, "new" for
  /// the empty card; the active one's when there is no card cursor).
  std::string follow;
  /// How the active declaration came (biscide's `arrival`): "jump", "side",
  /// "within"; from which lane; "back" or "forward".
  std::string arrival_how, arrival_from, arrival_dir;
  int64_t declarations = 0;

  static LanesState parse(const mp::Value& v);
  const NodeInfo* node(int64_t id) const;
  const CardInfo* card(int64_t node, Lane lane) const;
};

}  // namespace biscide
