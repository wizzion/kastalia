/*!
Deck JS - deck.navigation
Copyright (c) 2012 Romain Champourlier
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/deck.js/blob/master/MIT-license.txt
https://github.com/imakewebthings/deck.js/blob/master/GPL-license.txt
*/

/*
This module adds automatic control of the deck.
*/
(function($, deck, undefined) {
	var $d = $(document);
	
	clearAutomaticTimeout = function() {
		if ($[deck].automatic && $[deck].automatic.timeout) {
			window.clearTimeout($[deck].automatic.timeout);
		}
	};
	
	setTimeoutIfNeeded = function(e, from, to) {
		// Clear previous timeout (necessary in cases the user generates deck's change
		// events, for example by changing slides manually).
		clearAutomaticTimeout();
		
		var opts = $[deck]('getOptions');
		if ($[deck]('getSlides')[$[deck]('getSlides').length-2] == $[deck]('getSlide')) {
			// On last slide. Set timeout to go to first if cycling, else don't setTimeout
			if (opts.automatic.cycle) {
				window.setTimeout(function() {
					$[deck]('go', 0);
					if (e) e.preventDefault();
				}, opts.automatic.slideDuration);
			}
		}
		else if ($(opts.selectors.automaticLink).hasClass(opts.classes.automaticRunning)) {
			// Running, not yet on last slide.
			$[deck].automatic = {
				timeout: window.setTimeout(function() {
					$[deck]('next');
					if (e) e.preventDefault();
				}, opts.automatic.slideDuration)
			};
		}
	};
	
	/*
	Extends defaults/options.
	
	options.classes.automaticRunning
		This class is added to the automatic link when the deck is currently in running
		state.
		
	options.classes.automaticStopped
		This class is added to the automatic link when the deck is currently in stopped
		state.
		
	options.selectors.automaticLink
		The elements that match this selector will toggle automatic run of the deck
		when clicked.
	*/
	$.extend(true, $[deck].defaults, {
		classes: {
			automaticRunning: 'deck-automatic-running',
			automaticStopped: 'deck-automatic-stopped'
		},
		
		selectors: {
			automaticLink: '.deck-automatic-link'
		},
		
		automatic: {
			startRunning: true,
			cycle: true,
			slideDuration: 3000
		}
	});

	$d.bind('deck.init', function() {
		var opts = $[deck]('getOptions'),
		slides = $[deck]('getSlides'),
		$current = $[deck]('getSlide'),
		ndx;
		
		// Setup initial state
		if (opts.automatic.startRunning) {
			$(opts.selectors.automaticLink).addClass(opts.classes.automaticRunning);
		}
		setTimeoutIfNeeded(null, ndx, ndx);
		
		// Setup automatic link events
		$(opts.selectors.automaticLink)
		.unbind('click.deckautomatic')
		.bind('click.deckautomatic', function(e) {
			$(this).toggleClass(opts.classes.automaticRunning + ' ' + opts.classes.automaticStopped);
			if ($(this).hasClass(opts.classes.automaticRunning)) {
				// Should start
				setTimeoutIfNeeded(null, ndx, ndx);
			}
			else {
				// Should stop
				clearAutomaticTimeout();
			}
		});
	})
	.bind('deck.change', setTimeoutIfNeeded);
})(jQuery, 'deck');
