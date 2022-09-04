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
  file_mime_type: string | null
  published: boolean
  made_by: number
  decision: SchemaSuggestionDecision | null
  decision_msg_id: number | null
  decision_made_by: number | null
  decision_made_at: string
  inserted_at: string | null
  updated_at: string | null
}

export type SchemaSuggestionDecision = 'sfw' | 'nsfw' | 'reject'

export type SchemaSuggestionType = 'video' | 'photo' | 'document'
