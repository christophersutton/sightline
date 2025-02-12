import * as functions from "firebase-functions/v1";
import {defineString} from "firebase-functions/params";
import admin from "firebase-admin";
import {Storage} from "@google-cloud/storage";
import OpenAI from "openai";

const storage = new Storage();
const openai = new OpenAI({
  apiKey: defineString("OPENAI_API_KEY").value(),
});

// Constants for configuration
const ALLOWED_VIDEO_TYPES = ["video/mp4"];
const BUCKET_NAME = defineString("STORAGE_BUCKET").value();

/**
 * Processes a video file through multiple AI services:
 * 1. Stores in Firebase Storage
 * 2. Transcribes using OpenAI Whisper
 * 3. Moderates content
 * 4. Classifies content with tags
 */
export const processVideo = functions.https.onCall(async (data, context) => {
  if (!context?.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "processVideo must be called while authenticated.",
    );
  }

  try {
    const {videoBuffer, fileName, contentType} = data;

    // Validate input
    if (!videoBuffer || !fileName || !contentType) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required video data",
      );
    }

    if (!ALLOWED_VIDEO_TYPES.includes(contentType)) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid video format",
      );
    }

    // Upload to Firebase Storage
    const bucket = storage.bucket(BUCKET_NAME);
    const videoPath = `videos/${context.auth.uid}/${Date.now()}-${fileName}`;
    const file = bucket.file(videoPath);

    await file.save(Buffer.from(videoBuffer));
    const [url] = await file.getSignedUrl({
      action: "read",
      expires: "03-01-2500", // Long-lived URL
    });

    // Get transcription from Whisper
    const transcription = await openai.audio.transcriptions.create({
      file: videoBuffer,
      model: "whisper-1",
    });

    // Check content moderation
    const moderationResult = await openai.moderations.create({
      input: transcription.text,
    });

    // Get content classification
    const classificationResponse = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: "Classify the following content into relevant tags. " +
              // eslint-disable-next-line max-len
              "Return only a JSON array of applicable tags from these options: " +
              "[\"restaurant\", \"drinks\", \"outdoor\", \"indoor\", " +
              "\"entertainment\", \"shopping\"]",
        },
        {
          role: "user",
          content: transcription.text,
        },
      ],
      response_format: {type: "json_object"},
    });

    // Store results in Firestore
    const result = {
      videoUrl: url,
      transcription: transcription.text,
      moderation: moderationResult.results[0],
      classification: JSON.parse(
          classificationResponse.choices[0].message.content,
      ),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      userId: context.auth.uid,
    };

    await admin.firestore().collection("videoProcessing").add(result);

    return result;
  } catch (error) {
    console.error("Video processing error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});
