import boto3
import pandas as pd
import io
import json
import plotly.express as px
import os

# Configuration
BUCKET_NAME = os.getenv("BUCKET_NAME")
SERIES_KEY = "pr.data.0.Current"
POPULATION_KEY = "population_data.json"

# Initialize S3 client
s3 = boto3.client("s3")

def download_file_from_s3(bucket, key):
    """Download a file from S3 and return its content."""
    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        print(f"Successfully downloaded {key} from {bucket}.")
        return obj["Body"].read()
    except s3.exceptions.NoSuchKey:
        print(f"File {key} not found in bucket {bucket}.")
        return None
    except Exception as e:
        print(f"Error downloading {key}: {e}")
        return None

def upload_file_to_s3(bucket, key, file_content):
    """Upload file content to S3."""
    try:
        s3.put_object(Bucket=bucket, Key=key, Body=file_content)
        print(f"Successfully uploaded {key} to {bucket}.")
    except Exception as e:
        print(f"Error uploading {key}: {e}")

def load_series_data(bucket, key):
    """Load the series data from S3 into a Pandas DataFrame."""
    file_content = download_file_from_s3(bucket, key)
    if file_content:
        try:
            return pd.read_csv(io.BytesIO(file_content), delimiter="\t")
        except Exception as e:
            print(f"Error reading series data: {e}")
    return None

def load_population_data(bucket, key):
    """Load the population data from S3 into a Pandas DataFrame."""
    file_content = download_file_from_s3(bucket, key)
    if file_content:
        try:
            population_json = pd.read_json(io.BytesIO(file_content))
            return pd.json_normalize(population_json, record_path="data")
        except Exception as e:
            print(f"Error reading population data: {e}")
    return None

def lambda_handler(event, context):
    # Load data
    series = load_series_data(BUCKET_NAME, SERIES_KEY)
    population_file_content = download_file_from_s3(BUCKET_NAME, POPULATION_KEY)

    # Check if data is loaded successfully
    if series is None or population_file_content is None:
        return {"statusCode": 500, "body": "Failed to load data"}

    # Parse and normalize population data
    raw_data = json.loads(population_file_content.decode("utf-8"))
    if isinstance(raw_data, dict) and "data" in raw_data:
        population = pd.json_normalize(raw_data, record_path="data")
    elif isinstance(raw_data, list):
        population = pd.DataFrame(raw_data)
    else:
        return {"statusCode": 500, "body": "Unexpected JSON structure"}

    # Filter data
    population["Year"] = population["Year"].astype(int)
    population["Population"] = population["Population"].astype(int)
    population_stats = population[(population["Year"] >= 2013) & (population["Year"] <= 2018)]
    
    # Perform calculations
    mean_population = population_stats["Population"].mean()
    std_population = population_stats["Population"].std()

    # Prepare series data
    series.rename(columns={"series_id        ": "series_id", "       value": "value"}, inplace=True)
    max_value_series = series.groupby(["series_id", "year"], as_index=False)["value"].agg("sum")
    max_value_series = max_value_series.sort_values("value", ascending=False).drop_duplicates("series_id", keep="first").sort_index().reset_index(drop=True)

    # Generate bar plot
    filtered_df = pd.merge(series, population, left_on="year", right_on="Year", how="left")
    fig1 = px.bar(
        filtered_df,
        x="Year",
        y="Population",
        color="Nation",
        title="Population by Year and Nation",
        labels={"Year": "Year", "Population": "Population"},
        barmode="group",
        text="Population"
    )
    
    # Save plot to local file
    fig1_output = "/tmp/Population_by_Year_and_Nation.html"
    fig1.write_html(fig1_output)
    print(f"Generated plot: {fig1_output}")

    # Upload the plot to S3
    with open(fig1_output, "rb") as f:
        s3_key = "Population_by_Year_and_Nation.html"
        upload_file_to_s3(BUCKET_NAME, s3_key, f.read())
        print(f"Plot uploaded to S3: {s3_key}")

    # Return success message
    return {
        "statusCode": 200,
        "body": {
            "mean_population": mean_population,
            "std_population": std_population,
            "s3_plot_url": f"https://{BUCKET_NAME}.s3.amazonaws.com/{s3_key}"
        }
    }



