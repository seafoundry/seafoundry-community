/* tslint:disable */
/**
 * This file was automatically generated from JSON Schema.
 * DO NOT MODIFY IT BY HAND. Instead, modify the source JSON Schema file,
 * and run 'npm run generate-models' to regenerate this file.
 */

export interface Organization {
  /**
   * Unique identifier for the organization
   */
  id: string;
  /**
   * Organization name
   */
  name: string;
  /**
   * Organization domain/subdomain
   */
  domain: string;
  /**
   * Organization description
   */
  description?: string;
  /**
   * URL to organization logo
   */
  logoUrl?: string;
  /**
   * Organization website URL
   */
  website?: string;
  /**
   * List of activities the organization performs
   */
  activities?: string[];
  /**
   * Timestamp when the organization was created
   */
  createdAt: string;
  /**
   * Timestamp when the organization was last updated
   */
  updatedAt?: string;
  /**
   * ID of user who created the organization
   */
  createdById?: string;
  [k: string]: unknown;
}
