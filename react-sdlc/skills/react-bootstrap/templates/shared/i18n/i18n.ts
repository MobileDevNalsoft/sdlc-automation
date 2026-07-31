// DESTINATION: src/shared/i18n/i18n.ts
//
// Parallel to flutter-bootstrap's l10n scaffolding, adopted for the same
// reason: single-language i18n costs almost nothing NOW, and retrofitting it
// later means touching every string in every component. Adding a locale
// afterwards is then a JSON file plus one line here — no component changes.
//
// `createInstance()` rather than the default global export: a global i18next
// instance is shared across every test in a run, so one test changing the
// language leaks into the next.
import i18next from 'i18next';
import type { i18n as I18nType } from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';

export const defaultNS = 'translation';
export const resources = { en: { translation: en } } as const;

export const i18n: I18nType = i18next.createInstance();

void i18n.use(initReactI18next).init({
  resources,
  lng: 'en',
  fallbackLng: 'en',
  defaultNS,
  interpolation: {
    // React already escapes interpolated values; escaping again produces
    // visible &amp; sequences in the UI.
    escapeValue: false,
  },
  returnNull: false,
});
