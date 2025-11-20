# BackendService - DynamoDB + Flask sample

This repository contains a small Flask backend that reads from an AWS DynamoDB table and a minimal frontend to display the results.

## Features
- Flask backend exposing `/api/items` to list items from a DynamoDB table
- Basic front-end at `/` that fetches `/api/items` and renders a table
- Environment-driven configuration for region and table name

## Requirements
- Python 3.10+
- AWS credentials with permission to access the DynamoDB table

## Setup (Windows PowerShell)
1. Create a virtual environment and activate it:

```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1
```

2. Install dependencies

```powershell
pip install -r requirements.txt
```

3. Provide AWS credentials and table name. For local development you can put these in a `.env` file in the repository root:

```
AWS_ACCESS_KEY_ID=yourkey
AWS_SECRET_ACCESS_KEY=yoursecret
AWS_REGION=us-east-1
DYNAMODB_TABLE=your-table-name
```

> ⚠️ Keep `.env` private and out of source control. The repo already includes `.gitignore` entries.

4. Run the app

```powershell
$env:FLASK_APP='app.py'; $env:FLASK_ENV='development'; flask run
```

Or directly:

```powershell
python app.py
```

5. Open http://127.0.0.1:5000/ in your browser to see the frontend.

## API
- GET /api/items
  - Query params:
    - limit (int): Optional limit to the number of items
    - key (str): Optional attribute name used for a filter
    - value (str): Value for the filter

Example: `/api/items?limit=10&key=status&value=active`

Note: If the `key` parameter matches a partition key or index on your table, the backend will
use a DynamoDB Query (much more efficient). If it does not, the service will fall back to a
filtered Scan (slower but convenient for testing).

## Notes
- This sample uses `scan()` which can be expensive on large tables—use `query()` with a partition key and pagination for production-ready code.
- For local testing without AWS, `localstack` can be used (not included here).

---

If you'd like, I can also add unit tests, a Dockerfile, and CI config to run the app on pull requests. Let me know which extras you want next.
