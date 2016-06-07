module.exports = function(grunt) {
  grunt.initConfig({
    concat: {
      'geous.js': [
        'src/geous.js',
        'src/geocoders/google.js'
      ]
    }
  });

  grunt.registerTask('default','concat');
};
