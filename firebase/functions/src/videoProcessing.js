/* eslint-disable max-len */
import * as functions from "firebase-functions/v1";
import {defineString} from "firebase-functions/params";
import admin from "firebase-admin";
import OpenAI from "openai";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import * as glob from "glob";

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
  [ProcessingState.CREATED]: [ProcessingState.READY_FOR_TRANSCRIPTION],
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
  // const validNextStates = ValidTransitions[fromState] || [];
  // return validNextStates.includes(toState);
  console.log("valid transition", ValidTransitions[fromState]);
  return true;
}

/**
 * Firestore trigger that handles the video processing state machine.
 */
export const handleVideoProcessing = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "4GB",
    })
    .firestore.document("content/{contentId}")
    .onUpdate(async (change, context) => {
    // Run cleanup at start of function
      cleanupTempDirectory();
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const contentId = context.params.contentId;

      // Pure state machine - only care about state transitions
      if (beforeData.processingStatus === afterData.processingStatus) {
        console.log(`No status change for ${contentId}: ${afterData.processingStatus}`);
        return null;
      }

      console.log(
          `State transition for ${contentId}: ${beforeData.processingStatus} -> ${afterData.processingStatus}`,
      );

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
  let fileStream;

  logMemoryUsage("start-transcription");

  try {
    const openai = new OpenAI({
      apiKey: OPENAI_API_KEY.value(),
    });

    if (!data.videoUrl) {
      throw new Error("Video URL not found in document");
    }

    // Enhanced debugging for storage path parsing
    console.log("Processing video path:", {
      originalPath: data.videoUrl,
      contentId: contentId,
    });

    // Parse storage path
    const gsPath = data.videoUrl.replace("gs://", "").split("/");
    const bucketName = gsPath.shift();
    const filePath = gsPath.join("/");
    const fileExtension = filePath.split(".").pop().toLowerCase();

    // Add debug logging for parsed paths
    console.log("Parsed storage paths:", {
      gsPath,
      bucketName,
      filePath,
      fileExtension,
    });

    // Validate file format
    const acceptedFormats = ["mp3", "mp4", "mpeg", "mpga", "wav", "webm"];
    if (!acceptedFormats.includes(fileExtension)) {
      throw new Error(`Unsupported file format: ${fileExtension}`);
    }

    // Check file size
    const bucket = admin.storage().bucket(bucketName);
    const file = bucket.file(filePath);
    const [metadata] = await file.getMetadata();

    // Add debug logging for file metadata
    console.log("File metadata:", {
      contentType: metadata.contentType,
      size: metadata.size,
      mediaLink: metadata.mediaLink,
      name: metadata.name,
      bucket: metadata.bucket,
      customMetadata: metadata.metadata,
    });

    const fileSizeInMB = parseInt(metadata.size) / (1024 * 1024);
    if (fileSizeInMB > 25) {
      throw new Error(`File size ${fileSizeInMB.toFixed(2)}MB exceeds limit of 25MB`);
    }

    logMemoryUsage("before-download");

    // Download file
    tempFilePath = path.join(os.tmpdir(), `${contentId}-${Date.now()}.${fileExtension}`);
    console.log("Downloading to temp path:", tempFilePath);

    await file.download({destination: tempFilePath});

    // Verify downloaded file
    const downloadedStats = fs.statSync(tempFilePath);
    console.log("Downloaded file details:", {
      exists: fs.existsSync(tempFilePath),
      size: downloadedStats.size,
      expectedSize: metadata.size,
      matches: downloadedStats.size === parseInt(metadata.size),
      tempPath: tempFilePath,
    });

    // More thorough file analysis
    let detectedFormat;
    try {
      const buffer = fs.readFileSync(tempFilePath, {start: 0, end: 1024});

      // Common video file signatures
      const signatures = {
        mp4: ["66747970"], // 'ftyp'
        quicktime: ["6d6f6f76"], // 'moov'
        iso2: ["69736f32"], // 'iso2'
        mp4a: ["6d703461"], // 'mp4a'
      };

      const fileStart = buffer.slice(0, 16).toString("hex");
      const analysis = {
        firstBytes: fileStart,
        knownSignatures: Object.entries(signatures).filter(([_, sig]) =>
          fileStart.includes(sig[0])).map(([name]) => name),
        possibleContainer: fileStart.includes("66747970") ? "MP4" :
                         fileStart.includes("6d6f6f76") ? "QuickTime" : "Unknown",
        mimeType: metadata.contentType,
        customMetadata: metadata.metadata,
      };

      console.log("Detailed file analysis:", analysis);

      // Set the appropriate content type based on the actual container format
      detectedFormat = analysis.possibleContainer === "QuickTime" ? "video/quicktime" :
                      analysis.possibleContainer === "MP4" ? "video/mp4" :
                      "video/mp4"; // fallback to mp4
    } catch (readError) {
      console.error("Error analyzing file:", readError);
      detectedFormat = "video/mp4"; // fallback to mp4 if analysis fails
    }

    logMemoryUsage("after-download");

    // Replace FormData creation with direct file stream
    const fileStream = fs.createReadStream(tempFilePath);

    console.log("Preparing OpenAI request:", {
      filePath: tempFilePath,
      fileSize: fs.statSync(tempFilePath).size,
      streamReady: !!fileStream,
      fileDescriptor: fileStream.fd,
      encoding: fileStream.readableEncoding,
    });

    // Update the OpenAI API call with the detected format
    const transcription = await openai.audio.transcriptions.create({
      file: fs.createReadStream(tempFilePath, {
        filepath: tempFilePath,
        contentType: detectedFormat,
      }),
      model: "whisper-1",
      response_format: "text",
    });

    console.log("Transcription response:", {
      hasText: !!transcription,
      textLength: transcription?.length,
    });

    // Clean up both files if needed
    fs.unlinkSync(tempFilePath);

    logMemoryUsage("after-cleanup");

    // Update document
    await docRef.ref.update({
      processingStatus: ProcessingState.READY_FOR_MODERATION,
      transcriptionText: transcription,
      fileFormat: fileExtension,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logMemoryUsage("end-transcription");
  } catch (error) {
    // Enhanced error logging
    console.error("Transcription error details:", {
      contentId,
      errorMessage: error.message,
      errorName: error.name,
      tempFileExists: tempFilePath ? fs.existsSync(tempFilePath) : false,
      streamState: fileStream ? fileStream.readableState : null,
    });

    // Clean up resources
    if (fileStream) {
      fileStream.destroy();
    }
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
    }

    await docRef.ref.update({
      processingStatus: ProcessingState.FAILED,
      error: error.message,
      errorDetails: {
        message: error.message,
        name: error.name,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        technicalDetails: error.stack,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    throw error;
  } finally {
    // Ensure cleanup happens in all cases
    if (fileStream) {
      fileStream.destroy();
    }
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      try {
        fs.unlinkSync(tempFilePath);
      } catch (cleanupError) {
        console.warn("Failed to cleanup temp file:", cleanupError);
      }
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

  const data = docRef.data();
  if (!data.transcriptionText) {
    throw new Error("No transcription found for content");
  }

  const openai = new OpenAI({
    apiKey: OPENAI_API_KEY.value(),
  });

  try {
    // Call OpenAI's moderation endpoint
    const moderationResponse = await openai.moderations.create({
      input: data.transcriptionText,
    });

    const result = moderationResponse.results[0];
    console.log(`Moderation results for ${contentId}:`, result);

    // Check if any category is flagged
    const isFlagged = result.flagged;

    if (isFlagged) {
      await docRef.ref.update({
        processingStatus: ProcessingState.REJECTED,
        moderationResults: {
          flagged: true,
          categories: result.categories,
          categoryScores: result.category_scores,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.ref.update({
        processingStatus: ProcessingState.READY_FOR_TAGGING,
        moderationResults: {
          flagged: false,
          categories: result.categories,
          categoryScores: result.category_scores,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    console.error(`Error moderating content ${contentId}:`, error);
    throw error;
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

  const data = docRef.data();
  if (!data.transcriptionText) {
    throw new Error("No transcription found for content");
  }

  const openai = new OpenAI({
    apiKey: OPENAI_API_KEY.value(),
  });

  const prompt = `Analyze this video transcription and:
1. Select relevant one or at most two relevant tags from this exact list: restaurant, drinks, events, music, art, outdoors, shopping, coffee
2. Generate a short, engaging caption (30-60 characters) with emoji that captures the vibe

Examples of good captions:
- "Weekend brunch vibes at Caroline 🍳"
- "Live music at Firehouse 🎷"
- "Secret speakeasy vibes 🍸"
- "Coffee and pastries at Dawn ☕️"
- "Street art hunting downtown 🎨"

Please format your response as JSON with these exact keys:
{
  "tags": ["tag1", "tag2"],
  "caption": "Your caption here"
}

Transcription: "${data.transcriptionText}"`;

  try {
    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo-preview",
      messages: [{
        role: "user",
        content: prompt,
      }],
      response_format: {type: "json_object"},
    });

    const response = JSON.parse(completion.choices[0].message.content);
    console.log(`Generated content for ${contentId}:`, response);

    // Validate tags against FilterCategory
    const validTags = response.tags.filter((tag) =>
      ["restaurant", "drinks", "events", "music", "art", "outdoors", "shopping", "coffee"].includes(tag),
    );

    // Move the video file to its final location
    const sourceVideoPath = data.videoUrl;

    if (!sourceVideoPath) {
      throw new Error("Video URL not found in document");
    }

    // Parse the source path
    const gsPath = sourceVideoPath.replace("gs://", "").split("/");
    const bucketName = gsPath.shift();
    const sourcePath = gsPath.join("/");

    // Create the destination path in the content folder
    const fileName = path.basename(sourcePath);
    const destinationPath = `content/${fileName}`;

    console.log("Moving video file:", {
      from: sourcePath,
      to: destinationPath,
      bucket: bucketName,
    });

    // Get bucket reference
    const bucket = admin.storage().bucket(bucketName);
    const sourceFile = bucket.file(sourcePath);
    const destinationFile = bucket.file(destinationPath);

    // Move the file
    try {
      await sourceFile.move(destinationFile);
      console.log("Successfully moved video file to content folder");
    } catch (moveError) {
      console.error("Error moving file:", moveError);
      throw new Error(`Failed to move video file: ${moveError.message}`);
    }

    // Update document with new video URL and complete status
    await docRef.ref.update({
      processingStatus: ProcessingState.COMPLETE,
      tags: validTags,
      caption: response.caption,
      videoUrl: `gs://${bucketName}/${destinationPath}`,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(`Error in final processing stage for ${docRef.id}:`, error);
    throw error;
  }
}

/**
 * Initializes processing for newly created content.
 */
export const initializeVideoProcessing = functions
    .runWith({
      timeoutSeconds: 540,
      memory: "2GB",
    })
    .firestore.document("content/{contentId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      const contentId = context.params.contentId;

      console.log(`Initializing processing for new content ${contentId}:`, {
        initialState: data.processingStatus,
        hasVideoUrl: !!data.videoUrl,
      });

      // Start in CREATED state if no video URL
      if (!data.videoUrl) {
        console.log(`Setting to CREATED state - no video URL for content ${contentId}`);
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
      memory: "4GB",
      failurePolicy: true,
    })
    .storage.bucket(STORAGE_BUCKET.value())
    .object()
    .onFinalize(async (object) => {
      cleanupTempDirectory();

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

      // Extract placeId from path (processing/placeId/contentId.mp4)
      const pathParts = object.name.split("/");
      console.log("Path parts:", pathParts);
      const placeId = pathParts[1];
      const contentId = pathParts[2]?.replace(".mp4", "");

      if (!contentId || !placeId) {
        console.error("Could not extract contentId or placeId from path:", object.name);
        return;
      }

      try {
        // Get the place document to fetch its neighborhoodId
        const placeDoc = await admin.firestore().collection("places").doc(placeId).get();

        if (!placeDoc.exists) {
          throw new Error(`Place document ${placeId} not found`);
        }

        const place = placeDoc.data();
        const neighborhoodId = place.neighborhoodId;

        if (!neighborhoodId) {
          throw new Error(`Place ${placeId} has no neighborhoodId`);
        }

        const docRef = admin.firestore().collection("content").doc(contentId);
        const doc = await docRef.get();

        if (!doc.exists) {
          console.error(`Document ${contentId} not found`);
          return;
        }

        // Start processing pipeline with neighborhoodId
        await docRef.update({
          processingStatus: ProcessingState.READY_FOR_TRANSCRIPTION,
          videoUrl: `gs://${object.bucket}/${object.name}`,
          neighborhoodId: neighborhoodId,
          placeIds: [placeId], // Ensure placeId is set
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Updated document ${contentId} to start processing with neighborhoodId: ${neighborhoodId}`);
      } catch (error) {
        console.error(`Failed to update document ${contentId}:`, error);

        // Update content document with error state if possible
        try {
          const docRef = admin.firestore().collection("content").doc(contentId);
          await docRef.update({
            processingStatus: ProcessingState.FAILED,
            error: error.message,
            errorDetails: {
              message: error.message,
              stage: "initialization",
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (updateError) {
          console.error("Failed to update error state:", updateError);
        }
      }
    });

/**
 * Cleans up any leftover media files in the temporary directory.
 * This helps prevent disk space issues from failed executions.
 * Called on cold starts to ensure clean state.
 */
function cleanupTempDirectory() {
  const tmpDir = os.tmpdir();
  const files = glob.sync(
      path.join(tmpDir, "*.{mp3,mp4,wav,m4a,mpeg,mpga,oga,ogg,webm,flac}"),
  );

  for (const file of files) {
    try {
      fs.unlinkSync(file);
      console.log(`Cleaned up old temp file: ${file}`);
    } catch (error) {
      console.warn(`Failed to delete temp file ${file}:`, error.message);
    }
  }
}

/**
 * Logs current memory usage statistics with a label for tracking memory consumption at different stages
 * @param {string} label - Identifier for the logging point (e.g., "start-transcription", "after-download")
 * @return {void}
 */
function logMemoryUsage(label) {
  const used = process.memoryUsage();
  console.log(`Memory usage at ${label}:`, {
    rss: `${Math.round(used.rss / 1024 / 1024)}MB`,
    heapTotal: `${Math.round(used.heapTotal / 1024 / 1024)}MB`,
    heapUsed: `${Math.round(used.heapUsed / 1024 / 1024)}MB`,
    external: `${Math.round(used.external / 1024 / 1024)}MB`,
  });
}
