export function parseUrl(input) {
  try {
    return new URL(input).toString()
  } catch {
    throw new Error('InvalidUrl')
  }
}
