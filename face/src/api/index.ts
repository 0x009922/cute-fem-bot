export * from './types'

import Axios from 'axios'
import { SchemaSuggestion, SchemaSuggestionDecision, SchemaUser } from './types'

let auth: string | null = null

const API_BASE: string = (import.meta.env.VITE_API_URL ?? '') + '/api/v1'
const axios = Axios.create({
  baseURL: API_BASE,
})

export function setAuth(value: string | null) {
  auth = value
}

function authForce(): string {
  if (!auth) throw new Error('No auth')
  return auth
}

export interface FetchSuggestionsResponse {
  suggestions: SchemaSuggestion[]
  users: SchemaUser[]
}

export interface FetchSuggestionsParams extends PaginationParams {}

export interface PaginationParams {
  page?: number
  page_size?: number
}

export async function fetchSuggestions(params?: FetchSuggestionsParams): Promise<FetchSuggestionsResponse> {
  return axios
    .get<FetchSuggestionsResponse>('/suggestions', {
      headers: {
        Authorization: authForce(),
      },
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
      headers: {
        Authorization: authForce(),
      },
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
