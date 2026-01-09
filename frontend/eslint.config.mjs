import path from 'path';
import { fileURLToPath } from 'url';
import js from '@eslint/js';
import typescriptPlugin from '@typescript-eslint/eslint-plugin';
import typescriptParser from '@typescript-eslint/parser';
import importPlugin from 'eslint-plugin-import';
import prettierPlugin from 'eslint-plugin-prettier';
import reactHooksPlugin from 'eslint-plugin-react-hooks';
import reactPlugin from 'eslint-plugin-react';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Browser and Node.js globals
const browserGlobals = {
  React: 'readonly',
  JSX: 'readonly',
  NodeJS: 'readonly',
  console: 'readonly',
  process: 'readonly',
  window: 'readonly',
  document: 'readonly',
  localStorage: 'readonly',
  sessionStorage: 'readonly',
  fetch: 'readonly',
  URL: 'readonly',
  URLSearchParams: 'readonly',
  FormData: 'readonly',
  Headers: 'readonly',
  Request: 'readonly',
  Response: 'readonly',
  AbortController: 'readonly',
  setTimeout: 'readonly',
  clearTimeout: 'readonly',
  setInterval: 'readonly',
  clearInterval: 'readonly',
  requestAnimationFrame: 'readonly',
  cancelAnimationFrame: 'readonly',
  HTMLElement: 'readonly',
  HTMLInputElement: 'readonly',
  HTMLDivElement: 'readonly',
  MouseEvent: 'readonly',
  KeyboardEvent: 'readonly',
  Event: 'readonly',
  ResizeObserver: 'readonly',
  MutationObserver: 'readonly',
  IntersectionObserver: 'readonly',
  Navigator: 'readonly',
  navigator: 'readonly',
  location: 'readonly',
  history: 'readonly',
  Image: 'readonly',
  Blob: 'readonly',
  File: 'readonly',
  FileReader: 'readonly',
  atob: 'readonly',
  btoa: 'readonly',
  alert: 'readonly',
  confirm: 'readonly',
  __dirname: 'readonly',
  __filename: 'readonly',
  module: 'readonly',
  require: 'readonly',
  exports: 'readonly',
  google: 'readonly',
  L: 'readonly',
  cartodb: 'readonly',
};

export default [
  // Ignore patterns
  {
    ignores: [
      'node_modules/**',
      '.next/**',
      'out/**',
      'coverage/**',
      '*.config.js',
      '*.config.mjs',
      'cypress/**',
    ],
  },
  
  // Base JavaScript recommended rules
  js.configs.recommended,

  // TypeScript files configuration
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parser: typescriptParser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        project: './tsconfig.json',
        ecmaFeatures: {
          jsx: true,
        },
      },
      globals: browserGlobals,
    },
    plugins: {
      '@typescript-eslint': typescriptPlugin,
      import: importPlugin,
      prettier: prettierPlugin,
      'react-hooks': reactHooksPlugin,
      react: reactPlugin,
    },
    settings: {
      'import/resolver': {
        typescript: true,
        node: true,
      },
      'import/extensions': ['.js', '.jsx', '.ts', '.tsx'],
      'import/ignore': ['leaflet'],
      react: {
        version: 'detect',
      },
    },
    rules: {
      ...typescriptPlugin.configs.recommended.rules,
      ...reactHooksPlugin.configs.recommended.rules,
      'import/no-named-as-default': 'off',
      'import/no-named-as-default-member': 'off',
      'import/namespace': ['error', { allowComputed: true }],
      'prettier/prettier': 'error',
      'no-console': 'warn',
      'no-debugger': 'warn',
      'react/display-name': 'off',
      '@typescript-eslint/consistent-type-imports': 'warn',
      '@typescript-eslint/no-unused-vars': [
        'warn',
        {
          ignoreRestSiblings: true,
        },
      ],
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-require-imports': 'off',
      // Next.js allows unused vars prefixed with _
      'no-unused-vars': 'off',
      // Disable @next/next rules since we're not using eslint-config-next
      '@next/next/no-img-element': 'off',
    },
  },

  // JavaScript/JSX files configuration
  {
    files: ['**/*.js', '**/*.jsx'],
    languageOptions: {
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        ecmaFeatures: {
          jsx: true,
        },
      },
      globals: browserGlobals,
    },
    plugins: {
      import: importPlugin,
      prettier: prettierPlugin,
      'react-hooks': reactHooksPlugin,
      react: reactPlugin,
    },
    settings: {
      react: {
        version: 'detect',
      },
    },
    rules: {
      ...reactHooksPlugin.configs.recommended.rules,
      'import/no-named-as-default': 'off',
      'import/no-named-as-default-member': 'off',
      'prettier/prettier': 'error',
      'no-console': 'warn',
      'no-debugger': 'warn',
      // In React 17+, React import is not required for JSX
      'no-unused-vars': ['warn', { varsIgnorePattern: '^React$' }],
    },
  },
];
