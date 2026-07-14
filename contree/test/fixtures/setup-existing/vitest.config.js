import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    passWithNoTests: true,
    reporters: ['tree'],
    include: [
      'src/**/*.unit.test.js',
      'src/**/*.integration.test.js',
      'test/component/**/*.component.test.js',
    ],
  },
})
