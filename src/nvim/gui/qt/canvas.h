// The canvas widget: the stage (where the cards lie, how they move), the
// camera rig (framing the lanes, or following the card cursor), the
// overlays (history, key), painted at each frame while anything moves; the
// mouse turned into the editor's calls.
//
// The mouse: a click on the active card's code puts Nvim's cursor there (a
// drag selects); a click on a name its uses lane shows puts the card
// cursor on that card; a click on another card puts the card cursor on it;
// a double click on it makes it the active one. The wheel scrolls a card's
// code under it (when it has more than it shows), else its lane. A card's
// window has all its part; the canvas scrolls it, smoothly, and keeps the
// cursor in view.
#pragma once

#include "camera.h"
#include "editor.h"
#include "geometry.h"
#include "overlays.h"
#include "screen.h"
#include "stage.h"
#include "state.h"

#include <QElapsedTimer>
#include <QTimer>
#include <QWidget>

#include <optional>
#include <string>
#include <tuple>
#include <unordered_map>

namespace biscide {

class Canvas : public QWidget {
  Q_OBJECT
 public:
  Canvas(Screen& screen, Editor& editor, QWidget* parent = nullptr);

  void set_state(LanesState s);
  void set_card_cols(int cols);
  /// Whether the keyboard is the cards' (not the tree's, not a picker's).
  void set_cards_focused(bool focused);
  /// Nvim drew: painted at the next frame (a card's cursor kept in view).
  void screen_changed();

  /// The most rows a card may have in this view.
  int max_rows() const;
  const LanesState& state() const { return st_; }
  /// Where a cell of a card's grid is drawn (in this widget), if shown.
  std::optional<QRectF> cell_rect(int64_t grid, int row, int col) const;

 signals:
  void view_changed();

 protected:
  void paintEvent(QPaintEvent*) override;
  void resizeEvent(QResizeEvent*) override;
  void mousePressEvent(QMouseEvent*) override;
  void mouseMoveEvent(QMouseEvent*) override;
  void mouseReleaseEvent(QMouseEvent*) override;
  void mouseDoubleClickEvent(QMouseEvent*) override;
  void wheelEvent(QWheelEvent*) override;

 private:
  /// What a press of the left button holds until its release.
  struct Press {
    enum class Kind { None, Card, Nvim, Lane } kind = Kind::None;
    QPointF at;
    std::string card;          ///< Card: the card pressed
    int64_t grid = 0;          ///< Nvim: the grid pressed
    std::pair<int, int> cell;  ///< Nvim: the last cell sent
    std::optional<Lane> lane;  ///< Lane, Card: the lane dragged
    bool dragged = false;

    static Press on_nvim(QPointF at, int64_t grid, std::pair<int, int> cell) {
      Press p;
      p.kind = Kind::Nvim;
      p.at = at;
      p.grid = grid;
      p.cell = cell;
      return p;
    }
    static Press on_card(QPointF at, std::string card, std::optional<Lane> lane) {
      Press p;
      p.kind = card.empty() ? Kind::Lane : Kind::Card;
      p.at = at;
      p.card = std::move(card);
      p.lane = lane;
      return p;
    }
  };

  float now() const { return static_cast<float>(clock_.elapsed()) / 1000.0f; }
  QSizeF view() const;
  PaintContext context() const;

  // The camera's views.
  std::pair<float, float> frame_x() const;
  Camera framing(const Drawn& active) const;
  Camera centred_on(const Drawn& d) const;
  float view_middle() const;
  void hold_frame();
  void aim(bool glide);

  bool in_view(const Drawn& d) const;
  const Placed* hit(QPointF at) const;
  std::optional<Lane> lane_at(float x) const;
  std::optional<std::pair<int, int>> cell_at(const Placed& c, QPointF at) const;
  /// The word of a card's code under a point.
  std::string word_at(const Placed& c, QPointF at) const;
  bool on_new_card(QPointF at) const;
  void bring(const Placed& c, QPointF at);
  std::tuple<Arrival, Lane, Direction> arrival(const std::string& new_decl) const;
  bool press_overlay(QPointF at);

  void run();
  void frame();
  void lua(const std::string& code, mp::Array args = {});

  Screen& screen_;
  Editor& editor_;
  LanesState st_;
  CardMetrics m_;
  Stage stage_;
  CameraRig rig_;
  Overlays overlays_;
  /// The counters the state was last seen with.
  int64_t seen_centre_ = -1, seen_focus_ = -1;
  std::string hovered_;
  /// A card just brought into view, lit for a moment.
  std::optional<std::pair<std::string, float>> flash_;
  /// A card's own scroll, in rows of its window (which has all its part):
  /// where it is drawn, where it is going.
  struct Scroll {
    float pos = 0, target = 0;
  };
  float scroll_of(int64_t win) const;
  /// How far a card scrolls: its part's rows it does not show.
  float scroll_max(const Placed& c) const;
  /// The card the cursor is in scrolled to show it.
  void follow_cursor();
  /// The camera onto the card typed in (centred), when typing starts in
  /// it, it grows or shrinks, or the cursor goes into another.
  void focus_typing();
  /// The scrolls moved on by `dt`; whether any still moves.
  bool step_scrolls(float dt);

  Press press_;
  std::unordered_map<int64_t, Scroll> scrolls_;
  /// The card typed in, as the camera last centred it.
  std::string typing_key_;
  int typing_rows_ = -1;
  int64_t seen_cursor_grid_ = -1;
  int seen_cursor_row_ = -1;
  float last_frame_ = 0;
  bool cards_focused_ = true;
  QTimer timer_;
  QElapsedTimer clock_;
};

}  // namespace biscide
