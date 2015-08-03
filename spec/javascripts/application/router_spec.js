describe('Router', function() {

  beforeEach(function() {
    this.router = new window.app.Router();
  });

  it('should be a instance of Backbone.Router', function() {
    expect(this.router).to.be.instanceof(Backbone.Router);
  });

});
