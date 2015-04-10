/*
 * Backbone -> 'upgrade', new_version
 */
define([
	'underscore', 'backbone', 'module',
],
function(_, Backbone, module){
	'use strict';

	var Version = Backbone.Model.extend({

		url:    module.config().url,
		delay:  module.config().check_every * 1000,

		initialize: function(){
			this.once('change:version', this.upgrade, this);
			this._t = setInterval( _.bind(this.fetch, this), this.delay );
		},

		upgrade: function(model, version) {
			clearInterval( this._t );
			Backbone.trigger('upgrade', version);
		},
	});

	new Version({
		version: module.config().version,
	});
}); // define()
