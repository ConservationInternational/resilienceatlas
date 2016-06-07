// jQuery(document).ready(function ($) {
//   var setMapLocation = function ($fields, geousMap) {
//     var location = $fields.geousable('getLocation');
//     geousMap.locations.empty();
//     geousMap.locations.add(location, { draggable: true });
//     geousMap.centerOnLocation(location);
//   };
//   // select target fieldset

//   //$('[data-geousable]').each(function () {
//   var el = $('.lat').parent().parent().parent();
//   $(el).each(function () {

//     var $fields = $(this),
//         $map = $('<div class="geous-map" style="width:100%;height:300px;"></div>');

//     // initialize the geousable plugin and container element
//     $fields.geousable({ overwrite: true });
//     $fields.prepend($map);
//     $fields.find('input').change(function() {
//       setMapLocation($fields, gmap);
//     });
//     // build a map with the fields' location
//     geous.gmap.create({
//       el: $map,
//       locations: [ $fields.geousable('getLocation') ]
//     });
//   });
// });

jQuery(document).ready(function ($) {
  var marker;
  var mapDiv = '<div id="geous-map" style="width:100%;height:300px;"></div>';
  var el = $('.lat').parent().parent().parent().append(mapDiv);

  var lat = $('.lat').val() || 5;
  var lng = $('.lng').val() || 35;

  function initMap() {
    var map = new google.maps.Map(document.getElementById('geous-map'), {
      zoom: 3,
      center: {lat: lat, lng: lng}
    });

    marker = new google.maps.Marker({
      map: map,
      draggable: true,
      animation: google.maps.Animation.DROP,
      position: {lat: lat, lng: lng}
    });
    marker.addListener('click', toggleBounce);
    marker.addListener('dragend', getPosiiton);
  }

  function toggleBounce() {
    if (marker.getAnimation() !== null) {
      marker.setAnimation(null);
    } else {
      marker.setAnimation(google.maps.Animation.BOUNCE);
    }
  };

  function getPosiiton() {
    var markerLat = marker.getPosition().lat();
    var markerLng = marker.getPosition().lng();

    lat = $('.lat').val( markerLat );
    lng = $('.lng').val( markerLng );

  }

  initMap();
});
