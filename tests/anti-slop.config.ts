export default {
  jsPlugins: [
    {
      name: 'anti-slop',
      specifier: '../templates/tools/oxlint/anti-slop/index.ts',
    },
  ],
  rules: {
    'anti-slop/no-conditional-empty-object-spread': 'error',
    'anti-slop/no-known-value-widening': 'error',
    'anti-slop/no-module-mocking': 'error',
    'anti-slop/no-object-parameters': 'error',
    'anti-slop/no-unknown-parameters': 'error',
    'anti-slop/no-unknown-returns': 'error',
    'anti-slop/no-unknown-type-aliases': 'error',
  },
};
