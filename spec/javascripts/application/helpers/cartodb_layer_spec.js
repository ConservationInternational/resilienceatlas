describe('CartoDBLayer Helper', function() {

  beforeEach(function() {
    var element = document.createElement('div');
    var map = L.map(element, { zoom: 5, center: [40, -3] });
    this.cartodbLayer = new window.app.Helper.CartoDBLayer(map);
  });

  describe('#initialize()', function() {

    it('should be an instance of Helper.Class', function() {
      expect(this.cartodbLayer).to.be.instanceof(window.app.Helper.Class);
    });

    it('should has a map instance of Leaflet Map', function() {
      expect(this.cartodbLayer.map).to.be.instanceof(L.Map);
    });

  });

});
