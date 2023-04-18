import { t } from '@transifex/native';

export const INDICATOR_VALUES = [1 / 9, 1 / 7, 1 / 5, 1 / 3, 1, 3, 5, 7, 9];
export const INDICATOR_HUMAN_READABLE_VALUES = [
  '1/9',
  '1/7',
  '1/5',
  '1/3',
  '1',
  '3',
  '5',
  '7',
  '9',
];
export const getIndicatorValueDesc = () => [
  t('Extremely'),
  t('Very'),
  t('Strongly'),
  t('Moderate'),
  t('Equally'),
  t('Moderate'),
  t('Strongly'),
  t('Very'),
  t('Extremely'),
];

export const AUTH_TOKEN = 'resilience_token';
