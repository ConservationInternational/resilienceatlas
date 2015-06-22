/*jshint node:true*/

module.exports = function(grunt) {

  'use strict';

  require('load-grunt-tasks')(grunt);

  grunt.initConfig({

    jshint: {
      options: {
        jshintrc: './.jshintrc',
        reporter: require('jshint-stylish')
      },
      all: ['Gruntfile.js', 'app/assets/javascripts/{,*/}{,*/}*.js']
    }

  });

  grunt.registerTask('default', ['jshint']);

};
