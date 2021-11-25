<?php
#
# Copyright (c) 2000-2015, 2018 University of Utah and the Flux Group.
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
require("defs.php3");

#
# Anyone can run this page. No login is needed.
# 
PAGEHEADER("Emulab Software Distributions");

# Insert plain html inside these brackets. Outside the brackets you are
# programming in php!
?>

<ul>
<li> The latest version of the Emulab software can be
     <a href="https://gitlab.flux.utah.edu/emulab/emulab-devel/wikis/Git-Repository">downloaded via Git</a>.
</li>

<br>
    
<li> The Frisbee disk loader;
     We no longer support Frisbee as a separate distribution.
     The Frisbee source is part of the Emulab source distribution and can
     be found in the <code>clientside/os/frisbee.redux</code> subdirectory.
     It is normally built as part of the complete Emulab build process,
     but there is a <code>Makefile.sa-linux</code> which should work to build
     Frisbee independently of Emulab. The tool for creating Frisbee format
     disk images is in the <code>clientside/os/imagezip subdirectory</code>.
     Likewise, there is a <code>Makefile.sa-linux</code> standalone Makefile.
     <p>
     We also no longer distribute a bootable FreeBSD ISO image with
     the Frisbee client included. The last such distribution is from
     July 2008 and can still be found
     <a href="/downloads/frisbee6-fs-20080702.iso">here</a>,
     but it is based on FreeBSD 6 and is unlikely to boot on any
     modern hardware. However, with a small amount of work you should
     be able to build the Frisbee client and embed it in the bootable
     distro of your choice.
     </li>
</ul>

<?php


#
# Standard Footer.
# 
PAGEFOOTER();
