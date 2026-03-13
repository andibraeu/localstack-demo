/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  rootDir: ".",
  testMatch: ["**/integration/**/*.test.ts"],
  testTimeout: 60_000,
  verbose: true,
};
