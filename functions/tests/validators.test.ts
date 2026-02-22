import {expect} from "chai";
import {
  validateUser,
  validateOrganization,
  validateInvitation,
  validateModel,
  validateAndSanitize,
} from "../src/validators";

describe("Validators", () => {
  describe("validateUser", () => {
    it("should validate a valid user object", () => {
      const validUser = {
        id: "user123",
        email: "test@example.com",
        name: "Test User",
        createdAt: "2024-01-01T00:00:00.000Z",
      };
      const result = validateUser(validUser);
      expect(result).to.be.true;
    });

    it("should reject an invalid user object", () => {
      const invalidUser = {
        id: "user123",
        // missing required email field
      };
      const result = validateUser(invalidUser);
      expect(result).to.be.false;
    });
  });

  describe("validateOrganization", () => {
    it("should validate a valid organization object", () => {
      const validOrg = {
        id: "org123",
        name: "Test Organization",
        domain: "test.org",
        createdAt: "2024-01-01T00:00:00.000Z",
      };
      const result = validateOrganization(validOrg);
      expect(result).to.be.true;
    });
  });

  describe("validateInvitation", () => {
    it("should validate a valid invitation object", () => {
      const validInvitation = {
        id: "invite123",
        email: "invitee@example.com",
        organizationId: "org123",
        invitedById: "user123",
        status: "pending",
        expiresAt: "2024-02-01T00:00:00.000Z",
        createdAt: "2024-01-01T00:00:00.000Z",
      };
      const result = validateInvitation(validInvitation);
      expect(result).to.be.true;
    });
  });

  describe("validateModel", () => {
    it("should return true for valid data and act as type guard", () => {
      const data = {
        id: "123",
        email: "test@example.com",
        name: "Test",
        createdAt: "2024-01-01T00:00:00.000Z",
      };
      const result = validateModel(data, validateUser);
      expect(result).to.be.true;
    });

    it("should return false for invalid data", () => {
      const data = {id: "123"}; // missing email
      const result = validateModel(data, validateUser);
      expect(result).to.be.false;
    });
  });

  describe("validateAndSanitize", () => {
    it("should return typed data when valid", () => {
      const data = {
        id: "123",
        email: "test@example.com",
        name: "Test",
        createdAt: "2024-01-01T00:00:00.000Z",
      };
      const result = validateAndSanitize(data, validateUser);
      expect(result).to.deep.equal(data);
    });

    it("should throw error with details when invalid", () => {
      const data = {id: "123"}; // missing email
      expect(() => validateAndSanitize(data, validateUser)).to.throw(
        /Validation failed/
      );
    });
  });
});
