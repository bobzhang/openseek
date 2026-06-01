///|
/// Diff/clear state for the live viewport region.
///
/// Steady-state redraws diff the new surface against the last one drawn so the
/// renderer can skip unchanged physical rows. Some operations (a terminal
/// resize, or a transcript insert that runs before the live area exists) drop
/// that cached surface. When they do, the old physical *footprint* must still
/// be remembered so the next redraw can erase rows the moved/shrunken region no
/// longer covers.
///
/// The three states make that lifecycle explicit:
///
///   - `Fresh`: nothing drawn yet, nothing to clear. The first redraw anchors
///     the live area at the current terminal cursor.
///   - `Drawn(surface)`: `surface` is on screen at the viewport's current `top`,
///     so redraws can diff against it row by row.
///   - `Stale(top, height)`: the cached surface was dropped, but the region it
///     occupied is remembered so the next redraw clears any rows it vacates.
priv enum FrameCache {
  Fresh
  Drawn(@surface.Surface)
  Stale(top~ : Int, height~ : Int)
}

///|
/// The cached surface available for row-level diffing, if any.
///
/// Only `Drawn` carries trustworthy on-screen content; `Fresh` and `Stale` have
/// no surface to diff against, so the next redraw rewrites every covered row.
fn FrameCache::surface(self : FrameCache) -> @surface.Surface? {
  match self {
    Drawn(surface) => Some(surface)
    Fresh | Stale(top=_, height=_) => None
  }
}

///|
/// The physical region the previous frame occupied, or `None` when there is no
/// prior frame.
///
/// `Drawn` reuses the viewport's live `top` because the cached surface has not
/// moved since it was drawn. `Stale` returns the remembered footprint. `Fresh`
/// has nothing on screen, so the first redraw clears nothing.
fn FrameCache::footprint(self : FrameCache, live_top~ : Int) -> Geometry? {
  match self {
    Fresh => None
    Drawn(surface) => Some({ top: live_top, height: surface.height() })
    Stale(top~, height~) => Some({ top, height })
  }
}

///|
/// Drop the cached surface but remember the region it covered so a later redraw
/// can clear vacated rows. Called when a resize (or a pre-live insert) makes the
/// cached physical rows untrustworthy.
///
/// Only `Drawn` has a footprint worth remembering; `Fresh` and `Stale` already
/// hold no live surface, so they are left unchanged.
fn FrameCache::invalidate(self : FrameCache, live_top~ : Int) -> FrameCache {
  match self {
    Drawn(surface) => Stale(top=live_top, height=surface.height())
    Fresh | Stale(top=_, height=_) => self
  }
}
