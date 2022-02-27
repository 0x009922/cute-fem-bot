export interface SchemaUser {
  id: number
  banned: boolean
  meta: SchemaUserMeta
}

export interface SchemaUserMeta {
  id: number
  first_name: string
  last_name?: string
  language_code: string
  is_bot: boolean
  username?: string
}

export interface SchemaSuggestion {
  file_id: string
  file_type: SchemaSuggestionType
  published: boolean
  suggestor_id: number
  decision: SchemaSuggestionDecision
}

export type SchemaSuggestionDecision = null | 'sfw' | 'nsfw'

export type SchemaSuggestionType = 'video' | 'photo' | 'document'
