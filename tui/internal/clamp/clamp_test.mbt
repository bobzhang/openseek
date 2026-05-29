///|
test "int clamps optional bounds" {
  inspect(int(3), content="3")
  inspect(int(-1, min=0), content="0")
  inspect(int(9, max=4), content="4")
  inspect(int(5, min=0, max=4), content="4")
  inspect(int(2, min=0, max=4), content="2")
}
