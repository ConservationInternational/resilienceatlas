define(['router'], function(Router) {

  'use strict';

  describe('@Router', function() {

    beforeEach(function() {
      this.router = new Router();
    });

    describe('#Instance', function() {
      it('router should instance Router', function() {
        expect(this.router).to.be.instanceOf(Router);
      });
    });

  });

});
