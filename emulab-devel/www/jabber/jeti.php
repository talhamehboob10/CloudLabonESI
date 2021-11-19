<?php
#
# Copyright (c) 2000-2005 University of Utah and the Flux Group.
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

$user	  = $_GET['user'];
$password = $_GET['password'];

echo "<html>
      <head>
        <title>Jeti Applet</title>
      </head>
      <body>
        <applet name=jeti archive=\"applet.jar,plugins/alertwindow.jar,".
           "plugins/emoticons.jar,plugins/groupchat.jar,".
           "plugins/appletloadgroupchat.jar,plugins/sound.jar,".
           "plugins/xhtml.jar\" ".
               "codebase=/jeti ".
               "code=nu.fw.jeti.applet.Jeti.class
                width=50% height=50%>
         <param name=server value=jabber.emulab.net>
         <param name=password value=$password> 
         <param name=user value=$user> 
         <param name=port value=5223> 
         <param name=ssl value=true>
        </applet>
        </body>
        </html>\n";

?>
