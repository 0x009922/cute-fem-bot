import { SuggestionDecisionParam, SchemaSuggestionType } from '../api'

export const SUGGESTION_TYPE_RU: Record<SchemaSuggestionType, string> = {
  document: 'документ',
  photo: 'фото',
  video: 'видео',
}

export const SUGGESTION_DECISION_PARAM_RU: Record<SuggestionDecisionParam, string> = {
  none: 'Не принято',
  sfw: 'SFW',
  nsfw: 'NSFW',
  whatever: 'Не важно',
}
