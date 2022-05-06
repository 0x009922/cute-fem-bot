import { SchemaSuggestionType } from '../api'

export function computeSuggestionType(typeInTable: SchemaSuggestionType, mime?: string) {
  if (typeInTable === 'photo' || typeInTable === 'video') return typeInTable

  if (mime) {
    if (mime.startsWith('image/')) return 'photo'
    if (mime.startsWith('video/')) return 'video'
  }

  return 'document'
}
