from flask import Flask, jsonify, render_template, request
from flask_cors import CORS
import os
from dynamodb_client import DynamoDBClient
from dotenv import load_dotenv

# Load .env file for local development
load_dotenv()

app = Flask(__name__, template_folder="templates", static_folder="static")
CORS(app)

# DynamoDB table name set via environment variable
TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "my-sample-table")
REGION = os.environ.get("AWS_REGION", "us-east-1")

dynamodb = DynamoDBClient(region_name=REGION, table_name=TABLE_NAME)


@app.route('/')
def index():
    """Serve the frontend single page."""
    return render_template('index.html')


@app.route('/api/items', methods=['GET'])
def get_items():
    """Return items from DynamoDB table as JSON.

    Query params:
    - limit (int): optional limit on number of items to return
    - key (str): optional attribute name to filter by (exact match)
    - value (str): optional attribute value to filter by
    """
    try:
        limit = request.args.get('limit', type=int)
        key = request.args.get('key')
        value = request.args.get('value')

        if key and value:
            # Attempt an efficient Query first (works if `key` is a partition key or index),
            # otherwise fall back to a scan with a filter.
            items = dynamodb.query_by_key(key, value, limit=limit)
        else:
            items = dynamodb.scan_all(limit=limit)

        return jsonify({'items': items}), 200
    except Exception as exc:
        return jsonify({'error': str(exc)}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
