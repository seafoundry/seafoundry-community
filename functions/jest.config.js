module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/test/**/*.test.ts"],
  moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json", "node"],
  collectCoverageFrom: [
    "src/**/*.{ts,tsx}",
    "!src/**/*.d.ts",
  ],
  transform: {
    "^.+\\.tsx?$": ["ts-jest", {tsconfig: "tsconfig.test.json"}],
  },
  // Security rules tests need longer timeout for emulator initialization
  testTimeout: 30000,
};
