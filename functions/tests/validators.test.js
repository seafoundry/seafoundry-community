"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const validators_1 = require("../src/validators");
describe("Validators", () => {
    describe("validateUser", () => {
        it("should validate a valid user object", () => {
            const validUser = {
                id: "user123",
                email: "test@example.com",
                name: "Test User",
                createdAt: "2024-01-01T00:00:00.000Z",
            };
            const result = (0, validators_1.validateUser)(validUser);
            (0, chai_1.expect)(result).to.be.true;
        });
        it("should reject an invalid user object", () => {
            const invalidUser = {
                id: "user123",
                // missing required email field
            };
            const result = (0, validators_1.validateUser)(invalidUser);
            (0, chai_1.expect)(result).to.be.false;
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
            const result = (0, validators_1.validateOrganization)(validOrg);
            (0, chai_1.expect)(result).to.be.true;
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
            const result = (0, validators_1.validateInvitation)(validInvitation);
            (0, chai_1.expect)(result).to.be.true;
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
            const result = (0, validators_1.validateModel)(data, validators_1.validateUser);
            (0, chai_1.expect)(result).to.be.true;
        });
        it("should return false for invalid data", () => {
            const data = { id: "123" }; // missing email
            const result = (0, validators_1.validateModel)(data, validators_1.validateUser);
            (0, chai_1.expect)(result).to.be.false;
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
            const result = (0, validators_1.validateAndSanitize)(data, validators_1.validateUser);
            (0, chai_1.expect)(result).to.deep.equal(data);
        });
        it("should throw error with details when invalid", () => {
            const data = { id: "123" }; // missing email
            (0, chai_1.expect)(() => (0, validators_1.validateAndSanitize)(data, validators_1.validateUser)).to.throw(/Validation failed/);
        });
    });
});
//# sourceMappingURL=validators.test.js.map