import * as functions from "firebase-functions/v1";
import {defineString} from "firebase-functions/params";
import vision from "@google-cloud/vision";
import admin from "firebase-admin";

const API_KEY = defineString("GOOGLE_MAPS_API_KEY");

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

    // Get the first landmark and extract its MID
    const firstLandmark = result.landmarkAnnotations[0];
    const landmarkMid = firstLandmark.mid;
    // Sanitize the landmark MID for use as a
    // Firestore document ID (remove leading
    // slash and replace inner "/" with "_")
    const sanitizedMid = landmarkMid ?
      landmarkMid.startsWith("/") ?
        landmarkMid.slice(1).replace(/\//g, "_") :
        landmarkMid :
      null;
    console.log(
        "Detected landmark:",
        firstLandmark,
        "Using sanitized MID:",
        sanitizedMid,
    );

    const location = firstLandmark.locations[0].latLng;

    // Fetch Knowledge Graph data for just this landmark
    const neighborhoodData = await fetchNeighborhoodData(
        location.latitude,
        location.longitude,
    );

    console.log("Neighborhood Data:", neighborhoodData);

    // Get a Firestore reference
    const db = admin.firestore();

    // Update the central neighborhood document with
    // landmark info, including the unique MID
    if (neighborhoodData?.place_id) {
      await db
          .collection("neighborhoods")
          .doc(neighborhoodData.place_id)
          .set(
              {
                name: neighborhoodData.name,
                bounds: neighborhoodData.bounds,
                landmarks: admin.firestore.FieldValue.arrayUnion({
                  mid: sanitizedMid,
                  name: firstLandmark.description,
                  location: new admin.firestore.GeoPoint(
                      location.latitude,
                      location.longitude,
                  ),
                }),
              },
              {merge: true},
          );
    }

    // Update the user's unlocked_neighborhoods
    // document to reference the landmark MID
    if (
      context.auth &&
      context.auth.uid &&
      neighborhoodData?.place_id &&
      sanitizedMid
    ) {
      await db
          .collection("users")
          .doc(context.auth.uid)
          .collection("unlocked_neighborhoods")
          .doc(neighborhoodData.place_id)
          .set(
              {
                unlocked_at: admin.firestore.FieldValue.serverTimestamp(),
                unlocked_by_landmark: "Vision API",
                landmark_mid: sanitizedMid,
                landmark_location: new admin.firestore.GeoPoint(
                    location.latitude,
                    location.longitude,
                ),
              },
              {merge: true},
          );
    }

    // Save or update the detected landmark in its own collection
    if (sanitizedMid) {
      await db.collection("detectedLandmarks").doc(sanitizedMid).set(
          {
            name: firstLandmark.description,
            locations: firstLandmark.locations,
            score: firstLandmark.score,
            detected_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
    }

    // Return a simplified response including the MID
    const landmark = {
      landmark: {
        name: firstLandmark.description,
        mid: sanitizedMid,
        score: firstLandmark.score,
        locations: firstLandmark.locations,
        neighborhood: neighborhoodData,
      },
    };
    console.log("Returning landmark response:", landmark);
    return landmark;
  } catch (err) {
    console.error("Error calling Vision API:", err);
    throw new functions.https.HttpsError("internal", err.message);
  }
});
