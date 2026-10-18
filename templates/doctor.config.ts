export default {
  blocking: 'error',
  noScore: true,
  ignore: {
    overrides: [
      { files: ['components/ui/**'], rules: ['react-doctor/only-export-components'] },
    ],
  },
  rules: {
    'react-doctor/no-high-complexity-react-function': 'warn',
  },
};
