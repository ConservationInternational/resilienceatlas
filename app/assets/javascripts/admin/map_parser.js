jQuery(document).ready(function ($) {
  var map;
  var marker;
  var mapDiv = '<div id="geous-map" style="width:100%;height:300px;"></div>';
  var el = $('.lat').parent().parent().parent().prepend(mapDiv);

  var $latInput = $('#site_scope_latitude');
  var $lngInput = $('#site_scope_longitude');
  var $zoomInput = $('#site_scope_zoom_level');

  var lat = parseFloat($latInput.val()) || 5;
  var lng = parseFloat($lngInput.val()) || 35;
  var zoom = parseInt($zoomInput.val()) || 3;

  function initMap() {
    var latlng = new google.maps.LatLng(lat, lng);
    map = new google.maps.Map(document.getElementById('geous-map'), {
      zoom: zoom,
      center: latlng
    });

    marker = new google.maps.Marker({
      map: map,
      draggable: true,
      animation: google.maps.Animation.DROP,
      position: latlng
    });

    marker.addListener('click', toggleBounce);
    marker.addListener('dragend', changeInputPosiiton);
    map.addListener('zoom_changed', changeInputZoom);

    setInputListeners();
  };

  function setInputListeners() {
    $latInput.on('change', updatePosition);
    $lngInput.on('change', updatePosition);
    $zoomInput.on('change', updateZoom);
  };

  function updatePosition(e) {
    lat = parseFloat($latInput.val()) || 5;
    lng = parseFloat($lngInput.val()) || 35;
    var latlng = new google.maps.LatLng(lat, lng);
    marker.setPosition(latlng);
  };

  function updateZoom(e) {
    var zoom = parseInt($zoomInput.val()) || 3;
    map.setZoom( zoom );
  };

  function toggleBounce() {
    if (marker.getAnimation() !== null) {
      marker.setAnimation(null);
    } else {
      marker.setAnimation(google.maps.Animation.BOUNCE);
    }
  };

  function changeInputPosiiton() {
    var markerLat = marker.getPosition().lat();
    var markerLng = marker.getPosition().lng();

    $latInput.val( markerLat );
    $lngInput.val( markerLng );
  };

  function changeInputZoom() {
    zoom = map.getZoom();
    $zoomInput.val(zoom);
  };

  initMap();
});
