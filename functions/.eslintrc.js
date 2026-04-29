module.exports = {
  root: true,
  env: { es6: true, node: true },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: "tsconfig.json",
    sourceType: "module",
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: ["lib/**/*"],
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  rules: {
    "quotes": ["error", "double"],
    "max-len": ["warn", { code: 120 }],
  },
};
