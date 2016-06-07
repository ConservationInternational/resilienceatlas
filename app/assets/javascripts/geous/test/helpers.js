(function () {
    this.testHelper = {

        checkFields: function (location, fields) {
            var scope;

            for (key in fields) {
                scope = location;
                if (key == 'lat' || key == 'lng') {
                    scope = scope.coordinates
                }
                expect(scope[key]).toEqual(fields[key]);
            }
        }
    };
})();
