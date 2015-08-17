describe('Layers Collection', function() {

  var layersData = [{
    'id': 1,
    'slug': 'lorem-ipsum',
    'name': 'Lorem ipsum',
    'description': 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    'cartocss': '#table_name {marker-fill: #F0F0F0;}',
    'sql': 'SELECT * FROM table_name',
    'color': '#ff0000',
    'order': 1,
    'zindex': 1,
    'category': 1,
    'active': true,
    'published': true
  }];

  before(function() {
    this.server = sinon.fakeServer.create();
  });

  beforeEach(function() {
    this.layersCollection = new window.app.Collection.Layers();
  });

  after(function() {
    this.server.restore();
  });

  describe('#initialize()', function() {

    it('should be an instance of Backbone.Collection', function() {
      expect(this.layersCollection).to.be.instanceof(Backbone.Collection);
    });

    it('should be empty', function() {
      expect(this.layersCollection.models).to.be.empty;
    });

  });

  describe('#fetch()', function() {

    it('should return data correctly', function() {
      var callback = sinon.spy();
      this.server.respondWith('GET', '/api/layers', [
        200,
        { 'Content-Type': 'application/json' },
        JSON.stringify(layersData)
      ]);
      this.layersCollection.fetch().done(callback);
      this.server.respond();
      sinon.assert.calledWith(callback, layersData);
    });

  });

});
