import os
import boto3
from boto3.dynamodb.conditions import Attr, Key


class DynamoDBClient:
    def __init__(self, region_name=None, table_name=None):
        self.region_name = region_name or os.environ.get("AWS_REGION")
        self.table_name = table_name or os.environ.get("DYNAMODB_TABLE")

        self._dynamodb = boto3.resource('dynamodb', region_name=self.region_name)
        self._table = self._dynamodb.Table(self.table_name)

    def scan_all(self, limit=None):
        """Simple scan returning all items (optionally limited).

        WARNING: scans can be expensive for large tables. For a production-ready
        application, use Query with indexes and pagination (LastEvaluatedKey).
        """
        kwargs = {}
        if limit:
            kwargs['Limit'] = limit

        response = self._table.scan(**kwargs)
        items = response.get('Items', [])

        # Support pagination
        while response.get('LastEvaluatedKey'):
            if limit and len(items) >= limit:
                break
            response = self._table.scan(**{'ExclusiveStartKey': response['LastEvaluatedKey']})
            items.extend(response.get('Items', []))

            if limit:
                items = items[:limit]
                break

        return items

    def scan_with_filter(self, attr_name, attr_value, limit=None):
        """Perform a scan with a basic equality filter on attribute names.

        This is provided as a convenience when test data uses simple attributes.
        For complex lookups, use Query and define a proper partition key.
        """
        condition = Attr(attr_name).eq(attr_value)
        kwargs = {'FilterExpression': condition}
        if limit:
            kwargs['Limit'] = limit

        response = self._table.scan(**kwargs)
        items = response.get('Items', [])

        while response.get('LastEvaluatedKey'):
            if limit and len(items) >= limit:
                break
            response = self._table.scan(**{'ExclusiveStartKey': response['LastEvaluatedKey'], **({'FilterExpression': condition} if condition else {})})
            items.extend(response.get('Items', []))

            if limit:
                items = items[:limit]
                break

        return items

    def query_by_key(self, key_name, key_value, limit=None):
        """Try to Query the table by a partition key; fall back to a filtered Scan.

        Query is much more efficient than Scan but requires the attribute to
        be a key (partition key or part of an index). If the attribute isn't
        a key, Query will raise a ValidationException and we fall back to Scan.
        """
        kwargs = {'KeyConditionExpression': Key(key_name).eq(key_value)}
        if limit:
            kwargs['Limit'] = limit

        try:
            response = self._table.query(**kwargs)
            return response.get('Items', [])
        except Exception:
            # If query isn't possible (attribute not key) fall back to a Scan
            return self.scan_with_filter(key_name, key_value, limit=limit)
