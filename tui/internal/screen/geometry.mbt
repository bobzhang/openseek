///|
pub(all) struct Rect {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
pub fn Rect::new(x~ : Int, y~ : Int, width~ : Int, height~ : Int) -> Rect {
  {
    x: if x < 0 {
      0
    } else {
      x
    },
    y: if y < 0 {
      0
    } else {
      y
    },
    width: if width < 0 {
      0
    } else {
      width
    },
    height: if height < 0 {
      0
    } else {
      height
    },
  }
}

///|
pub fn Rect::right(self : Rect) -> Int {
  self.x + self.width
}

///|
pub fn Rect::bottom(self : Rect) -> Int {
  self.y + self.height
}

///|
pub fn Rect::contains(self : Rect, row~ : Int, col~ : Int) -> Bool {
  row >= self.y && row < self.bottom() && col >= self.x && col < self.right()
}
