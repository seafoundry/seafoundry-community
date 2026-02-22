import * as admin from "firebase-admin";

type SebastianConfig = {
  customPrompt?: string;
  enabledFunctions?: string[];
  maxTokens?: number;
};

/**
 * Fetch custom Sebastian prompt for an organization.
 * Returns undefined if no custom prompt is configured.
 */
export async function getCustomPromptForOrg(
  organizationId: string
): Promise<string | undefined> {
  try {
    const orgDoc = await admin
      .firestore()
      .collection("organizations")
      .doc(organizationId)
      .get();

    if (!orgDoc.exists) {
      return undefined;
    }

    const data = orgDoc.data();
    const sebastianConfig = data?.sebastianConfig as SebastianConfig | undefined;

    return sebastianConfig?.customPrompt;
  } catch (error) {
    console.error("Error fetching custom prompt:", {
      error: error instanceof Error ? {
        name: error.name,
        message: error.message,
      } : error,
      organizationId,
      timestamp: new Date().toISOString(),
    });
    return undefined;
  }
}
