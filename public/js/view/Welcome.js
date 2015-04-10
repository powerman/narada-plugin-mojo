define([
	'jquery', 'underscore', 'backbone',
],
function($, _, Backbone){
	'use strict';

	return Backbone.View.extend({

		initialize: function(){
			this.template = _.template( $('#tmpl-welcome').html() );
			this.render();
		},

		render: function(){
			this.$el.html( this.template({message: 'Welcome to the Backbone!'}) );
			return this;
		},

	});
}); // define()
