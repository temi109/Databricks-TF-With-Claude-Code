import boto3
import pandas as pd
from io import StringIO

# S3 path
bucket_name = "ti-databricks-tf-eu-lakehouse"
key = "dev/nyc-taxi/raw/nyc_taxi_data.csv"  # full path to the file in S3

# Create S3 client
s3 = boto3.client("s3")  # Make sure your AWS credentials are configured

# Download the file into memory
obj = s3.get_object(Bucket=bucket_name, Key=key)
data = obj['Body'].read().decode('utf-8')

# Read CSV into pandas DataFrame
df = pd.read_csv(StringIO(data))

# Inspect
print(df.head())
print(df.info())