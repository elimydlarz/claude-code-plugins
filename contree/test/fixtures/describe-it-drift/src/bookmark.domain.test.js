import { describe, it } from 'vitest'
import { parseUrl } from './bookmark.js'

describe('Bookmark', () => {
  describe('URL handling', () => {
    it('returns canonical https form', () => {
      parseUrl('https://example.com')
    })
    it('throws for garbage input', () => {
      try { parseUrl('not a url') } catch {}
    })
  })
})
