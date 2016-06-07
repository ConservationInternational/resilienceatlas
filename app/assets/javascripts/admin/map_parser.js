jQuery(document).ready(function ($) {
  var setMapLocation = function ($fields, geousMap) {
    var location = $fields.geousable('getLocation');
    geousMap.locations.empty();
    geousMap.locations.add(location, { draggable: true });
    geousMap.centerOnLocation(location);
  };
  // select target fieldset

  //$('[data-geousable]').each(function () {
  var el = $('.lat').parent().parent().parent();
  $(el).each(function () {

    var $fields = $(this),
        $map = $('<div class="geous-map" style="width:100%;height:300px;"></div>');

    // initialize the geousable plugin and container element
    $fields.geousable({ overwrite: true });
    $fields.prepend($map);
    $fields.find('input').change(function() {
      setMapLocation($fields, gmap);
    });
    // build a map with the fields' location
    geous.gmap.create({
      el: $map,
      locations: [ $fields.geousable('getLocation') ]
    });
  });
});

