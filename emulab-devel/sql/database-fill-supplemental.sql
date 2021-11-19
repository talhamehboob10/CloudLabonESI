-- 
-- database-fill-supplemental.sql - Various things that need to go into new
-- sites' databases, but don't really fit into database-fill.sql, which is
-- auto-generated. Also, unlike the contents of database-fill.sql, inserting
-- these is not idempotent, since a site may have changed them for some reason.
--

INSERT IGNORE INTO `node_types` VALUES ('pc','pc',NULL,NULL,NULL,0,0,0,0,0,0,0,0,0,0,0,0);
INSERT IGNORE INTO`node_type_attributes` VALUES ('pc','imageable','1','boolean');
INSERT IGNORE INTO `node_types` VALUES ('pcvm','pcvm',NULL,NULL,NULL,1,0,1,1,0,0,0,0,0,0,0,0);
INSERT IGNORE INTO`node_type_attributes` VALUES ('pcvm','rebootable','1','boolean');
INSERT IGNORE INTO `node_types` VALUES ('pcvwa','pcvwa',NULL,NULL,NULL,1,0,0,1,1,0,0,0,0,0,0,0);
INSERT IGNORE INTO `node_type_attributes` VALUES ('pcvwa','default_osid','0','integer');

INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','4.10','delay','/kernel.delay');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','4.10','vnodehost','/kernel.jail');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','4.10','linkdelay','/kernel.linkdelay');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','5.4','delay','/boot/kernel.delay/kernel');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','5.4','linkdelay','/boot/kernel.linkdelay/kernel');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','6.2','delay','/boot/kernel.poll/kernel HZ=10000');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','6.2','linkdelay','/boot/kernel/kernel HZ=1000');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','7.3','delay','/boot/kernel.poll/kernel HZ=10000');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','8.2','delay','/boot/kernel/kernel kern.hz=10000');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','8.3','delay','/boot/kernel/kernel kern.hz=10000');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','10.2','delay','/boot/kernel/kernel kern.hz=10000');
INSERT IGNORE INTO os_boot_cmd VALUES ('FreeBSD','10.3','delay','/boot/kernel/kernel kern.hz=10000');
INSERT IGNORE INTO os_boot_cmd VALUES ('Linux','9.0','linkdelay','linkdelay');

INSERT IGNORE INTO emulab_indicies (name,idx) VALUES ('cur_log_seq', 1);
INSERT IGNORE INTO emulab_indicies (name,idx) VALUES ('frisbee_index', 1);
INSERT IGNORE INTO emulab_indicies (name,idx) VALUES ('next_osid', 10000);
-- The initial certs start at hardwired location cause no DB during install
-- Push this up so that user certs start above it. 
INSERT IGNORE INTO emulab_indicies (name,idx) VALUES ('user_sslcerts', 1000);
INSERT IGNORE INTO emulab_locks (name,value) VALUES ('pool_daemon', 0);

INSERT IGNORE INTO `interface_capabilities` VALUES ('generic','protocols','ethernet');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic','ethernet_defspeed','100000');
INSERT IGNORE INTO `interface_types` VALUES ('generic',100000,1,'Generic','Generic',1,'RJ45');
INSERT IGNORE INTO `interface_types` VALUES ('generic_1G',1000000,1,'Generic GB','Generic GB',1,'RJ45');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_1G','protocols','ethernet');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_1G','ethernet_defspeed','1000000');
INSERT IGNORE INTO `interface_types` VALUES ('generic_10G',10000000,1,'Generic GB','Generic 10GB',1,'RJ45');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_10G','protocols','ethernet');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_10G','ethernet_defspeed','10000000');
INSERT IGNORE INTO `interface_types` VALUES ('generic_40G',40000000,1,'Generic 40GB','Generic 40GB',1,'RJ45');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_40G','protocols','ethernet');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_40G','ethernet_defspeed','40000000');
INSERT IGNORE INTO `interface_types` VALUES ('generic_25G',25000000,1,'Generic 25GB','Generic 25GB',1,'RJ45');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_25G','protocols','ethernet');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_25G','ethernet_defspeed','25000000');
INSERT IGNORE INTO `interface_types` VALUES ('generic_100G',100000000,1,'Generic 100GB','Generic 100GB',1,'RJ45');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_100G','protocols','ethernet');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_100G','ethernet_defspeed','100000000');
INSERT IGNORE INTO `interface_types` VALUES ('generic_56G',56000000,1,'Generic 56GB','Generic 56GB',1,'RJ45');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_56G','protocols','ethernet');
INSERT IGNORE INTO `interface_capabilities` VALUES ('generic_56G','ethernet_defspeed','56000000');

-- We use these types for the ilo/drac management interfaces.
INSERT INTO `interface_types` VALUES ('ilo2',0,1,'HP','HP iLO 2',1,'RJ45');
INSERT INTO `interface_types` VALUES ('ilo3',0,1,'HP','HP iLO 3',1,'RJ45');
INSERT INTO `interface_types` VALUES ('drac',0,1,'Dell','Dell Drac',1,'RJ45');
INSERT INTO `interface_types` VALUES ('ipmi15',0,1,'IPMI','IPMI 1.5',1,'RJ45');
INSERT INTO `interface_types` VALUES ('ipmi20',0,1,'IPMI','IPMI 2.0',1,'RJ45');

-- For the external link support.
INSERT INTO `node_types` VALUES ('bbgeni','bbgeni',NULL,NULL,NULL,0,0,0,0,0,0,0,0,0,0,0,0);
INSERT INTO `node_types` VALUES ('bbgenivm','bbgenivm',NULL,NULL,NULL,1,0,0,1,0,0,0,0,0,0,0,0);
INSERT INTO `node_type_attributes` VALUES ('bbgeni','rebootable','0','boolean');
INSERT INTO `node_type_attributes` VALUES ('bbgeni','imageable','0','boolean');
INSERT INTO `node_type_attributes` VALUES ('bbgenivm','rebootable','0','boolean');
INSERT INTO `node_type_attributes` VALUES ('bbgenivm','imageable','0','boolean');
INSERT INTO `interface_types` VALUES ('bbg',1000000,1,'Unknown','Gigabit Ethernet',1,'RJ45');
INSERT INTO `interface_capabilities` VALUES ('bbg','ethernet_defspeed','1000000');
INSERT INTO `interface_capabilities` VALUES ('bbg','protocols','ethernet');

-- Bump first lan above real vlan number. Cause of a bug in how we
-- calculate tag numbers for looped links. Need a better fix later.
ALTER TABLE lans AUTO_INCREMENT = 5000;
