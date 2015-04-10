define('main', [
	'view/Welcome',
	'jquery', 'underscore', 'backbone',
	'model/Version',
	'jquery.jgrowl'
],
function(Welcome, $, _, Backbone){
	'use strict';

	Backbone.on({
		'run': function(){
			new Welcome({ el: $('#welcome-backbone') });
		},
		'upgrade': function(new_version){
			$.jGrowl('Please reload page to upgrade', {
				header: 'New version available'+'<br>'+new_version,
				theme:	'warning',
				sticky: true,
			});
		},
	});

	$(function(){ Backbone.trigger('run'); });
}); // define()

require(['underscore', 'underscore.string'], function(_, _s){
	'use strict';

	// Force escaping for <%=…%> (may break existing 3rd-party apps).
	// Define new placeholder <%#…%> for non-escaped output.
	_.extend(_.templateSettings, {
		escape:         /<%[=\-]([\s\S]+?)%>/g,
		interpolate:    /<%#([\s\S]+?)%>/g,
	});

	_.mixin(_s.exports());

	require(['main'], function(){});
});
