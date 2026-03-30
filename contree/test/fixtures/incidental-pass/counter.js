export function createCounter(initial = 0) {
  let count = initial
  return {
    increment() { count++ },
    decrement() { count-- },
    reset() { count = 0 },
    value() { return count },
  }
}
