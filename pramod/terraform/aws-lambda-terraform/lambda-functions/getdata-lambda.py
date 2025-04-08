import os
import requests
import json
import boto3
from botocore.exceptions import NoCredentialsError

# S3 Configuration
BUCKET_NAME = os.getenv("BUCKET_NAME")
HEADERS = {"User-Agent": "diman (dsahirwar@bestpeers.com)"}
POPULATION_API_URL = "https://datausa.io/api/data?drilldowns=Nation&measures=Population"
BLS_URL = "https://download.bls.gov/pub/time.series/pr/"
LOCAL_DIR = "/tmp"  # Lambda has limited writable storage in /tmp

# Initialize S3 client
s3 = boto3.client("s3")


def fetch_bls_files():
    """Fetch the BLS dataset."""
    response = requests.get(f"{BLS_URL}pr.data.0.Current", headers=HEADERS)
    if response.status_code == 200:
        file_path = os.path.join(LOCAL_DIR, "pr.data.0.Current")
        with open(file_path, "wb") as f:
            f.write(response.content)
        print(f"Downloaded: pr.data.0.Current")
        return [file_path]
    else:
        print(f"Failed to fetch BLS data: {response.status_code}")
        return []


def fetch_population_data():
    """Fetch population data."""
    response = requests.get(POPULATION_API_URL)
    if response.status_code == 200:
        data = response.json()
        json_file_path = os.path.join(LOCAL_DIR, "population_data.json")
        with open(json_file_path, "w") as f:
            json.dump(data, f, indent=4)
        print(f"Population data saved to {json_file_path}")
        return json_file_path
    else:
        print(f"Failed to fetch population data: {response.status_code}")
        return None


def upload_to_s3(file_path, key):
    """Upload a file to S3."""
    try:
        s3.upload_file(file_path, BUCKET_NAME, key)
        print(f"Uploaded {key} to S3 bucket {BUCKET_NAME}")
    except NoCredentialsError:
        print("AWS credentials not found.")


def file_exists_in_s3(key):
    """Check if a file already exists in the S3 bucket."""
    try:
        s3.head_object(Bucket=BUCKET_NAME, Key=key)
        return True
    except:
        return False


def sync_bls_data():
    """Sync BLS data with S3."""
    files = fetch_bls_files()
    for file_path in files:
        key = os.path.basename(file_path)
        if not file_exists_in_s3(key):
            upload_to_s3(file_path, key)
        else:
            print(f"File {key} already exists in S3. Skipping upload.")


def upload_population_data():
    """Fetch and upload population data to S3."""
    json_file_path = fetch_population_data()
    if json_file_path:
        key = os.path.basename(json_file_path)
        if not file_exists_in_s3(key):
            upload_to_s3(json_file_path, key)
        else:
            print(f"File {key} already exists in S3. Skipping upload.")


def lambda_handler(event, context):
    """AWS Lambda handler."""
    print("Syncing BLS data and uploading population data to S3...")
    sync_bls_data()
    upload_population_data()
    return {
        "statusCode": 200,
        "body": json.dumps("BLS and Population data synced with S3 successfully!")
    }
