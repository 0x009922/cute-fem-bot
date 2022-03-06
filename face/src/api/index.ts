export * from './types'

import { mande } from 'mande'
import { SchemaSuggestion, SchemaSuggestionDecision, SchemaUser } from './types'

let auth: string | null = null

export function setAuth(value: string | null) {
  auth = value
}

function authForce(): string {
  if (!auth) throw new Error('No auth')
  return auth
}

const suggestionsIndex = mande('/api/suggestions')
const filesIndex = mande('/api/files')

export interface FetchSuggestionsResponse {
  suggestions: SchemaSuggestion[]
  users: SchemaUser[]
}

export async function fetchSuggestions(): Promise<FetchSuggestionsResponse> {
  return suggestionsIndex.get<FetchSuggestionsResponse>('/', {
    headers: {
      Authorization: authForce(),
    },
  })
}

export interface FetchFileResponse {
  blob: Blob
  contentType: string | null
}

export interface UpdateSuggestionParams {
  decision?: SchemaSuggestionDecision
}

export async function fetchFile(fileId: string): Promise<FetchFileResponse> {
  return filesIndex
    .get(`/${fileId}`, {
      headers: {
        Authorization: authForce(),
      },
      responseAs: 'response',
    })
    .then(async (x) => {
      const blob = await x.blob()
      const contentType = x.headers.get('Content-Type')

      return { blob, contentType }
    })
}

export async function updateSuggestion(fileId: string, params: UpdateSuggestionParams): Promise<void> {
  await suggestionsIndex.put(`/${fileId}`, params)
}
