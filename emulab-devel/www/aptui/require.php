<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

# require.php
# -----------
#
# A simple library for managing dependencies with libraries and templates. Libraries are JavaScript code that is included with <script src="something.js"></script>. Templates are raw text blobs that are directly included in the DOM.
#
# ---------
# Libraries
# ---------
#
# Every top-level PHP file that uses JS code should contain a block of code near the end that prints out all script tags for all libraries. It looks like this:
#    REQUIRE_LIBRARY();
#    REQUIRE_OTHER_LIBRARY();
#    SPITREQUIRE("js/somemain.js");
#
# The REQUIRE_* functions are defined below to include the specified library and all dependencies. SPITREQUIRE() is used to include the main JS file for this page. If there is no main JS file, SPITNULLREQUIRE() includes a default 'main.js' which provides the minimum amount of javascript to make it behave like other pages.
# REQUIRE_* function must be invoked before SPITREQUIRE(). Both of these must be invoked before SPITFOOTER().
#
# ---------
# Templates
# ---------
# Templates are embedded by adding them to the template dependency list at any point before SPITFOOTER(). The key is used as the id for the script tag and is is used to look up the template in the JS code. So the key should only be alphanumeric characters plus '-' and use of that id elsewhere in the page should be avoided.
#    # Creates a template with key 'foo' from text at path 'template/foo.html'
#    AddTemplate("foo");
#    # Creates templates with keys 'foo' and 'bar' from text at paths 'template/foo.html' and 'template/bar.html'
#    AddTemplateList(array("foo", "bar")); 
#    # Creates a template with key 'arbitrary-key' from text at 'arbitrary/path/here.something'
#    AddTemplateKey("arbitrary-key", "arbitrary/path/here.something");
#    # Actually spit out the encoded text files along with the page footer.
#    SPITFOOTER()
#
# Both libraries and templates will only ever be included once per page. Library includes happen before including the main JS file and each libraries dependencies will be included before it is. Templates are included at the very end of the resulting file.
#
# ------------------
# Creating Libraries
# ------------------
#
# Most standard JS libraries can be included simply by adding a REQUIRE_LIBRARY() function below which adds them to the dependency list. Whatever symbols are exported to the global (window) namespace in JS will be available to use to any page which invokes the REQUIRE_LIBRARY() function. If a library has dependencies on other libraries, its REQUIRE_LIBRARY() function simply needs to invoke the REQUIRE_ function for those other libraries.
#
# Custom libraries can use both other libraries and templates. Their REQUIRE_ functions will include appropriate AddTemplate calls. Then they simply need this boilerplate around them in their JS file:
#
#   $(function() {
#     var templates = APT_OPTIONS.fetchTemplateList(['template-foo', 'template-bar']);
#     // templates['template-foo'] and templates['template-bar'] can now be used whenever the text is required.
#     window.SOME_SYMBOL = ...;
#     // Libraries that this library is dependant on can be accessed using their global 'window' symbols.
#   });
#
# ------------
# Main JS File
# ------------
#
# The Main JS File should have this boilerplate:
#
#   $(function () {
#     var templates = APT_OPTIONS.fetchTemplateList(['template-foo', 'template-bar']);
#     // templates['template-foo'] and templates['template-bar'] can now be used whenever the text is required.
#     // Libraries that this main file is dependant on can be accessed using their global 'window' symbols.
#   });

# Dependency lists

$PORTAL_TEMPLATES = array();
$PORTAL_LIBRARIES = array();

# Flag to signal that a requires was spit. For errors.
$spatrequired = 0;

#########################################################################################

function REQUIRE_APTFORMS()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_SUP();
  AddLibrary("js/aptforms.js");
}

function REQUIRE_BILEVEL()
{
  AddLibrary("js/bilevel.js");
}

function REQUIRE_CONTEXTMENU()
{
  AddLibrary("js/lib/bootstrap-contextmenu.js");
}

function REQUIRE_DATEFORMAT()
{
  AddLibrary("js/lib/date.format.js");
}

function REQUIRE_EXTEND()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_SUP();
  AddTemplateList(array("user-extend-modal"));
  AddLibrary("js/extend.js");
}

function REQUIRE_FILESIZE()
{
  AddLibrary("js/lib/filesize.min.js");
}

function REQUIRE_FILESTYLE()
{
  AddLibrary("js/lib/filestyle.js");
}

function REQUIRE_FORMHELPERS()
{
  AddLibrary("js/lib/bootstrap-formhelpers.js");
}

function REQUIRE_GENI_AUTH()
{
  AddLibrary("https://www.emulab.net/protogeni/speaks-for/geni-auth.js");
}

function REQUIRE_IDLEGRAPHS()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_SUP();
  REQUIRE_MOMENT();
  AddLibrary("js/idlegraphs.js");
}

function REQUIRE_IMAGE()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_SUP();
  REQUIRE_FILESIZE();
  AddTemplate("imaging-modal");
  AddLibrary("js/image.js");
}

function REQUIRE_JACKS()
{
  REQUIRE_JACKSMOD();
  AddLibrary("https://www.emulab.net/protogeni/jacks-utah/js/jacks.js");
}

function REQUIRE_JACKSMOD()
{
  $root = "https://www.emulab.net/protogeni/app/jacksmod/";
  AddLibrary($root . "jacksmod.js");
  AddLibrary($root . "common/loadbase.js");
  AddLibrary($root . "common/base.js");
  AddLibrary($root . "common/Component.js");
  AddLibrary($root . "common/util.js");
  AddLibrary($root . "common/ForceGraph.js");
  AddLibrary($root . "common/Graph.js");
  AddLibrary($root . "common/RspecLib.js");
  AddLibrary($root . "common/RspecParser.js");
  AddLibrary($root . "common/component/WaitingComponent.js");
  AddLibrary($root . "common/component/MapComponent.js");
  AddLibrary($root . "common/component/GraphNodeComponent.js");
  AddLibrary($root . "common/component/GraphLanComponent.js");
  AddLibrary($root . "common/component/GraphComponent.js");
  AddLibrary($root . "common/component/FailedComponent.js");
  AddLibrary($root . "common/component/ImagePickerComponent.js");
  AddLibrary($root . "thumb/ThumbComponent.js");
  AddLibrary($root . "imagepicker/main.js");
  AddLibrary($root . "thumb/main.js");
  AddLibrary($root . "common/loadcomplete.js");
}

function REQUIRE_JACKS_EDITOR()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_JACKS();
  AddTemplate("edit-modal");
  AddTemplate("edit-inline");
  AddLibrary("js/JacksEditor.js");
}

function REQUIRE_JQUERY_STEPS()
{
  AddLibrary("js/lib/jquery.steps.js");
}

function REQUIRE_LIQUIDFILLGAUGE()
{
  AddLibrary("js/liquidFillGauge.js");
}

function REQUIRE_MARKED()
{
  AddLibrary("js/lib/marked.js");
}

function REQUIRE_MOMENT()
{
  AddLibrary("js/lib/moment.js");
}

# This breaks the powder map, something in arcgis.
function REQUIRE_MOMENTTIMEZONE()
{
  AddLibrary("js/lib/moment-timezone.js");
}

function REQUIRE_TABLESORTER($extras = null)
{
    echo "<link rel='stylesheet'
                href='css/tablesorter-bootstrap_3.css'>\n";
    
  AddLibrary("js/lib/tablesorter/jquery.tablesorter.combined.js");
  AddLibrary("js/lib/sugar.min.js");
  AddLibrary("js/lib/tablesorter/parsers/parser-date.js");
  AddLibrary("js/lib/tablesorter/widgets/widget-math.js");
  if ($extras) {
      foreach ($extras as $extra) {
          AddLibrary($extra);
      }
  }
}

function REQUIRE_OPENSTACKGRAPHS()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_SUP();
  REQUIRE_MOMENT();
  AddLibrary("js/openstackgraphs.js");
}

function REQUIRE_PPWIZARDSTART()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_SUP();
  REQUIRE_JACKS_EDITOR();
  AddTemplate("choose-am");
  AddTemplate("image-picker-modal");
  AddTemplate("ppform-wizard");
  AddLibrary("js/ppwizardstart.js");
}

function REQUIRE_SUP()
{
  REQUIRE_DATEFORMAT();
  REQUIRE_MARKED();
  AddLibrary("js/quickvm_sup.js");
}

function REQUIRE_UNDERSCORE()
{
  AddLibrary("js/lib/underscore-min.js");
}

function REQUIRE_URITEMPLATE()
{
  AddLibrary("js/lib/uritemplate.js");
}

function REQUIRE_WIZARD_TEMPLATE()
{
  REQUIRE_UNDERSCORE();
  AddLibrary("js/wizard-template.js");
}

function REQUIRE_PICKER()
{
  REQUIRE_UNDERSCORE();
  AddLibrary("js/picker.js");
}

function REQUIRE_GENILIB_EDITOR()
{
  REQUIRE_UNDERSCORE();
  REQUIRE_SUP();
  REQUIRE_APTFORMS();
  REQUIRE_JACKS();
  AddTemplate("genilib-editor");
  AddLibrary("js/genilib-editor.js");
}

#########################################################################################

function SPITREQUIRE($main, $extras = "")
{
    global $spatrequired, $PORTAL_LIBRARIES, $APTBASE;
    
    echo $extras;
    echo "<script src='$APTBASE/js/lib/bootstrap.js'></script>\n";
    AddLibrary($main);
    EchoLibraryList($PORTAL_LIBRARIES);
    $spatrequired = 1;
}

function SPITNULLREQUIRE()
{
    global $APTBASE;
    
    AddLibrary("$APTBASE/js/quickvm_sup.js");
    SPITREQUIRE("$APTBASE/js/main.js");
}

function SPITREQUIRE_DATASET()
{
    REQUIRE_UNDERSCORE();
    REQUIRE_SUP();
    REQUIRE_MOMENT();
    REQUIRE_APTFORMS();
    SPITREQUIRE("js/create-dataset.js",
                "<script src='js/lib/jquery-ui.js'></script>");
}

#########################################################################################


#
# Echos a plaintext <script> tag with a base64-encoded template inside.
# The <script> tag has an id of $baseName. The template is loaded from
# the path 'template/$baseName.html'
#
function EchoTemplate($key, $value)
{
    echo "\n<script type='text/plain' id='" . $key . "'>\n";
#    echo base64_encode(file_get_contents("template/" . $baseName . ".html")) . "\n";
    echo base64_encode(file_get_contents($value)) . "\n";
    echo "</script>\n";
}

function EchoTemplateList($nameList)
{
    foreach ($nameList as $key => $value) {
        EchoTemplate($key, $value);
    }
}

function AddTemplate($baseName)
{
  global $PORTAL_TEMPLATES;
#  array_push($PORTAL_TEMPLATES, $baseName);
  $PORTAL_TEMPLATES[$baseName] = "template/" . $baseName . ".html";
}

function AddTemplateKey($key, $location)
{
  global $PORTAL_TEMPLATES;
  $PORTAL_TEMPLATES[$key] = $location;
}

function AddTemplateList($nameList)
{
  global $PORTAL_TEMPLATES;
  foreach ($nameList as $index => $name) {
    AddTemplate($name);
#    array_push($PORTAL_TEMPLATES, $name);
  }
}

function AddLibrary($baseName)
{
  global $PORTAL_LIBRARIES;
  $found = 0;
  foreach ($PORTAL_LIBRARIES as $index => $name) {
    if ($name === $baseName) {
      $found = 1;
      break;
    }
  }
  if ($found != 1) {
    array_push($PORTAL_LIBRARIES, $baseName);
  }
}

function EchoLibraryList($nameList)
{
    foreach ($nameList as $index => $name) {
      echo "<script src='$name'></script>\n";
    }
}
