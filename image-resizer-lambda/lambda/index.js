const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');
const path = require('path');

const s3Client = new S3Client();
const TARGET_SIZE = 100;

exports.handler = async (event) => {
  for (const record of event.Records) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

    // Safety check - only process files in RAW/ (S3 filter should already enforce this)
    if (!key.startsWith('RAW/')) {
      console.log(`Skipping ${key} - not in RAW/ prefix`);
      continue;
    }

    const destKey = key.replace('RAW/', 'OPTIMIZED/');

    try {
      // Download original image
      const { Body, ContentType } = await s3Client.send(
        new GetObjectCommand({ Bucket: bucket, Key: key })
      );

      // Convert stream → buffer
      const chunks = [];
      for await (const chunk of Body) {
        chunks.push(chunk);
      }
      const originalBuffer = Buffer.concat(chunks);

      // Resize to exactly 100×100 (cover = crop to fill, center by default)
      const resizedBuffer = await sharp(originalBuffer)
        .resize(TARGET_SIZE, TARGET_SIZE, {
          fit: 'cover',
          position: 'centre' // or 'entropy' for smart crop
        })
        .jpeg({ quality: 85 })          // always output as JPEG for thumbnails
        .toBuffer();

      // Upload thumbnail
      await s3Client.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: destKey,
          Body: resizedBuffer,
          ContentType: 'image/jpeg',
          CacheControl: 'max-age=31536000' // optional: cache thumbnails for 1 year
        })
      );

      console.log(`Successfully created thumbnail: ${destKey}`);
    } catch (error) {
      console.error(`Error processing ${key}:`, error);
      throw error; // Let Lambda retry the event
    }
  }

  return { status: 'success' };
};