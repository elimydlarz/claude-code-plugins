import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    passWithNoTests: true,
    reporters: ['tree'],
    include: [
      'src/**/*.unit.test.js',
      'src/**/*.domain.test.js',
      'src/**/*.use-case.test.js',
      'src/**/*.adapter.test.js',
      'test/component/**/*.component.test.js',
    ],
  },
})
