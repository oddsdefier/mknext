import baseConfig from './oxlint.config.ts';

export default {
  ...baseConfig,
  rules: {
    ...baseConfig.rules,
    'eslint/complexity': ['warn', { max: 15 }],
  },
};
