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
import {defineString} from "firebase-functions/params";
import vision from "@google-cloud/vision";
// import * as admin from "firebase-admin";

const API_KEY = defineString("GOOGLE_MAPS_API_KEY");

// Fetch Neighborhood Data
/**
 * Fetches information from the Knowledge Graph API for a given landmark ID.
 * @param {string} latitude -   The latitude of the landmark.
 * @param {string} longitude - The longitude of the landmark.
 * @return {Promise<Object>} The information from the Knowledge Graph API.
 */
async function fetchNeighborhoodData(latitude, longitude) {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&result_type=neighborhood&key=${API_KEY.value()}`;

  try {
    const response = await fetch(url);
    const data = await response.json();
    console.log(data);
    if (data.results && data.results.length > 0) {
      const neighborhood = data.results[0];
      return {
        place_id: neighborhood.place_id,
        name: neighborhood.address_components[0].long_name,
        bounds: neighborhood.geometry.bounds,
        formatted_address: neighborhood.formatted_address,
      };
    }
    return null;
  } catch (error) {
    console.error("Error fetching neighborhood data:", error);
    return null;
  }
}

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
  if (!context?.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "annotateImage must be called while authenticated.",
    );
  }

  const client = new vision.ImageAnnotatorClient();

  try {
    const [result] = await client.annotateImage(data);

    // If no landmarks found, return null
    if (!result.landmarkAnnotations?.length) {
      return {landmark: null};
    }

    // Get the first landmark
    const firstLandmark = result.landmarkAnnotations[0];
    console.log(firstLandmark);
    const location = firstLandmark.locations[0].latLng;

    // Fetch Knowledge Graph data for just this landmark
    const neighborhoodData = await fetchNeighborhoodData(
        location.latitude,
        location.longitude,
    );

    console.log(neighborhoodData);

    // After getting neighborhoodData but before returning
    // if (neighborhoodData?.place_id) {
    //   // Store/update neighborhood reference data
    //   const db = admin.firestore();
    //   await db.collection("neighborhoods").
    // doc(neighborhoodData.place_id).set({
    //     name: neighborhoodData.name,
    //     bounds: neighborhoodData.bounds,
    //     landmarks: admin.firestore.FieldValue.arrayUnion({
    //       name: firstLandmark.description,
    //       location: new admin.firestore.GeoPoint(
    //           location.latitude,
    //           location.longitude,
    //       ),
    //     }),
    //   }, {merge: true}); // Use merge to preserve existing landmark entries
    // }

    // Return a simplified response with just what we need
    const landmark = {
      landmark: {
        name: firstLandmark.description,
        score: firstLandmark.score,
        locations: firstLandmark.locations,
        neighborhood: neighborhoodData,
      },
    };
    console.log(landmark);
    return landmark;
  } catch (err) {
    console.error("Error calling Vision API:", err);
    throw new functions.https.HttpsError("internal", err.message);
  }
});
