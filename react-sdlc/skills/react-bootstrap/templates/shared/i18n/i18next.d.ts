// DESTINATION: src/shared/i18n/i18next.d.ts
//
// Makes translation keys TYPE-CHECKED against en.json. `t('common.retryy')`
// becomes a compile error rather than a string that silently renders its own
// key at runtime — the closest React equivalent of flutter's generated
// AppLocalizations class, which gets the same guarantee from codegen.
import type { defaultNS, resources } from './i18n';

declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: typeof defaultNS;
    resources: (typeof resources)['en'];
  }
}
