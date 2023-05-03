import ee


def get_region(geom):
    """Take a valid geojson object, get the feature in that object.
        Build up a EE Polygons, and finally return an EE Feature
        collection.)
    """
    polygons = []
    coordinates = geom.get('coordinates')
    polygons.append(ee.Geometry.Polygon(coordinates))
    return ee.FeatureCollection(polygons)
