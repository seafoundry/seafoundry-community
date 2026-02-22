/* tslint:disable */
/**
 * This file was automatically generated from JSON Schema.
 * DO NOT MODIFY IT BY HAND. Instead, modify the source JSON Schema file,
 * and run 'npm run generate-models' to regenerate this file.
 */

export interface Invitation {
  /**
   * Unique identifier for the invitation
   */
  id: string;
  /**
   * Email address of the invitee
   */
  email: string;
  /**
   * ID of the organization the user is invited to
   */
  organizationId: string;
  /**
   * ID of the user who sent the invitation
   */
  invitedById: string;
  /**
   * Current status of the invitation
   */
  status: 'pending' | 'accepted' | 'declined' | 'expired';
  /**
   * Role assigned to the invitee upon acceptance
   */
  role?: 'admin' | 'practitioner_plus' | 'practitioner' | 'view_only';
  /**
   * Timestamp when the invitation expires
   */
  expiresAt: string;
  /**
   * Timestamp when the invitation was created
   */
  createdAt: string;
  /**
   * Timestamp when the invitation was accepted
   */
  acceptedAt?: string;
  /**
   * Whether the invitation email was sent
   */
  emailSent?: boolean;
  /**
   * Timestamp when the email was sent
   */
  emailSentAt?: string;
  /**
   * Error message if email sending failed
   */
  emailError?: string;
  /**
   * Timestamp when the invitation was resent
   */
  resentAt?: string;
  [k: string]: unknown;
}
