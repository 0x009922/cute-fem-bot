export * from './types'

import Axios from 'axios'
import { SchemaSuggestion, SchemaSuggestionDecision, SchemaUser } from './types'

const API_BASE: string = (import.meta.env.VITE_API_URL ?? '') + '/api/v1'
const axios = Axios.create({
  baseURL: API_BASE,
})

const AUTH_HEADER = 'Authorization'
export function setAuth(value: string | null) {
  if (value) {
    axios.defaults.headers.common[AUTH_HEADER] = value
  } else {
    delete axios.defaults.headers.common[AUTH_HEADER]
  }
}

export interface FetchSuggestionsResponse {
  suggestions: SchemaSuggestion[]
  users: SchemaUser[]
}

export interface FetchSuggestionsParams extends PaginationParams {
  published?: boolean
  decision?: SuggestionDecisionParam
}

export const SUGGESTION_DECISION_PARAM_VALUES = ['sfw', 'nsfw', 'none', 'whatever'] as const

export type SuggestionDecisionParam = typeof SUGGESTION_DECISION_PARAM_VALUES[number]

export interface PaginationParams {
  page?: number
  page_size?: number
}

export async function fetchSuggestions(params?: FetchSuggestionsParams): Promise<FetchSuggestionsResponse> {
  return axios
    .get<FetchSuggestionsResponse>('/suggestions', {
      params,
    })
    .then((x) => x.data)
}

export interface FetchFileResponse {
  blob: Blob
  contentType: string | null
}

export interface UpdateSuggestionParams {
  decision?: SchemaSuggestionDecision
}

export async function fetchFile(fileId: string): Promise<FetchFileResponse | null> {
  return axios
    .get(`/files/${fileId}`, {
      responseType: 'blob',
    })
    .then((x) => {
      if (x.status === 204) return null

      const blob = x.data
      const contentType = x.headers['content-type']

      return { blob, contentType }
    })
}

export async function updateSuggestion(fileId: string, params: UpdateSuggestionParams): Promise<void> {
  await axios.put(`/suggestions/${fileId}`, params)
}
