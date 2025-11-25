const { S3Client, GetObjectCommand, PutObjectCommand } = require('@aws-sdk/client-s3');
const sharp = require('sharp');
const path = require('path');

const s3Client = new S3Client();
const TARGET_SIZE = 100;

const KEYCLOAK_TOKEN_URL =
    `${process.env.KEYCLOAK_BASE_URL}/realms/rrs-waitque/protocol/openid-connect/token`;

const COMPANY_SERVICE_BASE_URL =
    `${process.env.COMPANY_SERVICE_BASE_URL}/api/system`;

exports.handler = async (event) => {
    for (const record of event.Records) {
        const bucket = record.s3.bucket.name;
        const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

        // Safety check - only process files in RAW/logo/ (S3 filter should already enforce this)
        if (!key.startsWith('RAW/logo/')) {
            console.log(`Skipping ${key} - not in RAW/logo/ prefix`);
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
                    fit: "cover",
                    position: "centre"
                })
                .webp({ quality: 90 })
                .toBuffer();


            // Upload thumbnail
            await s3Client.send(
                new PutObjectCommand({
                    Bucket: bucket,
                    Key: destKey,
                    Body: resizedBuffer,
                    ContentType: 'image/webp',
                    CacheControl: 'max-age=31536000' // optional: cache thumbnails for 1 year
                })
            );

            console.log(`Successfully created thumbnail: ${destKey}`);

            const keyParts = key.split("/");
            const companyId = keyParts[2];
            const token = await getAccessToken();

            const response = await fetch(
                `${COMPANY_SERVICE_BASE_URL}/companies/${companyId}/logoUrl`,
                {
                    method: "PUT",
                    headers: {
                        Authorization: `Bearer ${token}`,
                        Accept: "application/json",
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({ logoUrl: destKey }),
                }
            );

            console.log(`Response status for updating logoUrl: ${response.status}`);

            if (!response.ok) {
                return {
                    statusCode: response.status,
                    body: `Error fetching logoUrl: ${await response.text()}`
                };
            }

            const data = await response.json();

            console.log("Updated company logoUrl:", data);
        } catch (error) {
            console.error(`Error processing ${key}:`, error);
            throw error; // Let Lambda retry the event
        }
    }

    return { status: 'success' };
};

async function getAccessToken() {
    const body = new URLSearchParams({
        grant_type: "client_credentials",
        client_id: process.env.KEYCLOAK_CLIENT_ID,
        client_secret: process.env.KEYCLOAK_CLIENT_SECRET,
    });

    const response = await fetch(KEYCLOAK_TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body,
    });

    if (!response.ok) {
        throw new Error(`Keycloak token error: ${await response.text()}`);
    }

    const data = await response.json();
    return data.access_token;
}