REPLACE INTO `interface_types`
  VALUES ('bce',1000000,1,'Broadcom','Gigabit Ethernet',1,'RJ45');
REPLACE INTO `interface_capabilities`
  VALUES ('bce','protocols','ethernet');
REPLACE INTO `interface_capabilities`
  VALUES ('bce','ethernet_defspeed','1000000');

REPLACE INTO `interface_types`
  VALUES ('bnx',10000000,1,'Broadcom','10G Ethernet',1,'RJ45');
REPLACE INTO `interface_capabilities`
  VALUES ('bnx','protocols','ethernet');
REPLACE INTO `interface_capabilities`
  VALUES ('bnx','ethernet_defspeed','10000000');

REPLACE INTO `interface_types`
  VALUES ('igb',1000000,1,'Intel','Gigabit Ethernet',1,'RJ45');
REPLACE INTO `interface_capabilities`
  VALUES ('igb','protocols','ethernet');
REPLACE INTO `interface_capabilities`
  VALUES ('igb','ethernet_defspeed','1000000');

REPLACE INTO `interface_types`
  VALUES ('ilo2',0,1,'HP','HP iLO 2',1,'RJ45');

replace into node_types set
      class='switch', isswitch=1, type='hp2610';
replace into node_type_attributes set
      type='hp2610',attrkey='forwarding_protocols',
      attrvalue='ethernet',attrtype='string';
replace into nodes set
      node_id='procurve1',phys_nodeid='procurve1',type='hp2610',role='ctrlswitch';
REPLACE INTO `switch_stack_types`
  VALUES ('Control','generic',0,0,NULL,128,256,'procurve1');

replace into node_types set
      class='switch', isswitch=1, type='hp6600';
replace into node_type_attributes set
      type='hp6600',attrkey='forwarding_protocols',
      attrvalue='ethernet',attrtype='string';
replace into node_types set
      class='switch', isswitch=1, type='hp5406';
replace into node_type_attributes set
      type='hp5406',attrkey='forwarding_protocols',
      attrvalue='ethernet',attrtype='string';
replace into nodes set
      node_id='procurve2',phys_nodeid='procurve2',type='hp5406',role='testswitch';
replace into node_types set
      class='switch', isswitch=1, type='hp5406r';
replace into node_type_attributes set
      type='hp5406r',attrkey='forwarding_protocols',
      attrvalue='ethernet',attrtype='string';
      
REPLACE INTO `switch_stack_types`
  VALUES ('Experiment','generic',0,0,NULL,257,999,'procurve2');

replace into switch_stacks (node_id,stack_id,is_primary)
      values ('procurve2','Experiment',1),("procurve1",'Control',1);

replace into node_types set
      class='switch', isswitch=1, type='external-switch';
replace into node_type_attributes set
      type='external-switch',attrkey='forwarding_protocols',
      attrvalue='ethernet',attrtype='string';

replace into node_attributes values ('procurve2', 'does_openflow', 'yes', '0');
