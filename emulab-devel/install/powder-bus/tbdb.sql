UPDATE images set architecture='x86_64';

REPLACE INTO `node_types`
  VALUES ('power','powduino',NULL,NULL,NULL,0,0,0,0,0,0,0,0,0,0,0,0);
REPLACE INTO `node_type_attributes`
  VALUES ('powduino','rebootable','0','boolean');
REPLACE INTO `node_type_attributes`
  VALUES ('powduino','imageable','0','boolean');
REPLACE into `nodes` set
      node_id='powduino',phys_nodeid='powduino',
      type='powduino',role='powerctrl';
REPLACE into `outlets` set
      node_id='ed1-real',power_id='powduino',outlet='0';
REPLACE INTO `outlets` set
      node_id='n300-1',power_id='powduino',outlet='1';
REPLACE INTO `outlets` set
      node_id='frontend',power_id='powduino',outlet='2';
REPLACE INTO `outlets` set
      node_id='switch',power_id='powduino',outlet='3';
REPLACE into node_attributes
  VALUES ('ed1', 'reservation_autoapprove_limit', '0', '0');
REPLACE into node_attributes
  VALUES ('n300-1', 'reservation_autoapprove_limit', '0', '0');

replace INTO `node_type_attributes` VALUES ('e300-8d','powercycleafterreload','1','boolean');
replace INTO `node_type_attributes` VALUES ('e300-8d','delayreloadtillalloc','1','boolean');
replace INTO `node_type_attributes` VALUES ('e300-8d','reservation_autoapprove_limit','0','integer');

REPLACE INTO `interface_types` VALUES ('P2PLTE',100000,1,'NA','NA',1,'Wireless');
REPLACE INTO `interface_capabilities` VALUES ('P2PLTE','protocols','P2PLTE');
REPLACE INTO `interface_capabilities` VALUES ('P2PLTE','P2PLTE_defspeed','10000');
REPLACE INTO `interface_capabilities` VALUES ('P2PLTE','overtheair','1');

REPLACE INTO `interface_types` VALUES ('RFF-FDD',100000,1,'NA','NA',1,'FDD');
REPLACE INTO `interface_capabilities` VALUES ('RFF-FDD','protocols','RFF-FDD');
REPLACE INTO `interface_capabilities` VALUES ('RFF-FDD','RFF-FDD_defspeed','10000');
REPLACE INTO `interface_capabilities` VALUES ('RFF-FDD','overtheair','1');

REPLACE INTO `interface_types` VALUES ('RFF-TDD',100000,1,'NA','NA',1,'TDD');
REPLACE INTO `interface_capabilities` VALUES ('RFF-TDD','protocols','RFF-TDD');
REPLACE INTO `interface_capabilities` VALUES ('RFF-TDD','RFF-TDD_defspeed','10000');
REPLACE INTO `interface_capabilities` VALUES ('RFF-TDD','overtheair','1');

REPLACE INTO `node_type_features` VALUES ('e300-8d','?+disk_sysvol',454000);
REPLACE INTO `node_type_features` VALUES ('e300-8d','?+disk_any',454000);
REPLACE INTO `node_type_features` VALUES ('e300-8d','?+disk_nonsysvol',0);
