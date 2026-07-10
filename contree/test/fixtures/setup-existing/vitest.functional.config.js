import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    passWithNoTests: true,
    reporters: ['tree'],
    include: [
      'test/system/**/*.system.test.js',
      'test/journey/**/*.journey.test.js',
    ],
  },
})
