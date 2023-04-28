import ee
import json
with open("privatekey.json") as keyfile:
    extracted_key_data = keyfile.read()
    service_account = 'gef-ldmp-server@gef-ld-toolbox.iam.gserviceaccount.com'
    credentials = ee.ServiceAccountCredentials(service_account, key_data=extracted_key_data)
ee.Initialize(credentials, use_cloud_api=True)
service_account = 'gef-ldmp-server@gef-ld-toolbox.iam.gserviceaccount.com'
#credentials = ee.ServiceAccountCredentials(service_account, 'privatekey.json')
#ee.Initialize(credentials)

def serialize_response(url):

    return {
        'download_url': url
    }

def download_image(request):
    # For more information about CORS and CORS preflight requests, see
    # https://developer.mozilla.org/en-US/docs/Glossary/Preflight_request
    # for more information.
    # Set CORS headers for the main request
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }
    # Set CORS headers for the preflight request
    if request.method == 'OPTIONS':
        # Allows GET requests from any origin with the Content-Type
        # header and caches preflight response for an 3600s
        headers.update({
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        })

        return ('', 204, headers)

    

    request = request.get_json()
    if 'geometry' in request:
        polygon = ee.Geometry.Polygon(request['geometry'].get('features')[0].get('geometry').get('coordinates'))
        image = ee.Image(request['assetId']).clip(ee.Geometry(polygon))
    else:
        image = ee.Image(request['assetId'])
    url = image.getDownloadUrl()

    return (json.dumps(serialize_response(url)), 200, headers)
