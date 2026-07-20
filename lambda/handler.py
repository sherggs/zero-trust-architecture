import boto3
import os
import base64
import binascii
import json

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

DEFAULT_LIMIT = 25
MAX_LIMIT = 100


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str),
    }


def _decode_cursor(cursor):
    return json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())


def _encode_cursor(last_evaluated_key):
    return base64.urlsafe_b64encode(json.dumps(last_evaluated_key).encode()).decode()


def lambda_handler(event, handler):
    params = event.get("queryStringParameters") or {}

    try:
        limit = int(params.get("limit", DEFAULT_LIMIT))
    except (TypeError, ValueError):
        return _response(400, {"error": "limit must be an integer"})

    if limit < 1 or limit > MAX_LIMIT:
        return _response(400, {"error": f"limit must be between 1 and {MAX_LIMIT}"})
    scan_kwargs = {"Limit": limit}

    cursor = params.get("cursor")
    if cursor:
        try:
            scan_kwargs["ExclusiveStartKey"] = _decode_cursor(cursor)
        except (binascii.Error, json.JSONDecodeError, UnicodeDecodeError):
            return _response(400, {"error": "invalid cursor"})

    result = table.scan(**scan_kwargs)

    body = {"count": result["Count"], "items": result["Items"]}

    last_key = result.get("LastEvaluatedKey")
    if last_key:
        body["next_cursor"] = _encode_cursor(last_key)

    return _response(200, body)
