/* tslint:disable */
/**
 * This file was automatically generated from JSON Schema.
 * DO NOT MODIFY IT BY HAND. Instead, modify the source JSON Schema file,
 * and run 'npm run generate-models' to regenerate this file.
 */

export interface User {
  /**
   * Unique identifier for the user
   */
  id: string;
  /**
   * User's email address
   */
  email: string;
  /**
   * User's display name
   */
  name?: string;
  /**
   * ID of the organization the user belongs to
   */
  organizationId?: string;
  /**
   * User's role within the organization
   */
  role?: 'admin' | 'practitioner_plus' | 'practitioner' | 'view_only';
  /**
   * Timestamp when the user was created
   */
  createdAt: string;
  /**
   * Timestamp when the user was last updated
   */
  updatedAt?: string;
  [k: string]: unknown;
}
