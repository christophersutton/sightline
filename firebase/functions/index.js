/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import * as functions from "firebase-functions/v1";
import vision from "@google-cloud/vision";

// This will allow only requests with an auth token to access the Vision
// API, including anonymous ones.
// It is highly recommended to limit access only to signed-in users. This may
// be done by adding the following condition to the if statement:
//    || context.auth.token?.firebase?.sign_in_provider === 'anonymous'
//
// For more fine-grained control, you may add additional failure checks, ie:
//    || context.auth.token?.firebase?.email_verified === false
// Also see: https://firebase.google.com/docs/auth/admin/custom-claims
export const annotateImage = functions.https.onCall(async (data, context) => {
  // Check if the caller is authenticated
  if (!context?.auth) {
    console.error("Unauthenticated access attempt.");
    throw new functions.https.HttpsError(
        "unauthenticated",
        "annotateImage must be called while authenticated.",
    );
  }

  // Log authentication details if required
  // (do not log sensitive details in production)
  console.log("annotateImage called by user:", context.auth.uid);

  // Log the request data for debugging
  // (you can remove sensitive fields in production)
  console.log("Request Data:", JSON.stringify(data, null, 2));

  // Additional basic validation and logging for the payload structure
  if (!data.image || !data.image.content) {
    console.error("Malformed request: Missing image content.");
  }
  if (!data.features || !Array.isArray(data.features)) {
    console.warn("'features' expects array. Received:", data.features);
  }

  // Initialize the Vision client
  const client = new vision.ImageAnnotatorClient();

  try {
    // Call the Vision API; the method returns an array
    // where the first element is the result.
    const [result] = await client.annotateImage(data);

    // Log the response from the Vision API
    console.log("Vision API response:", JSON.stringify(result, null, 2));

    // Return the result to the client
    return result;
  } catch (err) {
    // Log the error with as much detail as possible for debugging.
    console.error("Error calling Vision API:", err);
    throw new functions.https.HttpsError("internal", err.message);
  }
});
