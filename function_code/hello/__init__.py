import azure.functions as func
import logging
import json
from datetime import datetime


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Simple HTTP trigger function that returns a greeting message.

    This function demonstrates basic Azure Functions HTTP trigger functionality
    and can be called through API Management.
    """
    logging.info('HTTP trigger function processed a request for hello endpoint.')

    try:
        # Get name from query string or request body
        name = req.params.get('name')
        if not name:
            try:
                req_body = req.get_json()
                if req_body:
                    name = req_body.get('name')
            except ValueError:
                pass

        # Default name if none provided
        if not name:
            name = "World"

        # Create response data
        response_data = {
            "message": f"Hello, {name}!",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "function": "hello",
            "status": "success"
        }

        logging.info(f'Successfully processed hello request for name: {name}')

        return func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            headers={
                "Content-Type": "application/json",
                "Cache-Control": "no-cache"
            }
        )

    except Exception as e:
        logging.error(f'Error processing hello request: {str(e)}')

        error_response = {
            "error": "Internal server error",
            "message": "An error occurred while processing your request",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "status": "error"
        }

        return func.HttpResponse(
            json.dumps(error_response),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )