// The stage: where the lanes' cards lie on the canvas and how they move.
// Laid out around the active card where it lies: its file stacked, what
// uses it on the left, what it uses on the right, the one the reader came
// from at the far left. When the lanes change, each card slides from where
// it (or the same declaration) was drawn, new cards fade in, the ones gone
// fade out where they lay. Each lane scrolls up and down on its own.
#pragma once

#include "geometry.h"
#include "motion.h"
#include "state.h"

#include <functional>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace biscide {

/// A card on the stage: its key and declaration's (no lane), where it lies
/// (world units), its window.
struct Placed {
  std::string key, decl;
  int64_t node = 0;
  Lane lane = Lane::File;
  float x = 0, y = 0, w = 0, h = 0;
  int rows = 1;
  int64_t win = 0;
  int textoff = 0;  ///< the columns before its text
};

/// Where a card is drawn now (its place, moved by its motion and its
/// lane's scroll).
struct Drawn {
  float x = 0, y = 0, w = 0, h = 0;
  bool contains(float wx, float wy) const { return wx >= x && wx <= x + w && wy >= y && wy <= y + h; }
};

/// A card no longer shown, fading out where it lay.
struct Ghost {
  Placed card;
  Drawn drawn;
  Fade fade;
};

/// How the active card came to be the active one.
enum class Arrival {
  Jump,    ///< from elsewhere (a picker, the history, a file)
  Side,    ///< a card of a side lane
  Within,  ///< another card of the file lane, or the same one laid out again
};

/// Which way a jump goes: back (the history, the previous one) lays the
/// lanes out to the left, forth to the right; the camera travels there.
enum class Direction { None, Back, Forward };

/// A card's key without its lane: its declaration's.
std::string decl_of(const std::string& key);

class Stage {
 public:
  explicit Stage(const CardMetrics& m) : m_(m) {}

  /// The lanes laid out anew around the active card, where it lies now
  /// (`how` it came, from lane `from`; a jump a step `dir`; `old_decl` the
  /// one active before); each card moving from where it was. `in_view`
  /// says whether a card leaving is seen (it fades out there).
  void arrange(const LanesState& s, Arrival how, Lane from, Direction dir, const std::string& old_decl, float t,
               const std::function<bool(const Drawn&)>& in_view);
  /// Whether `s` has the cards laid out now, the same sizes.
  bool same_cards(const LanesState& s) const;
  /// The same cards: their declarations' ids and windows taken from `s`.
  void adopt(const LanesState& s);
  void clear();

  float column_x(Lane l) const;
  Drawn drawn(const Placed& p, float t) const;
  /// How opaque a card is now: its fade; the file's other cards a step back.
  float opacity(const Placed& p, int64_t active, float t) const;

  const std::vector<Placed>& cards() const { return cards_; }
  const std::vector<Ghost>& ghosts() const { return ghosts_; }
  const Placed* card(int64_t node, Lane lane) const;
  const Placed* by_decl(const std::string& decl, Lane lane) const;
  const Placed* by_key(const std::string& key) const;
  /// The empty card under the file lane's last one (`rows` tall).
  std::optional<Drawn> new_card(int rows) const;

  /// Scrolls a lane by `dy` (world units), keeping a card of it across the
  /// world height `middle`: gliding there (the wheel), or at once (a drag).
  void scroll(Lane l, float dy, float middle, bool glide = true);
  /// Scrolls a lane (gliding) so its card `p`'s top is at world height `y`.
  void scroll_card_to(const Placed& p, float y);
  /// Where a lane's scroll is going.
  float lane_scroll_target(Lane l) const { return scroll_target_[static_cast<int>(l)]; }

  void tick(float t);
  bool moving(float t) const;

 private:
  CardMotion motion_of(const Placed& p) const;
  Placed make(const CardInfo& c, float y) const;

  const CardMetrics& m_;
  std::vector<Placed> cards_;
  std::vector<Ghost> ghosts_;
  std::map<std::string, CardMotion> motion_;
  float centre_x_ = 0;
  float scroll_[4] = {0, 0, 0, 0};
  float scroll_target_[4] = {0, 0, 0, 0};
  float last_tick_ = 0;
};

}  // namespace biscide
