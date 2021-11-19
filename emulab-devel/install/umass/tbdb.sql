update images set architecture='x86_64';

REPLACE into tipservers values ("boss.cloudlab.umass.edu");

REPLACE into tiplines set 
    tipname='pc01',node_id='pc01',server='boss.cloudlab.umass.edu',disabled=0;
REPLACE into tiplines set 
    tipname='pc02',node_id='pc02',server='boss.cloudlab.umass.edu',disabled=0;
REPLACE into tiplines set 
    tipname='pc03',node_id='pc03',server='boss.cloudlab.umass.edu',disabled=0;
REPLACE into tiplines set 
    tipname='pc04',node_id='pc04',server='boss.cloudlab.umass.edu',disabled=0;
REPLACE into tiplines set 
    tipname='pc05',node_id='pc05',server='boss.cloudlab.umass.edu',disabled=0;

REPLACE into `outlets` set
      node_id='pc01',power_id='ipmi20',outlet='0';
REPLACE into `outlets` set
      node_id='pc02',power_id='ipmi20',outlet='0';
REPLACE into `outlets` set
      node_id='pc03',power_id='ipmi20',outlet='0';
REPLACE into `outlets` set
      node_id='pc04',power_id='ipmi20',outlet='0';
REPLACE into `outlets` set
      node_id='pc05',power_id='ipmi20',outlet='0';

INSERT INTO `outlets_remoteauth`
   VALUES ('pc01','ipmi20','ipmi-passwd','root','root',NULL);
INSERT INTO `outlets_remoteauth`
   VALUES ('pc02','ipmi20','ipmi-passwd','root','root',NULL);
INSERT INTO `outlets_remoteauth`
   VALUES ('pc03','ipmi20','ipmi-passwd','root','root',NULL);
INSERT INTO `outlets_remoteauth`
   VALUES ('pc04','ipmi20','ipmi-passwd','root','root',NULL);
INSERT INTO `outlets_remoteauth`
   VALUES ('pc05','ipmi20','ipmi-passwd','root','root',NULL);
