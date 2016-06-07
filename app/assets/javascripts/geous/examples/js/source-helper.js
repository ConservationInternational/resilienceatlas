document.write('<script src="http://rjzaworski.com/js/prettify/prettify.js"><\/script>');

(function($){

$(document).ready(function(){

	$('.source').hide();

	$('.demo').each(function(){

		var src = $('#' + $(this).data('demo')).text(),
			target;

		if (src) {
			target = $('.source', this);
			target.children(0).text(src);

			$('.toggle-source', this).click(function(e){
				e.preventDefault();
				target.slideToggle();
			});
		}
	});

	if (prettyPrint) {
		$('pre code').addClass('prettyprint');
		prettyPrint();
	}
});

})(jQuery);
