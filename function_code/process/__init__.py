import azure.functions as func
import logging
import json
from datetime import datetime
from typing import Dict, Any
import os


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP trigger function that processes data sent to it.

    This function demonstrates data processing capabilities and integration
    with Key Vault for secrets management.
    """
    logging.info('HTTP trigger function processed a request for process endpoint.')

    try:
        # Only allow POST requests for data processing
        if req.method != 'POST':
            return func.HttpResponse(
                json.dumps({
                    "error": "Method not allowed",
                    "message": "This endpoint only accepts POST requests",
                    "timestamp": datetime.utcnow().isoformat() + "Z"
                }),
                status_code=405,
                headers={"Content-Type": "application/json"}
            )

        # Get request body
        try:
            req_body = req.get_json()
            if not req_body:
                return func.HttpResponse(
                    json.dumps({
                        "error": "Bad request",
                        "message": "Request body must contain valid JSON",
                        "timestamp": datetime.utcnow().isoformat() + "Z"
                    }),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )
        except ValueError as e:
            logging.error(f'Invalid JSON in request body: {str(e)}')
            return func.HttpResponse(
                json.dumps({
                    "error": "Bad request",
                    "message": "Invalid JSON format",
                    "timestamp": datetime.utcnow().isoformat() + "Z"
                }),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Process the data
        processed_data = process_business_logic(req_body)

        # Create response
        response_data = {
            "message": "Data processed successfully",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "function": "process",
            "status": "success",
            "input_size": len(str(req_body)),
            "processed_data": processed_data
        }

        logging.info('Successfully processed data request')

        return func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            headers={
                "Content-Type": "application/json",
                "Cache-Control": "no-cache"
            }
        )

    except Exception as e:
        logging.error(f'Error processing data request: {str(e)}')

        error_response = {
            "error": "Internal server error",
            "message": "An error occurred while processing your data",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "status": "error"
        }

        return func.HttpResponse(
            json.dumps(error_response),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )


def process_business_logic(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Example business logic for processing data.

    Replace this with your actual business logic.
    """
    try:
        # Example: Convert all string values to uppercase
        processed = {}

        for key, value in data.items():
            if isinstance(value, str):
                processed[f"processed_{key}"] = value.upper()
            elif isinstance(value, (int, float)):
                processed[f"processed_{key}"] = value * 2
            elif isinstance(value, list):
                processed[f"processed_{key}"] = [
                    item.upper() if isinstance(item, str) else item
                    for item in value
                ]
            else:
                processed[f"processed_{key}"] = value

        # Add some metadata
        processed["processing_info"] = {
            "processed_at": datetime.utcnow().isoformat() + "Z",
            "original_keys": list(data.keys()),
            "processing_version": "1.0"
        }

        return processed

    except Exception as e:
        logging.error(f'Error in business logic processing: {str(e)}')
        raise