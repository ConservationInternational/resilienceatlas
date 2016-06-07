describe('geous', function () {

    it ('attached to the global namespace', function () {
        expect(geous).toBeDefined();
    });

    describe('geous.options', function () {

        it ('initializes with defaults', function () {
            var keys = [
                'useCache',
                'cacheAdapter',
                'cachePersist',
                'cachePrefix',
                'geocoder'
            ];

            keys.forEach(function (key) {
                expect(geous.options[key]).toBeDefined();
            });
        });
        
        it ('may be configured', function () {
            var geocoder = 'foobar',
                userConfig = {
                    geocoder: geocoder
                };

            geous.configure(userConfig);
            expect(geous.options.geocoder).toEqual(geocoder);
        });
    });

    describe('geous.Events', function () {

        var callback = null,
            evt = null,
            obj = null;

        beforeEach(function () {
            callback = jasmine.createSpy();
            evt = 'FourAlarmFire';
            obj = {};
            geous.extend(obj, geous.Events);
        });

        it ('triggers events', function () {
            obj.on(evt, callback);
            obj.trigger(evt, 1, 3, 4);
            expect(callback).toHaveBeenCalledWith(1, 3, 4);
        });

        it ('removes events', function () {
            obj.on(evt, callback);
            obj.off(evt, callback);
            obj.trigger(evt);
            expect(callback).not.toHaveBeenCalled();
        })
    });

    describe ('geous.HashStore', function () {

        var key, value;

        beforeEach(function () {
            key = 'foo';
            value = 'bar';
        });

        it('sets and gets data', function () {

            var store = new geous.HashStore({
                storageAdapter: geous.options.cacheAdapter
            });

            store.set(key, value);
            expect(store.get(key)).toEqual(value);
        });

        it('persists and restores data', function () {

            var store = new geous.HashStore({
                storageAdapter: geous.options.cacheAdapter,
                persist: true
            });

            store.set(key, value);
            delete store;

            store = new geous.HashStore({
                storageAdapter: geous.options.cacheAdapter,
                persist: true
            });

            expect(store.get(key)).toEqual(value);
        });
    });

    describe('geous.Location', function () {

        var address = '123 abc st',
            city = 'akron',
            state = 'ohio',
            raw_address = [address, city, state].join(' '),
            lat = 48.3689,
            lng = -99.9962;

        var addressHash = { address: address, city: city, state: state },
            latLngHash = { lat: lat, lng: lng };

        it('accepts a variety of formats', function () {

            var tests = [
                {
                    args: [ new geous.Location(new geous.Location(raw_address)) ],
                    expect: { raw_address: raw_address }
                }, {
                    args: [ raw_address ],
                    expect: { raw_address: raw_address }
                }, {
                    args: [ lat, lng ],
                    expect: latLngHash 
                }, {
                    args: [[ lat, lng ]],
                    expect: latLngHash
                }, {
                    args: [[ address, city, state ]],
                    expect: { raw_address: raw_address }
                }, {
                    args: [ latLngHash ],
                    expect: latLngHash
                }, {
                    args: [ addressHash ],
                    expect: addressHash
                }
            ];

            tests.forEach(function (test) {

                var ctor = function () {},
                    instance,
                    location;

                ctor.prototype = geous.Location.prototype;
                instance = new ctor;

                location = geous.Location.apply(instance, test.args);

                testHelper.checkFields(location, test.expect);
            });
        });

        it('clones object inputs', function () {

            var tests = [
                {
                    args: addressHash,
                    expect: addressHash
                }, {
                    args: latLngHash,
                    expect: latLngHash
                }
            ];
            
            tests.forEach(function (test) {
                var location = new geous.Location(test.args);
                testHelper.checkFields(location, test.expect);
            });
        });

        it('can set its address from a few different formats', function () {
            
            var tests = [
                {
                    args: [ raw_address ],
                    expect: { raw_address: raw_address }
                }, {
                    args: [[address, city, state]],
                    expect: { raw_address: raw_address }
                }, {
                    args: [ addressHash ],
                    expect: addressHash 
                }
            ];

            tests.forEach(function (test) {
                var location = new geous.Location;
                location.setAddress.apply(location, test.args);
                testHelper.checkFields(location, test.expect);
            });
        });

        it('can set its coordinates from a few different formats', function () {

            var tests = [
                {
                    args: [ lat, lng ],
                    expect: latLngHash
                }, {
                    args: [[ lat, lng ]],
                    expect: latLngHash
                }, {
                    args: [ latLngHash ],
                    expect: latLngHash
                }
            ];

            tests.forEach(function (test) {
                var location = new geous.Location;
                location.setCoordinates.apply(location, test.args);
                testHelper.checkFields(location, test.expect);
            });
        });
    });
});
