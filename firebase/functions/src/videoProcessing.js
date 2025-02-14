/* eslint-disable max-len */
import * as functions from "firebase-functions/v1";
import {defineString} from "firebase-functions/params";
import admin from "firebase-admin";
import OpenAI from "openai";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

// Constants for configuration
const OPENAI_API_KEY = defineString("OPENAI_API_KEY");
const STORAGE_BUCKET = defineString("STORAGE_BUCKET");

// Define clear states that represent processing stages
const ProcessingState = {
  // Initial states
  CREATED: "created", // Document created, no video yet

  // Processing pipeline states - each state means "ready to process this step"
  READY_FOR_TRANSCRIPTION: "ready_for_transcription", // Video uploaded, ready to begin
  READY_FOR_MODERATION: "ready_for_moderation", // Transcription done, ready for moderation
  READY_FOR_TAGGING: "ready_for_tagging", // Moderation passed, ready for tagging

  // Terminal states
  COMPLETE: "complete", // Successfully processed
  REJECTED: "rejected", // Failed moderation
  FAILED: "failed", // Technical error occurred
};

// Valid state transitions
const ValidTransitions = {
  [ProcessingState.CREATED]: [
    ProcessingState.READY_FOR_TRANSCRIPTION,
  ],
  [ProcessingState.READY_FOR_TRANSCRIPTION]: [
    ProcessingState.READY_FOR_MODERATION,
    ProcessingState.FAILED,
  ],
  [ProcessingState.READY_FOR_MODERATION]: [
    ProcessingState.READY_FOR_TAGGING,
    ProcessingState.REJECTED,
    ProcessingState.FAILED,
  ],
  [ProcessingState.READY_FOR_TAGGING]: [
    ProcessingState.COMPLETE,
    ProcessingState.FAILED,
  ],

  // Terminal states have no valid transitions out
  [ProcessingState.COMPLETE]: [],
  [ProcessingState.REJECTED]: [],
  [ProcessingState.FAILED]: [],
};

/**
 * Validates if a state transition is allowed in the video processing state machine
 * @param {string} fromState - The current state
 * @param {string} toState - The target state
 * @return {boolean} Whether the transition is valid
 */
function isValidTransition(fromState, toState) {
  const validNextStates = ValidTransitions[fromState] || [];
  return validNextStates.includes(toState);
}

/**
 * Firestore trigger that handles the video processing state machine.
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

      // Validate state transition
      if (!isValidTransition(beforeData.processingStatus, afterData.processingStatus)) {
        console.error(`Invalid state transition for ${contentId}`);
        await change.after.ref.update({
          processingStatus: ProcessingState.FAILED,
          error: `Invalid state transition from ${beforeData.processingStatus} to ${afterData.processingStatus}`,
          errorDetails: {
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
        });
        return;
      }

      try {
        switch (afterData.processingStatus) {
          case ProcessingState.READY_FOR_TRANSCRIPTION:
            console.log(`Starting transcription for ${contentId}`);
            await transcribeVideo(change.after);
            break;

          case ProcessingState.READY_FOR_MODERATION:
            console.log(`Starting moderation for ${contentId}`);
            await moderateContent(change.after);
            break;

          case ProcessingState.READY_FOR_TAGGING:
            console.log(`Starting tagging for ${contentId}`);
            await generateTags(change.after);
            break;

          default:
            console.log(`No processing needed for state: ${afterData.processingStatus}`);
        }
      } catch (error) {
        console.error(`Error processing ${contentId}:`, error);
        await change.after.ref.update({
          processingStatus: ProcessingState.FAILED,
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
 * @param {FirebaseFirestore.DocumentSnapshot} docRef - Firestore document reference for the content
 * @return {Promise<void>}
 */
async function transcribeVideo(docRef) {
  const data = docRef.data();
  const contentId = docRef.id;
  let tempFilePath;

  console.log(`Starting transcription for content ${contentId}`, {
    videoPath: data.videoPath,
    currentState: data.processingStatus,
  });

  try {
    const openai = new OpenAI({
      apiKey: OPENAI_API_KEY.value(),
    });

    const videoPath = data.videoPath;
    if (!videoPath) {
      throw new Error("Video path not found in document");
    }

    const gsPath = videoPath.replace("gs://", "").split("/");
    const bucketName = gsPath.shift();
    const filePath = gsPath.join("/");

    const bucket = admin.storage().bucket(bucketName);
    const file = bucket.file(filePath);

    const [metadata] = await file.getMetadata();
    const contentType = metadata.contentType;

    const acceptedFormats = ["flac", "m4a", "mp3", "mp4", "mpeg", "mpga", "oga", "ogg", "wav", "webm"];
    const fileExtension = contentType.split("/").pop();

    if (!acceptedFormats.includes(fileExtension)) {
      throw new Error(`Unsupported file format: ${fileExtension}. Supported formats: ${acceptedFormats.join(", ")}`);
    }

    tempFilePath = path.join(os.tmpdir(), `${contentId}-${Date.now()}.${fileExtension}`);
    console.log(`Downloading video ${contentId} to:`, tempFilePath);

    await file.download({destination: tempFilePath});
    console.log(`Successfully downloaded video ${contentId}`);

    console.log("Sending to OpenAI for transcription...");
    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempFilePath),
      model: "whisper-1",
      response_format: "verbose_json",
      timestamp_granularities: ["word"],
    });

    // Update to next state with transcription results
    await docRef.ref.update({
      processingStatus: ProcessingState.READY_FOR_MODERATION,
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
      processingStatus: ProcessingState.FAILED,
      error: error instanceof Error ? error.message : "Unknown error",
      errorDetails: {
        message: error.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    throw error;
  } finally {
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
      console.log(`Cleaned up temporary file for video ${contentId}`);
    }
  }
}

/**
 * Performs content moderation on the transcribed video content.
 * @param {FirebaseFirestore.DocumentSnapshot} docRef - Firestore document reference for the content
 * @return {Promise<void>}
 */
async function moderateContent(docRef) {
  const contentId = docRef.id;
  console.log(`Starting moderation for content ${contentId}`);

  // Simulate some processing time
  await new Promise((resolve) => setTimeout(resolve, 2000));

  // Simulate 90% pass rate
  const shouldPass = Math.random() < 0.9;

  console.log(`Moderation decision for content ${contentId}:`, {
    passed: shouldPass,
  });

  if (shouldPass) {
    await docRef.ref.update({
      processingStatus: ProcessingState.READY_FOR_TAGGING,
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
 * Generates tags for the content based on the transcription and moderation results.
 * @param {FirebaseFirestore.DocumentSnapshot} docRef - Firestore document reference for the content
 * @return {Promise<void>}
 */
async function generateTags(docRef) {
  const contentId = docRef.id;
  console.log(`Starting tagging for content ${contentId}`);

  // Simulate some processing time
  await new Promise((resolve) => setTimeout(resolve, 2000));

  await docRef.ref.update({
    processingStatus: ProcessingState.COMPLETE,
    tags: ["restaurant", "indoor"],
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Initializes processing for newly created content.
 */
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

      // Start in CREATED state if no video path
      if (!data.videoPath) {
        console.log(`Setting to CREATED state - no video path for content ${contentId}`);
        await snap.ref.update({
          processingStatus: ProcessingState.CREATED,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Initialize the processing pipeline
      await snap.ref.update({
        processingStatus: ProcessingState.READY_FOR_TRANSCRIPTION,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

/**
 * Handles video upload events.
 */
export const handleVideoUpload = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "2GB",
      failurePolicy: true,
    })
    .storage
    .bucket(STORAGE_BUCKET.value())
    .object()
    .onFinalize(async (object) => {
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
      const contentId = pathParts[2]?.replace(".mp4", "");

      if (!contentId) {
        console.error("Could not extract contentId from path:", object.name);
        return;
      }

      try {
        const docRef = admin.firestore()
            .collection("content")
            .doc(contentId);

        const doc = await docRef.get();
        if (!doc.exists) {
          console.error(`Document ${contentId} not found`);
          return;
        }

        console.log("Current document state:", doc.data());

        // Start processing pipeline
        await docRef.update({
          processingStatus: ProcessingState.READY_FOR_TRANSCRIPTION,
          videoPath: `gs://${object.bucket}/${object.name}`,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Updated document ${contentId} to start processing`);
      } catch (error) {
        console.error(`Failed to update document ${contentId}:`, error);
      }
    });
