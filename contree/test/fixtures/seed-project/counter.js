export function createCounter(initial = 0) {
  let count = initial
  return {
    increment() { count++ },
    decrement() { count-- },
    value() { return count },
  }
}
