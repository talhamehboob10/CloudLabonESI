<?php
#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

# Alternate domain def structures.  The first element of the outermost
# array is the regex pattern to match against $_SERVER['SERVER_NAME'].
# The second element is another array that contains key-value pairs
# for various top-level variable overrides.  See SetDomainDefs() in
# defs.php3 for more info.

#
# PhantomNet view declaration
#
$PNET_DOMVIEW = array('hide_sidebar' => 0, 'hide_banner' => 0,
		      'hide_copyright' => 0, 'show_pnet' => 1,
		      'css-override' => 1, 'hide_elab' => 1);

$ALTERNATE_DOMAINS[] = 
    array('/phantom/', 
	  array('THISHOMEBASE' => 'PhantomNet',
		'WIKINODE' => 'wiki.phantomnet.org',
		'FORUMURL' => 'http://groups.google.com/group/phantomnet-users',
		'DOMVIEW' => $PNET_DOMVIEW
		));

?>