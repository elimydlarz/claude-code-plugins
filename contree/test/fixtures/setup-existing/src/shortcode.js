const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789'

export const generate = () => Array.from(
  { length: 6 },
  () => alphabet[Math.floor(Math.random() * alphabet.length)],
).join('')

export const isValid = (code) => typeof code === 'string' && /^[a-z0-9]{6}$/.test(code)
