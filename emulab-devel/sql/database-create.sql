-- MySQL dump 10.10
--
-- Host: localhost    Database: tbdb
-- ------------------------------------------------------
-- Server version	5.0.20-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


DROP TABLE IF EXISTS `apt_mobile_aggregates`;
CREATE TABLE `apt_mobile_aggregates` (
  `urn` varchar(128) NOT NULL default '',
  `type` enum('bus') default NULL,
  PRIMARY KEY  (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `apt_mobile_buses`;
CREATE TABLE `apt_mobile_buses` (
  `urn` varchar(128) NOT NULL default '',
  `busid` int(8) NOT NULL default '0',
  `last_ping` datetime default NULL,
  `last_control_ping` datetime default NULL,
  `last_report` datetime default NULL,
  `routeid` smallint(5) default NULL,
  `routedescription` tinytext,
  `route_changed` datetime default NULL,
  `latitude` float(8,5) NOT NULL default '0.00000',
  `longitude` float(8,5) NOT NULL default '0.00000',
  `speed` float(8,2) NOT NULL default '0.00',
  `heading` smallint(5) NOT NULL default '0',
  `location_stamp` datetime default NULL,
  `gpsd_latitude` float(12,8) NOT NULL default '0.00000000',
  `gpsd_longitude` float(12,8) NOT NULL default '0.00000000',
  `gpsd_speed` float(8,2) NOT NULL default '0.00',
  `gpsd_heading` float(8,2) NOT NULL default '0.00',
  `gpsd_stamp` datetime default NULL,
  PRIMARY KEY  (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `apt_mobile_bus_route_change_history`;
CREATE TABLE `apt_mobile_bus_route_change_history` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `urn` varchar(128) NOT NULL default '',
  `busid` int(8) NOT NULL default '0',
  `routeid` smallint(5) default NULL,
  `routedescription` tinytext,
  `route_changed` datetime default NULL,
  PRIMARY KEY (`busid`,`idx`),
  KEY `urn` (`urn`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `apt_mobile_bus_routes`;
CREATE TABLE `apt_mobile_bus_routes` (
  `routeid` smallint(5) NOT NULL default '0',
  `description` tinytext,
  PRIMARY KEY  (`routeid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `apt_instance_bus_routes`;
CREATE TABLE `apt_instance_bus_routes` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `routeid` smallint(5) NOT NULL default '0',
  `routedescription` tinytext,
  PRIMARY KEY (`uuid`,`routeid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `address_ranges`
--

DROP TABLE IF EXISTS `address_ranges`;
CREATE TABLE `address_ranges` (
  `baseaddr` varchar(40) NOT NULL default '',
  `prefix` tinyint(4) unsigned NOT NULL default '0',
  `type` varchar(30) NOT NULL default '',
  `role` enum('public','internal') NOT NULL default 'internal',
  PRIMARY KEY (`baseaddr`,`prefix`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `accessed_files`
--

DROP TABLE IF EXISTS `accessed_files`;
CREATE TABLE `accessed_files` (
  `fn` text NOT NULL,
  `idx` int(11) unsigned NOT NULL auto_increment,
  PRIMARY KEY  (`fn`(255)),
  KEY `idx` (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `active_checkups`
--

DROP TABLE IF EXISTS `active_checkups`;
CREATE TABLE `active_checkups` (
  `object` varchar(128) NOT NULL default '',
  `object_type` varchar(64) NOT NULL default '',
  `type` varchar(64) NOT NULL default '',
  `state` varchar(16) NOT NULL default 'new',
  `start` datetime default NULL,
  PRIMARY KEY  (`object`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `addr_pool_history`
--

DROP TABLE IF EXISTS `addr_pool_history`;
CREATE TABLE `addr_pool_history` (
  `history_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `pool_id` varchar(32) NOT NULL DEFAULT '',
  `op` enum('alloc','free') NOT NULL DEFAULT 'alloc',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `exptidx` int(10) unsigned DEFAULT NULL,
  `stamp` int(10) unsigned DEFAULT NULL,
  `addr` varchar(15) DEFAULT NULL,
  `version` enum('ipv4','ipv6') NOT NULL DEFAULT 'ipv4',
  PRIMARY KEY (`history_id`),
  KEY `exptidx` (`exptidx`),
  KEY `stamp` (`stamp`),
  KEY `addr` (`addr`),
  KEY `addrstamp` (`addr`,`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_radio_locations`
--

DROP TABLE IF EXISTS `apt_aggregate_radio_locations`;
CREATE TABLE `apt_aggregate_radio_locations` (
  `aggregate_urn` varchar(128) NOT NULL default '',
  `location` varchar(64) NOT NULL default '',
  `itype` enum('FE','ME','BS','PE','unknown') NOT NULL default 'unknown',
  `latitude` float(8,5) default NULL,
  `longitude` float(8,5) default NULL,
  `mapurl` tinytext,
  `streeturl` tinytext,
  `notes` text,
  PRIMARY KEY  (`aggregate_urn`,`location`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_radios`
--

DROP TABLE IF EXISTS `apt_aggregate_radio_info`;
CREATE TABLE `apt_aggregate_radio_info` (
  `aggregate_urn` varchar(128) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `location` varchar(64) NOT NULL default '',
  `radio_type` tinytext,
  `power_id` varchar(32) default NULL,
  `cnuc_id` varchar(32) default NULL,
  `grouping` varchar(32) default NULL,
  `notes` text,
  PRIMARY KEY  (`aggregate_urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS `apt_sas_radio_state`;
CREATE TABLE `apt_sas_radio_state` (
  `aggregate_urn` varchar(128) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `fccid` varchar(32) NOT NULL default '',
  `serial` varchar(32) NOT NULL default '',
  `state` enum('idle','unregistered','registered') default 'idle',
  `updated` datetime default NULL,
  `cbsdid` varchar(128) default NULL,
  `locked` datetime default NULL, 
  `locker_pid` int(11) default '0',
  PRIMARY KEY  (`aggregate_urn`,`node_id`),
  UNIQUE KEY `cbsdid` (`cbsdid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `apt_sas_grant_state`;
CREATE TABLE `apt_sas_grant_state` (
  `cbsdid` varchar(128) NOT NULL default '',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `grantid` varchar(128) NOT NULL default '',
  `state` enum('granted','authorized','suspended','terminated') default NULL,
  `updated` datetime default NULL,
  `freq_low` int(11) default '0',
  `freq_high` int(11) default '0',
  `interval` int(11) default '0',
  `expires` datetime default NULL,
  `transmitExpires` datetime default NULL,
  PRIMARY KEY  (`cbsdid`,`idx`),
  UNIQUE KEY `grantid` (`cbsdid`,`grantid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_radio_frontends
--

DROP TABLE IF EXISTS `apt_aggregate_radio_frontends`;
CREATE TABLE `apt_aggregate_radio_frontends` (
  `aggregate_urn` varchar(128) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `iface` varchar(32) NOT NULL default '',
  `frontend` enum('TDD','FDD','none') NOT NULL default 'none',
  `transmit_frequencies` text,
  `receive_frequencies` text,
  `monitored` tinyint(1) NOT NULL default '0',
  `notes` text,
  PRIMARY KEY  (`aggregate_urn`,`node_id`,`iface`,`frontend`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_radioinfo`
--

DROP TABLE IF EXISTS `apt_aggregate_radioinfo`;
CREATE TABLE `apt_aggregate_radioinfo` (
  `aggregate_urn` varchar(128) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `location` varchar(64) NOT NULL default '',
  `installation_type` enum('FE','ME','BS','unknown') NOT NULL default 'unknown',
  `radio_type` tinytext,
  `transmit_frequencies` text,
  `receive_frequencies` text,
  `power_id` varchar(32) default NULL,
  `cnuc_id` varchar(32) default NULL,
  `monitored` tinyint(1) NOT NULL default '0',
  `notes` text,
  PRIMARY KEY  (`aggregate_urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_nodes`
--

DROP TABLE IF EXISTS `apt_aggregate_nodes`;
CREATE TABLE `apt_aggregate_nodes` (
  `urn` varchar(128) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `type` varchar(30) NOT NULL default '',
  `available` tinyint(1) NOT NULL default '0',
  `reservable` tinyint(1) NOT NULL default '0',
  `updated` datetime default NULL,
  PRIMARY KEY  (`urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_nodetypes`
--

DROP TABLE IF EXISTS `apt_aggregate_nodetypes`;
CREATE TABLE `apt_aggregate_nodetypes` (
  `urn` varchar(128) NOT NULL default '',
  `type` varchar(30) NOT NULL default '',
  `count` int(11) default '0',
  `free` int(11) default '0',
  `updated` datetime default NULL,
  PRIMARY KEY  (`urn`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_nodetype_attributes`
--

DROP TABLE IF EXISTS `apt_aggregate_nodetype_attributes`;
CREATE TABLE `apt_aggregate_nodetype_attributes` (
  `urn` varchar(128) NOT NULL default '',
  `type` varchar(30) NOT NULL default '',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY  (`urn`,`type`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_reservable_nodes`
--

DROP TABLE IF EXISTS `apt_aggregate_reservable_nodes`;
CREATE TABLE `apt_aggregate_reservable_nodes` (
  `urn` varchar(128) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `type` varchar(30) NOT NULL default '',
  `available` tinyint(1) NOT NULL default '0',
  `updated` datetime default NULL,
  PRIMARY KEY  (`urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregates_status_events`
--

DROP TABLE IF EXISTS `apt_aggregate_events`;
CREATE TABLE `apt_aggregate_events` (
  `urn` varchar(128) NOT NULL default '',
  `event` enum('up','down','offline','unknown') NOT NULL default 'unknown',
  `stamp` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`urn`,`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregate_status`
--

DROP TABLE IF EXISTS `apt_aggregate_status`;
CREATE TABLE `apt_aggregate_status` (
  `urn` varchar(128) NOT NULL default '',
  `status` enum('up','down','offline','unknown') NOT NULL default 'unknown',
  `last_success` datetime default NULL,
  `last_attempt` datetime default NULL,
  `pcount` int(11) default '0',
  `pfree` int(11) default '0',
  `vcount` int(11) default '0',
  `vfree` int(11) default '0',
  `last_error` text,
  PRIMARY KEY  (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_aggregates`
--

DROP TABLE IF EXISTS `apt_aggregates`;
CREATE TABLE `apt_aggregates` (
  `urn` varchar(128) NOT NULL default '',
  `name` varchar(32) NOT NULL default '',
  `nickname` varchar(32) NOT NULL default '',
  `abbreviation` varchar(32) NOT NULL default '',
  `adminonly` tinyint(1) NOT NULL default '0',
  `isfederate` tinyint(1) NOT NULL default '0',
  `isFE` tinyint(1) NOT NULL default '0',
  `ismobile` tinyint(1) NOT NULL default '0',
  `disabled` tinyint(1) NOT NULL default '0',
  `noupdate` tinyint(1) NOT NULL default '0',
  `nomonitor` tinyint(1) NOT NULL default '0',
  `nolocalimages` tinyint(1) NOT NULL default '0',
  `prestageimages` tinyint(1) NOT NULL default '0',
  `deferrable` tinyint(1) NOT NULL default '0',
  `updated` datetime NOT NULL default '0000-00-00 00:00:00',
  `weburl` tinytext,
  `has_datasets` tinyint(1) NOT NULL default '0',
  `does_syncthing` tinyint(1) NOT NULL default '0',
  `reservations` tinyint(1) NOT NULL default '0',
  `panicpoweroff` tinyint(1) NOT NULL default '0',
  `precalcmaxext` tinyint(1) NOT NULL default '0',
  `portals` set('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `canuse_feature` varchar(64) default NULL,
  `latitude` float(8,5) default NULL,
  `longitude` float(8,5) default NULL,
  `required_license` int(11) default NULL,
  `jsondata` text,
  PRIMARY KEY  (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_datasets`
--

DROP TABLE IF EXISTS `apt_datasets`;
CREATE TABLE `apt_datasets` (
  `idx` int(10) unsigned NOT NULL default '0',
  `dataset_id` varchar(32) NOT NULL default '',
  `uuid` varchar(40) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator_uid` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `aggregate_urn` varchar(128) default NULL,
  `remote_urn` varchar(128) NOT NULL default '',
  `remote_uuid` varchar(40) NOT NULL default '',
  `remote_url` tinytext,
  `created` datetime default NULL,
  `updated` datetime default NULL,
  `expires` datetime default NULL,
  `last_used` datetime default NULL,
  `state` enum('new','valid','unapproved','grace','locked','expired','busy','failed') NOT NULL default 'new',  
  `type` enum('stdataset','ltdataset','imdataset','unknown') NOT NULL default 'unknown',
  `fstype` varchar(40) NOT NULL default 'none',
  `size` int(10) unsigned NOT NULL default '0',
  `read_access` enum('project','global') NOT NULL default 'project',
  `write_access` enum('creator','project') NOT NULL default 'creator',
  `public` tinyint(1) NOT NULL default '0',
  `shared` tinyint(1) NOT NULL default '0',
  `locked` datetime default NULL, 
  `locker_pid` int(11) default '0',
  `webtask_id` varchar(128) default NULL,
  `error` text,
  `credential_string` text,
  PRIMARY KEY (`idx`),
  UNIQUE KEY `plid` (`pid_idx`,`dataset_id`),
  UNIQUE KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `apt_deferred_instances`
--

DROP TABLE IF EXISTS `apt_deferred_instances`;
CREATE TABLE `apt_deferred_instances` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `start_at` datetime default NULL,
  `last_retry` datetime default NULL,
  `retry_until` datetime default NULL,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `apt_extension_group_policies`
--

DROP TABLE IF EXISTS `apt_extension_group_policies`;
CREATE TABLE `apt_extension_group_policies` (
  `pid` varchar(48) default NULL,
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator` varchar(8) default NULL,
  `creator_idx` mediumint(8) unsigned default NULL,
  `disabled` tinyint(1) NOT NULL default '0',
  `limit` int(10) unsigned default NULL,
  `admin_after_limit` tinyint(1) NOT NULL default '0',
  `created` datetime default NULL,
  `reason` mediumtext,
  PRIMARY KEY (`pid_idx`,`gid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_extension_user_policies`
--

DROP TABLE IF EXISTS `apt_extension_user_policies`;
CREATE TABLE `apt_extension_user_policies` (
  `uid` varchar(8) default NULL,
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator` varchar(8) default NULL,
  `creator_idx` mediumint(8) unsigned default NULL,
  `disabled` tinyint(1) NOT NULL default '0',
  `limit` int(10) unsigned default NULL,
  `admin_after_limit` tinyint(1) NOT NULL default '0',
  `created` datetime default NULL,
  `reason` mediumtext,
  PRIMARY KEY (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_aggregate_history`
--

DROP TABLE IF EXISTS `apt_instance_aggregate_history`;
CREATE TABLE `apt_instance_aggregate_history` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `aggregate_urn` varchar(128) NOT NULL default '',
  `status` varchar(32) default NULL,
  `added` datetime default NULL,
  `started` datetime default NULL,
  `destroyed` datetime default NULL,
  `physnode_count` smallint(5) unsigned NOT NULL default '0',
  `virtnode_count` smallint(5) unsigned NOT NULL default '0',
  `deferred` tinyint(1) NOT NULL default '0',
  `deferred_reason` tinytext,
  `retry_count` smallint(5) unsigned NOT NULL default '0',
  `last_retry` datetime default NULL,
  `public_url` tinytext,
  `webtask_id` varchar(128) NOT NULL default '',
  `extension_needpush` datetime default NULL,
  `manifest_needpush` datetime default NULL,
  `prestage_data` mediumtext,  
  `manifest` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_aggregates`
--

DROP TABLE IF EXISTS `apt_instance_aggregates`;
CREATE TABLE `apt_instance_aggregates` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `aggregate_urn` varchar(128) NOT NULL default '',
  `status` varchar(32) default NULL,
  `added` datetime default NULL,  
  `started` datetime default NULL,
  `destroyed` datetime default NULL,
  `physnode_count` smallint(5) unsigned NOT NULL default '0',
  `virtnode_count` smallint(5) unsigned NOT NULL default '0',
  `deferred` tinyint(1) NOT NULL default '0',
  `deferred_reason` tinytext,
  `retry_count` smallint(5) unsigned NOT NULL default '0',
  `last_retry` datetime default NULL,
  `public_url` tinytext,
  `webtask_id` varchar(128) NOT NULL default '',
  `extension_needpush` datetime default NULL,
  `manifest_needpush` datetime default NULL,
  `prestage_data` mediumtext,  
  `manifest` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_extension_info`
--

DROP TABLE IF EXISTS `apt_instance_extension_info`;
CREATE TABLE `apt_instance_extension_info` (
  `uuid` varchar(40) NOT NULL default '',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(16) NOT NULL default '',
  `tstamp` datetime default NULL,
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `action` enum('request','deny','info') NOT NULL default 'request',
  `wanted` int(10) unsigned NOT NULL default '0',
  `granted` int(10) unsigned default NULL,
  `needapproval` tinyint(1) NOT NULL default '0',
  `autoapproved` tinyint(1) NOT NULL default '0',
  `autoapproved_reason` tinytext,
  `autoapproved_metrics` mediumtext,
  `maxextension` datetime default NULL,
  `expiration` datetime default NULL,
  `admin` tinyint(1) NOT NULL default '0',
  `reason` mediumtext,
  `message` mediumtext,
  PRIMARY KEY (`uuid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_failures`
--

DROP TABLE IF EXISTS `apt_instance_failures`;
CREATE TABLE `apt_instance_failures` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `profile_id` int(10) unsigned NOT NULL default '0',
  `profile_version` int(10) unsigned NOT NULL default '0',
  `slice_uuid` varchar(40) default NULL,
  `creator` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator_uuid` varchar(40) NOT NULL default '',
  `pid` varchar(48) default NULL,
  `pid_idx` mediumint(8) unsigned default NULL,
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `start_at` datetime default NULL,
  `started` datetime default NULL,
  `stop_at` datetime default NULL,
  `exitcode` int(10) default '0',
  `exitmessage` mediumtext,
  `public_url` tinytext,
  `logfileid` varchar(40) default NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_history`
--

DROP TABLE IF EXISTS `apt_instance_history`;
CREATE TABLE `apt_instance_history` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `profile_id` int(10) unsigned NOT NULL default '0',
  `profile_version` int(10) unsigned NOT NULL default '0',
  `slice_uuid` varchar(40) NOT NULL default '',
  `creator` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator_uuid` varchar(40) NOT NULL default '',
  `pid` varchar(48) default NULL,
  `pid_idx` mediumint(8) unsigned default NULL,
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `aggregate_urn` varchar(128) default NULL,
  `public_url` tinytext,
  `logfileid` varchar(40) default NULL,
  `created` datetime default NULL,
  `start_at` datetime default NULL,
  `started` datetime default NULL,
  `stop_at` datetime default NULL,
  `destroyed` datetime default NULL,
  `expired` tinyint(1) NOT NULL default '0',
  `extension_count` smallint(5) unsigned NOT NULL default '0',
  `extension_days` smallint(5) unsigned NOT NULL default '0',
  `extension_hours` int(10) unsigned NOT NULL default '0',
  `physnode_count` smallint(5) unsigned NOT NULL default '0',
  `virtnode_count` smallint(5) unsigned NOT NULL default '0',
  `servername` tinytext,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `repourl` tinytext,
  `reponame` varchar(40) default NULL,
  `reporef` varchar(128) default NULL,
  `repohash` varchar(64) default NULL,
  `rspec` mediumtext,
  `script` mediumtext,
  `params` mediumtext,
  `manifest` mediumtext,
  PRIMARY KEY (`uuid`),
  KEY `profile_id` (`profile_id`),
  KEY `creator` (`creator`),
  KEY `creator_idx` (`creator_idx`),
  KEY `pid_idx` (`pid_idx`),
  KEY `servername` (`uuid`,`servername`(32)),
  KEY `slice_uuid` (`slice_uuid`),
  KEY `portal` (`portal`),
  KEY `destroyed` (`destroyed`)
  KEY `profile_id_created` (`profile_id`,`created`),
  KEY `portal_started` (`portal`,`started`),
  KEY `portal_creator` (`portal`,`creator_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_slice_status`
--

DROP TABLE IF EXISTS `apt_instance_slice_status`;
CREATE TABLE `apt_instance_slice_status` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `aggregate_urn` varchar(128) NOT NULL default '',
  `timestamp` int(10) unsigned NOT NULL default '0',
  `modified` datetime NOT NULL default '0000-00-00 00:00:00',
  `slice_data` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_sliver_status`
--

DROP TABLE IF EXISTS `apt_instance_sliver_status`;
CREATE TABLE `apt_instance_sliver_status` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `aggregate_urn` varchar(128) NOT NULL default '',
  `sliver_urn` varchar(128) NOT NULL default '',
  `resource_id` varchar(32) NOT NULL default '',
  `client_id` varchar(32) NOT NULL default '',
  `timestamp` int(10) unsigned NOT NULL default '0',
  `modified` datetime NOT NULL default '0000-00-00 00:00:00',
  `sliver_data` mediumtext,
  `frisbee_data` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`,`sliver_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instances`
--

DROP TABLE IF EXISTS `apt_instances`;
CREATE TABLE `apt_instances` (
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `profile_id` int(10) unsigned NOT NULL default '0',
  `profile_version` int(10) unsigned NOT NULL default '0',
  `slice_uuid` varchar(40) NOT NULL default '',
  `creator` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator_uuid` varchar(40) NOT NULL default '',
  `pid` varchar(48) default NULL,
  `pid_idx` mediumint(8) unsigned default NULL,
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `aggregate_urn` varchar(128) default NULL,
  `public_url` tinytext,
  `webtask_id` varchar(128) default NULL,
  `created` datetime default NULL,
  `start_at` datetime default NULL,
  `started` datetime default NULL,
  `stop_at` datetime default NULL,
  `maxextension` datetime default NULL,
  `maxextension_timestamp` datetime default NULL,
  `status` varchar(32) default NULL,
  `status_timestamp` datetime default NULL,
  `canceled` tinyint(2) NOT NULL default '0',
  `canceled_timestamp` datetime default NULL,
  `paniced` tinyint(2) NOT NULL default '0',
  `paniced_timestamp` datetime default NULL,
  `admin_lockdown` tinyint(1) NOT NULL default '0',
  `user_lockdown` tinyint(1) NOT NULL default '0',
  `admin_notes` mediumtext,
  `extension_code` varchar(32) default NULL,
  `extension_reason` mediumtext,
  `extension_history` mediumtext,
  `extension_adminonly` tinyint(1) NOT NULL default '0',
  `extension_disabled` tinyint(1) NOT NULL default '0',
  `extension_disabled_reason` mediumtext,
  `extension_limit` int(10) unsigned default NULL,
  `extension_limit_reason` mediumtext,
  `extension_admin_after_limit` tinyint(1) NOT NULL default '0',
  `extension_requested` tinyint(1) NOT NULL default '0',
  `extension_denied` tinyint(1) NOT NULL default '0',
  `extension_denied_reason` mediumtext,
  `extension_count` smallint(5) unsigned NOT NULL default '0',
  `extension_days` smallint(5) unsigned NOT NULL default '0',
  `extension_hours` int(10) unsigned NOT NULL default '0',
  `physnode_count` smallint(5) unsigned NOT NULL default '0',
  `virtnode_count` smallint(5) unsigned NOT NULL default '0',
  `servername` tinytext,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `monitor_pid` int(11) default '0',
  `needupdate` tinyint(3) NOT NULL default '0',
  `isopenstack` tinyint(1) NOT NULL default '0',
  `logfileid` varchar(40) default NULL,
  `cert` mediumtext,
  `privkey` mediumtext,
  `repourl` tinytext,
  `reponame` varchar(40) default NULL,
  `reporef` varchar(128) default NULL,
  `repohash` varchar(64) default NULL,
  `rspec` mediumtext,
  `script` mediumtext,
  `params` mediumtext,
  `paramdefs` mediumtext,
  `manifest` mediumtext,
  `openstack_utilization` mediumtext,
  PRIMARY KEY (`uuid`),
  KEY `creator` (`creator`),
  KEY `creator_idx` (`creator_idx`),
  KEY `pid_idx` (`pid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_news`
--

DROP TABLE IF EXISTS `apt_news`;
CREATE TABLE `apt_news` (
  `idx` int(11) NOT NULL auto_increment,
  `title` tinytext,
  `created` datetime default NULL,
  `author` varchar(32) default NULL,
  `author_idx` mediumint(8) unsigned NOT NULL default '0',
  `portals` set('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `body` text,
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_parameter_sets`
--

DROP TABLE IF EXISTS `apt_parameter_sets`;
CREATE TABLE `apt_parameter_sets` (
  `uuid` varchar(40) NOT NULL,
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `name` varchar(64) NOT NULL default '',
  `description` text,
  `public` tinyint(1) NOT NULL default '0',
  `global` tinyint(1) NOT NULL default '0',
  `profileid` int(10) unsigned NOT NULL default '0',
  `version_uuid` varchar(40) default NULL,
  `reporef` varchar(128) default NULL,
  `repohash` varchar(64) default NULL,
  `bindings` mediumtext,    
  `hashkey` varchar(64) default NULL,
  PRIMARY KEY (`uuid`),
  UNIQUE KEY `uid_idx` (`uid_idx`,`profileid`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_profile_favorites`
--

DROP TABLE IF EXISTS `apt_profile_favorites`;
CREATE TABLE `apt_profile_favorites` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `profileid` int(10) unsigned NOT NULL default '0',  
  `marked` datetime default NULL,
  PRIMARY KEY (`uid_idx`,`profileid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_profile_images`
--

DROP TABLE IF EXISTS `apt_profile_images`;
CREATE TABLE `apt_profile_images` (
  `name` varchar(64) NOT NULL default '',
  `profileid` int(10) unsigned NOT NULL default '0',  
  `version` int(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `client_id` varchar(32) NOT NULL default '',
  `authority` varchar(64) default NULL,
  `ospid` varchar(64) default NULL,
  `os` varchar(128) default NULL,
  `osvers` int(8) default NULL,
  `local_pid` varchar(48) default NULL,
  `image` varchar(256) NOT NULL default '',
  PRIMARY KEY (`profileid`,`version`,`client_id`),
  KEY `image` (`image`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_profile_versions`
--

DROP TABLE IF EXISTS `apt_profile_versions`;
CREATE TABLE `apt_profile_versions` (
  `name` varchar(64) NOT NULL default '',
  `profileid` int(10) unsigned NOT NULL default '0',  
  `version` int(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `updater` varchar(8) NOT NULL default '',
  `updater_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `last_use` datetime default NULL,
  `published` datetime default NULL,
  `deleted` datetime default NULL,
  `disabled` tinyint(1) NOT NULL default '0',
  `nodelete` tinyint(1) NOT NULL default '0',
  `uuid` varchar(40) NOT NULL,
  `parent_profileid` int(8) unsigned default NULL,
  `parent_version` int(8) unsigned default NULL,
  `status` varchar(32) default NULL,
  `repourl` tinytext,
  `reponame` varchar(40) default NULL,
  `reporef` varchar(128) default NULL,
  `repohash` varchar(64) default NULL,
  `repokey` varchar(64) default NULL,
  `portal_converted` tinyint(1) NOT NULL default '0',
  `rspec` mediumtext,
  `script` mediumtext,
  `paramdefs` mediumtext,
  `hashkey` varchar(64) default NULL,
  PRIMARY KEY (`profileid`,`version`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `hashkey` (`hashkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_profiles`
--

DROP TABLE IF EXISTS `apt_profiles`;
CREATE TABLE `apt_profiles` (
  `name` varchar(64) NOT NULL default '',
  `profileid` int(10) unsigned NOT NULL default '0',  
  `version` int(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uuid` varchar(40) NOT NULL,
  `webtask_id` varchar(128) default NULL,
  `public` tinyint(1) NOT NULL default '0',
  `shared` tinyint(1) NOT NULL default '0',
  `listed` tinyint(1) NOT NULL default '0',
  `topdog` tinyint(1) NOT NULL default '0',
  `no_image_versions` tinyint(1) NOT NULL default '0',
  `disabled` tinyint(1) NOT NULL default '0',
  `nodelete` tinyint(1) NOT NULL default '0',
  `project_write` tinyint(1) NOT NULL default '0',
  `locked` datetime default NULL,
  `locker_pid` int(11) default '0',
  `lastused` datetime default NULL,
  `usecount` int(11) default '0',
  `examples_portals` set('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,  
  `hashkey` varchar(64) default NULL,
  PRIMARY KEY (`profileid`),
  UNIQUE KEY `pidname` (`pid_idx`,`name`,`version`),
  KEY `profileid_version` (`profileid`,`version`),
  KEY `hashkey` (`hashkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_groups`
--

DROP TABLE IF EXISTS `apt_reservation_groups`;
CREATE TABLE `apt_reservation_groups` (
  `uuid` varchar(40) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator_uid` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `noidledetection` datetime DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  `locker_pid` int(11) default '0',
  `notified` datetime DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `reason` mediumtext,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_group_reservations`
--

DROP TABLE IF EXISTS `apt_reservation_group_reservations`;
CREATE TABLE `apt_reservation_group_reservations` (
  `uuid` varchar(40) NOT NULL default '',
  `aggregate_urn` varchar(128) NOT NULL default '',
  `remote_uuid` varchar(40) NOT NULL default '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `count` smallint(5) unsigned NOT NULL DEFAULT '0',
  `using` smallint(5) unsigned default NULL,
  `utilization` smallint(5) unsigned default NULL,
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `approved_pushed` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `canceled_pushed` datetime DEFAULT NULL,
  `cancel_canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `deleted_pushed` datetime DEFAULT NULL,
  `noidledetection_needpush` tinyint(1) NOT NULL default '0',
  `jsondata` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_group_rf_reservations`
--

DROP TABLE IF EXISTS `apt_reservation_group_rf_reservations`;
CREATE TABLE `apt_reservation_group_rf_reservations` (
  `uuid` varchar(40) NOT NULL default '',
  `freq_uuid` varchar(40) NOT NULL default '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  PRIMARY KEY (`uuid`,`freq_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_project_rfranges`
--

DROP TABLE IF EXISTS `apt_project_rfranges`;
CREATE TABLE `apt_project_rfranges` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `range_id` varchar(32) default NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `disabled` tinyint(1) NOT NULL default '0',
  PRIMARY KEY (`pid_idx`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_global_rfranges`
--

DROP TABLE IF EXISTS `apt_global_rfranges`;
CREATE TABLE `apt_global_rfranges` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `range_id` varchar(32) default NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `disabled` tinyint(1) NOT NULL default '0',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_named_rfranges`
--

DROP TABLE IF EXISTS `apt_named_rfranges`;
CREATE TABLE `apt_named_rfranges` (
  `range_id` varchar(32) NOT NULL DEFAULT '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`range_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_rfrange_sets`
--

DROP TABLE IF EXISTS `apt_rfrange_sets`;
CREATE TABLE `apt_rfrange_sets` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `setname` varchar(32) NOT NULL DEFAULT '',
  `range_id` varchar(32) default NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `disabled` tinyint(1) NOT NULL default '0',
  PRIMARY KEY (`setname`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_rfranges`
--

DROP TABLE IF EXISTS `apt_instance_rfranges`;
CREATE TABLE `apt_instance_rfranges` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL default '',
  `name` varchar(16) default NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`uuid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_instance_rfrange_history`
--

DROP TABLE IF EXISTS `apt_instance_rfrange_history`;
CREATE TABLE `apt_instance_rfrange_history` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL default '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`uuid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_group_route_reservations`
--

DROP TABLE IF EXISTS `apt_reservation_group_route_reservations`;
CREATE TABLE `apt_reservation_group_route_reservations` (
  `uuid` varchar(40) NOT NULL default '',
  `route_uuid` varchar(40) NOT NULL default '',
  `routeid` smallint(5) NOT NULL default '0',
  `routename` tinytext,
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  PRIMARY KEY (`uuid`,`route_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_group_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_history`;
CREATE TABLE `apt_reservation_group_history` (
  `uuid` varchar(40) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator_uid` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `reason` mediumtext,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_group_reservation_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_reservation_history`;
CREATE TABLE `apt_reservation_group_reservation_history` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL default '',
  `aggregate_urn` varchar(128) NOT NULL default '',
  `remote_uuid` varchar(40) NOT NULL default '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `count` smallint(5) unsigned NOT NULL DEFAULT '0',
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `agguuid` (`uuid`,`aggregate_urn`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_group_rf_reservation_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_rf_reservation_history`;
CREATE TABLE `apt_reservation_group_rf_reservation_history` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL default '',
  `freq_uuid` varchar(40) NOT NULL default '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `uuids` (`uuid`,`freq_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_group_route_reservation_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_route_reservation_history`;
CREATE TABLE `apt_reservation_group_route_reservation_history` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL default '',
  `route_uuid` varchar(40) NOT NULL default '',
  `routeid` smallint(5) NOT NULL default '0',
  `routename` tinytext,
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `uuids` (`uuid`,`route_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_history_actions`
--

DROP TABLE IF EXISTS `apt_reservation_history_actions`;
CREATE TABLE `apt_reservation_history_actions` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `aggregate_urn` varchar(128) NOT NULL default '',
  `reservation_uuid` varchar(40) default NULL,
  `stamp` datetime default NULL,
  `action` enum('validate','submit','approve','delete','cancel','restore') NOT NULL default 'validate',
  PRIMARY KEY (`idx`),
  KEY `agguuid` (`aggregate_urn`,`reservation_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_reservation_history_details`
--

DROP TABLE IF EXISTS `apt_reservation_history_details`;
CREATE TABLE `apt_reservation_history_details` (
  `idx` mediumint(8) unsigned NOT NULL default '0',
  `aggregate_urn` varchar(128) NOT NULL default '',
  `reservation_uuid` varchar(40) default NULL,
  `pid` varchar(48) default NULL,
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid` varchar(8) default NULL,
  `uid_idx` mediumint(8) unsigned default NULL,
  `stamp` datetime default NULL,
  `nodes` smallint(5) NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `refused` tinyint(1) NOT NULL default '0',
  `approved` tinyint(1) NOT NULL default '0',
  `reason` mediumtext,
  PRIMARY KEY (`idx`),
  KEY `agguuid` (`aggregate_urn`,`reservation_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_announcements`
--

DROP TABLE IF EXISTS `apt_announcements`;
CREATE TABLE `apt_announcements` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `uuid` varchar(40) NOT NULL,
  `created` datetime default NULL,
  `uid_idx` int(10) default NULL,
  `pid_idx` int(10) default NULL,
  `genesis` varchar(64) NOT NULL default 'emulab',
  `portal` varchar(64) NOT NULL default 'emulab',
  `priority` tinyint(1) NOT NULL default '3',
  `retired` tinyint(1) NOT NULL default '0',
  `max_seen` int(8) NOT NULL default '20',
  `text` mediumtext,
  `style` varchar(64) NOT NULL default 'alert-info',
  `link_label` tinytext,
  `link_url` tinytext,
  `display_start` datetime default NULL,
  `display_end` datetime default NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `apt_announcement_info`
-- 

DROP TABLE IF EXISTS `apt_announcement_info`;
CREATE TABLE `apt_announcement_info` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `aid` int(10) NOT NULL default '0',
  `uid_idx` int(10) default NULL,
  `dismissed` tinyint(1) NOT NULL default '0',
  `clicked` tinyint(1) NOT NULL default '0',
  `seen_count` int(8) NOT NULL default '0',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `archive_revisions`
--

DROP TABLE IF EXISTS `archive_revisions`;
CREATE TABLE `archive_revisions` (
  `archive_idx` int(10) unsigned NOT NULL default '0',
  `revision` int(10) unsigned NOT NULL auto_increment,
  `parent_revision` int(10) unsigned default NULL,
  `tag` varchar(64) NOT NULL default '',
  `view` varchar(64) NOT NULL default '',
  `date_created` int(10) unsigned NOT NULL default '0',
  `converted` tinyint(1) default '0',
  `description` text,
  PRIMARY KEY  (`archive_idx`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `archive_tags`
--

DROP TABLE IF EXISTS `archive_tags`;
CREATE TABLE `archive_tags` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `tag` varchar(64) NOT NULL default '',
  `archive_idx` int(10) unsigned NOT NULL default '0',
  `view` varchar(64) NOT NULL default '',
  `date_created` int(10) unsigned NOT NULL default '0',
  `tagtype` enum('user','commit','savepoint','internal') NOT NULL default 'internal',
  `version` tinyint(1) default '0',
  `description` text,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `tag` (`tag`,`archive_idx`,`view`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `archive_views`
--

DROP TABLE IF EXISTS `archive_views`;
CREATE TABLE `archive_views` (
  `view` varchar(64) NOT NULL default '',
  `archive_idx` int(10) unsigned NOT NULL default '0',
  `revision` int(10) unsigned default NULL,
  `current_tag` varchar(64) default NULL,
  `previous_tag` varchar(64) default NULL,
  `date_created` int(10) unsigned NOT NULL default '0',
  `branch_tag` varchar(64) default NULL,
  `parent_view` varchar(64) default NULL,
  `parent_revision` int(10) unsigned default NULL,
  PRIMARY KEY  (`view`,`archive_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `archives`
--

DROP TABLE IF EXISTS `archives`;
CREATE TABLE `archives` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `directory` tinytext,
  `date_created` int(10) unsigned NOT NULL default '0',
  `archived` tinyint(1) default '0',
  `date_archived` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `blob_files`
--

DROP TABLE IF EXISTS `blob_files`;
CREATE TABLE `blob_files` (
  `filename` varchar(255) NOT NULL,
  `hash` varchar(64) default NULL,
  `hash_mtime` datetime default NULL,
  PRIMARY KEY  (`filename`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `blobs`
--

DROP TABLE IF EXISTS `blobs`;
CREATE TABLE `blobs` (
  `uuid` varchar(40) NOT NULL,
  `filename` tinytext,
  `owner_uid` varchar(8) NOT NULL default '',
  `vblob_id` varchar(40) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  PRIMARY KEY  (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `blockstore_attributes`
--

DROP TABLE IF EXISTS `blockstore_attributes`;
CREATE TABLE `blockstore_attributes` (
  `bsidx` int(10) unsigned NOT NULL,
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') default 'string',
  PRIMARY KEY  (`bsidx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `blockstore_state`
--

DROP TABLE IF EXISTS `blockstore_state`;
CREATE TABLE `blockstore_state` (
  `bsidx` int(10) unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL default '',
  `bs_id` varchar(32) NOT NULL default '',
  `remaining_capacity` int(10) unsigned NOT NULL default '0',
  `ready` tinyint(4) unsigned NOT NULL default '0',
  PRIMARY KEY (`bsidx`),
  UNIQUE KEY nidbid (`node_id`,`bs_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `blockstore_trees`
--

DROP TABLE IF EXISTS `blockstore_trees`;
CREATE TABLE `blockstore_trees` (
  `bsidx` int(10) unsigned NOT NULL,
  `aggidx` int(10) unsigned NOT NULL default '0',
  `hint` tinytext NOT NULL,
  PRIMARY KEY (`bsidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `blockstore_type_attributes`
--

DROP TABLE IF EXISTS `blockstore_type_attributes`;
CREATE TABLE `blockstore_type_attributes` (
  `type` varchar(30) NOT NULL default '',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') default 'string',
  `isfeature` tinyint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`type`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `blockstores`
--

DROP TABLE IF EXISTS `blockstores`;
CREATE TABLE `blockstores` (
  `bsidx` int(10) unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL default '',
  `bs_id` varchar(32) NOT NULL default '',
  `lease_idx` int(10) unsigned NOT NULL default '0',
  `type` varchar(30) NOT NULL default '',
  `role` enum('element','compound','partition') NOT NULL default 'element',
  `total_size` int(10) unsigned NOT NULL default '0',
  `exported` tinyint(1) NOT NULL default '0',
  `inception` datetime default NULL,
  PRIMARY KEY (`bsidx`),
  UNIQUE KEY nidbid (`node_id`,`bs_id`,`lease_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `bridges`
--

DROP TABLE IF EXISTS `bridges`;
CREATE TABLE `bridges` (
  `pid` varchar(48) default NULL,
  `eid` varchar(32) default NULL,
  `exptidx` int(11) NOT NULL default '0',
  `node_id` varchar(32) NOT NULL default '',
  `bridx` mediumint(8) unsigned NOT NULL default '0',
  `iface` varchar(8) NOT NULL default '',
  `vname` varchar(32) NOT NULL default '',
  `vnode` varchar(32) default NULL,
  PRIMARY KEY  (`node_id`,`bridx`,`iface`),
  KEY `pid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `buildings`
--

DROP TABLE IF EXISTS `buildings`;
CREATE TABLE `buildings` (
  `building` varchar(32) NOT NULL default '',
  `image_path` tinytext,
  `title` tinytext NOT NULL,
  PRIMARY KEY  (`building`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `cameras`
--

DROP TABLE IF EXISTS `cameras`;
CREATE TABLE `cameras` (
  `name` varchar(32) NOT NULL default '',
  `building` varchar(32) NOT NULL default '',
  `floor` varchar(32) NOT NULL default '',
  `hostname` varchar(255) default NULL,
  `port` smallint(5) unsigned NOT NULL default '6100',
  `device` varchar(64) NOT NULL default '',
  `loc_x` float NOT NULL default '0',
  `loc_y` float NOT NULL default '0',
  `width` float NOT NULL default '0',
  `height` float NOT NULL default '0',
  `config` tinytext,
  `fixed_x` float NOT NULL default '0',
  `fixed_y` float NOT NULL default '0',
  PRIMARY KEY  (`name`,`building`,`floor`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `causes`
--

DROP TABLE IF EXISTS `causes`;
CREATE TABLE `causes` (
  `cause` varchar(16) NOT NULL default '',
  `cause_desc` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`cause`),
  UNIQUE KEY `cause_desc` (`cause_desc`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `cdroms`
--

DROP TABLE IF EXISTS `cdroms`;
CREATE TABLE `cdroms` (
  `cdkey` varchar(64) NOT NULL default '',
  `user_name` tinytext NOT NULL,
  `user_email` tinytext NOT NULL,
  `ready` tinyint(4) NOT NULL default '0',
  `requested` datetime NOT NULL default '0000-00-00 00:00:00',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `version` int(10) unsigned NOT NULL default '1',
  PRIMARY KEY  (`cdkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `checkup_types`
--

DROP TABLE IF EXISTS `checkup_types`;
CREATE TABLE `checkup_types` (
  `object_type` varchar(64) NOT NULL default '',
  `checkup_type` varchar(64) NOT NULL default '',
  `major_type` varchar(64) NOT NULL default '',
  `expiration` int(10) NOT NULL default '86400',
  PRIMARY KEY  (`object_type`,`checkup_type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `checkups`
--

DROP TABLE IF EXISTS `checkups`;
CREATE TABLE `checkups` (
  `object` varchar(128) NOT NULL default '',
  `object_type` varchar(64) NOT NULL default '',
  `type` varchar(64) NOT NULL default '',
  `next` datetime default NULL,
  PRIMARY KEY  (`object`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `checkups_temp`
--

DROP TABLE IF EXISTS `checkups_temp`;
CREATE TABLE `checkups_temp` (
  `object` varchar(128) NOT NULL default '',
  `object_type` varchar(64) NOT NULL default '',
  `type` varchar(64) NOT NULL default '',
  `next` datetime default NULL,
  PRIMARY KEY  (`object`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `client_service_ctl`
--

DROP TABLE IF EXISTS `client_service_ctl`;
CREATE TABLE `client_service_ctl` (
  `obj_type` enum('node_type','node','osid') NOT NULL default 'node_type',
  `obj_name` varchar(64) NOT NULL default '',
  `service_idx` int(10) NOT NULL default '0',
  `env` enum('load','boot') NOT NULL default 'boot',
  `whence` enum('first','every') NOT NULL default 'every',
  `alt_blob_id` varchar(40) NOT NULL default '',
  `enable` tinyint(1) NOT NULL default '1',
  `enable_hooks` tinyint(1) NOT NULL default '1',
  `fatal` tinyint(1) NOT NULL default '1',
  `user_can_override` tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (`obj_type`,`obj_name`,`service_idx`,`env`,`whence`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `client_service_hooks`
--

DROP TABLE IF EXISTS `client_service_hooks`;
CREATE TABLE `client_service_hooks` (
  `obj_type` enum('node_type','node','osid') NOT NULL default 'node_type',
  `obj_name` varchar(64) NOT NULL default '',
  `service_idx` int(10) NOT NULL default '0',
  `env` enum('load','boot') NOT NULL default 'boot',
  `whence` enum('first','every') NOT NULL default 'every',
  `hook_blob_id` varchar(40) NOT NULL default '',
  `hook_op` enum('boot','shutdown','reconfig','reset') NOT NULL default 'boot',
  `hook_point` enum('pre','post') NOT NULL default 'post',
  `argv` varchar(255) NOT NULL default '',
  `fatal` tinyint(1) NOT NULL default '0',
  `user_can_override` tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (`obj_type`,`obj_name`,`service_idx`,`env`,`whence`,`hook_blob_id`,`hook_op`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `client_services`
--

DROP TABLE IF EXISTS `client_services`;
CREATE TABLE `client_services` (
  `idx` int(10) NOT NULL default '0',
  `service` varchar(64) NOT NULL default 'isup',
  `env` enum('load','boot') NOT NULL default 'boot',
  `whence` enum('first','every') NOT NULL default 'every',
  `hooks_only` int(1) NOT NULL default '0',
  PRIMARY KEY  (`idx`,`service`,`env`,`whence`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `comments`
--

DROP TABLE IF EXISTS `comments`;
CREATE TABLE `comments` (
  `table_name` varchar(64) NOT NULL default '',
  `column_name` varchar(64) NOT NULL default '',
  `description` text NOT NULL,
  UNIQUE KEY `table_name` (`table_name`,`column_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `current_reloads`
--

DROP TABLE IF EXISTS `current_reloads`;
CREATE TABLE `current_reloads` (
  `node_id` varchar(32) NOT NULL default '',
  `idx` smallint(5) unsigned NOT NULL default '0',
  `image_id` int(8) unsigned NOT NULL default '0',
  `imageid_version` int(8) unsigned NOT NULL default '0',
  `mustwipe` tinyint(4) NOT NULL default '0',
  `prepare` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `daily_stats`
--

DROP TABLE IF EXISTS `daily_stats`;
CREATE TABLE `daily_stats` (
  `theday` date NOT NULL default '0000-00-00',
  `exptstart_count` int(11) unsigned default '0',
  `exptpreload_count` int(11) unsigned default '0',
  `exptswapin_count` int(11) unsigned default '0',
  `exptswapout_count` int(11) unsigned default '0',
  `exptswapmod_count` int(11) unsigned default '0',
  `allexpt_duration` int(11) unsigned default '0',
  `allexpt_vnodes` int(11) unsigned default '0',
  `allexpt_vnode_duration` int(11) unsigned default '0',
  `allexpt_pnodes` int(11) unsigned default '0',
  `allexpt_pnode_duration` int(11) unsigned default '0',
  PRIMARY KEY  (`theday`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `datapository_databases`
--

DROP TABLE IF EXISTS `datapository_databases`;
CREATE TABLE `datapository_databases` (
  `dbname` varchar(64) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `uid` varchar(8) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  PRIMARY KEY  (`dbname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `default_firewall_rules`
--

DROP TABLE IF EXISTS `default_firewall_rules`;
CREATE TABLE `default_firewall_rules` (
  `type` enum('ipfw','ipfw2','iptables','ipfw2-vlan','iptables-vlan','iptables-dom0','iptables-domU') NOT NULL default 'ipfw',
  `style` enum('open','closed','basic','emulab') NOT NULL default 'basic',
  `enabled` tinyint(4) NOT NULL default '0',
  `ruleno` int(10) unsigned NOT NULL default '0',
  `rule` text NOT NULL,
  PRIMARY KEY  (`type`,`style`,`ruleno`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `default_firewall_vars`
--

DROP TABLE IF EXISTS `default_firewall_vars`;
CREATE TABLE `default_firewall_vars` (
  `name` varchar(255) NOT NULL default '',
  `value` text,
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `delays`
--

DROP TABLE IF EXISTS `delays`;
CREATE TABLE `delays` (
  `node_id` varchar(32) NOT NULL default '',
  `pipe0` smallint(5) unsigned NOT NULL default '0',
  `delay0` float(10,2) NOT NULL default '0.00',
  `bandwidth0` int(10) unsigned NOT NULL default '100',
  `backfill0` int(10) unsigned NOT NULL default '0',
  `lossrate0` float(10,8) NOT NULL default '0.00000000',
  `q0_limit` int(11) default '0',
  `q0_maxthresh` int(11) default '0',
  `q0_minthresh` int(11) default '0',
  `q0_weight` float default '0',
  `q0_linterm` int(11) default '0',
  `q0_qinbytes` tinyint(4) default '0',
  `q0_bytes` tinyint(4) default '0',
  `q0_meanpsize` int(11) default '0',
  `q0_wait` int(11) default '0',
  `q0_setbit` int(11) default '0',
  `q0_droptail` int(11) default '0',
  `q0_red` tinyint(4) default '0',
  `q0_gentle` tinyint(4) default '0',
  `pipe1` smallint(5) unsigned NOT NULL default '0',
  `delay1` float(10,2) NOT NULL default '0.00',
  `bandwidth1` int(10) unsigned NOT NULL default '100',
  `backfill1` int(10) unsigned NOT NULL default '0',
  `lossrate1` float(10,8) NOT NULL default '0.00000000',
  `q1_limit` int(11) default '0',
  `q1_maxthresh` int(11) default '0',
  `q1_minthresh` int(11) default '0',
  `q1_weight` float default '0',
  `q1_linterm` int(11) default '0',
  `q1_qinbytes` tinyint(4) default '0',
  `q1_bytes` tinyint(4) default '0',
  `q1_meanpsize` int(11) default '0',
  `q1_wait` int(11) default '0',
  `q1_setbit` int(11) default '0',
  `q1_droptail` int(11) default '0',
  `q1_red` tinyint(4) default '0',
  `q1_gentle` tinyint(4) default '0',
  `iface0` varchar(8) NOT NULL default '',
  `iface1` varchar(8) NOT NULL default '',
  `viface_unit0` int(10) default NULL,
  `viface_unit1` int(10) default NULL,
  `exptidx` int(11) NOT NULL default '0',
  `eid` varchar(32) default NULL,
  `pid` varchar(48) default NULL,
  `vname` varchar(32) default NULL,
  `vlan0` varchar(32) NOT NULL default '',
  `vlan1` varchar(32) NOT NULL default '',
  `vnode0` varchar(32) NOT NULL default '',
  `vnode1` varchar(32) NOT NULL default '',
  `card0` tinyint(3) unsigned default NULL,
  `card1` tinyint(3) unsigned default NULL,
  `noshaping` tinyint(1) default '0',
  `isbridge` tinyint(1) default '0',
  PRIMARY KEY  (`node_id`,`iface0`,`iface1`,`vlan0`,`vlan1`,`vnode0`,`vnode1`),
  KEY `pid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `deleted_users`
--

DROP TABLE IF EXISTS `deleted_users`;
CREATE TABLE `deleted_users` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `usr_created` datetime default NULL,
  `usr_deleted` datetime default NULL,
  `usr_name` tinytext,
  `usr_title` tinytext,
  `usr_affil` tinytext,
  `usr_affil_abbrev` varchar(16) default NULL,
  `usr_email` tinytext,
  `usr_URL` tinytext,
  `usr_addr` tinytext,
  `usr_addr2` tinytext,
  `usr_city` tinytext,
  `usr_state` tinytext,
  `usr_zip` tinytext,
  `usr_country` tinytext,
  `usr_phone` tinytext,
  `webonly` tinyint(1) default '0',
  `wikionly` tinyint(1) default '0',
  `notes` text,
  PRIMARY KEY  (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `delta_inst`
--

DROP TABLE IF EXISTS `delta_inst`;
CREATE TABLE `delta_inst` (
  `node_id` varchar(32) NOT NULL default '',
  `partition` tinyint(4) NOT NULL default '0',
  `delta_id` varchar(10) NOT NULL default '',
  PRIMARY KEY  (`node_id`,`partition`,`delta_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `delta_proj`
--

DROP TABLE IF EXISTS `delta_proj`;
CREATE TABLE `delta_proj` (
  `delta_id` varchar(10) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  PRIMARY KEY  (`delta_id`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `deltas`
--

DROP TABLE IF EXISTS `deltas`;
CREATE TABLE `deltas` (
  `delta_id` varchar(10) NOT NULL default '',
  `delta_desc` text,
  `delta_path` text NOT NULL,
  `private` enum('yes','no') NOT NULL default 'no',
  PRIMARY KEY  (`delta_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `elabinelab_attributes`
--

DROP TABLE IF EXISTS `elabinelab_attributes`;
CREATE TABLE `elabinelab_attributes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `role` enum('boss','router','ops','fs','node') NOT NULL default 'node',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  `ordering` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`role`,`attrkey`,`ordering`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `elabinelab_vlans`
--

DROP TABLE IF EXISTS `elabinelab_vlans`;
CREATE TABLE `elabinelab_vlans` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `inner_id` varchar(32) NOT NULL default '',
  `outer_id` varchar(32) NOT NULL default '',
  `stack` enum('Control','Experimental') NOT NULL default 'Experimental',
  PRIMARY KEY  (`exptidx`,`inner_id`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`inner_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `emulab_features`
--

DROP TABLE IF EXISTS `emulab_features`;
CREATE TABLE `emulab_features` (
  `feature` varchar(64) NOT NULL default '',
  `description` mediumtext,
  `added` datetime NOT NULL,
  `enabled` tinyint(1) NOT NULL default '0',
  `disabled` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`feature`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `emulab_indicies`
--

DROP TABLE IF EXISTS `emulab_indicies`;
CREATE TABLE `emulab_indicies` (
  `name` varchar(64) NOT NULL default '',
  `idx` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `emulab_locks`
--

DROP TABLE IF EXISTS `emulab_locks`;
CREATE TABLE `emulab_locks` (
  `name` varchar(64) NOT NULL default '',
  `value` int(10) NOT NULL default '0',
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `emulab_peers`
--

DROP TABLE IF EXISTS `emulab_peers`;
CREATE TABLE `emulab_peers` (
  `name` varchar(64) NOT NULL default '',
  `urn` varchar(128) NOT NULL default '',
  `is_primary` tinyint(1) NOT NULL default '0',
  `weburl` tinytext,
  PRIMARY KEY  (`name`),
  UNIQUE KEY `urn` (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `emulab_pubs`
--

DROP TABLE IF EXISTS `emulab_pubs`;
CREATE TABLE `emulab_pubs` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `uuid` varchar(40) NOT NULL,
  `created` datetime NOT NULL,
  `owner` mediumint(8) unsigned NOT NULL,
  `submitted_by` mediumint(8) unsigned NOT NULL,
  `last_edit` datetime NOT NULL,
  `last_edit_by` mediumint(8) unsigned NOT NULL,
  `type` tinytext NOT NULL,
  `authors` tinytext NOT NULL,
  `affil` tinytext NOT NULL,
  `title` tinytext NOT NULL,
  `conf` tinytext NOT NULL,
  `conf_url` tinytext NOT NULL,
  `where` tinytext NOT NULL,
  `year` tinytext NOT NULL,
  `month` float(3,1) NOT NULL,
  `volume` tinytext NOT NULL,
  `number` tinytext NOT NULL,
  `pages` tinytext NOT NULL,
  `url` tinytext NOT NULL,
  `evaluated_on_emulab` tinytext NOT NULL,
  `category` tinytext NOT NULL,
  `project` tinytext NOT NULL,
  `cite_osdi02` tinyint(1) default NULL,
  `no_cite_why` tinytext NOT NULL,
  `notes` text NOT NULL,
  `visible` tinyint(1) NOT NULL default '1',
  `deleted` tinyint(1) NOT NULL default '0',
  `editable_owner` tinyint(1) NOT NULL default '1',
  `editable_proj` tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `emulab_pubs_month_map`
--

DROP TABLE IF EXISTS `emulab_pubs_month_map`;
CREATE TABLE `emulab_pubs_month_map` (
  `display_order` int(10) unsigned NOT NULL auto_increment,
  `month` float(3,1) NOT NULL,
  `month_name` char(8) NOT NULL,
  PRIMARY KEY  (`month`),
  UNIQUE KEY `display_order` (`display_order`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `emulab_sites`
--

DROP TABLE IF EXISTS `emulab_sites`;
CREATE TABLE `emulab_sites` (
  `urn` varchar(128) NOT NULL default '',
  `commonname` varchar(64) NOT NULL,
  `url` tinytext,
  `created` datetime NOT NULL,
  `updated` datetime NOT NULL,
  `buildinfo` datetime NOT NULL,
  `commithash` varchar(64) NOT NULL,
  `dbrev` tinytext NOT NULL,
  `install` tinytext NOT NULL,
  `os_version` tinytext NOT NULL,
  `perl_version` tinytext NOT NULL,
  `tbops` tinytext,
  UNIQUE KEY `commonname` (`commonname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `errors`
--

DROP TABLE IF EXISTS `errors`;
CREATE TABLE `errors` (
  `session` int(10) unsigned NOT NULL default '0',
  `rank` tinyint(1) NOT NULL default '0',
  `stamp` int(10) unsigned NOT NULL default '0',
  `exptidx` int(11) NOT NULL default '0',
  `script` smallint(3) NOT NULL default '0',
  `cause` varchar(16) NOT NULL default '',
  `confidence` float NOT NULL default '0',
  `inferred` tinyint(1) default NULL,
  `need_more_info` tinyint(1) default NULL,
  `mesg` text NOT NULL,
  `tblog_revision` varchar(8) NOT NULL default '',
  PRIMARY KEY  (`session`,`rank`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `event_eventtypes`
--

DROP TABLE IF EXISTS `event_eventtypes`;
CREATE TABLE `event_eventtypes` (
  `idx` smallint(5) unsigned NOT NULL default '0',
  `type` tinytext NOT NULL,
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `event_groups`
--

DROP TABLE IF EXISTS `event_groups`;
CREATE TABLE `event_groups` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `group_name` varchar(64) NOT NULL default '',
  `agent_name` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`exptidx`,`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`idx`),
  KEY `group_name` (`group_name`),
  KEY `agent_name` (`agent_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `event_objecttypes`
--

DROP TABLE IF EXISTS `event_objecttypes`;
CREATE TABLE `event_objecttypes` (
  `idx` smallint(5) unsigned NOT NULL default '0',
  `type` tinytext NOT NULL,
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `event_triggertypes`
--

DROP TABLE IF EXISTS `event_triggertypes`;
CREATE TABLE `event_triggertypes` (
  `idx` smallint(5) unsigned NOT NULL,
  `type` tinytext NOT NULL,
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `eventlist`
--

DROP TABLE IF EXISTS `eventlist`;
CREATE TABLE `eventlist` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `time` float(10,3) NOT NULL default '0.000',
  `vnode` varchar(32) NOT NULL default '',
  `vname` varchar(64) NOT NULL default '',
  `objecttype` smallint(5) unsigned NOT NULL default '0',
  `eventtype` smallint(5) unsigned NOT NULL default '0',
  `triggertype` smallint(5) unsigned NOT NULL default '0',
  `isgroup` tinyint(1) unsigned default '0',
  `arguments` text,
  `atstring` text,
  `parent` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`exptidx`,`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`idx`),
  KEY `vnode` (`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_blobs`
--

DROP TABLE IF EXISTS `experiment_blobs`;
CREATE TABLE `experiment_blobs` (
  `idx` int(11) unsigned NOT NULL auto_increment,
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `path` varchar(255) NOT NULL default '',
  `action` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `exptidx` (`exptidx`,`path`,`action`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_features`
--

DROP TABLE IF EXISTS `experiment_features`;
CREATE TABLE `experiment_features` (
  `feature` varchar(64) NOT NULL default '',
  `added` datetime NOT NULL,
  `exptidx` int(11) NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`feature`,`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_input_data`
--

DROP TABLE IF EXISTS `experiment_input_data`;
CREATE TABLE `experiment_input_data` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `md5` varchar(32) NOT NULL default '',
  `compressed` tinyint(1) unsigned default '0',
  `input` mediumblob,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `md5` (`md5`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_inputs`
--

DROP TABLE IF EXISTS `experiment_inputs`;
CREATE TABLE `experiment_inputs` (
  `rsrcidx` int(10) unsigned NOT NULL default '0',
  `exptidx` int(10) unsigned NOT NULL default '0',
  `input_data_idx` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`rsrcidx`,`input_data_idx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_keys`
--

DROP TABLE IF EXISTS `experiment_keys`;
CREATE TABLE `experiment_keys` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `rsa_privkey` text,
  `rsa_pubkey` text,
  `ssh_pubkey` text,
  PRIMARY KEY  (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_pmapping`
--

DROP TABLE IF EXISTS `experiment_pmapping`;
CREATE TABLE `experiment_pmapping` (
  `rsrcidx` int(10) unsigned NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `node_type` varchar(30) NOT NULL default '',
  `node_erole` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`rsrcidx`,`vname`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_resources`
--

DROP TABLE IF EXISTS `experiment_resources`;
CREATE TABLE `experiment_resources` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `exptidx` int(10) unsigned NOT NULL default '0',
  `lastidx` int(10) unsigned default NULL,
  `tstamp` datetime default NULL,
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `swapin_time` int(10) unsigned NOT NULL default '0',
  `swapout_time` int(10) unsigned NOT NULL default '0',
  `swapmod_time` int(10) unsigned NOT NULL default '0',
  `byswapmod` tinyint(1) unsigned default '0',
  `byswapin` tinyint(1) unsigned default '0',
  `vnodes` smallint(5) unsigned default '0',
  `pnodes` smallint(5) unsigned default '0',
  `wanodes` smallint(5) unsigned default '0',
  `plabnodes` smallint(5) unsigned default '0',
  `simnodes` smallint(5) unsigned default '0',
  `jailnodes` smallint(5) unsigned default '0',
  `delaynodes` smallint(5) unsigned default '0',
  `linkdelays` smallint(5) unsigned default '0',
  `walinks` smallint(5) unsigned default '0',
  `links` smallint(5) unsigned default '0',
  `lans` smallint(5) unsigned default '0',
  `shapedlinks` smallint(5) unsigned default '0',
  `shapedlans` smallint(5) unsigned default '0',
  `wirelesslans` smallint(5) unsigned default '0',
  `minlinks` tinyint(3) unsigned default '0',
  `maxlinks` tinyint(3) unsigned default '0',
  `delay_capacity` tinyint(3) unsigned default NULL,
  `batchmode` tinyint(1) unsigned default '0',
  `archive_tag` varchar(64) default NULL,
  `input_data_idx` int(10) unsigned default NULL,
  `thumbnail` mediumblob,
  PRIMARY KEY  (`idx`),
  KEY `exptidx` (`exptidx`),
  KEY `lastidx` (`lastidx`),
  KEY `inputdata` (`input_data_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_run_bindings`
--

DROP TABLE IF EXISTS `experiment_run_bindings`;
CREATE TABLE `experiment_run_bindings` (
  `exptidx` int(10) unsigned NOT NULL default '0',
  `runidx` int(10) unsigned NOT NULL default '0',
  `name` varchar(64) NOT NULL default '',
  `value` tinytext NOT NULL,
  PRIMARY KEY  (`exptidx`,`runidx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_runs`
--

DROP TABLE IF EXISTS `experiment_runs`;
CREATE TABLE `experiment_runs` (
  `exptidx` int(10) unsigned NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `runid` varchar(32) NOT NULL default '',
  `description` tinytext,
  `starting_archive_tag` varchar(64) default NULL,
  `ending_archive_tag` varchar(64) default NULL,
  `archive_tag` varchar(64) default NULL,
  `start_time` datetime default NULL,
  `stop_time` datetime default NULL,
  `swapmod` tinyint(1) NOT NULL default '0',
  `hidden` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_stats`
--

DROP TABLE IF EXISTS `experiment_stats`;
CREATE TABLE `experiment_stats` (
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `eid` varchar(32) NOT NULL default '',
  `eid_uuid` varchar(40) NOT NULL default '',
  `creator` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `exptidx` int(10) unsigned NOT NULL default '0',
  `rsrcidx` int(10) unsigned NOT NULL default '0',
  `lastrsrc` int(10) unsigned default NULL,
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `destroyed` datetime default NULL,
  `last_activity` datetime default NULL,
  `swapin_count` smallint(5) unsigned default '0',
  `swapin_last` datetime default NULL,
  `swapout_count` smallint(5) unsigned default '0',
  `swapout_last` datetime default NULL,
  `swapmod_count` smallint(5) unsigned default '0',
  `swapmod_last` datetime default NULL,
  `swap_errors` smallint(5) unsigned default '0',
  `swap_exitcode` tinyint(3) default '0',
  `idle_swaps` smallint(5) unsigned default '0',
  `swapin_duration` int(10) unsigned default '0',
  `batch` tinyint(3) unsigned default '0',
  `elabinelab` tinyint(1) NOT NULL default '0',
  `elabinelab_exptidx` int(10) unsigned default NULL,
  `security_level` tinyint(1) NOT NULL default '0',
  `archive_idx` int(10) unsigned default NULL,
  `last_error` int(10) unsigned default NULL,
  `dpdbname` varchar(64) default NULL,
  `geniflags` int(10) unsigned default NULL,
  `slice_uuid` varchar(40) default NULL,
  `nonlocal_id` varchar(128) default NULL,
  `nonlocal_user_id` varchar(128) default NULL,
  `nonlocal_type` tinytext,
  PRIMARY KEY  (`exptidx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `pideid` (`pid`,`eid`),
  KEY `eid_uuid` (`eid_uuid`),
  KEY `pid_idx` (`pid_idx`),
  KEY `creator_idx` (`creator_idx`),
  KEY `geniflags` (`geniflags`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_events`
--

DROP TABLE IF EXISTS `experiment_template_events`;
CREATE TABLE `experiment_template_events` (
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `vname` varchar(64) NOT NULL default '',
  `vnode` varchar(32) NOT NULL default '',
  `time` float(10,3) NOT NULL default '0.000',
  `objecttype` smallint(5) unsigned NOT NULL default '0',
  `eventtype` smallint(5) unsigned NOT NULL default '0',
  `arguments` text,
  PRIMARY KEY  (`parent_guid`,`parent_vers`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_graphs`
--

DROP TABLE IF EXISTS `experiment_template_graphs`;
CREATE TABLE `experiment_template_graphs` (
  `parent_guid` varchar(16) NOT NULL default '',
  `scale` float(10,3) NOT NULL default '1.000',
  `image` mediumblob,
  `imap` mediumtext,
  PRIMARY KEY  (`parent_guid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_input_data`
--

DROP TABLE IF EXISTS `experiment_template_input_data`;
CREATE TABLE `experiment_template_input_data` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `md5` varchar(32) NOT NULL default '',
  `input` mediumtext,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `md5` (`md5`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_inputs`
--

DROP TABLE IF EXISTS `experiment_template_inputs`;
CREATE TABLE `experiment_template_inputs` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `tid` varchar(32) NOT NULL default '',
  `input_idx` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`parent_guid`,`parent_vers`,`idx`),
  KEY `pidtid` (`pid`,`tid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_instance_bindings`
--

DROP TABLE IF EXISTS `experiment_template_instance_bindings`;
CREATE TABLE `experiment_template_instance_bindings` (
  `instance_idx` int(10) unsigned NOT NULL default '0',
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `exptidx` int(10) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `name` varchar(64) NOT NULL default '',
  `value` tinytext NOT NULL,
  PRIMARY KEY  (`instance_idx`,`name`),
  KEY `parent_guid` (`parent_guid`,`parent_vers`),
  KEY `pidtid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_instance_deadnodes`
--

DROP TABLE IF EXISTS `experiment_template_instance_deadnodes`;
CREATE TABLE `experiment_template_instance_deadnodes` (
  `instance_idx` int(10) unsigned NOT NULL default '0',
  `exptidx` int(10) unsigned NOT NULL default '0',
  `runidx` int(10) unsigned NOT NULL default '0',
  `node_id` varchar(32) NOT NULL default '',
  `vname` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`instance_idx`,`runidx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_instances`
--

DROP TABLE IF EXISTS `experiment_template_instances`;
CREATE TABLE `experiment_template_instances` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `exptidx` int(10) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `logfileid` varchar(40) default NULL,
  `description` tinytext,
  `start_time` datetime default NULL,
  `stop_time` datetime default NULL,
  `continue_time` datetime default NULL,
  `runtime` int(10) unsigned default '0',
  `pause_time` datetime default NULL,
  `runidx` int(10) unsigned default NULL,
  `template_tag` varchar(64) default NULL,
  `export_time` datetime default NULL,
  `locked` datetime default NULL,
  `locker_pid` int(11) default '0',
  PRIMARY KEY  (`idx`),
  KEY `exptidx` (`exptidx`),
  KEY `parent_guid` (`parent_guid`,`parent_vers`),
  KEY `pid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_metadata`
--

DROP TABLE IF EXISTS `experiment_template_metadata`;
CREATE TABLE `experiment_template_metadata` (
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `metadata_guid` varchar(16) NOT NULL default '',
  `metadata_vers` smallint(5) unsigned NOT NULL default '0',
  `internal` tinyint(1) NOT NULL default '0',
  `hidden` tinyint(1) NOT NULL default '0',
  `metadata_type` enum('tid','template_description','parameter_description','annotation','instance_description','run_description') default NULL,
  PRIMARY KEY  (`parent_guid`,`parent_vers`,`metadata_guid`,`metadata_vers`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_metadata_items`
--

DROP TABLE IF EXISTS `experiment_template_metadata_items`;
CREATE TABLE `experiment_template_metadata_items` (
  `guid` varchar(16) NOT NULL default '',
  `vers` smallint(5) unsigned NOT NULL default '0',
  `parent_guid` varchar(16) default NULL,
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `template_guid` varchar(16) NOT NULL default '',
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `name` varchar(64) NOT NULL default '',
  `value` mediumtext,
  `created` datetime default NULL,
  PRIMARY KEY  (`guid`,`vers`),
  KEY `parent` (`parent_guid`,`parent_vers`),
  KEY `template` (`template_guid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_parameters`
--

DROP TABLE IF EXISTS `experiment_template_parameters`;
CREATE TABLE `experiment_template_parameters` (
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `tid` varchar(32) NOT NULL default '',
  `name` varchar(64) NOT NULL default '',
  `value` tinytext,
  `metadata_guid` varchar(16) default NULL,
  `metadata_vers` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`parent_guid`,`parent_vers`,`name`),
  KEY `pidtid` (`pid`,`tid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_searches`
--

DROP TABLE IF EXISTS `experiment_template_searches`;
CREATE TABLE `experiment_template_searches` (
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `name` varchar(64) NOT NULL default '',
  `expr` mediumtext,
  `created` datetime default NULL,
  PRIMARY KEY  (`parent_guid`,`parent_vers`,`uid_idx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_template_settings`
--

DROP TABLE IF EXISTS `experiment_template_settings`;
CREATE TABLE `experiment_template_settings` (
  `parent_guid` varchar(16) NOT NULL default '',
  `parent_vers` smallint(5) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `tid` varchar(32) NOT NULL default '',
  `uselinkdelays` tinyint(4) NOT NULL default '0',
  `forcelinkdelays` tinyint(4) NOT NULL default '0',
  `multiplex_factor` smallint(5) default NULL,
  `uselatestwadata` tinyint(4) NOT NULL default '0',
  `usewatunnels` tinyint(4) NOT NULL default '1',
  `wa_delay_solverweight` float default '0',
  `wa_bw_solverweight` float default '0',
  `wa_plr_solverweight` float default '0',
  `sync_server` varchar(32) default NULL,
  `cpu_usage` tinyint(4) unsigned NOT NULL default '0',
  `mem_usage` tinyint(4) unsigned NOT NULL default '0',
  `veth_encapsulate` tinyint(4) NOT NULL default '1',
  `allowfixnode` tinyint(4) NOT NULL default '1',
  `jail_osname` varchar(30) default NULL,
  `delay_osname` varchar(30) default NULL,
  `use_ipassign` tinyint(4) NOT NULL default '0',
  `ipassign_args` varchar(255) default NULL,
  `linktest_level` tinyint(4) NOT NULL default '0',
  `linktest_pid` int(11) default '0',
  `useprepass` tinyint(1) NOT NULL default '0',
  `elab_in_elab` tinyint(1) NOT NULL default '0',
  `elabinelab_eid` varchar(32) default NULL,
  `elabinelab_cvstag` varchar(64) default NULL,
  `elabinelab_nosetup` tinyint(1) NOT NULL default '0',
  `security_level` tinyint(1) NOT NULL default '0',
  `delay_capacity` tinyint(3) unsigned default NULL,
  `savedisk` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`parent_guid`,`parent_vers`),
  KEY `pidtid` (`pid`,`tid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiment_templates`
--

DROP TABLE IF EXISTS `experiment_templates`;
CREATE TABLE `experiment_templates` (
  `guid` varchar(16) NOT NULL default '',
  `vers` smallint(5) unsigned NOT NULL default '0',
  `parent_guid` varchar(16) default NULL,
  `parent_vers` smallint(5) unsigned default NULL,
  `child_guid` varchar(16) default NULL,
  `child_vers` smallint(5) unsigned default NULL,
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `tid` varchar(32) NOT NULL default '',
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `description` mediumtext,
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `archive_idx` int(10) unsigned default NULL,
  `created` datetime default NULL,
  `modified` datetime default NULL,
  `locked` datetime default NULL,
  `state` varchar(16) NOT NULL default 'new',
  `path` tinytext,
  `maximum_nodes` int(6) unsigned default NULL,
  `minimum_nodes` int(6) unsigned default NULL,
  `logfile` tinytext,
  `logfile_open` tinyint(4) NOT NULL default '0',
  `prerender_pid` int(11) default '0',
  `hidden` tinyint(1) NOT NULL default '0',
  `active` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`guid`,`vers`),
  KEY `pidtid` (`pid`,`tid`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `experiments`
--

DROP TABLE IF EXISTS `experiments`;
CREATE TABLE `experiments` (
  `eid` varchar(32) NOT NULL default '',
  `eid_uuid` varchar(40) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `swapper_idx` mediumint(8) unsigned default NULL,
  `expt_created` datetime default NULL,
  `expt_expires` datetime default NULL,
  `expt_name` tinytext,
  `expt_head_uid` varchar(8) NOT NULL default '',
  `expt_start` datetime default NULL,
  `expt_end` datetime default NULL,
  `expt_terminating` datetime default NULL,
  `expt_locked` datetime default NULL,
  `expt_swapped` datetime default NULL,
  `expt_swap_uid` varchar(8) NOT NULL default '',
  `swappable` tinyint(4) NOT NULL default '0',
  `priority` tinyint(4) NOT NULL default '0',
  `noswap_reason` tinytext,
  `idleswap` tinyint(4) NOT NULL default '0',
  `idleswap_timeout` int(4) NOT NULL default '0',
  `noidleswap_reason` tinytext,
  `autoswap` tinyint(4) NOT NULL default '0',
  `autoswap_timeout` int(4) NOT NULL default '0',
  `batchmode` tinyint(4) NOT NULL default '0',
  `shared` tinyint(4) NOT NULL default '0',
  `state` varchar(16) NOT NULL default 'new',
  `maximum_nodes` int(6) unsigned default NULL,
  `minimum_nodes` int(6) unsigned default NULL,
  `virtnode_count` int(6) unsigned default NULL,
  `testdb` tinytext,
  `path` tinytext,
  `logfile` tinytext,
  `logfile_open` tinyint(4) NOT NULL default '0',
  `attempts` smallint(5) unsigned NOT NULL default '0',
  `canceled` tinyint(4) NOT NULL default '0',
  `batchstate` varchar(16) default NULL,
  `event_sched_pid` int(11) default '0',
  `prerender_pid` int(11) default '0',
  `uselinkdelays` tinyint(4) NOT NULL default '0',
  `forcelinkdelays` tinyint(4) NOT NULL default '0',
  `multiplex_factor` smallint(5) default NULL,
  `packing_strategy` enum('pack','balance') default NULL,
  `uselatestwadata` tinyint(4) NOT NULL default '0',
  `usewatunnels` tinyint(4) NOT NULL default '1',
  `wa_delay_solverweight` float default '0',
  `wa_bw_solverweight` float default '0',
  `wa_plr_solverweight` float default '0',
  `swap_requests` tinyint(4) NOT NULL default '0',
  `last_swap_req` datetime default NULL,
  `idle_ignore` tinyint(4) NOT NULL default '0',
  `sync_server` varchar(32) default NULL,
  `cpu_usage` tinyint(4) unsigned NOT NULL default '0',
  `mem_usage` tinyint(4) unsigned NOT NULL default '0',
  `keyhash` varchar(64) default NULL,
  `eventkey` varchar(64) default NULL,
  `idx` int(10) unsigned NOT NULL auto_increment,
  `sim_reswap_count` smallint(5) unsigned NOT NULL default '0',
  `veth_encapsulate` tinyint(4) NOT NULL default '1',
  `encap_style` enum('alias','veth','veth-ne','vlan','vtun','egre','gre','default') NOT NULL default 'default',
  `allowfixnode` tinyint(4) NOT NULL default '1',
  `jail_osname` varchar(30) default NULL,
  `delay_osname` varchar(30) default NULL,
  `use_ipassign` tinyint(4) NOT NULL default '0',
  `ipassign_args` varchar(255) default NULL,
  `linktest_level` tinyint(4) NOT NULL default '0',
  `linktest_pid` int(11) default '0',
  `useprepass` tinyint(1) NOT NULL default '0',
  `usemodelnet` tinyint(1) NOT NULL default '0',
  `modelnet_cores` tinyint(4) unsigned NOT NULL default '0',
  `modelnet_edges` tinyint(4) unsigned NOT NULL default '0',
  `modelnetcore_osname` varchar(30) default NULL,
  `modelnetedge_osname` varchar(30) default NULL,
  `elab_in_elab` tinyint(1) NOT NULL default '0',
  `elabinelab_eid` varchar(32) default NULL,
  `elabinelab_exptidx` int(11) default NULL,
  `elabinelab_cvstag` varchar(64) default NULL,
  `elabinelab_nosetup` tinyint(1) NOT NULL default '0',
  `elabinelab_singlenet` tinyint(1) NOT NULL default '0',
  `security_level` tinyint(1) NOT NULL default '0',
  `lockdown` tinyint(1) NOT NULL default '0',
  `paniced` tinyint(1) NOT NULL default '0',
  `panic_date` datetime default NULL,
  `delay_capacity` tinyint(3) unsigned default NULL,
  `savedisk` tinyint(1) NOT NULL default '0',
  `skipvlans` tinyint(1) NOT NULL default '0',
  `locpiper_pid` int(11) default '0',
  `locpiper_port` int(11) default '0',
  `instance_idx` int(10) unsigned NOT NULL default '0',
  `dpdb` tinyint(1) NOT NULL default '0',
  `dpdbname` varchar(64) default NULL,
  `dpdbpassword` varchar(64) default NULL,
  `geniflags` int(11) NOT NULL default '0',
  `nonlocal_id` varchar(128) default NULL,
  `nonlocal_user_id` varchar(128) default NULL,
  `nonlocal_type` tinytext,
  `nonfsmounts` tinyint(1) NOT NULL default '0',
  `nfsmounts` enum('emulabdefault','genidefault','all','none') NOT NULL default 'emulabdefault',
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`),
  UNIQUE KEY `pididxeid` (`pid_idx`,`eid`),
  UNIQUE KEY `keyhash` (`keyhash`),
  KEY `batchmode` (`batchmode`),
  KEY `state` (`state`),
  KEY `eid_uuid` (`eid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `exported_tables`
--

DROP TABLE IF EXISTS `exported_tables`;
CREATE TABLE `exported_tables` (
  `table_name` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`table_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `exppid_access`
--

DROP TABLE IF EXISTS `exppid_access`;
CREATE TABLE `exppid_access` (
  `exp_eid` varchar(32) NOT NULL default '',
  `exp_pid` varchar(48) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  PRIMARY KEY  (`exp_eid`,`exp_pid`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `external_networks`
--

DROP TABLE IF EXISTS `external_networks`;
CREATE TABLE `external_networks` (
  `network_id` varchar(32) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `node_type` varchar(30) NOT NULL default '',
  `external_manager` tinytext,
  `external_interface` tinytext,
  `external_wire` tinytext,
  `external_subport` tinytext,
  `mode` enum('chain','tree') NOT NULL default 'tree',
  `vlans` tinytext,
  PRIMARY KEY  (`network_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
  
--
-- Table structure for table `firewall_rules`
--

DROP TABLE IF EXISTS `firewall_rules`;
CREATE TABLE `firewall_rules` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `fwname` varchar(32) NOT NULL default '',
  `ruleno` int(10) unsigned NOT NULL default '0',
  `rule` text NOT NULL,
  PRIMARY KEY  (`exptidx`,`fwname`,`ruleno`),
  KEY `fwname` (`fwname`),
  KEY `pideid` (`pid`,`eid`,`fwname`,`ruleno`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `firewalls`
--

DROP TABLE IF EXISTS `firewalls`;
CREATE TABLE `firewalls` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `fwname` varchar(32) NOT NULL default '',
  `vlan` int(11) default NULL,
  `vlanid` int(11) default NULL,
  PRIMARY KEY  (`exptidx`,`fwname`),
  KEY `vlan` (`vlan`),
  KEY `pideid` (`pid`,`eid`,`fwname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `floorimages`
--

DROP TABLE IF EXISTS `floorimages`;
CREATE TABLE `floorimages` (
  `building` varchar(32) NOT NULL default '',
  `floor` varchar(32) NOT NULL default '',
  `image_path` tinytext,
  `thumb_path` tinytext,
  `x1` int(6) NOT NULL default '0',
  `y1` int(6) NOT NULL default '0',
  `x2` int(6) NOT NULL default '0',
  `y2` int(6) NOT NULL default '0',
  `scale` tinyint(4) NOT NULL default '1',
  `pixels_per_meter` float(10,3) NOT NULL default '0.000',
  PRIMARY KEY  (`building`,`floor`,`scale`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `foreign_keys`
--

DROP TABLE IF EXISTS `foreign_keys`;
CREATE TABLE `foreign_keys` (
  `table1` varchar(30) NOT NULL default '',
  `column1` varchar(30) NOT NULL default '',
  `table2` varchar(30) NOT NULL default '',
  `column2` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`table1`,`column1`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `frisbee_blobs`
--

DROP TABLE IF EXISTS `frisbee_blobs`;
CREATE TABLE `frisbee_blobs` (
  `idx` int(11) unsigned NOT NULL auto_increment,
  `path` varchar(255) NOT NULL default '',
  `imageid` int(8) unsigned default NULL,
  `imageid_version` int(8) unsigned default NULL,
  `load_address` text,
  `frisbee_pid` int(11) default '0',
  `load_busy` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `path` (`path`),
  UNIQUE KEY `imageid` (`imageid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `fs_resources`
--

DROP TABLE IF EXISTS `fs_resources`;
CREATE TABLE `fs_resources` (
  `rsrcidx` int(10) unsigned NOT NULL default '0',
  `fileidx` int(11) unsigned NOT NULL default '0',
  `exptidx` int(10) unsigned NOT NULL default '0',
  `type` enum('r','w','rw','l') default 'r',
  `size` int(11) unsigned default '0',
  PRIMARY KEY  (`rsrcidx`,`fileidx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `fileidx` (`fileidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `future_reservation_attributes`
--

DROP TABLE IF EXISTS `future_reservation_attributes`;
CREATE TABLE `future_reservation_attributes` (
  `reservation_idx` mediumint(8) unsigned NOT NULL,
  `attrkey` varchar(32) NOT NULL,
  `attrvalue` tinytext,
  PRIMARY KEY (`reservation_idx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `future_reservations`
--

DROP TABLE IF EXISTS `future_reservations`;
CREATE TABLE `future_reservations` (
  `idx` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `nodes` smallint(5) unsigned NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `cancel` datetime DEFAULT NULL,
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `notes` mediumtext,
  `admin_notes` mediumtext,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `approved` datetime DEFAULT NULL,
  `approver` varchar(8) DEFAULT NULL,
  `notified` datetime DEFAULT NULL,
  `notified_unused` datetime DEFAULT NULL,
  `override_unused` tinyint(1) NOT NULL default '0',
  `uuid` varchar(40) NOT NULL default '',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `global_ipalloc`
--

DROP TABLE IF EXISTS `global_ipalloc`;
CREATE TABLE `global_ipalloc` (
  `exptidx` int(11) NOT NULL default '0',
  `lanidx` int(11) NOT NULL default '0',
  `member` int(11) NOT NULL default '0',
  `fabric_idx` int(11) NOT NULL default '0',
  `ipint` int(11) unsigned NOT NULL default '0',
  `ip` varchar(15) default NULL,
  PRIMARY KEY  (`exptidx`,`lanidx`,`ipint`),
  UNIQUE KEY `fabip` (`fabric_idx`,`ipint`),
  KEY `ipint` (`ipint`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `global_policies`
--

DROP TABLE IF EXISTS `global_policies`;
CREATE TABLE `global_policies` (
  `policy` varchar(32) NOT NULL default '',
  `auxdata` varchar(128) NOT NULL default '',
  `test` varchar(32) NOT NULL default '',
  `count` int(10) NOT NULL default '0',
  PRIMARY KEY  (`policy`,`auxdata`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `global_vtypes`
--

DROP TABLE IF EXISTS `global_vtypes`;
CREATE TABLE `global_vtypes` (
  `vtype` varchar(30) NOT NULL default '',
  `weight` float NOT NULL default '0.5',
  `types` text NOT NULL,
  PRIMARY KEY  (`vtype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `group_exports`
--

DROP TABLE IF EXISTS `group_exports`;
CREATE TABLE `group_exports` (
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `peer` varchar(64) NOT NULL default '',
  `exported` datetime default NULL,
  `updated` datetime default NULL,
  PRIMARY KEY  (`pid_idx`,`gid_idx`,`peer`),
  UNIQUE KEY pidpeer (`pid`,`gid`,`peer`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `group_features`
--

DROP TABLE IF EXISTS `group_features`;
CREATE TABLE `group_features` (
  `feature` varchar(64) NOT NULL default '',
  `added` datetime NOT NULL,
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`feature`,`gid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `group_membership`
--

DROP TABLE IF EXISTS `group_membership`;
CREATE TABLE `group_membership` (
  `uid` varchar(8) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `trust` enum('none','user','local_root','group_root','project_root') default NULL,
  `date_applied` date default NULL,
  `date_approved` datetime default NULL,
  `date_nagged` datetime default NULL,
  PRIMARY KEY  (`uid_idx`,`gid_idx`),
  UNIQUE KEY `uid` (`uid`,`pid`,`gid`),
  KEY `pid` (`pid`),
  KEY `gid` (`gid`),
  KEY `pid_idx_gid_idx` (`pid_idx`,`gid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `group_policies`
--

DROP TABLE IF EXISTS `group_policies`;
CREATE TABLE `group_policies` (
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `policy` varchar(32) NOT NULL default '',
  `auxdata` varchar(64) NOT NULL default '',
  `count` int(10) NOT NULL default '0',
  PRIMARY KEY  (`pid_idx`,`gid_idx`,`policy`,`auxdata`),
  UNIQUE KEY `pid` (`pid`,`gid`,`policy`,`auxdata`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `group_stats`
--

DROP TABLE IF EXISTS `group_stats`;
CREATE TABLE `group_stats` (
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_uuid` varchar(40) NOT NULL default '',
  `exptstart_count` int(11) unsigned default '0',
  `exptstart_last` datetime default NULL,
  `exptpreload_count` int(11) unsigned default '0',
  `exptpreload_last` datetime default NULL,
  `exptswapin_count` int(11) unsigned default '0',
  `exptswapin_last` datetime default NULL,
  `exptswapout_count` int(11) unsigned default '0',
  `exptswapout_last` datetime default NULL,
  `exptswapmod_count` int(11) unsigned default '0',
  `exptswapmod_last` datetime default NULL,
  `last_activity` datetime default NULL,
  `allexpt_duration` double(14,0) unsigned default '0',
  `allexpt_vnodes` int(11) unsigned default '0',
  `allexpt_vnode_duration` double(14,0) unsigned default '0',
  `allexpt_pnodes` int(11) unsigned default '0',
  `allexpt_pnode_duration` double(14,0) unsigned default '0',
  PRIMARY KEY  (`gid_idx`),
  UNIQUE KEY `pidgid` (`pid`,`gid`),
  KEY `gid_uuid` (`gid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
CREATE TABLE `groups` (
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_uuid` varchar(40) NOT NULL default '',
  `leader` varchar(8) NOT NULL default '',
  `leader_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `description` tinytext,
  `unix_gid` smallint(5) unsigned NOT NULL auto_increment,
  `unix_name` varchar(16) NOT NULL default '',
  `expt_count` mediumint(8) unsigned default '0',
  `expt_last` date default NULL,
  `wikiname` tinytext,
  `mailman_password` tinytext,
  PRIMARY KEY  (`gid_idx`),
  UNIQUE KEY `pidgid` (`pid`,`gid`),
  KEY `unix_gid` (`unix_gid`),
  KEY `gid` (`gid`),
  KEY `pid` (`pid`),
  KEY `pididx` (`pid_idx`,`gid_idx`),
  KEY `gid_uuid` (`gid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `iface_counters`
--

DROP TABLE IF EXISTS `iface_counters`;
CREATE TABLE `iface_counters` (
  `node_id` varchar(32) NOT NULL default '',
  `tstamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `mac` varchar(12) NOT NULL default '0',
  `ipkts` int(11) NOT NULL default '0',
  `opkts` int(11) NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`tstamp`,`mac`),
  KEY `macindex` (`mac`),
  KEY `node_idindex` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `ifaces`
--

DROP TABLE IF EXISTS `ifaces`;
CREATE TABLE `ifaces` (
  `lanid` int(11) NOT NULL default '0',
  `ifaceid` int(11) NOT NULL default '0',
  `exptidx` int(11) NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `vnode` varchar(32) NOT NULL default '',
  `vname` varchar(32) NOT NULL default '',
  `vidx` int(11) NOT NULL default '0',
  `vport` tinyint(3) NOT NULL default '0',
  PRIMARY KEY  (`lanid`,`ifaceid`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`),
  KEY `lanid` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_aliases`
--

DROP TABLE IF EXISTS `image_aliases`;
CREATE TABLE `image_aliases` (
  `imagename` varchar(30) NOT NULL default '',
  `imageid` int(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uuid` varchar(40) NOT NULL default '',
  `target_imagename` varchar(30) NOT NULL default '',
  `target_imageid` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`imageid`,`target_imageid`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_boot_status`
--

DROP TABLE IF EXISTS `image_boot_status`;
CREATE TABLE `image_boot_status` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `stamp` int(10) unsigned NOT NULL,
  `exptidx` int(11) NOT NULL default '0',
  `rsrcidx` int(10) unsigned default NULL,
  `node_id` varchar(32) NOT NULL,
  `node_type` varchar(30) NOT NULL,
  `imageid` int(8) default NULL,
  `imageid_version` int(8) default NULL,
  `status` enum('success','reloadfail','bootfail','timedout','tbfailed') NOT NULL default 'success',
  PRIMARY KEY  (`idx`),
  KEY `stamp` (`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_deletions`
--

DROP TABLE IF EXISTS `image_deletions`;
CREATE TABLE `image_deletions` (
  `urn` varchar(128) default NULL,
  `image_uuid` varchar(40) NOT NULL default '',
  `deleted` datetime default NULL,
  PRIMARY KEY  (`image_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_history`
--

DROP TABLE IF EXISTS `image_history`;
CREATE TABLE `image_history` (
  `history_id` int(10) unsigned NOT NULL auto_increment,
  `stamp` int(10) unsigned NOT NULL,
  `node_history_id` int(10) unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL,
  `action` varchar(8) NOT NULL,
  `newly_alloc` int(1) default NULL,
  `rsrcidx` int(10) unsigned default NULL,
  `log_session` int(10) unsigned default NULL,
  `req_type` varchar(30) default NULL,
  `phys_type` varchar(30) NOT NULL,
  `req_os` int(1) default NULL,
  `osid` int(8) default NULL,
  `osid_vers` int(8) default NULL,
  `imageid` int(8) default NULL,
  `imageid_version` int(8) default NULL,
  PRIMARY KEY  (`history_id`),
  KEY `node_id` (`node_id`,`history_id`),
  KEY `stamp` (`stamp`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `node_history_id` (`node_history_id`),
  KEY `imagestamp` (`imageid`,`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_incoming_relocations`
--

DROP TABLE IF EXISTS `image_incoming_relocations`;
CREATE TABLE `image_incoming_relocations` (
  `imagename` varchar(30) NOT NULL default '',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `remote_urn` varchar(128) default NULL,
  `metadata_url` tinytext,
  `created` datetime default NULL,
  `locked` datetime default NULL,
  PRIMARY KEY  (`pid_idx`,`imagename`),
  UNIQUE KEY `remote_urn`  (`remote_urn`),
  UNIQUE KEY  `metadata_url` (`metadata_url`(128))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_notifications`
--

DROP TABLE IF EXISTS `image_notifications`;
CREATE TABLE `image_notifications` (
  `imageid` int(8) unsigned NOT NULL default '0',
  `version` int(8) unsigned NOT NULL default '0',
  `origin_uuid` varchar(64) default NULL,
  `notified` datetime default NULL,
  PRIMARY KEY  (`imageid`,`version`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_permissions`
--

DROP TABLE IF EXISTS `image_permissions`;
CREATE TABLE `image_permissions` (
  `imageid` int(8) unsigned NOT NULL default '0',
  `imagename` varchar(30) NOT NULL default '',
  `permission_type` enum('user','group') NOT NULL default 'user',
  `permission_id` varchar(128) NOT NULL default '',
  `permission_idx` mediumint(8) unsigned NOT NULL default '0',
  `allow_write` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`imageid`,`permission_type`,`permission_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_versions`
--

DROP TABLE IF EXISTS `image_versions`;
CREATE TABLE `image_versions` (
  `imagename` varchar(30) NOT NULL default '',
  `version` int(8) unsigned NOT NULL default '0',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `imageid` int(8) unsigned NOT NULL default '0',
  `parent_imageid` int(8) unsigned default NULL,
  `parent_version` int(8) unsigned default NULL,
  `uuid` varchar(40) NOT NULL default '',
  `old_imageid` varchar(45) NOT NULL default '',
  `creator` varchar(8) default NULL,
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `creator_urn` varchar(128) default NULL,
  `created` datetime default NULL,
  `updater` varchar(8) default NULL,
  `updater_idx` mediumint(8) unsigned NOT NULL default '0',
  `updater_urn` varchar(128) default NULL,
  `description` tinytext NOT NULL,
  `loadpart` tinyint(4) NOT NULL default '0',
  `loadlength` tinyint(4) NOT NULL default '0',
  `part1_osid` int(8) unsigned default NULL,
  `part1_vers` int(8) unsigned NOT NULL default '0',
  `part2_osid` int(8) unsigned default NULL,
  `part2_vers` int(8) unsigned NOT NULL default '0',
  `part3_osid` int(8) unsigned default NULL,
  `part3_vers` int(8) unsigned NOT NULL default '0',
  `part4_osid` int(8) unsigned default NULL,
  `part4_vers` int(8) unsigned NOT NULL default '0',
  `default_osid` int(8) unsigned NOT NULL default '0',
  `default_vers` int(8) unsigned NOT NULL default '0',
  `path` tinytext,
  `magic` tinytext,
  `ezid` tinyint(4) NOT NULL default '0',
  `shared` tinyint(4) NOT NULL default '0',
  `global` tinyint(4) NOT NULL default '0',
  `mbr_version` varchar(50) NOT NULL default '1',
  `updated` datetime default NULL,
  `deleted` datetime default NULL,
  `last_used` datetime default NULL,
  `format` varchar(8) NOT NULL default 'ndz',
  `access_key` varchar(64) default NULL,
  `auth_uuid` varchar(64) default NULL,
  `auth_key` varchar(512) default NULL,
  `decryption_key` varchar(256) default NULL,
  `hash` varchar(64) default NULL,
  `deltahash` varchar(64) default NULL,
  `size` bigint(20) unsigned NOT NULL default '0',
  `deltasize` bigint(20) unsigned NOT NULL default '0',
  `lba_low` bigint(20) unsigned NOT NULL default '0',
  `lba_high` bigint(20) unsigned NOT NULL default '0',
  `lba_size` int(10) unsigned NOT NULL default '512',
  `relocatable` tinyint(1) NOT NULL default '0',
  `metadata_url` tinytext,
  `imagefile_url` tinytext,
  `origin_urn` varchar(128) default NULL,
  `origin_name` varchar(128) default NULL,
  `origin_uuid` varchar(64) default NULL,
  `origin_neednotify` tinyint(1) NOT NULL default '0',
  `origin_needupdate` tinyint(1) NOT NULL default '0',
  `authority_urn` varchar(128) default NULL,
  `credential_string_save` text,
  `logfileid` varchar(40) default NULL,
  `noexport` tinyint(1) NOT NULL default '0',
  `noclone` tinyint(1) NOT NULL default '0',
  `ready` tinyint(1) NOT NULL default '0',
  `isdelta` tinyint(1) NOT NULL default '0',
  `isdataset` tinyint(1) NOT NULL default '0',
  `released` tinyint(1) NOT NULL default '0',
  `ims_reported` datetime default NULL,
  `ims_update` datetime default NULL,
  `ims_noreport` tinyint(1) NOT NULL default '0',
  `nodetypes` text default NULL,
  `uploader_path` tinytext,
  `uploader_status` tinytext,
  `notes` mediumtext,
  `deprecated` datetime default NULL,
  `deprecated_iserror` tinyint(1) NOT NULL default '0',
  `deprecated_message` mediumtext,
  PRIMARY KEY  (`imageid`,`version`),
  KEY `pid` (`pid`,`imagename`,`version`),
  KEY `gid` (`gid`),
  KEY `old_imageid` (`old_imageid`),
  KEY `uuid` (`uuid`),
  FULLTEXT KEY `imagesearch` (`imagename`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_updates`
--

DROP TABLE IF EXISTS `image_updates`;
CREATE TABLE `image_updates` (
  `imageid` int(8) unsigned NOT NULL default '0',
  `updater` varchar(8) default NULL,
  `updater_idx` mediumint(8) unsigned NOT NULL default '0',
  `updater_urn` varchar(128) default NULL,
  `updated` datetime default NULL,
  `url` varchar(255) NOT NULL default '',
  `credential_string` text,
  PRIMARY KEY  (`imageid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_pending_imports`
--

DROP TABLE IF EXISTS `image_pending_imports`;
CREATE TABLE `image_pending_imports` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `imagename` varchar(30) NOT NULL default '',
  `imageid` int(8) unsigned default NULL,
  `imageuuid` varchar(40) default NULL,
  `uid` varchar(8) default NULL,
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid_urn` varchar(128) default NULL,
  `pid` varchar(48) default NULL,
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) default NULL,
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `type` enum('import','copyback','relocation') default NULL,
  `locked` datetime default NULL,
  `locker_pid` int(11) default '0',
  `failed` datetime default NULL,
  `failure_message` text,
  `remote_urn` varchar(128) default NULL,
  `metadata_url` varchar(256) default '',
  `credential_string` text,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `url` (`metadata_url`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `images`
--

DROP TABLE IF EXISTS `images`;
CREATE TABLE `images` (
  `imagename` varchar(30) NOT NULL default '',
  `architecture` varchar(30) default NULL,
  `version` int(8) unsigned NOT NULL default '0',
  `imageid` int(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uuid` varchar(40) NOT NULL default '',
  `webtask_id` varchar(128) default NULL,
  `listed` tinyint(1) NOT NULL default '1',
  `nodelta` tinyint(1) NOT NULL default '0',
  `noversioning` tinyint(1) NOT NULL default '0',
  `metadata_url` tinytext,
  `relocate_urn` tinytext,
  `credential_string` text,
  `locked` datetime default NULL,
  `locker_pid` int(11) default '0',
  PRIMARY KEY  (`imageid`),
  UNIQUE KEY `pid` (`pid`,`imagename`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `interface_capabilities`
--

DROP TABLE IF EXISTS `interface_capabilities`;
CREATE TABLE `interface_capabilities` (
  `type` varchar(30) NOT NULL default '',
  `capkey` varchar(64) NOT NULL default '',
  `capval` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`type`,`capkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `interface_settings`
--

DROP TABLE IF EXISTS `interface_settings`;
CREATE TABLE `interface_settings` (
  `node_id` varchar(32) NOT NULL default '',
  `iface` varchar(32) NOT NULL default '',
  `capkey` varchar(32) NOT NULL default '',
  `capval` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`node_id`,`iface`,`capkey`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `interface_state`
--

DROP TABLE IF EXISTS `interface_state`;
CREATE TABLE `interface_state` (
  `node_id` varchar(32) NOT NULL default '',
  `card_saved` tinyint(3) unsigned NOT NULL default '0',
  `port_saved` smallint(5) unsigned NOT NULL default '0',
  `iface` varchar(32) NOT NULL,
  `enabled` tinyint(1) default '1',
  `tagged` tinyint(1) default '0',
  `remaining_bandwidth` int(11) NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`iface`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `interface_types`
--

DROP TABLE IF EXISTS `interface_types`;
CREATE TABLE `interface_types` (
  `type` varchar(30) NOT NULL default '',
  `max_speed` int(11) default NULL,
  `full_duplex` tinyint(1) default NULL,
  `manufacturer` varchar(30) default NULL,
  `model` varchar(30) default NULL,
  `ports` smallint(5) unsigned default NULL,
  `connector` varchar(30) default NULL,
  PRIMARY KEY  (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `interfaces`
--

DROP TABLE IF EXISTS `interfaces`;
CREATE TABLE `interfaces` (
  `node_id` varchar(32) NOT NULL default '',
  `card_saved` tinyint(3) unsigned NOT NULL default '0',
  `port_saved` smallint(5) unsigned NOT NULL default '0',
  `mac` varchar(12) NOT NULL default '000000000000',
  `guid` varchar(16) default NULL,
  `IP` varchar(15) default NULL,
  `IPaliases` text,
  `mask` varchar(15) default NULL,
  `interface_type` varchar(30) default NULL,
  `iface` text NOT NULL,
  `role` enum('ctrl','expt','jail','fake','other','gw','outer_ctrl','mngmnt') default NULL,
  `current_speed` varchar(12) NOT NULL default '0',
  `duplex` enum('full','half') NOT NULL default 'full',
  `noportcontrol` tinyint(1) NOT NULL default '0',
  `rtabid` smallint(5) unsigned NOT NULL default '0',
  `vnode_id` varchar(32) default NULL,
  `whol` tinyint(4) NOT NULL default '0',
  `trunk` tinyint(1) NOT NULL default '0',
  `trunk_mode` enum('equal','dual') NOT NULL default 'equal',
  `LAG` tinyint(1) NOT NULL default '0',
  `uuid` varchar(40) NOT NULL default '',
  `logical` tinyint(1) unsigned NOT NULL default '0',
  `autocreated` tinyint(1) unsigned NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`iface`(128)),
  KEY `mac` (`mac`),
  KEY `IP` (`IP`),
  KEY `uuid` (`uuid`),
  KEY `role` (`role`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `node_ip_changes`
--

DROP TABLE IF EXISTS `node_ip_changes`;
CREATE TABLE `node_ip_changes` (
  `node_id` varchar(32) NOT NULL default '',
  `oldIP` varchar(15) default NULL,
  `newIP` varchar(15) default NULL,
  `changed` datetime NOT NULL default '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `interfaces_rf_limit`
--

DROP TABLE IF EXISTS `interfaces_rf_limit`;
CREATE TABLE `interfaces_rf_limit` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `iface` text NOT NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `power` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`node_id`,`iface`(128),`freq_low`,`freq_high`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_rf_reports`
--

DROP TABLE IF EXISTS `node_rf_reports`;
CREATE TABLE `node_rf_reports` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `tstamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `which` enum('system','user') NOT NULL default 'user',
  `report` mediumtext NOT NULL,
  PRIMARY KEY (`node_id`,`which`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_rf_violations`
--

DROP TABLE IF EXISTS `node_rf_violations`;
CREATE TABLE `node_rf_violations` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `iface` text NOT NULL,
  `tstamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `frequency` float(8,3) NOT NULL DEFAULT '0.000',
  `power` float(8,3) NOT NULL DEFAULT '0.000',
  KEY nodeiface (`node_id`,`iface`(128)),
  KEY nodestamp (`node_id`,`iface`(128),`tstamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `ipport_ranges`
--

DROP TABLE IF EXISTS `ipport_ranges`;
CREATE TABLE `ipport_ranges` (
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `low` int(11) NOT NULL default '0',
  `high` int(11) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `ipsubnets`
--

DROP TABLE IF EXISTS `ipsubnets`;
CREATE TABLE `ipsubnets` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `idx` smallint(5) unsigned NOT NULL auto_increment,
  PRIMARY KEY  (`idx`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `knowledge_base_entries`
--

DROP TABLE IF EXISTS `knowledge_base_entries`;
CREATE TABLE `knowledge_base_entries` (
  `idx` int(11) NOT NULL auto_increment,
  `creator_uid` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `date_created` datetime default NULL,
  `section` tinytext,
  `title` tinytext,
  `body` text,
  `xref_tag` varchar(64) default NULL,
  `faq_entry` tinyint(1) NOT NULL default '0',
  `date_modified` datetime default NULL,
  `modifier_uid` varchar(8) default NULL,
  `modifier_idx` mediumint(8) unsigned NOT NULL default '0',
  `archived` tinyint(1) NOT NULL default '0',
  `date_archived` datetime default NULL,
  `archiver_uid` varchar(8) default NULL,
  `archiver_idx` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `lan_attributes`
--

DROP TABLE IF EXISTS `lan_attributes`;
CREATE TABLE `lan_attributes` (
  `lanid` int(11) NOT NULL default '0',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` text NOT NULL,
  `attrtype` enum('integer','float','boolean','string') default 'string',
  PRIMARY KEY  (`lanid`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `lan_member_attributes`
--

DROP TABLE IF EXISTS `lan_member_attributes`;
CREATE TABLE `lan_member_attributes` (
  `lanid` int(11) NOT NULL default '0',
  `memberid` int(11) NOT NULL default '0',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') default 'string',
  PRIMARY KEY  (`lanid`,`memberid`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `lan_members`
--

DROP TABLE IF EXISTS `lan_members`;
CREATE TABLE `lan_members` (
  `lanid` int(11) NOT NULL default '0',
  `memberid` int(11) NOT NULL auto_increment,
  `node_id` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`lanid`,`memberid`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `lans`
--

DROP TABLE IF EXISTS `lans`;
CREATE TABLE `lans` (
  `lanid` int(11) NOT NULL auto_increment,
  `exptidx` int(11) NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `vname` varchar(64) NOT NULL default '',
  `vidx` int(11) NOT NULL default '0',
  `type` varchar(32) NOT NULL default '',
  `link` int(11) default NULL,
  `ready` tinyint(1) default '0',
  `locked` datetime default NULL,
  PRIMARY KEY  (`lanid`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `last_reservation`
--

DROP TABLE IF EXISTS `last_reservation`;
CREATE TABLE `last_reservation` (
  `node_id` varchar(32) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`pid_idx`),
  UNIQUE KEY `pid` (`node_id`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `lease_attributes`
--

DROP TABLE IF EXISTS `lease_attributes`;
CREATE TABLE `lease_attributes` (
  `lease_idx` int(10) unsigned NOT NULL default '0',
  `attrkey` varchar(32) NOT NULL default '',
  `attrval` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') default 'string',
  PRIMARY KEY (`lease_idx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `lease_attributes`
--

DROP TABLE IF EXISTS `lease_permissions`;
CREATE TABLE `lease_permissions` (
  `lease_idx` int(10) unsigned NOT NULL default '0',
  `lease_id` varchar(32) NOT NULL default '',
  `permission_type` enum('user','group','global') NOT NULL default 'user',
  `permission_id` varchar(128) NOT NULL default '',
  `permission_idx` mediumint(8) unsigned NOT NULL default '0',
  `allow_modify` tinyint(1) NOT NULL default '0',
  PRIMARY KEY (`lease_idx`,`permission_type`,`permission_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `licenses`
--

DROP TABLE IF EXISTS `licenses`;
CREATE TABLE `licenses` (
  `license_idx` int(11) NOT NULL auto_increment,
  `license_name` varchar(48) NOT NULL default '',
  `license_level` enum('project','user') NOT NULL default 'project',  
  `license_target` enum('signup','usage') NOT NULL default 'signup',  
  `created` datetime default NULL,
  `validfor` int(11) NOT NULL default '0',
  `form_text` tinytext,
  `license_text` text,
  `license_type` enum('md','text','html') NOT NULL default 'md',
  `description_text` text,
  `description_type` enum('md','text','html') NOT NULL default 'md',
  PRIMARY KEY (`license_idx`),
  UNIQUE KEY `license_name` (`license_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `linkdelays`
--

DROP TABLE IF EXISTS `linkdelays`;
CREATE TABLE `linkdelays` (
  `node_id` varchar(32) NOT NULL default '',
  `iface` varchar(8) NOT NULL default '',
  `ip` varchar(15) NOT NULL default '',
  `netmask` varchar(15) NOT NULL default '255.255.255.0',
  `type` enum('simplex','duplex') NOT NULL default 'duplex',
  `exptidx` int(11) NOT NULL default '0',
  `eid` varchar(32) default NULL,
  `pid` varchar(48) default NULL,
  `vlan` varchar(32) NOT NULL default '',
  `vnode` varchar(32) NOT NULL default '',
  `pipe` smallint(5) unsigned NOT NULL default '0',
  `delay` float(10,2) NOT NULL default '0.00',
  `bandwidth` int(10) unsigned NOT NULL default '100',
  `lossrate` float(10,8) NOT NULL default '0.00000000',
  `rpipe` smallint(5) unsigned NOT NULL default '0',
  `rdelay` float(10,2) NOT NULL default '0.00',
  `rbandwidth` int(10) unsigned NOT NULL default '100',
  `rlossrate` float(10,8) NOT NULL default '0.00000000',
  `q_limit` int(11) default '0',
  `q_maxthresh` int(11) default '0',
  `q_minthresh` int(11) default '0',
  `q_weight` float default '0',
  `q_linterm` int(11) default '0',
  `q_qinbytes` tinyint(4) default '0',
  `q_bytes` tinyint(4) default '0',
  `q_meanpsize` int(11) default '0',
  `q_wait` int(11) default '0',
  `q_setbit` int(11) default '0',
  `q_droptail` int(11) default '0',
  `q_red` tinyint(4) default '0',
  `q_gentle` tinyint(4) default '0',
  PRIMARY KEY  (`exptidx`,`node_id`,`vlan`,`vnode`),
  KEY `id` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `location_info`
--

DROP TABLE IF EXISTS `location_info`;
CREATE TABLE `location_info` (
  `node_id` varchar(32) NOT NULL default '',
  `floor` varchar(32) NOT NULL default '',
  `building` varchar(32) NOT NULL default '',
  `loc_x` int(10) unsigned NOT NULL default '0',
  `loc_y` int(10) unsigned NOT NULL default '0',
  `loc_z` float default NULL,
  `orientation` float default NULL,
  `contact` tinytext,
  `email` tinytext,
  `phone` tinytext,
  `room` varchar(32) default NULL,
  `stamp` int(10) unsigned default NULL,
  PRIMARY KEY  (`node_id`,`building`,`floor`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `log`
--

DROP TABLE IF EXISTS `log`;
CREATE TABLE `log` (
  `seq` int(10) unsigned NOT NULL default '0',
  `stamp` int(10) unsigned NOT NULL default '0',
  `session` int(10) unsigned NOT NULL default '0',
  `attempt` tinyint(1) NOT NULL default '0',
  `cleanup` tinyint(1) NOT NULL default '0',
  `invocation` int(10) unsigned NOT NULL default '0',
  `parent` int(10) unsigned NOT NULL default '0',
  `script` smallint(3) NOT NULL default '0',
  `level` tinyint(2) NOT NULL default '0',
  `sublevel` tinyint(2) NOT NULL default '0',
  `priority` smallint(3) NOT NULL default '0',
  `inferred` tinyint(1) NOT NULL default '0',
  `cause` varchar(16) NOT NULL default '',
  `type` enum('normal','entering','exiting','thecause','extra','summary','primary','secondary') default 'normal',
  `relevant` tinyint(1) NOT NULL default '0',
  `mesg` text NOT NULL,
  PRIMARY KEY  (`seq`),
  KEY `session` (`session`),
  KEY `stamp` (`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `logfiles`
--

DROP TABLE IF EXISTS `logfiles`;
CREATE TABLE `logfiles` (
  `logid` varchar(40) NOT NULL default '',
  `logidx` int(10) unsigned NOT NULL default '0',
  `filename` tinytext,
  `isopen` tinyint(4) NOT NULL default '0',
  `gid_idx` mediumint(8) unsigned NOT NULL default '0',
  `date_created` datetime default NULL,
  `public` tinyint(1) NOT NULL default '0',
  `compressed` tinyint(1) NOT NULL default '0',
  `stored` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`logid`),
  KEY `logidx` (`logidx`),
  KEY `filename` (`filename`(128)),
  KEY `isopen` (`isopen`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `logfile_metadata`
--

DROP TABLE IF EXISTS `logfile_metadata`;
CREATE TABLE `logfile_metadata` (
  `logidx` int(10) unsigned NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `metakey` tinytext,
  `metaval` tinytext,
  PRIMARY KEY  (`logidx`,`idx`),
  UNIQUE KEY `logidxkey` (`logidx`,`metakey`(128)),
  KEY `headervalue` (`metakey`(64),`metaval`(128))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `logical_wires`
--

DROP TABLE IF EXISTS `logical_wires`;
CREATE TABLE `logical_wires` (
  `type` enum('Node','Trunk','Unused') NOT NULL default 'Unused',
  `node_id1` char(32) NOT NULL default '',
  `iface1` char(128) NOT NULL default '',
  `physiface1` char(128) NOT NULL default '',
  `node_id2` char(32) NOT NULL default '',
  `iface2` char(128) NOT NULL default '',
  `physiface2` char(128) NOT NULL default '',
  PRIMARY KEY  (`node_id1`,`iface1`,`node_id2`,`iface2`),
  UNIQUE KEY `physiface`  (`node_id1`,`physiface1`,`node_id2`,`physiface2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `login`
--

DROP TABLE IF EXISTS `login`;
CREATE TABLE `login` (
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid` varchar(10) NOT NULL default '',
  `hashkey` varchar(64) NOT NULL default '',
  `hashhash` varchar(64) NOT NULL default '',
  `timeout` varchar(10) NOT NULL default '',
  `adminon` tinyint(1) NOT NULL default '0',
  `opskey` varchar(64) NOT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') NOT NULL default 'emulab',
  PRIMARY KEY  (`uid_idx`,`hashkey`),
  UNIQUE KEY `hashhash` (`uid_idx`,`hashhash`),
  UNIQUE KEY `uidkey` (`uid`,`hashkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `login_failures`
--

DROP TABLE IF EXISTS `login_failures`;
CREATE TABLE `login_failures` (
  `IP` varchar(15) NOT NULL default '1.1.1.1',
  `frozen` tinyint(3) unsigned NOT NULL default '0',
  `failcount` smallint(5) unsigned NOT NULL default '0',
  `failstamp` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `login_history`
--

DROP TABLE IF EXISTS `login_history`;
CREATE TABLE `login_history` (
  `idx` int(11) NOT NULL auto_increment,
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid` varchar(10) NOT NULL default '',
  `tstamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `IP` varchar(16) default NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  PRIMARY KEY (`idx`),
  KEY `idxstamp` (`uid_idx`,`tstamp`),
  KEY `uidstamp` (`uid`,`tstamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `loginmessage`
--

DROP TABLE IF EXISTS `loginmessage`;
CREATE TABLE `loginmessage` (
  `valid` tinyint(4) NOT NULL default '1',
  `message` tinytext NOT NULL,
  PRIMARY KEY  (`valid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `mailman_listnames`
--

DROP TABLE IF EXISTS `mailman_listnames`;
CREATE TABLE `mailman_listnames` (
  `listname` varchar(64) NOT NULL default '',
  `owner_uid` varchar(8) NOT NULL default '',
  `owner_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  PRIMARY KEY  (`listname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `mode_transitions`
--

DROP TABLE IF EXISTS `mode_transitions`;
CREATE TABLE `mode_transitions` (
  `op_mode1` varchar(20) NOT NULL default '',
  `state1` varchar(20) NOT NULL default '',
  `op_mode2` varchar(20) NOT NULL default '',
  `state2` varchar(20) NOT NULL default '',
  `label` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`op_mode1`,`state1`,`op_mode2`,`state2`),
  KEY `op_mode1` (`op_mode1`,`state1`),
  KEY `op_mode2` (`op_mode2`,`state2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `motelogfiles`
--

DROP TABLE IF EXISTS `motelogfiles`;
CREATE TABLE `motelogfiles` (
  `logfileid` varchar(45) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(32) NOT NULL default '',
  `creator` varchar(8) NOT NULL default '',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `updated` datetime default NULL,
  `description` tinytext NOT NULL,
  `classfilepath` tinytext NOT NULL,
  `specfilepath` tinytext,
  `mote_type` varchar(30) default NULL,
  PRIMARY KEY  (`logfileid`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `network_fabrics`
--

DROP TABLE IF EXISTS `network_fabrics`;
CREATE TABLE `network_fabrics` (
  `idx` int(11) NOT NULL auto_increment,
  `name` varchar(64) NOT NULL default '',
  `created` datetime default NULL,
  `ipalloc` tinyint(1) NOT NULL default '0',
  `ipalloc_onenet` tinyint(1) NOT NULL default '0',
  `ipalloc_subnet` varchar(15) NOT NULL default '',
  `ipalloc_netmask` varchar(15) NOT NULL default '',
  `ipalloc_submask` varchar(15) default NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `new_interfaces`
--

DROP TABLE IF EXISTS `new_interfaces`;
CREATE TABLE `new_interfaces` (
  `new_interface_id` int(11) NOT NULL auto_increment,
  `new_node_id` int(11) NOT NULL default '0',
  `card` int(11) NOT NULL default '0',
  `port` smallint(5) unsigned default NULL,
  `mac` varchar(12) NOT NULL default '',
  `guid` varchar(16) default NULL,
  `interface_type` varchar(15) default NULL,
  `switch_id` varchar(32) default NULL,
  `switch_card` tinyint(3) default NULL,
  `switch_port` smallint(5) unsigned default NULL,
  `cable` smallint(6) default NULL,
  `len` tinyint(4) default NULL,
  `role` tinytext,
  `IP` varchar(15) default NULL,
  PRIMARY KEY  (`new_interface_id`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

--
-- Table structure for table `new_interface_types`
--

DROP TABLE IF EXISTS `new_interface_types`;
CREATE TABLE `new_interface_types` (
  `new_interface_type_id` int(11) NOT NULL auto_increment,
  `type` varchar(30) default NULL,
  `max_speed` int(11) default NULL,
  `full_duplex` tinyint(1) default NULL,
  `manufacturer` varchar(30) default NULL,
  `model` varchar(30) default NULL,
  `ports` smallint(5) unsigned default NULL,
  `connector` varchar(30) default NULL,
  PRIMARY KEY  (`new_interface_type_id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;

--
-- Table structure for table `new_nodes`
--

DROP TABLE IF EXISTS `new_nodes`;
CREATE TABLE `new_nodes` (
  `new_node_id` int(11) NOT NULL auto_increment,
  `node_id` varchar(32) NOT NULL default '',
  `type` varchar(30) default NULL,
  `IP` varchar(15) default NULL,
  `temporary_IP` varchar(15) default NULL,
  `dmesg` text,
  `created` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `identifier` varchar(255) default NULL,
  `floor` varchar(32) default NULL,
  `building` varchar(32) default NULL,
  `loc_x` int(10) unsigned NOT NULL default '0',
  `loc_y` int(10) unsigned NOT NULL default '0',
  `contact` tinytext,
  `phone` tinytext,
  `room` varchar(32) default NULL,
  `role` varchar(32) NOT NULL default 'testnode',
  PRIMARY KEY  (`new_node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `new_wires`
--

DROP TABLE IF EXISTS `new_wires`;
CREATE TABLE `new_wires` (
  `new_wire_id` int(11) NOT NULL auto_increment,
  `cable` smallint(3) unsigned default NULL,
  `len` tinyint(3) unsigned default NULL,
  `type` enum('Node','Serial','Power','Dnard','Control','Trunk','OuterControl','Unused','Management') default NULL,
  `node_id1` char(32) default NULL,
  `card1` tinyint(3) unsigned default NULL,
  `port1` smallint(5) unsigned default NULL,
  `node_id2` char(32) default NULL,
  `card2` tinyint(3) unsigned default NULL,
  `port2` smallint(5) unsigned default NULL,
  PRIMARY KEY  (`new_wire_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `newdelays`
--

DROP TABLE IF EXISTS `newdelays`;
CREATE TABLE `newdelays` (
  `node_id` varchar(32) NOT NULL default '',
  `pipe0` smallint(5) unsigned NOT NULL default '0',
  `delay0` int(10) unsigned NOT NULL default '0',
  `bandwidth0` int(10) unsigned NOT NULL default '100',
  `lossrate0` float(10,3) NOT NULL default '0.000',
  `pipe1` smallint(5) unsigned NOT NULL default '0',
  `delay1` int(10) unsigned NOT NULL default '0',
  `bandwidth1` int(10) unsigned NOT NULL default '100',
  `lossrate1` float(10,3) NOT NULL default '0.000',
  `iface0` varchar(8) NOT NULL default '',
  `iface1` varchar(8) NOT NULL default '',
  `eid` varchar(32) default NULL,
  `pid` varchar(48) default NULL,
  `vname` varchar(32) default NULL,
  `card0` tinyint(3) unsigned default NULL,
  `card1` tinyint(3) unsigned default NULL,
  PRIMARY KEY  (`node_id`,`iface0`,`iface1`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `next_reserve`
--

DROP TABLE IF EXISTS `next_reserve`;
CREATE TABLE `next_reserve` (
  `node_id` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nextfreenode`
--

DROP TABLE IF EXISTS `nextfreenode`;
CREATE TABLE `nextfreenode` (
  `nodetype` varchar(30) NOT NULL default '',
  `nextid` int(10) unsigned NOT NULL default '1',
  `nextpri` int(10) unsigned NOT NULL default '1',
  PRIMARY KEY  (`nodetype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_activity`
--

DROP TABLE IF EXISTS `node_activity`;
CREATE TABLE `node_activity` (
  `node_id` varchar(32) NOT NULL default '',
  `last_tty_act` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_net_act` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_cpu_act` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_ext_act` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_report` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_attributes`
--

DROP TABLE IF EXISTS `node_attributes`;
CREATE TABLE `node_attributes` (
  `node_id` varchar(32) NOT NULL default '',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  `hidden` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`attrkey`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_auxtypes`
--

DROP TABLE IF EXISTS `node_auxtypes`;
CREATE TABLE `node_auxtypes` (
  `node_id` varchar(32) NOT NULL default '',
  `type` varchar(30) NOT NULL default '',
  `count` int(11) default '1',
  PRIMARY KEY  (`node_id`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_bootlogs`
--

DROP TABLE IF EXISTS `node_bootlogs`;
CREATE TABLE `node_bootlogs` (
  `node_id` varchar(32) NOT NULL default '',
  `bootlog` text,
  `bootlog_timestamp` datetime default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_features`
--

DROP TABLE IF EXISTS `node_features`;
CREATE TABLE `node_features` (
  `node_id` varchar(32) NOT NULL default '',
  `feature` varchar(30) NOT NULL default '',
  `weight` float NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`feature`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_history`
--

DROP TABLE IF EXISTS `node_history`;
CREATE TABLE `node_history` (
  `history_id` int(10) unsigned NOT NULL auto_increment,
  `node_id` varchar(32) NOT NULL default '',
  `op` enum('alloc','free','move','create','destroy') NOT NULL default 'alloc',
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `exptidx` int(10) unsigned default NULL,
  `stamp` int(10) unsigned default NULL,
  `cnet_IP` varchar(15) default NULL,
  `cnet_mac` varchar(12) default NULL,
  `phys_nodeid` varchar(32) default NULL,
  PRIMARY KEY  (`history_id`),
  KEY `node_id` (`node_id`,`history_id`),
  KEY `exptidx` (`exptidx`),
  KEY `stamp` (`stamp`),
  KEY `cnet_IP` (`cnet_IP`),
  KEY `nodestamp` (`node_id`,`stamp`),
  KEY `ipstamp` (`cnet_IP`,`stamp`),
  KEY `hid_stamp` (`history_id`,`stamp`),
  KEY `cnet_mac` (`cnet_mac`),
  KEY `macstamp` (`cnet_mac`,`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_hostkeys`
--

DROP TABLE IF EXISTS `node_hostkeys`;
CREATE TABLE `node_hostkeys` (
  `node_id` varchar(32) NOT NULL default '',
  `sshrsa_v1` mediumtext,
  `sshrsa_v2` mediumtext,
  `sshdsa_v2` mediumtext,
  `sfshostid` varchar(128) default NULL,
  `tpmblob` mediumtext,
  `tpmx509` mediumtext,
  `tpmidentity` mediumtext,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_idlestats`
--

DROP TABLE IF EXISTS `node_idlestats`;
CREATE TABLE `node_idlestats` (
  `node_id` varchar(32) NOT NULL default '',
  `tstamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `last_tty` datetime NOT NULL default '0000-00-00 00:00:00',
  `load_1min` float NOT NULL default '0',
  `load_5min` float NOT NULL default '0',
  `load_15min` float NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`tstamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_licensekeys`
--

DROP TABLE IF EXISTS `node_licensekeys`;
CREATE TABLE `node_licensekeys` (
  `node_id` varchar(32) NOT NULL default '',
  `keytype` varchar(16) NOT NULL default '',
  `keydata` mediumtext,
  PRIMARY KEY  (`node_id`,`keytype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_reservations`
--

DROP TABLE IF EXISTS `node_reservations`;
CREATE TABLE `node_reservations` (
  `node_id` varchar(32) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `reservation_name` varchar(48) NOT NULL default 'default',
  PRIMARY KEY (`node_id`,`pid_idx`,`reservation_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_rusage`
--

DROP TABLE IF EXISTS `node_rusage`;
CREATE TABLE `node_rusage` (
  `node_id` varchar(32) NOT NULL default '',
  `load_1min` float NOT NULL default '0',
  `load_5min` float NOT NULL default '0',
  `load_15min` float NOT NULL default '0',
  `disk_used` float NOT NULL default '0',
  `status_timestamp` datetime default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_startloc`
--

DROP TABLE IF EXISTS `node_startloc`;
CREATE TABLE `node_startloc` (
  `node_id` varchar(32) NOT NULL default '',
  `building` varchar(32) NOT NULL default '',
  `floor` varchar(32) NOT NULL default '',
  `loc_x` float NOT NULL default '0',
  `loc_y` float NOT NULL default '0',
  `orientation` float NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`building`,`floor`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_status`
--

DROP TABLE IF EXISTS `node_status`;
CREATE TABLE `node_status` (
  `node_id` varchar(32) NOT NULL default '',
  `status` enum('up','possibly down','down','unpingable') default NULL,
  `status_timestamp` datetime default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_type_attributes`
--

DROP TABLE IF EXISTS `node_type_attributes`;
CREATE TABLE `node_type_attributes` (
  `type` varchar(30) NOT NULL default '',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') default 'string',
  PRIMARY KEY  (`type`,`attrkey`),
  KEY `node_id` (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_type_features`
--

DROP TABLE IF EXISTS `node_type_features`;
CREATE TABLE `node_type_features` (
  `type` varchar(30) NOT NULL default '',
  `feature` varchar(30) NOT NULL default '',
  `weight` float NOT NULL default '0',
  PRIMARY KEY  (`type`,`feature`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `node_type_hardware`
--

DROP TABLE IF EXISTS `node_type_hardware`;
CREATE TABLE `node_type_hardware` (
  `type` varchar(30) NOT NULL default '',
  `updated` datetime default NULL,
  `uname` text,
  `rawjson` mediumtext,  
  PRIMARY KEY  (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_type_hardware_paths`
--

DROP TABLE IF EXISTS `node_type_hardware_paths`;
CREATE TABLE `node_type_hardware_paths` (
  `type` varchar(30) NOT NULL default '',
  `path` varchar(255) NOT NULL default '',
  `value` text,
  PRIMARY KEY  (`type`,`path`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_type_hardware`
--

DROP TABLE IF EXISTS `node_hardware`;
CREATE TABLE `node_hardware` (
  `node_id` varchar(30) NOT NULL default '',
  `updated` datetime default NULL,
  `uname` text,
  `rawjson` mediumtext,  
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_type_hardware_paths`
--

DROP TABLE IF EXISTS `node_hardware_paths`;
CREATE TABLE `node_hardware_paths` (
  `node_id` varchar(30) NOT NULL default '',
  `path` varchar(255) NOT NULL default '',
  `value` text,
  PRIMARY KEY  (`node_id`,`path`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_types`
--

DROP TABLE IF EXISTS `node_types`;
CREATE TABLE `node_types` (
  `class` varchar(30) default NULL,
  `type` varchar(30) NOT NULL default '',
  `architecture` varchar(30) default NULL,
  `modelnetcore_osid` varchar(35) default NULL,
  `modelnetedge_osid` varchar(35) default NULL,
  `isvirtnode` tinyint(4) NOT NULL default '0',
  `ismodelnet` tinyint(1) NOT NULL default '0',
  `isjailed` tinyint(1) NOT NULL default '0',
  `isdynamic` tinyint(1) NOT NULL default '0',
  `isremotenode` tinyint(4) NOT NULL default '0',
  `issubnode` tinyint(4) NOT NULL default '0',
  `isplabdslice` tinyint(4) NOT NULL default '0',
  `isplabphysnode` tinyint(4) NOT NULL default '0',
  `issimnode` tinyint(4) NOT NULL default '0',
  `isgeninode` tinyint(4) NOT NULL default '0',
  `isfednode` tinyint(4) NOT NULL default '0',
  `isswitch` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_types_auxtypes`
--

DROP TABLE IF EXISTS `node_types_auxtypes`;
CREATE TABLE `node_types_auxtypes` (
  `auxtype` varchar(30) NOT NULL default '',
  `type` varchar(30) NOT NULL default '',
  PRIMARY KEY  (`auxtype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `node_utilization`
--

DROP TABLE IF EXISTS `node_utilization`;
CREATE TABLE `node_utilization` (
  `node_id` varchar(32) NOT NULL default '',
  `allocated` int(10) unsigned NOT NULL default '0',
  `down` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nodeipportnum`
--

DROP TABLE IF EXISTS `nodeipportnum`;
CREATE TABLE `nodeipportnum` (
  `node_id` varchar(32) NOT NULL default '',
  `port` smallint(5) unsigned NOT NULL default '11000',
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nodelog`
--

DROP TABLE IF EXISTS `nodelog`;
CREATE TABLE `nodelog` (
  `node_id` varchar(32) NOT NULL default '',
  `log_id` int(10) unsigned NOT NULL auto_increment,
  `type` enum('misc') NOT NULL default 'misc',
  `reporting_uid` varchar(8) NOT NULL default '',
  `reporting_idx` mediumint(8) unsigned NOT NULL default '0',
  `entry` tinytext NOT NULL,
  `reported` datetime default NULL,
  PRIMARY KEY  (`node_id`,`log_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nodes`
--

DROP TABLE IF EXISTS `nodes`;
CREATE TABLE `nodes` (
  `node_id` varchar(32) NOT NULL default '',
  `type` varchar(30) NOT NULL default '',
  `phys_nodeid` varchar(32) default NULL,
  `role` enum('testnode','virtnode','ctrlnode','testswitch','ctrlswitch','powerctrl','widearea_switch','unused') NOT NULL default 'unused',
  `inception` datetime default NULL,
  `def_boot_osid` int(8) unsigned default NULL,
  `def_boot_osid_vers` int(8) unsigned default '0',
  `def_boot_path` text,
  `def_boot_cmd_line` text,
  `temp_boot_osid` int(8) unsigned default NULL,
  `temp_boot_osid_vers` int(8) unsigned default '0',
  `next_boot_osid` int(8) unsigned default NULL,
  `next_boot_osid_vers` int(8) unsigned default '0',
  `next_boot_path` text,
  `next_boot_cmd_line` text,
  `pxe_boot_path` text,
  `next_pxe_boot_path` text,
  `rpms` text,
  `deltas` text,
  `tarballs` text,
  `loadlist` text,
  `startupcmd` tinytext,
  `startstatus` tinytext,
  `ready` tinyint(4) unsigned NOT NULL default '0',
  `priority` int(11) NOT NULL default '-1',
  `bootstatus` enum('okay','failed','unknown') default 'unknown',
  `status` enum('up','possibly down','down','unpingable') default NULL,
  `status_timestamp` datetime default NULL,
  `failureaction` enum('fatal','nonfatal','ignore') NOT NULL default 'fatal',
  `routertype` enum('none','ospf','static','manual','static-ddijk','static-old') NOT NULL default 'none',
  `eventstate` varchar(20) default NULL,
  `state_timestamp` int(10) unsigned default NULL,
  `op_mode` varchar(20) default NULL,
  `op_mode_timestamp` int(10) unsigned default NULL,
  `allocstate` varchar(20) default NULL,
  `allocstate_timestamp` int(10) unsigned default NULL,
  `update_accounts` smallint(6) default '0',
  `next_op_mode` varchar(20) NOT NULL default '',
  `ipodhash` varchar(64) default NULL,
  `osid` int(8) unsigned default NULL,
  `ntpdrift` float default NULL,
  `ipport_low` int(11) NOT NULL default '11000',
  `ipport_next` int(11) NOT NULL default '11000',
  `ipport_high` int(11) NOT NULL default '20000',
  `sshdport` int(11) NOT NULL default '11000',
  `jailflag` tinyint(3) unsigned NOT NULL default '0',
  `jailip` varchar(15) default NULL,
  `jailipmask` varchar(15) default NULL,
  `sfshostid` varchar(128) default NULL,
  `stated_tag` varchar(32) default NULL,
  `rtabid` smallint(5) unsigned NOT NULL default '0',
  `cd_version` varchar(32) default NULL,
  `battery_voltage` float default NULL,
  `battery_percentage` float default NULL,
  `battery_timestamp` int(10) unsigned default NULL,
  `boot_errno` int(11) NOT NULL default '0',
  `destination_x` float default NULL,
  `destination_y` float default NULL,
  `destination_orientation` float default NULL,
  `reserved_pid` varchar(48) default NULL,
  `reservation_name` varchar(48) default NULL,
  `reservable` tinyint(1) NOT NULL default '0',
  `uuid` varchar(40) NOT NULL default '',
  `reserved_memory` int(10) unsigned default '0',
  `nonfsmounts` tinyint(1) NOT NULL default '0',
  `nfsmounts` enum('emulabdefault','genidefault','all','none') default NULL,
  `taint_states` set('useronly','blackbox','dangerous','mustreload') default NULL,
  PRIMARY KEY  (`node_id`),
  KEY `phys_nodeid` (`phys_nodeid`),
  KEY `node_id` (`node_id`,`phys_nodeid`),
  KEY `role` (`role`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nodetypeXpid_permissions`
--

DROP TABLE IF EXISTS `nodetypeXpid_permissions`;
CREATE TABLE `nodetypeXpid_permissions` (
  `type` varchar(30) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`type`,`pid_idx`),
  UNIQUE KEY `typepid` (`type`,`pid`),
  KEY `pid` (`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nodeuidlastlogin`
--

DROP TABLE IF EXISTS `nodeuidlastlogin`;
CREATE TABLE `nodeuidlastlogin` (
  `node_id` varchar(32) NOT NULL default '',
  `uid` varchar(10) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `date` date default NULL,
  `time` time default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nologins`
--

DROP TABLE IF EXISTS `nologins`;
CREATE TABLE `nologins` (
  `nologins` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`nologins`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nonces`
--

DROP TABLE IF EXISTS `nonces`;
CREATE TABLE `nonces` (
  `node_id` varchar(32) NOT NULL,
  `purpose` varchar(64) NOT NULL,
  `nonce` mediumtext,
  `expires` int(10) NOT NULL,
  PRIMARY KEY  (`node_id`,`purpose`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nonlocal_user_accounts`
--

DROP TABLE IF EXISTS `nonlocal_user_accounts`;
CREATE TABLE `nonlocal_user_accounts` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid_uuid` varchar(40) NOT NULL default '',
  `unix_uid` int(10) unsigned NOT NULL auto_increment,
  `created` datetime default NULL,
  `updated` datetime default NULL,
  `privs` enum('user','local_root') default 'local_root',
  `shell` enum('tcsh','bash','sh') default 'bash',
  `urn` tinytext,
  `name` tinytext,
  `email` tinytext,
  `exptidx` int(11) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`unix_uid`),
  KEY `uid` (`uid`),
  KEY `urn` (`urn`(255)),
  KEY `uid_uuid` (`uid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nonlocal_user_bindings`
--

DROP TABLE IF EXISTS `nonlocal_user_bindings`;
CREATE TABLE `nonlocal_user_bindings` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `exptidx` int(11) NOT NULL default '0',
  PRIMARY KEY  (`uid_idx`,`exptidx`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nonlocal_user_pubkeys`
--

DROP TABLE IF EXISTS `nonlocal_user_pubkeys`;
CREATE TABLE `nonlocal_user_pubkeys` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `pubkey` text,
  `stamp` datetime default NULL,
  `comment` varchar(128) NOT NULL default '',
  PRIMARY KEY  (`uid_idx`,`idx`),
  KEY `uid` (`uid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nonlocal_users`
--

DROP TABLE IF EXISTS `nonlocal_users`;
CREATE TABLE `nonlocal_users` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid_uuid` varchar(40) NOT NULL default '',
  `created` datetime default NULL,
  `name` tinytext,
  `email` tinytext,
  PRIMARY KEY  (`uid_idx`),
  UNIQUE KEY `uid_uuid` (`uid_uuid`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nseconfigs`
--

DROP TABLE IF EXISTS `nseconfigs`;
CREATE TABLE `nseconfigs` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `nseconfig` mediumtext,
  PRIMARY KEY  (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `nsfiles`
--

DROP TABLE IF EXISTS `nsfiles`;
CREATE TABLE `nsfiles` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `nsfile` mediumtext,
  PRIMARY KEY  (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `ntpinfo`
--

DROP TABLE IF EXISTS `ntpinfo`;
CREATE TABLE `ntpinfo` (
  `node_id` varchar(32) NOT NULL default '',
  `IP` varchar(64) NOT NULL default '',
  `type` enum('server','peer') NOT NULL default 'peer',
  PRIMARY KEY  (`node_id`,`IP`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `obstacles`
--

DROP TABLE IF EXISTS `obstacles`;
CREATE TABLE `obstacles` (
  `obstacle_id` int(11) unsigned NOT NULL auto_increment,
  `floor` varchar(32) default NULL,
  `building` varchar(32) default NULL,
  `x1` int(10) unsigned NOT NULL default '0',
  `y1` int(10) unsigned NOT NULL default '0',
  `z1` int(10) unsigned NOT NULL default '0',
  `x2` int(10) unsigned NOT NULL default '0',
  `y2` int(10) unsigned NOT NULL default '0',
  `z2` int(10) unsigned NOT NULL default '0',
  `description` tinytext,
  `label` tinytext,
  `draw` tinyint(1) NOT NULL default '0',
  `no_exclusion` tinyint(1) NOT NULL default '0',
  `no_tooltip` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`obstacle_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `os_boot_cmd`
--

DROP TABLE IF EXISTS `os_boot_cmd`;
CREATE TABLE `os_boot_cmd` (
  `OS` enum('Unknown','Linux','Fedora','FreeBSD','NetBSD','OSKit','Windows','TinyOS','Other') NOT NULL default 'Unknown',
  `version` varchar(12) NOT NULL default '',
  `role` enum('default','delay','linkdelay','vnodehost') NOT NULL default 'default',
  `boot_cmd_line` text,
  PRIMARY KEY  (`OS`,`version`,`role`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `os_info_versions`
--

DROP TABLE IF EXISTS `os_info_versions`;
CREATE TABLE `os_info_versions` (
  `osname` varchar(30) NOT NULL default '',
  `vers` int(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `osid` int(8) unsigned NOT NULL default '0',
  `parent_osid` int(8) unsigned default NULL,
  `parent_vers` int(8) unsigned default NULL,
  `uuid` varchar(40) NOT NULL default '',
  `old_osid` varchar(35) NOT NULL default '',
  `creator` varchar(8) default NULL,
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `deleted` datetime default NULL,
  `description` tinytext NOT NULL,
  `OS` enum('Unknown','Linux','Fedora','FreeBSD','NetBSD','OSKit','Windows','TinyOS','Other') default 'Unknown',
  `version` varchar(12) default '',
  `path` tinytext,
  `magic` tinytext,
  `machinetype` varchar(30) NOT NULL default '',
  `osfeatures` set('ping','ssh','ipod','isup','veths','veth-ne','veth-en','mlinks','linktest','linkdelays','vlans','suboses','ontrustedboot','no-usb-boot','egre','loc-bstore','rem-bstore','openvz-host','xen-host','docker-host') default NULL,
  `ezid` tinyint(4) NOT NULL default '0',
  `shared` tinyint(4) NOT NULL default '0',
  `mustclean` tinyint(4) NOT NULL default '1',
  `op_mode` varchar(20) NOT NULL default 'MINIMAL',
  `nextosid` int(8) unsigned default NULL,
  `def_parentosid` int(8) unsigned default NULL,
  `old_nextosid` varchar(35) NOT NULL default '',
  `max_concurrent` int(11) default NULL,
  `mfs` tinyint(4) NOT NULL default '0',
  `reboot_waittime` int(10) unsigned default NULL,
  `protogeni_export` tinyint(1) NOT NULL default '0',
  `taint_states` set('useronly','blackbox','dangerous','mustreload') default NULL,
  PRIMARY KEY  (`osid`,`vers`),
  KEY `pid` (`pid`,`osname`,`vers`),
  KEY `OS` (`OS`),
  KEY `path` (`path`(255)),
  KEY `old_osid` (`old_osid`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `os_info`
--

DROP TABLE IF EXISTS `os_info`;
CREATE TABLE `os_info` (
  `osname` varchar(30) NOT NULL default '',
  `version` int(8) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `osid` int(8) unsigned NOT NULL default '0',
  `uuid` varchar(40) NOT NULL default '',
  PRIMARY KEY  (`osid`),
  UNIQUE KEY `pid` (`pid`,`osname`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `os_submap`
--

DROP TABLE IF EXISTS `os_submap`;
CREATE TABLE `os_submap` (
  `osid` int(8) unsigned NOT NULL default '0',
  `parent_osid` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`osid`,`parent_osid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `osconfig_files`
--

DROP TABLE IF EXISTS `osconfig_files`;
CREATE TABLE `osconfig_files` (
  `file_idx` int(10) unsigned NOT NULL auto_increment,
  `type` enum('script','scriptdep','archive','file') NOT NULL default 'file',
  `path` varchar(255) NOT NULL default '',
  `dest` varchar(255) NOT NULL default '',
  `prio` int(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`file_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `osconfig_targets`
--

DROP TABLE IF EXISTS `osconfig_targets`;
CREATE TABLE `osconfig_targets` (
  `constraint_idx` int(10) unsigned NOT NULL auto_increment,
  `target_apply` enum('premfs','postload') NOT NULL default 'postload',
  `target_file_idx` int(10) unsigned NOT NULL default '0',
  `constraint_name` varchar(16) NOT NULL default '',
  `constraint_value` varchar(128) NOT NULL default '',
  PRIMARY KEY  (`constraint_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `osid_map`
--

DROP TABLE IF EXISTS `osid_map`;
CREATE TABLE `osid_map` (
  `osid` int(8) unsigned NOT NULL default '0',
  `btime` datetime NOT NULL default '1000-01-01 00:00:00',
  `etime` datetime NOT NULL default '9999-12-31 23:59:59',
  `nextosid` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`osid`,`btime`,`etime`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `osidtoimageid`
--

DROP TABLE IF EXISTS `osidtoimageid`;
CREATE TABLE `osidtoimageid` (
  `osid` int(8) unsigned NOT NULL default '0',
  `type` varchar(30) NOT NULL default '',
  `imageid` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`osid`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `outlets`
--

DROP TABLE IF EXISTS `outlets`;
CREATE TABLE `outlets` (
  `node_id` varchar(32) NOT NULL default '',
  `power_id` varchar(32) NOT NULL default '',
  `outlet` tinyint(1) unsigned NOT NULL default '0',
  `last_power` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `outlets_remoteauth`
--

DROP TABLE IF EXISTS `outlets_remoteauth`;
CREATE TABLE `outlets_remoteauth` (
  `node_id` varchar(32) NOT NULL,
  `key_type` varchar(64) NOT NULL,
  `key_role` varchar(64) NOT NULL default '',
  `key_uid` varchar(64) NOT NULL default '',
  `mykey` text NOT NULL,
  `key_privlvl` enum('CALLBACK','USER','OPERATOR','ADMINISTRATOR','OTHER') DEFAULT NULL,
  PRIMARY KEY  (`node_id`,`key_type`,`key_role`,`key_uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `partitions`
--

DROP TABLE IF EXISTS `partitions`;
CREATE TABLE `partitions` (
  `node_id` varchar(32) NOT NULL default '',
  `partition` tinyint(4) NOT NULL default '0',
  `osid` int(8) unsigned default NULL,
  `osid_vers` int(8) unsigned default NULL,
  `imageid` int(8) unsigned default NULL,
  `imageid_version` int(8) unsigned default NULL,
  `imagepid` varchar(48) NOT NULL default '',
  PRIMARY KEY  (`node_id`,`partition`),
  KEY `osid` (`osid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_attributes`
--

DROP TABLE IF EXISTS `plab_attributes`;
CREATE TABLE `plab_attributes` (
  `attr_idx` int(11) unsigned NOT NULL auto_increment,
  `plc_idx` int(10) unsigned default NULL,
  `slicename` varchar(64) default NULL,
  `nodegroup_idx` int(10) unsigned default NULL,
  `node_id` varchar(32) default NULL,
  `attrkey` varchar(64) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY  (`attr_idx`),
  UNIQUE KEY `realattrkey` (`plc_idx`,`slicename`,`nodegroup_idx`,`node_id`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_comondata`
--

DROP TABLE IF EXISTS `plab_comondata`;
CREATE TABLE `plab_comondata` (
  `node_id` varchar(32) NOT NULL,
  `resptime` float default NULL,
  `uptime` float default NULL,
  `lastcotop` float default NULL,
  `date` double default NULL,
  `drift` float default NULL,
  `cpuspeed` float default NULL,
  `busycpu` float default NULL,
  `syscpu` float default NULL,
  `freecpu` float default NULL,
  `1minload` float default NULL,
  `5minload` float default NULL,
  `numslices` int(11) default NULL,
  `liveslices` int(11) default NULL,
  `connmax` float default NULL,
  `connavg` float default NULL,
  `timermax` float default NULL,
  `timeravg` float default NULL,
  `memsize` float default NULL,
  `memact` float default NULL,
  `freemem` float default NULL,
  `swapin` int(11) default NULL,
  `swapout` int(11) default NULL,
  `diskin` int(11) default NULL,
  `diskout` int(11) default NULL,
  `gbfree` float default NULL,
  `swapused` float default NULL,
  `bwlimit` float default NULL,
  `txrate` float default NULL,
  `rxrate` float default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_mapping`
--

DROP TABLE IF EXISTS `plab_mapping`;
CREATE TABLE `plab_mapping` (
  `node_id` varchar(32) NOT NULL default '',
  `plab_id` varchar(32) NOT NULL default '',
  `hostname` varchar(255) NOT NULL default '',
  `IP` varchar(15) NOT NULL default '',
  `mac` varchar(17) NOT NULL default '',
  `create_time` datetime default NULL,
  `deleted` tinyint(1) NOT NULL default '0',
  `plc_idx` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_nodegroup_members`
--

DROP TABLE IF EXISTS `plab_nodegroup_members`;
CREATE TABLE `plab_nodegroup_members` (
  `plc_idx` int(10) unsigned NOT NULL default '0',
  `nodegroup_idx` int(10) unsigned NOT NULL default '0',
  `node_id` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`plc_idx`,`nodegroup_idx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_nodegroups`
--

DROP TABLE IF EXISTS `plab_nodegroups`;
CREATE TABLE `plab_nodegroups` (
  `plc_idx` int(10) unsigned NOT NULL default '0',
  `nodegroup_idx` int(10) unsigned NOT NULL default '0',
  `name` varchar(64) NOT NULL default '',
  `description` text NOT NULL,
  PRIMARY KEY  (`plc_idx`,`nodegroup_idx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_nodehist`
--

DROP TABLE IF EXISTS `plab_nodehist`;
CREATE TABLE `plab_nodehist` (
  `idx` mediumint(10) unsigned NOT NULL auto_increment,
  `node_id` varchar(32) NOT NULL,
  `phys_node_id` varchar(32) NOT NULL,
  `timestamp` datetime NOT NULL,
  `component` varchar(64) NOT NULL,
  `operation` varchar(64) NOT NULL,
  `status` enum('success','failure','unknown') NOT NULL default 'unknown',
  `msg` text,
  PRIMARY KEY  (`idx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_nodehiststats`
--

DROP TABLE IF EXISTS `plab_nodehiststats`;
CREATE TABLE `plab_nodehiststats` (
  `node_id` varchar(32) NOT NULL,
  `unavail` float default NULL,
  `jitdeduct` float default NULL,
  `succtime` int(11) default NULL,
  `succnum` int(11) default NULL,
  `succjitnum` int(11) default NULL,
  `failtime` int(11) default NULL,
  `failnum` int(11) default NULL,
  `failjitnum` int(11) default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_objmap`
--

DROP TABLE IF EXISTS `plab_objmap`;
CREATE TABLE `plab_objmap` (
  `plc_idx` int(10) unsigned NOT NULL,
  `objtype` varchar(32) NOT NULL,
  `elab_id` varchar(64) NOT NULL,
  `plab_id` varchar(255) NOT NULL,
  `plab_name` tinytext NOT NULL,
  PRIMARY KEY  (`plc_idx`,`objtype`,`elab_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_plc_attributes`
--

DROP TABLE IF EXISTS `plab_plc_attributes`;
CREATE TABLE `plab_plc_attributes` (
  `plc_idx` int(10) unsigned NOT NULL default '0',
  `attrkey` varchar(64) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY  (`plc_idx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_plc_info`
--

DROP TABLE IF EXISTS `plab_plc_info`;
CREATE TABLE `plab_plc_info` (
  `plc_idx` int(10) unsigned NOT NULL auto_increment,
  `plc_name` varchar(64) NOT NULL default '',
  `api_url` varchar(255) NOT NULL default '',
  `def_slice_prefix` varchar(32) NOT NULL default '',
  `nodename_prefix` varchar(30) NOT NULL default '',
  `node_type` varchar(30) NOT NULL default '',
  `svc_slice_name` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`plc_idx`),
  KEY `plc_name` (`plc_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_site_mapping`
--

DROP TABLE IF EXISTS `plab_site_mapping`;
CREATE TABLE `plab_site_mapping` (
  `site_name` varchar(255) NOT NULL default '',
  `site_idx` smallint(5) unsigned NOT NULL auto_increment,
  `node_id` varchar(32) NOT NULL default '',
  `node_idx` tinyint(3) unsigned NOT NULL default '0',
  `plc_idx` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`site_name`,`site_idx`,`node_idx`,`plc_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_slice_attributes`
--

DROP TABLE IF EXISTS `plab_slice_attributes`;
CREATE TABLE `plab_slice_attributes` (
  `plc_idx` int(10) unsigned NOT NULL default '0',
  `slicename` varchar(64) NOT NULL default '',
  `attrkey` varchar(64) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY  (`plc_idx`,`slicename`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_slice_nodes`
--

DROP TABLE IF EXISTS `plab_slice_nodes`;
CREATE TABLE `plab_slice_nodes` (
  `slicename` varchar(64) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `leaseend` datetime default NULL,
  `nodemeta` text,
  `plc_idx` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`slicename`,`plc_idx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `plab_slices`
--

DROP TABLE IF EXISTS `plab_slices`;
CREATE TABLE `plab_slices` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `slicename` varchar(64) NOT NULL default '',
  `slicemeta` text,
  `slicemeta_legacy` text,
  `leaseend` datetime default NULL,
  `admin` tinyint(1) default '0',
  `plc_idx` int(10) unsigned NOT NULL default '0',
  `is_created` tinyint(1) default '0',
  `is_configured` tinyint(1) default '0',
  `no_cleanup` tinyint(1) default '0',
  `no_destroy` tinyint(1) default '0',
  PRIMARY KEY  (`exptidx`,`slicename`,`plc_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `port_counters`
--

DROP TABLE IF EXISTS `port_counters`;
CREATE TABLE `port_counters` (
  `node_id` char(32) NOT NULL default '',
  `card_saved` tinyint(3) unsigned NOT NULL default '0',
  `port_saved` smallint(5) unsigned NOT NULL default '0',
  `iface` text NOT NULL,
  `ifInOctets` int(10) unsigned NOT NULL default '0',
  `ifInUcastPkts` int(10) unsigned NOT NULL default '0',
  `ifInNUcastPkts` int(10) unsigned NOT NULL default '0',
  `ifInDiscards` int(10) unsigned NOT NULL default '0',
  `ifInErrors` int(10) unsigned NOT NULL default '0',
  `ifInUnknownProtos` int(10) unsigned NOT NULL default '0',
  `ifOutOctets` int(10) unsigned NOT NULL default '0',
  `ifOutUcastPkts` int(10) unsigned NOT NULL default '0',
  `ifOutNUcastPkts` int(10) unsigned NOT NULL default '0',
  `ifOutDiscards` int(10) unsigned NOT NULL default '0',
  `ifOutErrors` int(10) unsigned NOT NULL default '0',
  `ifOutQLen` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`iface`(128))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `port_registration`
--

DROP TABLE IF EXISTS `port_registration`;
CREATE TABLE `port_registration` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `service` varchar(64) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `port` int(11) unsigned NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`service`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`service`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `portmap`
--

DROP TABLE IF EXISTS `portmap`;
CREATE TABLE `portmap` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `vnode` varchar(32) NOT NULL default '',
  `vport` tinyint(4) NOT NULL default '0',
  `pport` varchar(32) NOT NULL default ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `priorities`
--

DROP TABLE IF EXISTS `priorities`;
CREATE TABLE `priorities` (
  `priority` smallint(3) NOT NULL default '0',
  `priority_name` varchar(8) NOT NULL default '',
  PRIMARY KEY  (`priority`),
  UNIQUE KEY `name` (`priority_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `proj_memb`
--

DROP TABLE IF EXISTS `proj_memb`;
CREATE TABLE `proj_memb` (
  `uid` varchar(8) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `trust` enum('none','user','local_root','group_root') default NULL,
  `date_applied` date default NULL,
  `date_approved` date default NULL,
  PRIMARY KEY  (`uid`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `project_leases`
--

DROP TABLE IF EXISTS `project_leases`;
CREATE TABLE `project_leases` (
  `lease_idx` int(10) unsigned NOT NULL default '0',
  `lease_id` varchar(32) NOT NULL default '',
  `uuid` varchar(40) NOT NULL default '',
  `owner_uid` varchar(8) NOT NULL default '',
  `owner_urn` varchar(128) default NULL,
  `pid` varchar(48) NOT NULL default '',
  `gid` varchar(48) NOT NULL default '',
  `type` enum('stdataset','ltdataset','unknown') NOT NULL default 'unknown',
  `inception` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `lease_end` timestamp NOT NULL default '2037-01-19 03:14:07',
  `last_used` timestamp NOT NULL default '0000-00-00 00:00:00',
  `last_checked` timestamp NOT NULL default '0000-00-00 00:00:00',
  `state` enum('valid','unapproved','grace','locked','expired','failed') NOT NULL default 'unapproved',
  `statestamp` timestamp NOT NULL default '0000-00-00 00:00:00',
  `renewals` int(10) unsigned NOT NULL default '0',
  `locked` datetime default NULL, 
  `locker_pid` int(11) default '0',
  PRIMARY KEY (`lease_idx`),
  UNIQUE KEY `plid` (`pid`,`lease_id`),
  UNIQUE KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `project_licenses`
--

DROP TABLE IF EXISTS `project_licenses`;
CREATE TABLE `project_licenses` (
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `license_idx` int(11) NOT NULL default '0',
  `accepted` datetime default NULL,
  `expiration` datetime default NULL,
  PRIMARY KEY (`pid_idx`,`license_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `project_quotas`
--

DROP TABLE IF EXISTS `project_quotas`;
CREATE TABLE `project_quotas` (
  `quota_idx` int(10) unsigned NOT NULL,
  `quota_id` varchar(32) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `type` enum('ltdataset','unknown') NOT NULL default 'unknown',
  `size` int(10) unsigned NOT NULL default '0',
  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `locked` datetime default NULL, 
  `locker_pid` int(11) default '0',
  `notes` tinytext,
  PRIMARY KEY (`quota_idx`),
  UNIQUE KEY `qpid` (`pid`,`quota_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `project_reservations`
--

DROP TABLE IF EXISTS `project_reservations`;
CREATE TABLE `project_reservations` (
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `name` varchar(48) NOT NULL default 'default',
  `priority` smallint(5) NOT NULL default '0',
  `count` smallint(5) NOT NULL default '0',
  `types` varchar(128) default NULL,
  `creator` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `start` datetime default NULL,
  `end` datetime default NULL,
  `active` tinyint(1) NOT NULL default '0',
  `terminal` tinyint(1) NOT NULL default '0',
  `approved` datetime DEFAULT NULL,
  `approver` varchar(8) DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `uuid` varchar(40) NOT NULL default '',
  `notes` mediumtext,
  PRIMARY KEY (`pid_idx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `project_stats`
--

DROP TABLE IF EXISTS `project_stats`;
CREATE TABLE `project_stats` (
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `exptstart_count` int(11) unsigned default '0',
  `exptstart_last` datetime default NULL,
  `exptpreload_count` int(11) unsigned default '0',
  `exptpreload_last` datetime default NULL,
  `exptswapin_count` int(11) unsigned default '0',
  `exptswapin_last` datetime default NULL,
  `exptswapout_count` int(11) unsigned default '0',
  `exptswapout_last` datetime default NULL,
  `exptswapmod_count` int(11) unsigned default '0',
  `exptswapmod_last` datetime default NULL,
  `last_activity` datetime default NULL,
  `allexpt_duration` double(14,0) unsigned default '0',
  `allexpt_vnodes` int(11) unsigned default '0',
  `allexpt_vnode_duration` double(14,0) unsigned default '0',
  `allexpt_pnodes` int(11) unsigned default '0',
  `allexpt_pnode_duration` double(14,0) unsigned default '0',
  PRIMARY KEY  (`pid_idx`),
  UNIQUE KEY `pid` (`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `projects`
--

DROP TABLE IF EXISTS `projects`;
CREATE TABLE `projects` (
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `expires` date default NULL,
  `nagged` datetime default NULL,
  `name` tinytext,
  `URL` tinytext,
  `funders` tinytext,
  `addr` tinytext,
  `head_uid` varchar(8) NOT NULL default '',
  `head_idx` mediumint(8) unsigned NOT NULL default '0',
  `num_members` int(11) default '0',
  `num_pcs` int(11) default '0',
  `num_sharks` int(11) default '0',
  `num_pcplab` int(11) default '0',
  `num_ron` int(11) default '0',
  `why` text,
  `control_node` varchar(10) default NULL,
  `unix_gid` smallint(5) unsigned NOT NULL auto_increment,
  `approved` tinyint(4) default '0',
  `hidden` tinyint(1) default '0',
  `disabled` tinyint(1) default '0',
  `inactive` tinyint(4) default '0',
  `forClass` tinyint(1) default '0',
  `date_inactive` datetime default NULL,
  `public` tinyint(4) NOT NULL default '0',
  `public_whynot` tinytext,
  `expt_count` mediumint(8) unsigned default '0',
  `expt_last` date default NULL,
  `pcremote_ok` set('pcplabphys','pcron','pcwa') default NULL,
  `default_user_interface` enum('emulab','plab') NOT NULL default 'emulab',
  `linked_to_us` tinyint(4) NOT NULL default '0',
  `cvsrepo_public` tinyint(1) NOT NULL default '0',
  `allow_workbench` tinyint(1) NOT NULL default '0',
  `nonlocal_id` varchar(128) default NULL,
  `nonlocal_type` tinytext,
  `manager_urn` varchar(128) default NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `bound_portal` tinyint(1) default '0',
  `experiment_accounts` enum('none','swapper') default NULL,
  `reservations_disabled` tinyint(1) NOT NULL default '0',
  `nsf_funded` tinyint(1) default '0',
  `nsf_updated` datetime default NULL,
  `nsf_awards` tinytext,
  `industry` tinyint(1) default '0',
  `consortium` tinyint(1) default '0',
  `expert_mode` tinyint(1) default '0',
  PRIMARY KEY  (`pid_idx`),
  UNIQUE KEY `pid` (`pid`),
  KEY `unix_gid` (`unix_gid`),
  KEY `approved` (`approved`),
  KEY `approved_2` (`approved`),
  KEY `pcremote_ok` (`pcremote_ok`),
  KEY `portal` (`portal`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `project_nsf_awards`
--
DROP TABLE IF EXISTS `project_nsf_awards`;
CREATE TABLE `project_nsf_awards` (
  `idx` smallint(5) unsigned NOT NULL auto_increment,
  `pid` varchar(48) NOT NULL default '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `award` varchar(32) NOT NULL default '',
  `supplement` tinyint(1) default '0',
  PRIMARY KEY  (`pid_idx`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `report_assign_violation`
--

DROP TABLE IF EXISTS `report_assign_violation`;
CREATE TABLE `report_assign_violation` (
  `seq` int(10) unsigned NOT NULL default '0',
  `unassigned` int(11) default NULL,
  `pnode_load` int(11) default NULL,
  `no_connect` int(11) default NULL,
  `link_users` int(11) default NULL,
  `bandwidth` int(11) default NULL,
  `desires` int(11) default NULL,
  `vclass` int(11) default NULL,
  `delay` int(11) default NULL,
  `trivial_mix` int(11) default NULL,
  `subnodes` int(11) default NULL,
  `max_types` int(11) default NULL,
  `endpoints` int(11) default NULL,
  PRIMARY KEY  (`seq`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `report_context`
--

DROP TABLE IF EXISTS `report_context`;
CREATE TABLE `report_context` (
  `seq` int(10) unsigned NOT NULL default '0',
  `i0` int(11) default NULL,
  `i1` int(11) default NULL,
  `i2` int(11) default NULL,
  `vc0` varchar(255) default NULL,
  `vc1` varchar(255) default NULL,
  `vc2` varchar(255) default NULL,
  PRIMARY KEY  (`seq`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `report_error`
--

DROP TABLE IF EXISTS `report_error`;
CREATE TABLE `report_error` (
  `seq` int(10) unsigned NOT NULL default '0',
  `stamp` int(10) unsigned NOT NULL default '0',
  `session` int(10) unsigned NOT NULL default '0',
  `invocation` int(10) unsigned NOT NULL default '0',
  `attempt` tinyint(1) NOT NULL default '0',
  `severity` smallint(3) NOT NULL default '0',
  `script` smallint(3) NOT NULL default '0',
  `error_type` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`seq`),
  KEY `session` (`session`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `reposition_status`
--

DROP TABLE IF EXISTS `reposition_status`;
CREATE TABLE `reposition_status` (
  `node_id` varchar(32) NOT NULL default '',
  `attempts` tinyint(4) NOT NULL default '0',
  `distance_remaining` float default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `reservation_history`
--

DROP TABLE IF EXISTS `reservation_history`;
CREATE TABLE `reservation_history` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint(8) unsigned NOT NULL default '0',
  `nodes` smallint(5) NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `created` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `notes` mediumtext,
  `admin_notes` mediumtext,
  `uuid` varchar(40) NOT NULL default '',
  KEY `start` (`start`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `reservation_version`
--

DROP TABLE IF EXISTS `reservation_version`;
CREATE TABLE `reservation_version` (
  `version` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`version`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `reserved`
--

DROP TABLE IF EXISTS `reserved`;
CREATE TABLE `reserved` (
  `node_id` varchar(32) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `rsrv_time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `vname` varchar(32) default NULL,
  `erole` enum('node','virthost','delaynode','simhost','sharedhost','subboss','storagehost') NOT NULL default 'node',
  `simhost_violation` tinyint(3) unsigned NOT NULL default '0',
  `old_pid` varchar(48) NOT NULL default '',
  `old_eid` varchar(32) NOT NULL default '',
  `old_exptidx` int(11) NOT NULL default '0',
  `cnet_vlan` int(11) default NULL,
  `inner_elab_role` tinytext,
  `inner_elab_boot` tinyint(1) default '0',
  `plab_role` enum('plc','node','none') NOT NULL default 'none',
  `plab_boot` tinyint(1) default '0',
  `mustwipe` tinyint(4) NOT NULL default '0',
  `genisliver_idx` int(10) unsigned default NULL,
  `external_resource_index` int(10) unsigned default NULL,
  `external_resource_id` tinytext,
  `external_resource_key` tinytext,
  `tmcd_redirect` tinytext,
  `sharing_mode` varchar(32) default NULL,
  `rootkey_private` tinyint(1) NOT NULL default '0',
  `rootkey_public` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`node_id`),
  UNIQUE KEY `vname` (`pid`,`eid`,`vname`),
  UNIQUE KEY `vname2` (`exptidx`,`vname`),
  KEY `old_pid` (`old_pid`,`old_eid`),
  KEY `old_exptidx` (`old_exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `reserved_addresses`
--

DROP TABLE IF EXISTS `reserved_addresses`;
CREATE TABLE `reserved_addresses` (
  `rsrvidx` int(10) unsigned NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(10) unsigned NOT NULL default '0',
  `rsrv_time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `baseaddr` varchar(40) NOT NULL default '',
  `prefix` tinyint(4) unsigned NOT NULL default '0',
  `type` varchar(30) NOT NULL default '',
  `role` enum('public','internal') NOT NULL default 'internal',
  PRIMARY KEY (`rsrvidx`),
  UNIQUE KEY `type_base` (`type`,`baseaddr`,`prefix`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `reserved_blockstores`
--

DROP TABLE IF EXISTS `reserved_blockstores`;
CREATE TABLE `reserved_blockstores` (
  `bsidx` int(10) unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL default '',
  `bs_id` varchar(32) NOT NULL default '',
  `vname` varchar(32) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `size` int(10) unsigned NOT NULL default '0',
  `vnode_id` varchar(32) NOT NULL default '',
  `rsrv_time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY (`exptidx`,`bsidx`,`vname`),
  UNIQUE KEY `vname` (`exptidx`,`vname`),
  KEY `nidbid` (`node_id`,`bs_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `reserved_vlantags`
--

DROP TABLE IF EXISTS `reserved_vlantags`;
CREATE TABLE `reserved_vlantags` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `lanid` int(11) NOT NULL default '0',
  `vname` varchar(128) NOT NULL default '',
  `tag` smallint(5) NOT NULL default '0',
  `reserve_time` datetime default NULL,  
  `locked` datetime default NULL,
  `state` varchar(32) NOT NULL default '',
  PRIMARY KEY (`exptidx`,`lanid`,`tag`),
  UNIQUE KEY `vname` (`pid`,`eid`,`vname`,`tag`),
  UNIQUE KEY `lanid` (`pid`,`eid`,`lanid`,`tag`),
  UNIQUE KEY `tag` (`tag`),
  KEY `id` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `scheduled_reloads`
--

DROP TABLE IF EXISTS `scheduled_reloads`;
CREATE TABLE `scheduled_reloads` (
  `node_id` varchar(32) NOT NULL default '',
  `image_id` int(8) unsigned NOT NULL default '0',
  `reload_type` enum('netdisk','frisbee') default NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `scripts`
--

DROP TABLE IF EXISTS `scripts`;
CREATE TABLE `scripts` (
  `script` smallint(3) NOT NULL auto_increment,
  `script_name` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`script`),
  UNIQUE KEY `id` (`script_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `session_info`
--

DROP TABLE IF EXISTS `session_info`;
CREATE TABLE `session_info` (
  `session` int(11) NOT NULL default '0',
  `uid` int(11) NOT NULL default '0',
  `exptidx` int(11) NOT NULL default '0',
  PRIMARY KEY  (`session`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `shared_vlans`
--

DROP TABLE IF EXISTS `shared_vlans`;
CREATE TABLE `shared_vlans` (
  `pid` varchar(48) default NULL,
  `eid` varchar(32) default NULL,
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `lanid` int(11) NOT NULL default '0',
  `token` varchar(128) NOT NULL default '',
  `created` datetime default NULL,
  `creator` varchar(8) NOT NULL default '',
  `creator_idx` mediumint(8) unsigned NOT NULL default '0',
  `open` tinyint(1) NOT NULL default '0',
  PRIMARY KEY (`token`),
  UNIQUE KEY `lan` (`exptidx`,`vname`),
  UNIQUE KEY `lanid` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `sitevariables`
--

DROP TABLE IF EXISTS `sitevariables`;
CREATE TABLE `sitevariables` (
  `name` varchar(255) NOT NULL default '',
  `value` text,
  `defaultvalue` text NOT NULL,
  `description` text,
  `ns_include` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `state_timeouts`
--

DROP TABLE IF EXISTS `state_timeouts`;
CREATE TABLE `state_timeouts` (
  `op_mode` varchar(20) NOT NULL default '',
  `state` varchar(20) NOT NULL default '',
  `timeout` int(11) NOT NULL default '0',
  `action` mediumtext NOT NULL,
  PRIMARY KEY  (`op_mode`,`state`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `state_transitions`
--

DROP TABLE IF EXISTS `state_transitions`;
CREATE TABLE `state_transitions` (
  `op_mode` varchar(20) NOT NULL default '',
  `state1` varchar(20) NOT NULL default '',
  `state2` varchar(20) NOT NULL default '',
  `label` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`op_mode`,`state1`,`state2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `state_triggers`
--

DROP TABLE IF EXISTS `state_triggers`;
CREATE TABLE `state_triggers` (
  `node_id` varchar(32) NOT NULL default '',
  `op_mode` varchar(20) NOT NULL default '',
  `state` varchar(20) NOT NULL default '',
  `trigger` tinytext NOT NULL,
  PRIMARY KEY  (`node_id`,`op_mode`,`state`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `subboss_attributes`
--

DROP TABLE IF EXISTS `subboss_attributes`;
CREATE TABLE `subboss_attributes` (
  `subboss_id` varchar(32) NOT NULL default '',
  `service` varchar(20) NOT NULL default '',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext,
  PRIMARY KEY  (`subboss_id`,`service`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `subboss_images`
--

DROP TABLE IF EXISTS `subboss_images`;
CREATE TABLE `subboss_images` (
  `subboss_id` varchar(32) NOT NULL default '',
  `imageid` int(8) unsigned NOT NULL default '0',
  `load_address` text,
  `frisbee_pid` int(11) default '0',
  `load_busy` tinyint(4) NOT NULL default '0',
  `sync` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`subboss_id`,`imageid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `subbosses`
--

DROP TABLE IF EXISTS `subbosses`;
CREATE TABLE `subbosses` (
  `node_id` varchar(32) NOT NULL default '',
  `service` varchar(20) NOT NULL default '',
  `subboss_id` varchar(32) NOT NULL default '',
  `disabled` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`service`),
  KEY `active` (`disabled`,`subboss_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `sw_configfiles`
--

DROP TABLE IF EXISTS `sw_configfiles`;
CREATE TABLE `sw_configfiles` (
  `id` int(11) NOT NULL auto_increment,
  `node_id` varchar(32) NOT NULL,
  `connection_id` int(11) NOT NULL default '0',
  `file` varchar(4) NOT NULL,
  `data` text,
  `swid` varchar(20) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `switch_paths`
--

DROP TABLE IF EXISTS `switch_paths`;
CREATE TABLE `switch_paths` (
  `pid` varchar(48) default NULL,
  `eid` varchar(32) default NULL,
  `vname` varchar(32) default NULL,
  `node_id1` varchar(32) default NULL,
  `node_id2` varchar(32) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `switch_stack_types`
--

DROP TABLE IF EXISTS `switch_stack_types`;
CREATE TABLE `switch_stack_types` (
  `stack_id` varchar(32) NOT NULL default '',
  `stack_type` varchar(10) default NULL,
  `supports_private` tinyint(1) NOT NULL default '0',
  `single_domain` tinyint(1) NOT NULL default '1',
  `snmp_community` varchar(32) default NULL,
  `min_vlan` int(11) default NULL,
  `max_vlan` int(11) default NULL,
  `leader` varchar(32) default NULL,
  PRIMARY KEY  (`stack_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `switch_stacks`
--

DROP TABLE IF EXISTS `switch_stacks`;
CREATE TABLE `switch_stacks` (
  `node_id` varchar(32) NOT NULL default '',
  `stack_id` varchar(32) NOT NULL default '',
  `is_primary` tinyint(1) NOT NULL default '1',
  `snmp_community` varchar(32) default NULL,
  `min_vlan` int(11) default NULL,
  `max_vlan` int(11) default NULL,
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `table_regex`
--

DROP TABLE IF EXISTS `table_regex`;
CREATE TABLE `table_regex` (
  `table_name` varchar(64) NOT NULL default '',
  `column_name` varchar(64) NOT NULL default '',
  `column_type` enum('text','int','float') default NULL,
  `check_type` enum('regex','function','redirect') default NULL,
  `check` tinytext NOT NULL,
  `min` int(11) NOT NULL default '0',
  `max` int(11) NOT NULL default '0',
  `comment` tinytext,
  UNIQUE KEY `table_name` (`table_name`,`column_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `tcp_proxy`
--

DROP TABLE IF EXISTS tcp_proxy;
CREATE TABLE tcp_proxy (
  node_id varchar(32) NOT NULL,
  node_ip varchar(15) NOT NULL,
  node_port int(5) NOT NULL,
  proxy_port int(5) NOT NULL,
  PRIMARY KEY  (node_id,node_ip,node_port),
  UNIQUE KEY proxy_port (proxy_port)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `template_stamps`
--

DROP TABLE IF EXISTS `template_stamps`;
CREATE TABLE `template_stamps` (
  `guid` varchar(16) NOT NULL default '',
  `vers` smallint(5) unsigned NOT NULL default '0',
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `instance` int(10) unsigned default NULL,
  `stamp_type` varchar(32) NOT NULL default '',
  `modifier` varchar(32) default NULL,
  `stamp` int(10) unsigned default NULL,
  `aux_type` varchar(32) default NULL,
  `aux_data` float default '0',
  PRIMARY KEY  (`guid`,`vers`,`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `testbed_stats`
--

DROP TABLE IF EXISTS `testbed_stats`;
CREATE TABLE `testbed_stats` (
  `idx` int(10) unsigned NOT NULL auto_increment,
  `start_time` datetime default NULL,
  `end_time` datetime default NULL,
  `exptidx` int(10) unsigned NOT NULL default '0',
  `rsrcidx` int(10) unsigned NOT NULL default '0',
  `action` varchar(16) NOT NULL default '',
  `exitcode` tinyint(3) default '0',
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `log_session` int(10) unsigned default NULL,
  PRIMARY KEY  (`idx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `exptidx` (`exptidx`),
  KEY `uid_idx` (`uid_idx`),
  KEY `idxdate` (`end_time`,`idx`),
  KEY `end_time` (`end_time`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `testsuite_preentables`
--

DROP TABLE IF EXISTS `testsuite_preentables`;
CREATE TABLE `testsuite_preentables` (
  `table_name` varchar(128) NOT NULL default '',
  `action` enum('drop','clean','prune') default 'drop',
  PRIMARY KEY  (`table_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `tiplines`
--

DROP TABLE IF EXISTS `tiplines`;
CREATE TABLE `tiplines` (
  `tipname` varchar(32) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  `server` varchar(64) NOT NULL default '',
  `disabled` tinyint(1) NOT NULL default '0',
  `portnum` int(11) NOT NULL default '0',
  `keylen` smallint(6) NOT NULL default '0',
  `keydata` text,
  `urlhash` varchar(64) default NULL,
  `urlstamp` int(10) unsigned NOT NULL default '0',
  `reuseurl` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`tipname`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `tipservers`
--

DROP TABLE IF EXISTS `tipservers`;
CREATE TABLE `tipservers` (
  `server` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`server`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `tmcd_redirect`
--

DROP TABLE IF EXISTS `tmcd_redirect`;
CREATE TABLE `tmcd_redirect` (
  `node_id` varchar(32) NOT NULL default '',
  `dbname` tinytext NOT NULL,
  PRIMARY KEY  (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `tpm_quote_values`
--

DROP TABLE IF EXISTS `tpm_quote_values`;
CREATE TABLE `tpm_quote_values` (
  `node_id` varchar(32) NOT NULL default '',
  `op_mode` varchar(20) NOT NULL,
  `state` varchar(20) NOT NULL,
  `pcr` int(11) NOT NULL,
  `value` mediumtext,
  PRIMARY KEY  (`node_id`,`op_mode`,`state`,`pcr`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `traces`
--

DROP TABLE IF EXISTS `traces`;
CREATE TABLE `traces` (
  `node_id` varchar(32) NOT NULL default '',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `iface0` varchar(8) NOT NULL default '',
  `iface1` varchar(8) NOT NULL default '',
  `pid` varchar(48) default NULL,
  `eid` varchar(32) default NULL,
  `exptidx` int(11) NOT NULL default '0',
  `linkvname` varchar(32) default NULL,
  `vnode` varchar(32) default NULL,
  `trace_type` tinytext,
  `trace_expr` tinytext,
  `trace_snaplen` int(11) NOT NULL default '0',
  `trace_db` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`idx`),
  KEY `pid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `uidnodelastlogin`
--

DROP TABLE IF EXISTS `uidnodelastlogin`;
CREATE TABLE `uidnodelastlogin` (
  `uid` varchar(10) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `node_id` varchar(32) NOT NULL default '',
  `date` date default NULL,
  `time` time default NULL,
  PRIMARY KEY  (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `unixgroup_membership`
--

DROP TABLE IF EXISTS `unixgroup_membership`;
CREATE TABLE `unixgroup_membership` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `gid` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`uid`,`gid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_credentials`
--

DROP TABLE IF EXISTS `user_credentials`;
CREATE TABLE `user_credentials` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `expires` datetime default NULL,
  `credential_string` text,
  `certificate_string` text,
  PRIMARY KEY  (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_exports`
--

DROP TABLE IF EXISTS `user_exports`;
CREATE TABLE `user_exports` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `peer` varchar(64) NOT NULL default '',
  `exported` datetime default NULL,
  `updated` datetime default NULL,
  PRIMARY KEY  (`uid_idx`,`peer`),
  UNIQUE KEY uidpeer (`uid`,`peer`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_features`
--

DROP TABLE IF EXISTS `user_features`;
CREATE TABLE `user_features` (
  `feature` varchar(64) NOT NULL default '',
  `added` datetime NOT NULL,
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid` varchar(8) NOT NULL default '',
  PRIMARY KEY  (`feature`,`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `user_licenses`
--

DROP TABLE IF EXISTS `user_licenses`;
CREATE TABLE `user_licenses` (
  `uid` varchar(48) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `license_idx` int(11) NOT NULL default '0',
  `accepted` datetime default NULL,
  `expiration` datetime default NULL,
  PRIMARY KEY (`uid_idx`,`license_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `user_policies`
--

DROP TABLE IF EXISTS `user_policies`;
CREATE TABLE `user_policies` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `policy` varchar(32) NOT NULL default '',
  `auxdata` varchar(64) NOT NULL default '',
  `count` int(10) NOT NULL default '0',
  PRIMARY KEY  (`uid`,`policy`,`auxdata`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_pubkeys`
--

DROP TABLE IF EXISTS `user_pubkeys`;
CREATE TABLE `user_pubkeys` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `internal` tinyint(1) NOT NULL default '0',
  `nodelete` tinyint(1) NOT NULL default '0',
  `isaptkey` tinyint(1) NOT NULL default '0',
  `pubkey` text,
  `stamp` datetime default NULL,
  `comment` varchar(128) NOT NULL default '',
  PRIMARY KEY  (`uid_idx`,`idx`),
  KEY `uid` (`uid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_sfskeys`
--

DROP TABLE IF EXISTS `user_sfskeys`;
CREATE TABLE `user_sfskeys` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `comment` varchar(128) NOT NULL default '',
  `pubkey` text,
  `stamp` datetime default NULL,
  PRIMARY KEY  (`uid_idx`,`comment`),
  KEY `uid` (`uid`,`comment`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_sslcerts`
--

DROP TABLE IF EXISTS `user_sslcerts`;
CREATE TABLE `user_sslcerts` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL default '0',
  `created` datetime default NULL,
  `expires` datetime default NULL,
  `revoked` datetime default NULL,
  `warned` datetime default NULL,
  `password` tinytext,
  `encrypted` tinyint(1) NOT NULL default '0',
  `DN` text,
  `cert` text,
  `privkey` text,
  PRIMARY KEY  (`idx`),
  KEY `uid` (`uid`),
  KEY `uid_idx` (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_stats`
--

DROP TABLE IF EXISTS `user_stats`;
CREATE TABLE `user_stats` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid_uuid` varchar(40) NOT NULL default '',
  `weblogin_count` int(11) unsigned default '0',
  `weblogin_last` datetime default NULL,
  `exptstart_count` int(11) unsigned default '0',
  `exptstart_last` datetime default NULL,
  `exptpreload_count` int(11) unsigned default '0',
  `exptpreload_last` datetime default NULL,
  `exptswapin_count` int(11) unsigned default '0',
  `exptswapin_last` datetime default NULL,
  `exptswapout_count` int(11) unsigned default '0',
  `exptswapout_last` datetime default NULL,
  `exptswapmod_count` int(11) unsigned default '0',
  `exptswapmod_last` datetime default NULL,
  `last_activity` datetime default NULL,
  `allexpt_duration` double(14,0) unsigned default '0',
  `allexpt_vnodes` int(11) unsigned default '0',
  `allexpt_vnode_duration` double(14,0) unsigned default '0',
  `allexpt_pnodes` int(11) unsigned default '0',
  `allexpt_pnode_duration` double(14,0) unsigned default '0',
  PRIMARY KEY  (`uid_idx`),
  KEY `uid_uuid` (`uid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_token_passwords`
--

DROP TABLE IF EXISTS `user_token_passwords`;
CREATE TABLE `user_token_passwords` (
  `idx` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `uid_idx` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `subsystem` varchar(64) NOT NULL,
  `scope_type` tinytext,
  `scope_value` tinytext,
  `username` varchar(64) NOT NULL,
  `plaintext` varchar(64) NOT NULL DEFAULT '',
  `hash` varchar(64) NOT NULL,
  `issued` datetime NOT NULL,
  `expiration` datetime DEFAULT NULL,
  `token_lifetime` int(10) unsigned NOT NULL,
  `token_onetime` tinyint(1) NOT NULL DEFAULT '0',
  `system` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`),
  UNIQUE KEY `user_token` (`subsystem`,`username`,`plaintext`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `uid_uuid` varchar(40) NOT NULL default '',
  `usr_created` datetime default NULL,
  `usr_expires` datetime default NULL,
  `usr_modified` datetime default NULL,
  `usr_name` tinytext,
  `usr_title` tinytext,
  `usr_affil` tinytext,
  `usr_affil_abbrev` varchar(16) default NULL,
  `usr_email` tinytext,
  `usr_URL` tinytext,
  `usr_addr` tinytext,
  `usr_addr2` tinytext,
  `usr_city` tinytext,
  `usr_state` tinytext,
  `usr_zip` tinytext,
  `usr_country` tinytext,
  `usr_phone` tinytext,
  `usr_shell` tinytext,
  `usr_pswd` tinytext NOT NULL,
  `usr_w_pswd` tinytext,
  `unix_uid` int(10) unsigned NOT NULL default '0',
  `status` enum('newuser','unapproved','unverified','active','frozen','archived','nonlocal','inactive','other') NOT NULL default 'newuser',
  `frozen_stamp` datetime default NULL,
  `frozen_by` varchar(8) default NULL,
  `admin` tinyint(4) default '0',
  `foreign_admin` tinyint(4) default '0',
  `dbedit` tinyint(4) default '0',
  `stud` tinyint(4) default '0',
  `webonly` tinyint(4) default '0',
  `pswd_expires` date default NULL,
  `cvsweb` tinyint(4) NOT NULL default '0',
  `emulab_pubkey` text,
  `home_pubkey` text,
  `adminoff` tinyint(4) default '0',
  `verify_key` varchar(64) default NULL,
  `widearearoot` tinyint(4) default '0',
  `wideareajailroot` tinyint(4) default '0',
  `notes` text,
  `weblogin_frozen` tinyint(3) unsigned NOT NULL default '0',
  `weblogin_failcount` smallint(5) unsigned NOT NULL default '0',
  `weblogin_failstamp` int(10) unsigned NOT NULL default '0',
  `plab_user` tinyint(1) NOT NULL default '0',
  `user_interface` enum('emulab','plab') NOT NULL default 'emulab',
  `chpasswd_key` varchar(32) default NULL,
  `chpasswd_expires` int(10) unsigned NOT NULL default '0',
  `wikiname` tinytext,
  `wikionly` tinyint(1) default '0',
  `mailman_password` tinytext,
  `nonlocal_id` varchar(128) default NULL,
  `nonlocal_type` tinytext,
  `manager_urn` varchar(128) default NULL,
  `default_project` mediumint(8) unsigned default NULL,
  `nocollabtools` tinyint(1) default '0',
  `initial_passphrase` varchar(128) default NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `bound_portal` tinyint(1) default '0',
  `require_aup` set('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `accepted_aup` set('emulab','aptlab','cloudlab','phantomnet','powder') default NULL,
  `ga_userid` varchar(32) default NULL,
  `portal_interface_warned` tinyint(1) NOT NULL default '0',
  `news_read` datetime NOT NULL default '0000-00-00 00:00:00',
  `affiliation_matched` tinyint(1) default '0',
  `affiliation_updated` date NOT NULL default '0000-00-00',
  `scopus_lastcheck` date NOT NULL default '0000-00-00',
  `expert_mode` tinyint(1) default '0',
  PRIMARY KEY  (`uid_idx`),
  KEY `unix_uid` (`unix_uid`),
  KEY `status` (`status`),
  KEY `uid_uuid` (`uid_uuid`),
  KEY `uid` (`uid`),
  KEY `nonlocal_id` (`nonlocal_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `user_scopus_info`
--

DROP TABLE IF EXISTS `user_scopus_info`;
CREATE TABLE `user_scopus_info` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `scopus_id` varchar(32) NOT NULL default '',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `validated` datetime default NULL,
  `validation_state` enum('valid','invalid','unknown') default 'unknown',
  `author_url` text,
  `latest_abstract_id` varchar(32) NOT NULL default '',
  `latest_abstract_pubdate` date NOT NULL default '0000-00-00',
  `latest_abstract_pubtype` varchar(64) NOT NULL default '',
  `latest_abstract_pubname` text,
  `latest_abstract_doi` varchar(64) default NULL,
  `latest_abstract_url` text,
  `latest_abstract_title` text,
  `latest_abstract_authors` text,
  `latest_abstract_cites` enum('emulab','cloudlab','phantomnet','powder') default NULL,
  PRIMARY KEY  (`uid_idx`,`scopus_id`),
  KEY `uid` (`uid`),
  KEY `scopus_id` (`scopus_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `scopus_paper_info`
--

DROP TABLE IF EXISTS `scopus_paper_info`;
CREATE TABLE `scopus_paper_info` (
  `scopus_id` varchar(32) NOT NULL default '',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `pubdate` date NOT NULL default '0000-00-00',
  `pubtype` varchar(64) NOT NULL default '',
  `pubname` text,
  `doi` varchar(128) default NULL,
  `url` text,
  `title` text,
  `authors` text,
  `cites` enum('emulab','cloudlab','phantomnet','powder') default NULL,
  `uses` enum('yes','no','unknown') default NULL,
  `citedby_count` int(10) default '0',
  PRIMARY KEY  (`scopus_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `scopus_paper_authors`
--

DROP TABLE IF EXISTS `scopus_paper_authors`;
CREATE TABLE `scopus_paper_authors` (
  `abstract_id` varchar(32) NOT NULL default '',
  `author_id` varchar(32) NOT NULL default '',
  `author` tinytext,
  PRIMARY KEY  (`abstract_id`,`author_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `userslastlogin`
--

DROP TABLE IF EXISTS `userslastlogin`;
CREATE TABLE `userslastlogin` (
  `uid` varchar(10) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `date` date default NULL,
  `time` time default NULL,
  PRIMARY KEY  (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `usrp_orders`
--

DROP TABLE IF EXISTS `usrp_orders`;
CREATE TABLE `usrp_orders` (
  `order_id` varchar(32) NOT NULL default '',
  `email` tinytext,
  `name` tinytext,
  `phone` tinytext,
  `affiliation` tinytext,
  `num_mobos` int(11) default '0',
  `num_dboards` int(11) default '0',
  `intended_use` tinytext,
  `comments` tinytext,
  `order_date` datetime default NULL,
  `modify_date` datetime default NULL,
  PRIMARY KEY  (`order_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `v2pmap`
--

DROP TABLE IF EXISTS `v2pmap`;
CREATE TABLE `v2pmap` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `version_info`
--

DROP TABLE IF EXISTS `version_info`;
CREATE TABLE `version_info` (
  `name` varchar(32) NOT NULL default '',
  `value` tinytext NOT NULL,
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `veth_interfaces`
--

DROP TABLE IF EXISTS `veth_interfaces`;
CREATE TABLE `veth_interfaces` (
  `node_id` varchar(32) NOT NULL default '',
  `veth_id` int(10) unsigned NOT NULL auto_increment,
  `mac` varchar(12) NOT NULL default '000000000000',
  `IP` varchar(15) default NULL,
  `mask` varchar(15) default NULL,
  `iface` varchar(10) default NULL,
  `vnode_id` varchar(32) default NULL,
  `rtabid` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`veth_id`),
  KEY `IP` (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `vinterfaces`
--

DROP TABLE IF EXISTS `vinterfaces`;
CREATE TABLE `vinterfaces` (
  `node_id` varchar(32) NOT NULL default '',
  `unit` int(10) unsigned NOT NULL auto_increment,
  `mac` varchar(12) NOT NULL default '000000000000',
  `IP` varchar(15) default NULL,
  `mask` varchar(15) default NULL,
  `type` enum('alias','veth','veth-ne','vlan') NOT NULL default 'veth',
  `iface` varchar(10) default NULL,
  `rtabid` smallint(5) unsigned NOT NULL default '0',
  `vnode_id` varchar(32) default NULL,
  `exptidx` int(10) NOT NULL default '0',
  `virtlanidx` int(11) NOT NULL default '0',
  `vlanid` int(11) NOT NULL default '0',
  `bandwidth` int(10) NOT NULL default '0',
  PRIMARY KEY  (`node_id`,`unit`),
  KEY `bynode` (`node_id`,`iface`),
  KEY `type` (`type`),
  KEY `vnode_id` (`vnode_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_agents`
--

DROP TABLE IF EXISTS `virt_agents`;
CREATE TABLE `virt_agents` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(64) NOT NULL default '',
  `vnode` varchar(32) NOT NULL default '',
  `objecttype` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vname`,`vnode`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_blobs`
--

DROP TABLE IF EXISTS `virt_blobs`;
CREATE TABLE `virt_blobs` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vblob_id` varchar(40) NOT NULL default '',
  `filename` tinytext,
  PRIMARY KEY  (`exptidx`,`vblob_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_blockstore_attributes`
--

DROP TABLE IF EXISTS `virt_blockstore_attributes`;
CREATE TABLE `virt_blockstore_attributes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `attrkey` varchar(32) NOT NULL default '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') default 'string',
  `isdesire` tinyint(4) unsigned NOT NULL default '0',
  PRIMARY KEY (`exptidx`,`vname`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_blockstores`
--

DROP TABLE IF EXISTS `virt_blockstores`;
CREATE TABLE `virt_blockstores` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `type` varchar(30) default NULL,
  `role` enum('remote','local','unknown') NOT NULL default 'unknown',
  `size` int(10) unsigned NOT NULL default '0',
  `fixed` text NOT NULL,
  PRIMARY KEY (`exptidx`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_bridges`
--

DROP TABLE IF EXISTS `virt_bridges`;
CREATE TABLE `virt_bridges` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `vlink` varchar(32) NOT NULL default '',
  `vport` tinyint(3) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vname`,`vlink`,`vport`),
  KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_client_service_ctl`
--

DROP TABLE IF EXISTS `virt_client_service_ctl`;
CREATE TABLE `virt_client_service_ctl` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vnode` varchar(32) NOT NULL default '',
  `service_idx` int(10) NOT NULL default '0',
  `env` enum('load','boot') NOT NULL default 'boot',
  `whence` enum('first','every') NOT NULL default 'every',
  `alt_vblob_id` varchar(40) NOT NULL default '',
  `enable` tinyint(1) NOT NULL default '1',
  `enable_hooks` tinyint(1) NOT NULL default '1',
  `fatal` tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (`exptidx`,`vnode`,`service_idx`,`env`,`whence`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_client_service_hooks`
--

DROP TABLE IF EXISTS `virt_client_service_hooks`;
CREATE TABLE `virt_client_service_hooks` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vnode` varchar(32) NOT NULL default '',
  `service_idx` int(10) NOT NULL default '0',
  `env` enum('load','boot') NOT NULL default 'boot',
  `whence` enum('first','every') NOT NULL default 'every',
  `hook_vblob_id` varchar(40) NOT NULL default '',
  `hook_op` enum('boot','shutdown','reconfig','reset') NOT NULL default 'boot',
  `hook_point` enum('pre','post') NOT NULL default 'post',
  `argv` varchar(255) NOT NULL default '',
  `fatal` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vnode`,`service_idx`,`env`,`whence`,`hook_vblob_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_client_service_opts`
--

DROP TABLE IF EXISTS `virt_client_service_opts`;
CREATE TABLE `virt_client_service_opts` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vnode` varchar(32) NOT NULL default '',
  `opt_name` varchar(32) NOT NULL default '',
  `opt_value` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`exptidx`,`vnode`,`opt_name`,`opt_value`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_firewalls`
--

DROP TABLE IF EXISTS `virt_firewalls`;
CREATE TABLE `virt_firewalls` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `fwname` varchar(32) NOT NULL default '',
  `type` enum('ipfw','ipfw2','iptables','ipfw2-vlan','iptables-vlan') NOT NULL default 'ipfw',
  `style` enum('open','closed','basic','emulab') NOT NULL default 'basic',
  `log` tinytext NOT NULL,
  PRIMARY KEY  (`exptidx`,`fwname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`fwname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_lan_lans`
--

DROP TABLE IF EXISTS `virt_lan_lans`;
CREATE TABLE `virt_lan_lans` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `idx` int(11) NOT NULL auto_increment,
  `vname` varchar(32) NOT NULL default '',
  `failureaction` enum('fatal','nonfatal') NOT NULL default 'fatal',
  PRIMARY KEY  (`exptidx`,`idx`),
  UNIQUE KEY `vname` (`pid`,`eid`,`vname`),
  UNIQUE KEY `idx` (`pid`,`eid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_lan_member_settings`
--

DROP TABLE IF EXISTS `virt_lan_member_settings`;
CREATE TABLE `virt_lan_member_settings` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `member` varchar(32) NOT NULL default '',
  `capkey` varchar(32) NOT NULL default '',
  `capval` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`exptidx`,`vname`,`member`,`capkey`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`member`,`capkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_lan_settings`
--

DROP TABLE IF EXISTS `virt_lan_settings`;
CREATE TABLE `virt_lan_settings` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `capkey` varchar(32) NOT NULL default '',
  `capval` varchar(64) NOT NULL default '',
  PRIMARY KEY  (`exptidx`,`vname`,`capkey`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`capkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_lans`
--

DROP TABLE IF EXISTS `virt_lans`;
CREATE TABLE `virt_lans` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `vnode` varchar(32) NOT NULL default '',
  `vport` tinyint(3) NOT NULL default '0',
  `vindex` int(11) NOT NULL default '-1',
  `ip` varchar(15) NOT NULL default '',
  `delay` float(10,2) default '0.00',
  `bandwidth` int(10) unsigned default NULL,
  `backfill` int(10) unsigned default '0',
  `est_bandwidth` int(10) unsigned default NULL,
  `lossrate` float(10,8) default NULL,
  `q_limit` int(11) default '0',
  `q_maxthresh` int(11) default '0',
  `q_minthresh` int(11) default '0',
  `q_weight` float default '0',
  `q_linterm` int(11) default '0',
  `q_qinbytes` tinyint(4) default '0',
  `q_bytes` tinyint(4) default '0',
  `q_meanpsize` int(11) default '0',
  `q_wait` int(11) default '0',
  `q_setbit` int(11) default '0',
  `q_droptail` int(11) default '0',
  `q_red` tinyint(4) default '0',
  `q_gentle` tinyint(4) default '0',
  `member` text,
  `mask` varchar(15) default '255.255.255.0',
  `rdelay` float(10,2) default NULL,
  `rbandwidth` int(10) unsigned default NULL,
  `rbackfill` int(10) unsigned default '0',
  `rest_bandwidth` int(10) unsigned default NULL,
  `rlossrate` float(10,8) default NULL,
  `cost` float NOT NULL default '1',
  `widearea` tinyint(4) default '0',
  `emulated` tinyint(4) default '0',
  `uselinkdelay` tinyint(4) default '0',
  `forcelinkdelay` tinyint(1) default '0',
  `nobwshaping` tinyint(4) default '0',
  `besteffort` tinyint(1) default '0',
  `nointerswitch` tinyint(1) default '0',
  `mustdelay` tinyint(1) default '0',
  `usevethiface` tinyint(4) default '0',
  `encap_style` enum('alias','veth','veth-ne','vlan','vtun','egre','gre','default') NOT NULL default 'default',
  `trivial_ok` tinyint(4) default '1',
  `protocol` varchar(30) NOT NULL default 'ethernet',
  `is_accesspoint` tinyint(4) default '0',
  `traced` tinyint(1) default '0',
  `trace_type` enum('header','packet','monitor') NOT NULL default 'header',
  `trace_expr` tinytext,
  `trace_snaplen` int(11) NOT NULL default '0',
  `trace_endnode` tinyint(1) NOT NULL default '0',
  `trace_db` tinyint(1) NOT NULL default '0',
  `fixed_iface` varchar(128) default '',
  `layer` tinyint(4) NOT NULL default '2',
  `implemented_by_path` tinytext,
  `implemented_by_link` tinytext,
  `ip_aliases` tinytext,
  `ofenabled` tinyint(1) default '0',
  `ofcontroller` tinytext,
  `bridge_vname` varchar(32) default NULL,
  PRIMARY KEY  (`exptidx`,`vname`,`vnode`,`vport`),
  UNIQUE KEY `vport` (`pid`,`eid`,`vname`,`vnode`,`vport`),
  KEY `pid` (`pid`,`eid`,`vname`),
  KEY `vnode` (`pid`,`eid`,`vnode`),
  KEY `pideid` (`pid`,`eid`,`vname`,`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_node_attributes`
--

DROP TABLE IF EXISTS `virt_node_attributes`;
CREATE TABLE `virt_node_attributes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `attrkey` varchar(64) NOT NULL default '',
  `attrvalue` tinytext,
  PRIMARY KEY  (`exptidx`,`vname`,`attrkey`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_node_desires`
--

DROP TABLE IF EXISTS `virt_node_desires`;
CREATE TABLE `virt_node_desires` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `desire` varchar(64) NOT NULL default '',
  `weight` float default NULL,
  PRIMARY KEY  (`exptidx`,`vname`,`desire`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`desire`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_node_disks`
--

DROP TABLE IF EXISTS `virt_node_disks`;
CREATE TABLE `virt_node_disks` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `diskname` varchar(32) NOT NULL default '',
  `disktype` varchar(32) NOT NULL default '',
  `disksize` int(11) unsigned NOT NULL default '0',
  `mountpoint` tinytext,
  `parameters` tinytext,
  `command` tinytext,
  PRIMARY KEY  (`exptidx`,`vname`,`diskname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`diskname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_node_motelog`
--

DROP TABLE IF EXISTS `virt_node_motelog`;
CREATE TABLE `virt_node_motelog` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `vname` varchar(32) NOT NULL default '',
  `logfileid` varchar(45) NOT NULL default '',
  PRIMARY KEY  (`pid`,`eid`,`vname`,`logfileid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_node_public_addr`
--

DROP TABLE IF EXISTS `virt_node_public_addr`;
CREATE TABLE `virt_node_public_addr` (
  `IP` varchar(15) NOT NULL default '',
  `mask` varchar(15) default NULL,
  `node_id` varchar(32) default NULL,
  `pool_id` varchar(32) default NULL,
  `pid` varchar(48) default NULL,
  `eid` varchar(32) default NULL,
  PRIMARY KEY  (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_address_allocation`
--

DROP TABLE IF EXISTS `virt_address_allocation`;
CREATE TABLE `virt_address_allocation` (
  `pool_id` varchar(32) NOT NULL default '',
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `count` int(10) NOT NULL default '0',
  `restriction` enum('contiguous','cidr','any') NOT NULL default 'any',
  `version` enum('ipv4','ipv6') NOT NULL default 'ipv4',
  PRIMARY KEY (`exptidx`,`pool_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_node_startloc`
--

DROP TABLE IF EXISTS `virt_node_startloc`;
CREATE TABLE `virt_node_startloc` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `building` varchar(32) NOT NULL default '',
  `floor` varchar(32) NOT NULL default '',
  `loc_x` float NOT NULL default '0',
  `loc_y` float NOT NULL default '0',
  `orientation` float NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_nodes`
--

DROP TABLE IF EXISTS `virt_nodes`;
CREATE TABLE `virt_nodes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `ips` text,
  `osname` varchar(128) default NULL,
  `loadlist` text,
  `parent_osname` varchar(128) default NULL,
  `cmd_line` text,
  `rpms` text,
  `deltas` text,
  `startupcmd` tinytext,
  `tarfiles` text,
  `vname` varchar(32) NOT NULL default '',
  `type` varchar(30) default NULL,
  `failureaction` enum('fatal','nonfatal','ignore') NOT NULL default 'fatal',
  `routertype` enum('none','ospf','static','manual','static-ddijk','static-old') NOT NULL default 'none',
  `fixed` text NOT NULL,
  `inner_elab_role` tinytext,
  `plab_role` enum('plc','node','none') NOT NULL default 'none',
  `plab_plcnet` varchar(32) NOT NULL default 'none',
  `numeric_id` int(11) default NULL,
  `sharing_mode` varchar(32) default NULL,
  `role` enum('node','bridge') NOT NULL default 'node',
  `firewall_style` tinytext,
  `firewall_log` tinytext,
  `nfsmounts` enum('emulabdefault','genidefault','all','none') default NULL,  
  `rootkey_private` tinyint(1) NOT NULL default '0',
  `rootkey_public` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`),
  KEY `pid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_parameters`
--

DROP TABLE IF EXISTS `virt_parameters`;
CREATE TABLE `virt_parameters` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `name` varchar(64) NOT NULL default '',
  `value` tinytext,
  `description` text,
  PRIMARY KEY  (`exptidx`,`name`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_paths`
--

DROP TABLE IF EXISTS `virt_paths`;
CREATE TABLE `virt_paths` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `pathname` varchar(32) NOT NULL default '',
  `segmentname` varchar(32) NOT NULL default '',
  `segmentindex` tinyint(4) unsigned NOT NULL default '0',
  `layer` tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`pathname`,`segmentname`),
  UNIQUE KEY `segidx` (`exptidx`,`pathname`,`segmentindex`),
  KEY `pid` (`pid`,`eid`,`pathname`),
  KEY `pideid` (`pid`,`eid`,`pathname`,`segmentname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_profile_parameters`
--

DROP TABLE IF EXISTS `virt_profile_parameters`;
CREATE TABLE `virt_profile_parameters` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int(11) NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL,
  `value` text NOT NULL,
  PRIMARY KEY (`exptidx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_programs`
--

DROP TABLE IF EXISTS `virt_programs`;
CREATE TABLE `virt_programs` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vnode` varchar(32) NOT NULL default '',
  `vname` varchar(32) NOT NULL default '',
  `command` tinytext,
  `dir` tinytext,
  `timeout` int(10) unsigned default NULL,
  `expected_exit_code` tinyint(4) unsigned default NULL,
  PRIMARY KEY  (`exptidx`,`vnode`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vnode`,`vname`),
  KEY `vnode` (`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_routes`
--

DROP TABLE IF EXISTS `virt_routes`;
CREATE TABLE `virt_routes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `src` varchar(32) NOT NULL default '',
  `dst` varchar(32) NOT NULL default '',
  `dst_type` enum('host','net') NOT NULL default 'host',
  `dst_mask` varchar(15) default '255.255.255.0',
  `nexthop` varchar(32) NOT NULL default '',
  `cost` int(11) NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vname`,`src`,`dst`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`src`,`dst`),
  KEY `pid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_simnode_attributes`
--

DROP TABLE IF EXISTS `virt_simnode_attributes`;
CREATE TABLE `virt_simnode_attributes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `nodeweight` smallint(5) unsigned NOT NULL default '1',
  `eventrate` int(11) unsigned NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_tiptunnels`
--

DROP TABLE IF EXISTS `virt_tiptunnels`;
CREATE TABLE `virt_tiptunnels` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `host` varchar(32) NOT NULL default '',
  `vnode` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`exptidx`,`host`,`vnode`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`host`,`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_trafgens`
--

DROP TABLE IF EXISTS `virt_trafgens`;
CREATE TABLE `virt_trafgens` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vnode` varchar(32) NOT NULL default '',
  `vname` varchar(32) NOT NULL default '',
  `role` tinytext NOT NULL,
  `proto` tinytext NOT NULL,
  `port` int(11) NOT NULL default '0',
  `ip` varchar(15) NOT NULL default '',
  `target_vnode` varchar(32) NOT NULL default '',
  `target_vname` varchar(32) NOT NULL default '',
  `target_port` int(11) NOT NULL default '0',
  `target_ip` varchar(15) NOT NULL default '',
  `generator` tinytext NOT NULL,
  PRIMARY KEY  (`exptidx`,`vnode`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vnode`,`vname`),
  KEY `vnode` (`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_user_environment`
--

DROP TABLE IF EXISTS `virt_user_environment`;
CREATE TABLE `virt_user_environment` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `idx` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `value` text,
  PRIMARY KEY  (`exptidx`,`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `virt_vtypes`
--

DROP TABLE IF EXISTS `virt_vtypes`;
CREATE TABLE `virt_vtypes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `name` varchar(32) NOT NULL default '',
  `weight` float(7,5) NOT NULL default '0.00000',
  `members` text,
  PRIMARY KEY  (`exptidx`,`name`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `vis_graphs`
--

DROP TABLE IF EXISTS `vis_graphs`;
CREATE TABLE `vis_graphs` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `zoom` decimal(8,3) NOT NULL default '0.000',
  `detail` tinyint(2) NOT NULL default '0',
  `image` mediumblob,
  PRIMARY KEY  (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `vis_nodes`
--

DROP TABLE IF EXISTS `vis_nodes`;
CREATE TABLE `vis_nodes` (
  `pid` varchar(48) NOT NULL default '',
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `vname` varchar(32) NOT NULL default '',
  `vis_type` varchar(10) NOT NULL default '',
  `x` float NOT NULL default '0',
  `y` float NOT NULL default '0',
  PRIMARY KEY  (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `vlantag_history`
--

DROP TABLE IF EXISTS `vlantag_history`;
CREATE TABLE `vlantag_history` (
  `history_id` int(10) unsigned NOT NULL auto_increment,
  `tag` smallint(5) NOT NULL default '0',
  `lanid` int(11) NOT NULL default '0',
  `lanname` varchar(64) NOT NULL default '',
  `exptidx` int(10) unsigned default NULL,
  `allocated` int(10) unsigned default NULL,
  `released` int(10) unsigned default NULL,
  PRIMARY KEY  (`history_id`),
  KEY `tag` (`tag`,`history_id`),
  KEY `exptidx` (`exptidx`),
  KEY `lanid` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `vlans`
--

DROP TABLE IF EXISTS `vlans`;
CREATE TABLE `vlans` (
  `eid` varchar(32) NOT NULL default '',
  `exptidx` int(11) NOT NULL default '0',
  `pid` varchar(48) NOT NULL default '',
  `virtual` varchar(64) default NULL,
  `members` text NOT NULL,
  `switchpath` text default NULL,
  `id` int(11) NOT NULL auto_increment,
  `tag` smallint(5) NOT NULL default '0',
  `stack` varchar(32) default NULL,
  `class` varchar(32) default NULL,
  PRIMARY KEY  (`id`),
  KEY `pid` (`pid`,`eid`,`virtual`),
  KEY `exptidx` (`exptidx`,`virtual`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `web_sessions`
--

DROP TABLE IF EXISTS `web_sessions`;
CREATE TABLE `web_sessions` (
  `session_id` varchar(128) NOT NULL default '', 
  `session_expires` datetime NOT NULL default '0000-00-00 00:00:00',
  `session_data` text,
  PRIMARY KEY  (`session_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `web_tasks`
--

DROP TABLE IF EXISTS `web_tasks`;
CREATE TABLE `web_tasks` (
  `task_id` varchar(128) NOT NULL default '',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `modified` datetime NOT NULL default '0000-00-00 00:00:00',
  `exited` datetime default NULL,
  `process_id` int(11) default '0',
  `object_uuid` varchar(40) NOT NULL default '',
  `exitcode` int(11) default '0',
  `task_data` mediumtext,
  PRIMARY KEY  (`task_id`),
  KEY `object_uuid` (`object_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `webcams`
--

DROP TABLE IF EXISTS `webcams`;
CREATE TABLE `webcams` (
  `id` int(11) unsigned NOT NULL default '0',
  `server` varchar(64) NOT NULL default '',
  `last_update` datetime default NULL,
  `URL` tinytext,
  `stillimage_URL` tinytext,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `webdb_table_permissions`
--

DROP TABLE IF EXISTS `webdb_table_permissions`;
CREATE TABLE `webdb_table_permissions` (
  `table_name` varchar(64) NOT NULL default '',
  `allow_read` tinyint(1) default '1',
  `allow_row_add_edit` tinyint(1) default '0',
  `allow_row_delete` tinyint(1) default '0',
  PRIMARY KEY  (`table_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `webnews`
--

DROP TABLE IF EXISTS `webnews`;
CREATE TABLE `webnews` (
  `msgid` int(11) NOT NULL auto_increment,
  `subject` tinytext,
  `date` datetime default NULL,
  `author` varchar(32) default NULL,
  `author_idx` mediumint(8) unsigned NOT NULL default '0',
  `body` text,
  `archived` tinyint(1) NOT NULL default '0',
  `archived_date` datetime default NULL,
  PRIMARY KEY  (`msgid`),
  KEY `date` (`date`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `webnews_protogeni`
--

DROP TABLE IF EXISTS `webnews_protogeni`;
CREATE TABLE `webnews_protogeni` (
  `msgid` int(11) NOT NULL auto_increment,
  `subject` tinytext,
  `date` datetime default NULL,
  `author` varchar(32) default NULL,
  `author_idx` mediumint(8) unsigned NOT NULL default '0',
  `body` text,
  `archived` tinyint(1) NOT NULL default '0',
  `archived_date` datetime default NULL,
  PRIMARY KEY  (`msgid`),
  KEY `date` (`date`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `widearea_accounts`
--

DROP TABLE IF EXISTS `widearea_accounts`;
CREATE TABLE `widearea_accounts` (
  `uid` varchar(8) NOT NULL default '',
  `uid_idx` mediumint(8) unsigned NOT NULL default '0',
  `node_id` varchar(32) NOT NULL default '',
  `trust` enum('none','user','local_root') default NULL,
  `date_applied` date default NULL,
  `date_approved` datetime default NULL,
  PRIMARY KEY  (`uid`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `widearea_delays`
--

DROP TABLE IF EXISTS `widearea_delays`;
CREATE TABLE `widearea_delays` (
  `time` double default NULL,
  `node_id1` varchar(32) NOT NULL default '',
  `iface1` varchar(10) NOT NULL default '',
  `node_id2` varchar(32) NOT NULL default '',
  `iface2` varchar(10) NOT NULL default '',
  `bandwidth` double default NULL,
  `time_stddev` float NOT NULL default '0',
  `lossrate` float NOT NULL default '0',
  `start_time` int(10) unsigned default NULL,
  `end_time` int(10) unsigned default NULL,
  PRIMARY KEY  (`node_id1`,`iface1`,`node_id2`,`iface2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `widearea_nodeinfo`
--

DROP TABLE IF EXISTS `widearea_nodeinfo`;
CREATE TABLE `widearea_nodeinfo` (
  `node_id` varchar(32) NOT NULL default '',
  `machine_type` varchar(40) default NULL,
  `contact_uid` varchar(8) NOT NULL default '',
  `contact_idx` mediumint(8) unsigned NOT NULL default '0',
  `connect_type` varchar(20) default NULL,
  `city` tinytext,
  `state` tinytext,
  `country` tinytext,
  `zip` tinytext,
  `external_node_id` tinytext,
  `hostname` varchar(255) default NULL,
  `site` varchar(255) default NULL,
  `latitude` float default NULL,
  `longitude` float default NULL,
  `bwlimit` varchar(32) default NULL,
  `privkey` varchar(128) default NULL,
  `IP` varchar(15) default NULL,
  `gateway` varchar(15) NOT NULL default '',
  `dns` tinytext NOT NULL,
  `boot_method` enum('static','dhcp','') NOT NULL default '',
  PRIMARY KEY  (`node_id`),
  KEY `IP` (`IP`),
  KEY `privkey` (`privkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `widearea_privkeys`
--

DROP TABLE IF EXISTS `widearea_privkeys`;
CREATE TABLE `widearea_privkeys` (
  `privkey` varchar(64) NOT NULL default '',
  `IP` varchar(15) NOT NULL default '1.1.1.1',
  `user_name` tinytext NOT NULL,
  `user_email` tinytext NOT NULL,
  `cdkey` varchar(64) default NULL,
  `nextprivkey` varchar(64) default NULL,
  `rootkey` varchar(64) default NULL,
  `lockkey` varchar(64) default NULL,
  `requested` datetime NOT NULL default '0000-00-00 00:00:00',
  `updated` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`privkey`,`IP`),
  KEY `IP` (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `widearea_recent`
--

DROP TABLE IF EXISTS `widearea_recent`;
CREATE TABLE `widearea_recent` (
  `time` double default NULL,
  `node_id1` varchar(32) NOT NULL default '',
  `iface1` varchar(10) NOT NULL default '',
  `node_id2` varchar(32) NOT NULL default '',
  `iface2` varchar(10) NOT NULL default '',
  `bandwidth` double default NULL,
  `time_stddev` float NOT NULL default '0',
  `lossrate` float NOT NULL default '0',
  `start_time` int(10) unsigned default NULL,
  `end_time` int(10) unsigned default NULL,
  PRIMARY KEY  (`node_id1`,`iface1`,`node_id2`,`iface2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `widearea_switches`
--

DROP TABLE IF EXISTS `widearea_switches`;
CREATE TABLE `widearea_switches` (
  `hrn` varchar(255) NOT NULL default '',
  `node_id` varchar(32) NOT NULL default '',
  PRIMARY KEY  (`hrn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `widearea_updates`
--

DROP TABLE IF EXISTS `widearea_updates`;
CREATE TABLE `widearea_updates` (
  `IP` varchar(15) NOT NULL default '1.1.1.1',
  `roottag` tinytext NOT NULL,
  `update_requested` datetime NOT NULL default '0000-00-00 00:00:00',
  `update_started` datetime default NULL,
  `force` enum('yes','no') NOT NULL default 'no',
  PRIMARY KEY  (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `wireless_stats`
--

DROP TABLE IF EXISTS `wireless_stats`;
CREATE TABLE `wireless_stats` (
  `name` varchar(32) NOT NULL default '',
  `floor` varchar(32) NOT NULL default '',
  `building` varchar(32) NOT NULL default '',
  `data_eid` varchar(32) default NULL,
  `data_pid` varchar(48) default NULL,
  `type` varchar(32) default NULL,
  `altsrc` tinytext,
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `wires`
--

DROP TABLE IF EXISTS `wires`;
CREATE TABLE `wires` (
  `cable` smallint(3) unsigned default NULL,
  `len` tinyint(3) unsigned NOT NULL default '0',
  `type` enum('Node','Serial','Power','Dnard','Control','Trunk','OuterControl','Unused','Management') NOT NULL default 'Node',
  `node_id1` char(32) NOT NULL default '',
  `card1` tinyint(3) unsigned NOT NULL default '0',
  `port1` smallint(5) unsigned NOT NULL default '0',
  `iface1` tinytext,
  `node_id2` char(32) NOT NULL default '',
  `card2` tinyint(3) unsigned NOT NULL default '0',
  `port2` smallint(5) unsigned NOT NULL default '0',
  `iface2` tinytext,
  `logical` tinyint(1) unsigned NOT NULL default '0',
  `trunkid` mediumint(4) unsigned NOT NULL default '0',
  `external_interface` tinytext,
  `external_wire` tinytext,
  PRIMARY KEY  (`node_id1`,`card1`,`port1`),
  KEY `node_id2` (`node_id2`,`card2`),
  KEY `dest` (`node_id2`,`card2`,`port2`),
  KEY `src` (`node_id1`,`card1`,`port1`),
  KEY `node_id1_iface1` (`node_id1`,`iface1`(32)),
  KEY `node_id2_iface2` (`node_id2`,`iface2`(32))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
