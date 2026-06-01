///|
struct Ui {
  tty : @tty.Tty
  config : Config
  viewport : @viewport.Viewport
  composer : @composer.Model
  history : History
  transcript : Array[Doc]
  mut activity : Text?
  mut queued_inputs : Array[Input]
  mut status : Text
  mut notice : Text?
  mut entered : Bool
  commands : @task.Queue
  events : @aqueue.Queue[Result[Event, Error]]
}

///|
fn Ui::new(tty : @tty.Tty, config : Config) -> Ui {
  let composer = @composer.Model::new(max_text_rows=config.composer_max_rows)
  {
    tty,
    config,
    viewport: @viewport.Viewport::new(height=1),
    composer,
    history: History::new(),
    transcript: [],
    activity: None,
    queued_inputs: [],
    status: Text::plain(""),
    notice: None,
    entered: false,
    commands: Queue(kind=Unbounded),
    events: Queue(kind=Unbounded),
  }
}

///|
async fn[T] run_ui_session(ui : Ui, body : async (Ui) -> T) -> T {
  @async.with_task_group() <| g => {
    g.spawn_bg(no_wait=true) <| () => { ui.commands.run() }
    ui.commands.wait(() => {
      ui.enter()
      // The first redraw may query cursor position through tty input. Do it
      // before the reader task starts so the reader cannot consume that
      // response as a normal key event.
      ui.redraw()
    })
    g.spawn_bg(no_wait=true) <| () => { ui.read_tty_events() }
    try body(ui) catch {
      error => {
        ui.commands.wait(() => ui.leave())
        raise error
      }
    } noraise {
      value => {
        ui.commands.wait(() => ui.leave())
        value
      }
    }
  }
}

///|
async fn Ui::put_event_result(self : Ui, result : Result[Event, Error]) -> Unit {
  self.events.put(result) catch {
    @aqueue.QueueAlreadyClosed => ()
    error => raise error
  }
}

///|
async fn Ui::read_tty_events(self : Ui) -> Unit {
  for ;; {
    let tty_event = self.tty.read_event(
      esc_timeout_ms=self.config.esc_timeout_ms,
    ) catch {
      @async/io.ReaderClosed => {
        self.put_event_result(Ok(Quit))
        self.events.close()
        return
      }
      error if @async.is_being_cancelled() => raise error
      error => {
        self.put_event_result(Err(error))
        self.events.close()
        return
      }
    }
    let event = self.commands.wait(() => self.handle_tty_event(tty_event)) catch {
      error if @async.is_being_cancelled() => raise error
      error => {
        self.put_event_result(Err(error))
        self.events.close()
        return
      }
    }
    if event is Some(event) {
      self.put_event_result(Ok(event))
    }
  }
}

///|
pub async fn[T] with_ui(
  config? : Config = Config::new(),
  body : async (Ui) -> T,
) -> T {
  let tty = @tty.Tty::open()
  defer tty.close()
  let ui = Ui::new(tty, config)
  // Request the kitty keyboard protocol's "disambiguate" level so modified keys
  // the legacy encoding cannot represent — Shift+Enter, Alt+F/Alt+B — are
  // reported as distinct CSI-u events. We deliberately avoid the higher levels
  // that also report key-release events, which would double-fire every key.
  // Terminals without kitty support ignore the request and degrade gracefully.
  let flags = @tty.KeyboardEnhancementFlags::disambiguate()
  tty.with_raw_mode() <| () => {
    tty.with_keyboard_enhancements(flags) <| () => { run_ui_session(ui, body) }
  }
}
