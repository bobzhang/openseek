///|
struct Queue {
  aq : @aqueue.Queue[async () -> Unit]
}

///|
pub async fn[T] Queue::wait(self : Queue, f : async () -> T) -> T {
  let result : @aqueue.Queue[Result[T, Error]] = Queue(kind=Blocking(1))
  self.aq.put(() => {
    let value : Result[T, Error] = try? f()
    result.put(value)
  })
  result.get().unwrap_or_error()
}

///|
pub fn Queue::Queue(kind~ : @aqueue.Kind) -> Queue {
  { aq: Queue(kind~) }
}

///|
pub async fn Queue::run(self : Queue) -> Unit {
  for ;; {
    let task = self.aq.get()
    task()
  }
}
