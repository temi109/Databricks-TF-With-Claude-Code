import boto3
import logging
from pathlib import Path
from urllib.parse import urlparse

# Configure logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s"
)

logger = logging.getLogger(__name__)


def parse_s3_uri(s3_uri: str):
    """
    Splits an S3 URI into bucket and key.
    Example:
    s3://my-bucket/path/file.csv
    -> ("my-bucket", "path/file.csv")
    """
    parsed = urlparse(s3_uri)

    bucket = parsed.netloc
    key = parsed.path.lstrip("/")

    logger.debug("Parsed S3 URI: bucket=%s key=%s", bucket, key)

    return bucket, key


def upload_file(local_file: str, s3_uri: str):
    logger.info("Starting upload process")

    s3 = boto3.client("s3")

    file_path = Path(local_file)

    if not file_path.exists():
        logger.error("Local file does not exist: %s", local_file)
        raise FileNotFoundError(f"{local_file} does not exist")

    logger.info("Local file found: %s", file_path)

    bucket, key = parse_s3_uri(s3_uri)

    # If URI points to a folder, append filename
    if key.endswith("/") or key == "":
        key = f"{key}{file_path.name}"
        logger.debug("Detected folder URI. Updated key=%s", key)

    logger.info("Uploading file to s3://%s/%s", bucket, key)

    try:
        s3.upload_file(
            Filename=str(file_path),
            Bucket=bucket,
            Key=key
        )
    except Exception as e:
        logger.exception("Upload failed")
        raise e

    logger.info("Upload successful: %s → s3://%s/%s", local_file, bucket, key)


if __name__ == "__main__":

    LOCAL_FILE = "./airflow/data/taxi_data/nyc_taxi_data.csv"
    S3_URI = "s3://ti-databricks-tf-eu-lakehouse/raw/nyc-taxi/"

    upload_file(LOCAL_FILE, S3_URI)