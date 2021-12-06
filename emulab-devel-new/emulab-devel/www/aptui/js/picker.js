$(function() {
window.picker = (function() {
    var templates = APT_OPTIONS.fetchTemplateList(['picker-template']);
    var pickerTemplate = _.template(templates['picker-template']);

    /*  target - <select> element to picker

	clickCallback - Function that gets called when an item is clicked on

	optionAttributes - If provided, attributes for specific list items to be added to the li HTML for that item.
			   Matched by item's value.
	example:
	{
	    "Cloudlab Utah": {
		class: "class-1 class-2"
		attr: { attr-1: "value-1", attr-2: "value-2" },
		tooltip: {
		    placement: 'right',
		    title: '<div>This testbed is incompatible with the selected profile</div>'
		}
	    }
	}

	dividers - If provided, the list elements will be separated by dividers as defined by the object.
		   name is optional

		   All elements that match the condition will be but BELOW the divider.
		   If an element matches more than one condition, it will be put under the bottom-most match.
		   Order of dividers will be from top to bottom.
	example:
	[
	    {
		match: 'class',
		key: 'federated',
		text: 'Federated Clusters'
	    },
	    {
		match: 'attr',
		key: 'data-health',
		value: '0',
		text: 'Clusters Down'
	    },
	    {
		match: 'attr',
		key: 'disabled'
	    }
	]

	pickerAttributes - HTML attributes to be added to the list container
	example:
	{
	    id: 'cluster1_picker',
	    class: 'cluster_picker_status cluster1',
	    attr: { data-cluser:, '1' }
	}
    */
    function MakePicker(target, clickCallback=null, optionAttributes=null, dividers=null, pickerAttributes=null) {
	if ($(target).hasClass('pickered')) {
	    return 0;
	}
	$(target).addClass('pickered');

	var options = $(target).find('option');

	var items = MakeListElements(options, optionAttributes);

	var divided = MakeDividers(items, dividers);

	if (!pickerAttributes) {
	    pickerAttributes = {}
	}

	if (!pickerAttributes['id'] && $(target).attr('id')) {
	    pickerAttributes['id'] = $(target).attr('id') + '_picker';
	}

	var html = pickerTemplate({
	    items: divided,
	    pickerAttributes: pickerAttributes
	});

	$(target).after(html);
	$(target).addClass('hidden');

	var container = '#'+pickerAttributes['id'];
	$(container).find('.dropdown-menu a').on('click', function() {
	    if (!$(this).hasClass('disabled')) {
		PickerItemClickEvent(target, container, this);

		if (clickCallback) { clickCallback(container, this, target); }
	    }
	});

	$(target).find('option:selected').removeAttr('')

	$('[data-toggle="tooltip"]').tooltip();

	return 1;
    }

    // Private Functions

    function MakeListElements(options, optionAttributes) {
    	items = [];

	_.each(options, function(element) {
	    item = {
		attr: {},
		class: ''
	    }

	    item['html'] = $(element).html();
	    item['value'] = $(element).attr('value');

	    if ($(element).prop('selected')) {
	    	item['class'] += 'initial ';
	    }
	    if (optionAttributes && optionAttributes[item['value']]) {
		var attributes = optionAttributes[item['value']];

		if (attributes['class']) {
		    item['class'] += attributes['class'];
		}

		if (attributes['attr']) {
		    _.each(attributes['attr'], function(value, key) {
			item['attr'][key] = value;
		    });
		}

		if (attributes['tooltip']) {
		    item['tooltip'] = attributes['tooltip'];
		}
	    }

	    items.push(item);
	});

	return items;
    }

    function MakeDividers(items, dividerInfo) {
	var dividers = [ { elements: [] } ];

	if (!dividerInfo) {
	    dividers[0]['elements'] = items;
	    return dividers;
	}

	_.each(dividerInfo, function(info) {
	    var divider = {
		info: info,
		elements: []
	    }

	    dividers.push(divider);
	});

	_.each(items, function(item) {
	    for (var i = dividers.length-1; i > -1; i--) {
		var match = false;

		if (i > 0) {
		    var info = dividers[i]['info'];
		    var key = info['key'];

		    if (info['match'] == 'class') {
			if (item['class'].indexOf(key) > -1) {
			    match = true;
			}
		    }
		    else if (info['match'] == 'attr') {
			if (item['attr']['key']) {
			    if (info['value']) {
				var value = info['value'];

				if (item['attr']['key'] == value) {
				    match = true;	
				}
			    }
			    else {
				match = true;
			    }
			}
		    }
		} 
		else {
		    match = true;
		}

		if (match) {
		    dividers[i]['elements'].push(item);
		    break;
		}
	    }
	});

	return dividers
    }

    function PickerItemClickEvent(target, container, that) {
	$(target).val($(that).attr('value'));

	$(container).find('.dropdown-toggle .value').html($(that).attr('value'));
	$(container).find('.selected').removeClass('selected');
	$(that).parent().addClass('selected');
    }

    return {
	MakePicker: MakePicker
    };
})();
});