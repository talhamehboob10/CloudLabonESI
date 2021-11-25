require(window.APT_OPTIONS.configObject,
	['js/quickvm_sup'],
function (sup)
{
    'use strict';

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
    }

    $(document).ready(initialize);
});
