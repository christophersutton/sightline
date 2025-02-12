/* eslint-disable max-len */
import * as functions from "firebase-functions/v1";
import {defineString} from "firebase-functions/params";
import admin from "firebase-admin";
import OpenAI from "openai";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

// Constants for configuration

// Replace the current OpenAI initialization
const OPENAI_API_KEY = defineString("OPENAI_API_KEY");

// Define clear states that represent the actual processing stages
const ProcessingState = {
  AWAITING_UPLOAD: "awaiting_upload", // Initial state when doc is created
  PENDING: "pending", // Video uploaded, ready to process
  MODERATING: "moderating",
  TAGGING: "tagging",
  COMPLETE: "complete",
  ERROR: "error",
  REJECTED: "rejected",
};

/**
 * Processes a video file through multiple AI services:
 * 1. Stores in Firebase Storage
 * 2. Transcribes using OpenAI Whisper
 * 3. Moderates content
 * 4. Classifies content with tags
 */

/**
 * Firestore trigger that handles the video processing state machine.
 * Monitors changes to content documents and routes to appropriate handlers
 * based on the processing status.
 *
 * @param {functions.Change<functions.firestore.DocumentSnapshot>} change - Contains state before and after the change
 * @param {functions.EventContext} context - Metadata about the event
 * @returns {Promise<void>}
 */
export const handleVideoProcessing = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "2GB",
    })
    .firestore
    .document("content/{contentId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const contentId = context.params.contentId;

      // Pure state machine - only care about state transitions
      if (beforeData.processingStatus === afterData.processingStatus) {
        console.log(`No status change for ${contentId}: ${afterData.processingStatus}`);
        return null;
      }

      console.log(`State transition for ${contentId}: ${beforeData.processingStatus} -> ${afterData.processingStatus}`);

      try {
        switch (afterData.processingStatus) {
          case ProcessingState.PENDING:
            console.log(`Starting transcription for ${contentId}`);
            await transcribeVideo(change.after);
            break;

          case ProcessingState.MODERATING:
            console.log(`Starting moderation for ${contentId}`);
            await moderateContent(change.after);
            break;

          case ProcessingState.TAGGING:
            console.log(`Starting tagging for ${contentId}`);
            await generateTags(change.after);
            break;

          default:
            console.log(`Unhandled state for ${contentId}: ${afterData.processingStatus}`);
        }
      } catch (error) {
        console.error(`Error processing ${contentId}:`, error);
        await change.after.ref.update({
          processingStatus: ProcessingState.ERROR,
          error: error.message,
          errorDetails: {
            state: afterData.processingStatus,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            stack: error.stack,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

/**
 * Performs video transcription using OpenAI's Whisper API.
 * Downloads video file temporarily, transcribes, then cleans up.
 *
 * @param {functions.firestore.DocumentSnapshot} docRef - Reference to the content document
 * @return {Promise<void>}
 */
async function transcribeVideo(docRef) {
  const data = docRef.data();
  const contentId = docRef.id;
  let tempFilePath;
  let tempAudioPath;

  console.log(`Starting transcription for content ${contentId}`, {
    videoPath: data.videoPath,
    currentState: data.processingStatus,
  });

  try {
    // Initialize OpenAI with the API key at runtime
    const openai = new OpenAI({
      apiKey: OPENAI_API_KEY.value(),
    });

    // Get the video file reference from the stored path
    const videoPath = data.videoPath;
    if (!videoPath) {
      throw new Error("Video path not found in document");
    }

    // Extract the full path from the gs:// URL
    const gsPath = videoPath.replace("gs://", "").split("/");
    const bucketName = gsPath.shift();
    const filePath = gsPath.join("/");

    const bucket = admin.storage().bucket(bucketName);
    const file = bucket.file(filePath);

    // Get file metadata to check format
    const [metadata] = await file.getMetadata();
    const contentType = metadata.contentType;

    // List of formats accepted by Whisper API
    const acceptedFormats = ["flac", "m4a", "mp3", "mp4", "mpeg", "mpga", "oga", "ogg", "wav", "webm"];
    const fileExtension = contentType.split("/").pop();

    if (!acceptedFormats.includes(fileExtension)) {
      throw new Error(`Unsupported file format: ${fileExtension}. Supported formats: ${acceptedFormats.join(", ")}`);
    }

    // Create a temporary file path
    tempFilePath = path.join(os.tmpdir(), `${contentId}-${Date.now()}.${fileExtension}`);
    console.log(`Downloading video ${contentId} to:`, tempFilePath);

    // Download the file
    await file.download({destination: tempFilePath});
    console.log(`Successfully downloaded video ${contentId}`);

    // Request transcription from OpenAI
    console.log("Sending to OpenAI for transcription...");
    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempFilePath),
      model: "whisper-1",
      response_format: "verbose_json",
      timestamp_granularities: ["word"],
    });

    // When done, update directly to next state
    await docRef.ref.update({
      processingStatus: ProcessingState.MODERATING,
      transcriptionStatus: "completed",
      transcriptionText: transcription.text,
      transcriptionWords: transcription.words || [],
      fileFormat: fileExtension,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Successfully transcribed video ${contentId}`);
  } catch (error) {
    console.error(`Transcription failed for content ${contentId}:`, {
      error: error.message,
      stack: error.stack,
      videoPath: data.videoPath,
    });

    await docRef.ref.update({
      processingStatus: ProcessingState.ERROR,
      transcriptionStatus: "error",
      transcriptionError: error instanceof Error ? error.message : "Unknown error",
      errorType: "TRANSCRIPTION_ERROR",
      errorDetails: {
        message: error.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    throw error;
  } finally {
    // Clean up temp files
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
      console.log(`Cleaned up temporary file for video ${contentId}`);
    }
    if (tempAudioPath && fs.existsSync(tempAudioPath)) {
      fs.unlinkSync(tempAudioPath);
      console.log(`Cleaned up temporary audio file for video ${contentId}`);
    }
  }
}

/**
 * Simulates the content moderation process with a delay.
 * Has a 90% chance of passing moderation.
 * Updates document with moderation results.
 *
 * @param {functions.firestore.DocumentSnapshot} docRef - Reference to the content document
 * @return {Promise<void>}
 */
async function moderateContent(docRef) {
  const contentId = docRef.id;
  console.log(`Starting moderation simulation for content ${contentId}`);

  // Simulate some processing time
  await new Promise((resolve) => setTimeout(resolve, 2000));

  // Simulate 90% pass rate
  const shouldPass = Math.random() < 0.9;

  console.log(`Moderation decision for content ${contentId}:`, {
    passed: shouldPass,
  });

  if (shouldPass) {
    await docRef.ref.update({
      processingStatus: ProcessingState.TAGGING,
      moderationResults: {
        flagged: false,
        categories: {},
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    await docRef.ref.update({
      processingStatus: ProcessingState.REJECTED,
      moderationResults: {
        flagged: true,
        categories: {
          "violence": true,
        },
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Simulates the content tagging process with a delay.
 * Updates document with dummy tags and marks as complete.
 *
 * @param {functions.firestore.DocumentSnapshot} docRef - Reference to the content document
 * @return {Promise<void>}
 */
async function generateTags(docRef) {
  const contentId = docRef.id;
  console.log(`Starting tagging simulation for content ${contentId}`);

  // Simulate some processing time
  await new Promise((resolve) => setTimeout(resolve, 2000));

  await docRef.ref.update({
    processingStatus: ProcessingState.COMPLETE,
    tags: ["restaurant", "indoor"],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// 2. Background classification function
// export const classifyVideoContent = functions.firestore
//     .document("content/{contentId}")
//     .onUpdate(async (change, context) => {
//       const before = change.before.data();
//       const after = change.after.data();

//       if (
//         before.processingStatus !== "moderating" ||
//         after.processingStatus !== "tagging"
//       ) {
//         return;
//       }

//       try {
//         // Get video analysis from Video Intelligence API
//         const [operation] = await videoClient.annotateVideo({
//           inputUri: after.videoPath,
//           // We'll need to store this path during upload
//           features: [
//             "LABEL_DETECTION",
//             "EXPLICIT_CONTENT_DETECTION",
//             "SPEECH_TRANSCRIPTION",
//           ],
//         });

//         const [analysisResult] = await operation.promise();

//         // Use the analysis result in classification if needed
//         console.log("Video analysis complete:", analysisResult);

//         // Get content classification
//         const classificationResponse = await openai.chat.completions.create({
//           model: "gpt-4",
//           messages: [
//             {
//               role: "system",
//               content:
//               "Classify the following content into relevant tags. " +
//               // eslint-disable-next-line max-len
//               "Return only a JSON array of applicable tags from these options: " +
//               "[\"restaurant\", \"drinks\", \"outdoor\", \"indoor\", " +
//               "\"entertainment\", \"shopping\"]",
//             },
//             {
//               role: "user",
//               content: after.transcription,
//             },
//           ],
//           response_format: {type: "json_object"},
//         });

//         const tags = JSON.parse(
//             classificationResponse.choices[0].message.content,
//         );

//         // Update document with final status and tags
//         await change.after.ref.update({
//           processingStatus: "complete",
//           tags: tags,
//           updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//         });
//       } catch (error) {
//         console.error("Classification error:", error);
//         await change.after.ref.update({
//           processingStatus: "rejected",
//           processingError: {
//             stage: "classification",
//             message: error.message,
//             timestamp: admin.firestore.FieldValue.serverTimestamp(),
//           },
//         });
//       }
//     });

export const initializeVideoProcessing = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "2GB",
    })
    .firestore
    .document("content/{contentId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      const contentId = context.params.contentId;

      console.log(`Initializing processing for new content ${contentId}:`, {
        initialState: data.processingStatus,
        hasVideoPath: !!data.videoPath,
      });

      // Only start processing if we have a video path
      if (!data.videoPath) {
        console.log(`Skipping processing - no video path for content ${contentId}`);
        return null;
      }

      // Initialize the processing state
      await snap.ref.update({
        processingStatus: ProcessingState.PENDING,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

// At the top level, just define the parameter
const STORAGE_BUCKET = defineString("STORAGE_BUCKET");

export const handleVideoUpload = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "2GB",
      failurePolicy: true, // This enables automatic retries
    })
    .storage
    .bucket(STORAGE_BUCKET.value()) // Need to use .value() here specifically for bucket definition
    .object()
    .onFinalize(async (object) => {
      // Remove the validation since we're using the value at definition
      // If bucket isn't configured, the function won't deploy at all

      // Only handle files in the processing directory
      if (!object.name.startsWith("processing/")) {
        console.log(`Ignoring file outside processing directory: ${object.name}`);
        return;
      }

      console.log("Storage trigger fired:", {
        name: object.name,
        bucket: object.bucket,
        contentType: object.contentType,
        metadata: object.metadata,
        generation: object.generation,
      });

      // Extract contentId from path (processing/placeId/contentId.mp4)
      const pathParts = object.name.split("/");
      console.log("Path parts:", pathParts);
      // pathParts[0] would be "processing"
      // pathParts[1] would be placeId
      // pathParts[2] would be "contentId.mp4"
      const contentId = pathParts[2]?.replace(".mp4", "");

      if (!contentId) {
        console.error("Could not extract contentId from path:", object.name);
        return;
      }

      // Update the content document to PENDING to start processing
      try {
        const docRef = admin.firestore()
            .collection("content")
            .doc(contentId);

        // First check if document exists
        const doc = await docRef.get();
        if (!doc.exists) {
          console.error(`Document ${contentId} not found`);
          return;
        }

        console.log("Current document state:", doc.data());

        await docRef.update({
          processingStatus: ProcessingState.PENDING,
          videoPath: `gs://${object.bucket}/${object.name}`,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Updated document ${contentId} to PENDING`);
      } catch (error) {
        console.error(`Failed to update document ${contentId}:`, error);
      }
    });
