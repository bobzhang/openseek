///|
pub(all) enum Input {
  Prompt(String)
  Command(String)
} derive(Eq, Debug)

///|
pub(all) enum Event {
  Queue(Input)
  Steer(Input)
  Interrupt
  Quit
} derive(Eq, Debug)
