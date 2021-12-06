$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['ssh-keys', 'oops-modal', 'waitwait-modal']);
    var sshkeysString = templates['ssh-keys'];
    var oopsString = templates['oops-modal'];
    var waitwaitString = templates['waitwait-modal'];

    var embedded        = 0;
    var target_uid      = "";
    var nonlocal        = false;
    var sshkeysTemplate = _.template(sshkeysString);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	embedded = window.EMBEDDED;
	nonlocal = window.NONLOCAL;
	target_uid = window.TARGET_UID;
	var pubkeys = JSON.parse(_.unescape($('#sshkey-list')[0].textContent));

	var html = sshkeysTemplate({
	    pubkeys:	pubkeys,
	    nonlocal:	nonlocal,
	});
	$('#page-body').html(html);
	$('#oops_div').html(oopsString);
	$('#waitwait_div').html(waitwaitString);

	//
	// Fix for filestyle problem; not a real class I guess, it
	// runs at page load, and so the filestyle'd button in the
	// form is not as it should be.
	//
	$('#sshkey_file').each(function() {
	    $(this).filestyle({input      : false,
			       buttonText : $(this).attr('data-buttonText'),
			       classButton: $(this).attr('data-classButton')});
	});

	//
	// File upload handler.
	// 
	$('#sshkey_file').change(function() {
		var reader = new FileReader();
		reader.onload = function(event) {
		    $('#sshkey_data').val(event.target.result);
		};
		reader.readAsText(this.files[0]);
	});

	// Handler for all of the delete buttons.
	$('.delete_pubkey_button').click(function (event) {
	    event.preventDefault();
	    var index     = $(this)[0].dataset['key'];
	    HandleDeleteKey(index);
	});

	// Form reset button.
	$('#ssh_clear_button').click(function (event) {
	    console.log("foo");
	    event.preventDefault();
	    $('#sshkey_data').val("");
	});
	// Add key button.
	$('#ssh_addkey_button').click(function (event) {
	    event.preventDefault();
	    HandleAddKey();
	});
    }

    /*
     * Submit key, look for error.
     */
    function HandleAddKey()
    {
	var keydata = $('#sshkey_data').val();
	if (keydata == "") {
	    alert("Key cannot be blank!");
	    return;
	}
	var callback = function(json) {
	    console.info(json);
	    sup.HideModal("#waitwait-modal");

	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (embedded) {
		window.parent.location.replace("../ssh-keys.php?user=" +
					       target_uid);
	    }
	    else {
		window.location.replace("ssh-keys.php?user=" + target_uid);
	    }
	}
	sup.ShowModal("#waitwait-modal");

	var xmlthing = sup.CallServerMethod(null, "ssh-keys", "addkey",
					    {"keydata"    : keydata,
					     "target_uid" : target_uid});
	xmlthing.done(callback);
    }
    
    function HandleDeleteKey(index)
    {
	var callback = function(json) {
	    console.info(json);
	    sup.HideModal("#waitwait-modal");

	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    $('#panel_' + index).remove();
	}
	sup.ShowModal("#waitwait-modal");

	var xmlthing = sup.CallServerMethod(null, "ssh-keys", "deletekey",
					    {"index"      : index,
					     "target_uid" : target_uid});
	xmlthing.done(callback);
    }
    
    $(document).ready(initialize);
});
