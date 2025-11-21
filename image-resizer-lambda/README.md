# Waitque Image Resizer Lambda

Resizes any image uploaded to `waitque-upload-bucket` under the `RAW/` prefix to a 100×100 JPEG thumbnail and saves it to the `OPTIMIZED/` prefix.

## Deployment Steps

1. Clone the repo
2. `cd lambda && npm install` (this installs sharp + AWS SDK)
3. `cd ../infrastructure`
4. `terraform init`
5. `terraform plan`
6. `terraform apply`

The Lambda will be created and automatically wired to your existing S3 bucket.

## Updating the function later

Any time you change `lambda/index.js`:
- `cd lambda && npm install` (if dependencies changed)
- `cd ../infrastructure && terraform apply` (it will re-zip and update the Lambda)

## Building the Sharp Layer (One-Time Setup)

The Sharp library needs to be pre-built for Lambda's Linux runtime. Use Docker for this:

1. Ensure Docker is installed/running.
2. From the repo root:  
   ```bash
   # Build the image
   docker build -t sharp-builder .

   # Run the container and extract the layer to your local dir
   docker run --rm -v $(pwd)/layer:/output sharp-builder