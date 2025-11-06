#!/bin/bash

set -euo pipefail

# Variables - customize these!
PROJECT_ID="[YOUR_PROJECT_ID]"
BUCKET_NAME="[YOUR_BUCKET_NAME]"
LOCATION="[YOUR_LOCATION]"
STATE_FILE_PREFIX="[YOUR_STATE_FILE_PREFIX]"

# Validate inputs
if [[ "$PROJECT_ID" == "[YOUR_PROJECT_ID]" ]] || [[ -z "$PROJECT_ID" ]]; then
  echo "Error: PROJECT_ID must be set"
  exit 1
fi

if [[ "$BUCKET_NAME" == "[YOUR_BUCKET_NAME]" ]] || [[ -z "$BUCKET_NAME" ]]; then
  echo "Error: BUCKET_NAME must be set"
  exit 1
fi

if [[ "$LOCATION" == "[YOUR_LOCATION]" ]] || [[ -z "$LOCATION" ]]; then
  echo "Error: LOCATION must be set (e.g., us-central1, us-east1)"
  exit 1
fi

# Set the project
gcloud config set project $PROJECT_ID

# 1. Create GCS bucket (if it doesn't exist)
if gsutil ls -b gs://$BUCKET_NAME >/dev/null 2>&1; then
  echo "Bucket $BUCKET_NAME already exists, skipping creation..."
else
  echo "Creating GCS bucket $BUCKET_NAME..."
  gsutil mb -p $PROJECT_ID -l $LOCATION gs://$BUCKET_NAME
fi

# 2. Enable versioning (recommended for state files)
echo "Enabling versioning on bucket..."
gsutil versioning set on gs://$BUCKET_NAME

# 3. Enable uniform bucket-level access (recommended)
echo "Enabling uniform bucket-level access..."
gsutil uniformbucketlevelaccess set on gs://$BUCKET_NAME

# 4. Set lifecycle policy to retain noncurrent versions (keep last 10 versions)
echo "Setting lifecycle policy..."
cat <<EOF > /tmp/lifecycle.json
{
  "rule": [
    {
      "action": {
        "type": "Delete"
      },
      "condition": {
        "numNewerVersions": 10
      }
    }
  ]
}
EOF
gsutil lifecycle set /tmp/lifecycle.json gs://$BUCKET_NAME
rm /tmp/lifecycle.json

# 5. Set bucket encryption (default encryption is enabled by default, but we can be explicit)
echo "Bucket encryption is enabled by default in GCS"

# 6. Set bucket labels
echo "Setting bucket labels..."
gsutil label ch -l "managed-by:terraform" gs://$BUCKET_NAME
gsutil label ch -l "purpose:terraform-state" gs://$BUCKET_NAME

echo "---------------------------------------------"
echo "Backend configuration created successfully!"
echo "---------------------------------------------"
echo "Use these values in your backend.tf:"
echo "bucket = \"$BUCKET_NAME\""
echo "prefix = \"$STATE_FILE_PREFIX\""
echo "---------------------------------------------"
echo ""
echo "Note: Make sure you have the following permissions:"
echo "  - storage.buckets.create"
echo "  - storage.buckets.get"
echo "  - storage.buckets.update"
echo "  - storage.objects.create"
echo "  - storage.objects.get"
echo "  - storage.objects.list"
echo "---------------------------------------------"

