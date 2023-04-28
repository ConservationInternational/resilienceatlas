import os
import json
from concurrent.futures import ThreadPoolExecutor, as_completed

import ee


EE_CREDENTIALS = ee.ServiceAccountCredentials(os.environ['GEE_ACCOUNT'],
        key_data=os.environ['GEE_KEY'])
ee.Initialize(EE_CREDENTIALS)

def get_coords(geojson):
    """."""
    if geojson.get('features') is not None:
        return geojson.get('features')[0].get('geometry').get('coordinates')
    elif geojson.get('geometry') is not None:
        return geojson.get('geometry').get('coordinates')
    else:
        return geojson.get('coordinates')

def get_area(aoi):
    return aoi.area().divide(10000).getInfo()


def get_chirps(year_start, year_end, aoi):
    precip = "users/geflanddegradation/toolbox_datasets/prec_chirps_1981_2019"
    
    prec = ee.Image(precip).select(ee.List.sequence(year_start - 1981, year_end - 1981, 1))

    values_prec = prec.reduceRegion(ee.Reducer.toList(), aoi, bestEffort=True)

    with ThreadPoolExecutor(max_workers=4) as executor:
        res = []
        for b, img in [('precipitation', values_prec)]:
            res.append(executor.submit((lambda b, img: {b: img.getInfo()}), b, img))
        out = {}
        for this_res in as_completed(res):
            out.update(this_res.result())

    ts = {}
    for key in out.keys():   
        d = list((int(k.replace('y', '')), list(int(w) for w in v)) for k, v in out[key].items())
        # Ensure the data is chronological
        d = sorted(d, key=lambda x: x[0]) 
        years = list(x[0] for x in d)
        data = list(list(x[1]) for x in d)
        ts[key] = {'values': data, 'time': years}

    return ts

def lambda_handler(event, context):
    geojson_txt = "{\"type\": \"Polygon\", \"coordinates\": [[[-72.17511689663989, 2.508542338282338], [-73.99546273090893, 2.508542338282338], [-73.99546273090893, 2.688196504013306], [-71.17511689663989, 2.688196504013306], [-71.17511689663989, 2.508542338282338]]]}"

    aoi = ee.Geometry.MultiPolygon(get_coords(json.loads(geojson_txt)))

    year_start = 2001
    year_end = 2015

    res = get_chirps(year_start, year_end, aoi)
    res['area'] = get_area(aoi)

    return {
        'statusCode': 200,
        'body': json.dumps(res)
    }
