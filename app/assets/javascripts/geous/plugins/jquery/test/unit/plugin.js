(function ($) {

    "use strict";

    var params = [
            {
                address: '123 abc st',
                city:    'akron',
                state:   'OH'
            },
            {
                lat: 1,
                lng: 2
            }
        ];

    $.each(params, function (index, vals) {

        test('set address #' + index, function () {
            var $form = $('#simple-form-fixture');
            $form.geousable('setLocation', new geous.Location(vals));
            $.each(vals, function (className, expected) {
                ok($form.find('.' + className).val() == expected);
            });
        });

        test('get address #' + index, function () {

            var $form = $('#simple-form-fixture'),
                location = new geous.Location(vals);

            $form.geousable('setLocation', location);
            location = $form.geousable('getLocation');

            $.each(vals, function (key, expected) {
                if (key == 'lat' || key == 'lng') {
                    ok(location.coordinates[key] == expected);
                } else {
                    ok(location[key] == expected);
                }
            });
        });
    });

})(jQuery);
