#!/usr/bin/env bash
# =============================================================================
# SupiCargo — AWS S3 Bucket Setup Script
# =============================================================================
# Usage:
#   chmod +x setup-s3.sh
#   ./setup-s3.sh
#
# Prerequisites:
#   - AWS CLI installed: https://aws.amazon.com/cli/
#   - AWS credentials configured: aws configure
#   - Your IAM user must have S3 permissions
# =============================================================================

set -euo pipefail

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
BUCKET_NAME="supicargo-uploads"
AWS_REGION="us-east-1"   # Change to your preferred region (e.g. us-west-2, sa-east-1)
IAM_USERNAME="supicargo-fleetbase"  # IAM user that Railway will authenticate as

echo ""
echo "🪣  SupiCargo — S3 Bucket Setup"
echo "================================"
echo "Bucket: s3://${BUCKET_NAME}"
echo "Region: ${AWS_REGION}"
echo ""

# ─── STEP 1: Create the S3 Bucket ─────────────────────────────────────────────
echo "➡️  Step 1: Creating S3 bucket..."

if [ "$AWS_REGION" = "us-east-1" ]; then
  # us-east-1 does not accept LocationConstraint
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

echo "✅  Bucket created: s3://${BUCKET_NAME}"

# ─── STEP 2: Block all public access ─────────────────────────────────────────
echo ""
echo "➡️  Step 2: Blocking public access (files served via signed URLs)..."

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✅  Public access blocked"

# ─── STEP 3: Enable versioning ────────────────────────────────────────────────
echo ""
echo "➡️  Step 3: Enabling versioning (protects against accidental deletes)..."

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "✅  Versioning enabled"

# ─── STEP 4: Enable server-side encryption ────────────────────────────────────
echo ""
echo "➡️  Step 4: Enabling server-side encryption (AES-256)..."

aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

echo "✅  Encryption enabled"

# ─── STEP 5: Set CORS for browser uploads ────────────────────────────────────
echo ""
echo "➡️  Step 5: Configuring CORS (allows browser-based file uploads)..."

aws s3api put-bucket-cors \
  --bucket "$BUCKET_NAME" \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }]
  }'

echo "✅  CORS configured"

# ─── STEP 6: Create lifecycle rule (clean up old incomplete uploads) ──────────
echo ""
echo "➡️  Step 6: Setting lifecycle rule (auto-clean incomplete multipart uploads)..."

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "CleanupIncompleteUploads",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
    }]
  }'

echo "✅  Lifecycle rule set"

# ─── STEP 7: Apply IAM bucket policy ─────────────────────────────────────────
echo ""
echo "➡️  Step 7: Applying IAM access policy..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_FILE="$SCRIPT_DIR/s3-bucket-policy.json"

aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy file://"$POLICY_FILE"

echo "✅  Bucket policy applied"

# ─── DONE ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉  S3 Bucket setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋  Copy these values into your Railway environment variables:"
echo ""
echo "  FILESYSTEM_DRIVER=s3"
echo "  AWS_BUCKET=${BUCKET_NAME}"
echo "  AWS_DEFAULT_REGION=${AWS_REGION}"
echo "  AWS_URL=https://${BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com"
echo ""
echo "💡  Also set:"
echo "  AWS_ACCESS_KEY_ID=<your IAM user access key>"
echo "  AWS_SECRET_ACCESS_KEY=<your IAM user secret key>"
echo ""
echo "  To get these keys, run:"
echo "  aws iam create-access-key --user-name ${IAM_USERNAME}"
echo "  (Create the IAM user first if it doesn't exist)"
echo ""
