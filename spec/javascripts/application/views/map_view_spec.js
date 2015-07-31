describe('View.Map:', function() {

  beforeEach(function() {
    this.mapView = new window.app.View.Map();
  });

  describe('#initialize()', function() {

    it('should be an instance of Backbone.View', function() {
      expect(this.mapView).to.be.instanceof(Backbone.View);
    });

  });

  describe('#createMap()', function() {

    it('should cretate a Leaflet instance', function() {
      expect(this.mapView.createMap).to.be.a('function');
      this.mapView.createMap();
      expect(this.mapView.map).to.be.instanceof(L.Map);
    });

    it('should remove the map object', function() {
      expect(this.mapView.removeMap).to.be.a('function');
      this.mapView.createMap();
      this.mapView.removeMap();
      expect(this.mapView.map).to.be.equal(null);
    });

  });

});
