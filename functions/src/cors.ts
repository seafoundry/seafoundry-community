/**
 * Shared CORS allowlist for HTTP/Callable functions.
 */

const productionOrigins = [
  "https://provenance.seafoundry.com",
  "https://seafoundryapp.web.app",
  "https://seafoundryapp.firebaseapp.com",
];

const developmentOrigins = [
  "http://localhost:5000",
  "http://localhost:8080",
  "http://localhost:55219",
];

export function getCorsOrigins(): string[] {
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  return isEmulator
    ? [...productionOrigins, ...developmentOrigins]
    : productionOrigins;
}
