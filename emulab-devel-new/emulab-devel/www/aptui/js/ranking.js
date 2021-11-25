$(function ()
{
    'use strict';
    var templates = APT_OPTIONS.fetchTemplateList(['ranking', 'output-dropdown']);
    var mainTemplate    = _.template(templates['ranking']);
    var dropdownString  = templates['output-dropdown'];
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	var userlist = decodejson('#user-json');
	var projlist = decodejson('#project-json');
	var proflist = decodejson('#profile-json');
	
	// Generate the main template.
	var html = mainTemplate({
	    "users"     : userlist,
	    "projects"  : projlist,
	    "profiles"  : proflist,
	    "allusers"  : window.ALLUSERS,
	    "days"      : window.DAYS,
	});
	$('#main-body').html(html);
	InitTable("users");
	InitTable("projects");
	InitTable("profiles");

        // Javascript to enable link to tab
        var hash = document.location.hash;
        if (hash) {
            $('.nav-tabs a[href="'+hash+'"]').tab('show');
        }
        // Change hash for page-reload
        $('a[data-toggle="tab"]').on('show.bs.tab', function (e) {
            window.location.hash = e.target.hash;
        });

	// Button to change the number of days.
	$('#update-results').click(function () {
	    var days = $('#days').val();
	    var url  = "ranking.php?days=" + days;

	    if ($('#allusers').is(':checked')) {
		url = url + "&allusers=1";
	    }
	    window.location.replace(url);
	});
    }
    
    function InitTable(name)
    {
	var tablename  = "#" + name + "_table";
	var searchname = "#" + name + "_search";
	
	var table = $(tablename)
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra", "filter", "output"],
		    headerTemplate : '{content} {icon}',

		    widgetOptions: {
			// include child row content while filtering, if true
			filter_childRows  : true,
			// include all columns in the search.
			filter_anyMatch   : true,
			// class name applied to filter row and each input
			filter_cssFilter  : 'form-control input-sm',
			// search from beginning
			filter_startsWith : false,
			// Set this option to false for case sensitive search
			filter_ignoreCase : true,
			// Only one search box.
			filter_columnFilters : false,

			// ',' 'json', 'array' or separator (e.g. ',')
			output_separator     : ',',
			// columns to ignore [0, 1,... ] (zero-based index)
			output_ignoreColumns : [],
			// include hidden columns in the output
			output_hiddenColumns : false,
			// include footer rows in the output
			output_includeFooter : true,
			// data-attribute containing alternate cell text
			output_dataAttrib    : 'data-name',
			// output all header rows (multiple rows)
			output_headerRows    : true,
			// (p)opup, (d)ownload
			output_delivery      : 'p',
			// (a)ll, (f)iltered or (v)isible
			output_saveRows      : 'f',
			// duplicate output data in tbody colspan/rowspan
			output_duplicateSpans: true,
			// change quote to left double quote
			output_replaceQuote  : '\u201c;',
			// output includes all cell HTML (except header cells)
			output_includeHTML   : true,
			// remove extra white-space characters (trim)
			output_trimSpaces    : false,
			// wrap every cell output in quotes
			output_wrapQuotes    : false,
			output_popupStyle    : 'width=580,height=310',
			output_saveFileName  : 'mytable.csv',
			// callbackJSON used when outputting JSON &
			// any header cells has a colspan - unique
			// names required
			output_callbackJSON  : function($cell,txt,cellIndex) {
			    return txt + '(' + cellIndex + ')'; },
			// callback executed when processing completes
			// return true to continue download/output
			// return false to stop delivery & do
			// something else with the data
			output_callback      : function(config, data) {
			    return true; },

			output_encoding      :
			      'data:application/octet-stream;charset=utf8,'
		    }
		});

	// Target the $('.search') input using built in functioning
	// this binds to the search using "search" and "keyup"
	// Allows using filter_liveSearch or delayed search &
	// pressing escape to cancel the search
	$.tablesorter.filter.bindSearch(table, $(searchname));

	//
	// All this output stuff from the example page.
	//
	var $this = $("#" + name + " .output-dropdown-control");
	
	$this.html(dropdownString);
	// Minor adjustment.
	$this.find('.btn-group').css("margin-top", "-2px");
	
	$this.find('.dropdown-toggle').click(function(e){
	    // this is needed because clicking inside the dropdown will close
	    // the menu with only bootstrap controlling it.
	    $this.find('.dropdown-menu').toggle();
	    return false;
	});
	// make separator & replace quotes buttons update the value
	$this.find('.output-separator').click(function(){
	    $this.find('.output-separator').removeClass('active');
	    var txt = $(this).addClass('active').html()
	    $this.find('.output-separator-input').val( txt );
	    $this.find('.output-filename').val(function(i, v){
		// change filename extension based on separator
		var filetype = (txt === 'json' || txt === 'array') ? 'js' :
		    txt === ',' ? 'csv' : 'txt';
		return v.replace(/\.\w+$/, '.' + filetype);
	    });
	    return false;
	});
	$this.find('.output-quotes').click(function(){
	    $this.find('.output-quotes').removeClass('active');
	    $this.find('.output-replacequotes')
		.val( $(this).addClass('active').text() );
	    return false;
	});

	// clicking the download button; all you really need is to
	// trigger an "output" event on the table
	$this.find('.download').click(function(){
	    var typ,
            wo = table[0].config.widgetOptions;
            var saved = $this.find('.output-filter-all :checked').attr('class');
	    wo.output_separator    = $this.find('.output-separator-input').val();
	    wo.output_delivery     =
		$this.find('.output-download-popup :checked')
		.attr('class') === "output-download" ? 'd' : 'p';
	    wo.output_saveRows     = saved === "output-filter" ? 'f' :
		saved === 'output-visible' ? 'v' : 'a';
	    wo.output_replaceQuote = $this.find('.output-replacequotes').val();
	    wo.output_trimSpaces   = $this.find('.output-trim').is(':checked');
	    wo.output_includeHTML  = $this.find('.output-html').is(':checked');
	    wo.output_wrapQuotes   = $this.find('.output-wrap').is(':checked');
	    wo.output_headerRows   = $this.find('.output-headers').is(':checked');
	    wo.output_saveFileName = $this.find('.output-filename').val();
	    table.trigger('outputTable');
	    return false;
	});
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    $(document).ready(initialize);
});


