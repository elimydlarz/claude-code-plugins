export function createCounter(initial = 0) {
  let count = initial
  return {
    increment(amount = 1) { count += amount },
    value() { return count },
  }
}
