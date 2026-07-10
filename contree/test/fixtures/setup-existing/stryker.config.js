export default {
  testRunner: 'vitest',
  mutate: ['src/**/*.js', '!src/**/*.test.js', '!src/**/*.contract.js'],
  thresholds: { high: 80, low: 60, break: 50 },
}
