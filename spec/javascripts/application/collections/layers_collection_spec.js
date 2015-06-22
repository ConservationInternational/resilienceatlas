define([
  'collections/layers_collection',
  'text!data/layers.json'
], function(LayersCollection, layersData) {

  'use strict';

  describe('@Layers Collection', function() {

    beforeEach(function() {
      this.layersCollection = new LayersCollection([{
        "name": "Urbanized and designated",
        "slug": "ubranized_and_designated",
        "group": "Urban settlements",
        "category": "layer",
        "type": "cartodb",
        "zindex": 0
      }, {
        "name": "Urban growth",
        "slug": "urban_growth",
        "group": "Environmental conservation",
        "category": "layer",
        "type": "cartodb",
        "zindex": 1
      }]);
    });

    describe('#Instance', function() {
      it('layersData should be a JSON object', function() {
        expect(typeof layersData).to.be.a('string');
        expect(JSON.parse(layersData)).to.be.an('array');
      });
      it('layers should be a instance of LayersCollection', function() {
        expect(this.layersCollection).to.be.instanceOf(LayersCollection);
      });
    });

    describe('#Parse', function() {
      it('layers should return grouped by category attribute', function() {
        var result = this.layersCollection.getByCategory();
        expect(result).to.be.an('object');
        expect(result).to.have.property('layer');
      });
      it('layers should return grouped by group attribute', function() {
        var result = this.layersCollection.getByGroup();
        expect(result).to.be.an('object');
        expect(result).to.have.property('Urban settlements');
        expect(result).to.have.property('Environmental conservation');
      });
      it('layers should return grouped by category and group', function() {
        var result = this.layersCollection.getByCategoryAndGroup();
        expect(result).to.be.an('object');
        expect(result).to.have.property('layer');
        expect(result.layer).to.be.an('object');
        expect(result.layer).to.have.property('Urban settlements');
        expect(result.layer).to.have.property('Environmental conservation');
      });
    });

  });

});
