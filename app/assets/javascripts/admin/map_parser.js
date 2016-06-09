jQuery(document).ready(function ($) {
  var marker;
  var mapDiv = '<div id="geous-map" style="width:100%;height:300px;"></div>';
  var el = $('.lat').parent().parent().parent().prepend(mapDiv);

  var lat = $('.lat').val() || 5;
  var lng = $('.lng').val() || 35;

  function initMap() {
    var latlng = new google.maps.LatLng(lat, lng);
    var map = new google.maps.Map(document.getElementById('geous-map'), {
      zoom: 3,
      center: latlng
    });

    marker = new google.maps.Marker({
      map: map,
      draggable: true,
      animation: google.maps.Animation.DROP,
      position: latlng
    });
    marker.addListener('click', toggleBounce);
    marker.addListener('dragend', getPosiiton);

    setInputListeners();
  };

  function setInputListeners() {
    $('.lat').on('change', updatePosition);
    $('.lng').on('change', updatePosition);
  };

  function updatePosition(e) {
    var lat = $('.lat').val() || 5;
    var lng = $('.lng').val() || 35;
    var latlng = new google.maps.LatLng(lat, lng);
    marker.setPosition(latlng);
  };

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
