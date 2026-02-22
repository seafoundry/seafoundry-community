import Ajv, {ValidateFunction, ErrorObject} from "ajv";
import addFormats from "ajv-formats";
import userSchema from "../../schemas/models/user.schema.json";
import organizationSchema from "../../schemas/models/organization.schema.json";
import invitationSchema from "../../schemas/models/invitation.schema.json";

// Initialize AJV with formats
const ajv = new Ajv({allErrors: true});
addFormats(ajv);

// Compile validators
export const validateUser = ajv.compile(userSchema);
export const validateOrganization = ajv.compile(organizationSchema);
export const validateInvitation = ajv.compile(invitationSchema);

/**
 * Validates arbitrary data using the provided validator (AJV) and returns a typed guard.
 * @param {unknown} data value to validate
 * @param {ValidateFunction} validator AJV validate function
 * @return {boolean} type guard indicating whether data matches T
 */
export function validateModel<T>(
  data: unknown,
  validator: ValidateFunction
): data is T {
  const isValid = validator(data);
  if (!isValid) {
    console.error("Validation errors:", validator.errors);
  }
  return isValid;
}

/**
 * Validates and returns the input as the requested type or throws with aggregated errors.
 * @param {unknown} data value to validate
 * @param {ValidateFunction} validator AJV validate function
 * @return {T} typed data when valid
 */
export function validateAndSanitize<T>(
  data: unknown,
  validator: ValidateFunction
): T {
  if (!validateModel<T>(data, validator)) {
    const errors = validator.errors
      ?.map((error: ErrorObject) => `${error.instancePath} ${error.message}`)
      .join(", ");
    throw new Error(`Validation failed: ${errors}`);
  }
  return data as T;
}
