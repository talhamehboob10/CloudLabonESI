-- MySQL dump 10.13  Distrib 8.0.27, for Linux (x86_64)
--
-- Host: localhost    Database: tbdb
-- ------------------------------------------------------
-- Server version	8.0.27-0ubuntu0.20.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `tbdb`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `tbdb` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `tbdb`;

--
-- Table structure for table `accessed_files`
--

DROP TABLE IF EXISTS `accessed_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accessed_files` (
  `fn` text NOT NULL,
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`fn`(255)),
  KEY `idx` (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `accessed_files`
--

LOCK TABLES `accessed_files` WRITE;
/*!40000 ALTER TABLE `accessed_files` DISABLE KEYS */;
/*!40000 ALTER TABLE `accessed_files` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `active_checkups`
--

DROP TABLE IF EXISTS `active_checkups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `active_checkups` (
  `object` varchar(128) NOT NULL DEFAULT '',
  `object_type` varchar(64) NOT NULL DEFAULT '',
  `type` varchar(64) NOT NULL DEFAULT '',
  `state` varchar(16) NOT NULL DEFAULT 'new',
  `start` datetime DEFAULT NULL,
  PRIMARY KEY (`object`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `active_checkups`
--

LOCK TABLES `active_checkups` WRITE;
/*!40000 ALTER TABLE `active_checkups` DISABLE KEYS */;
/*!40000 ALTER TABLE `active_checkups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `addr_pool_history`
--

DROP TABLE IF EXISTS `addr_pool_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `addr_pool_history` (
  `history_id` int unsigned NOT NULL AUTO_INCREMENT,
  `pool_id` varchar(32) NOT NULL DEFAULT '',
  `op` enum('alloc','free') NOT NULL DEFAULT 'alloc',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned DEFAULT NULL,
  `stamp` int unsigned DEFAULT NULL,
  `addr` varchar(15) DEFAULT NULL,
  `version` enum('ipv4','ipv6') NOT NULL DEFAULT 'ipv4',
  PRIMARY KEY (`history_id`),
  KEY `exptidx` (`exptidx`),
  KEY `stamp` (`stamp`),
  KEY `addr` (`addr`),
  KEY `addrstamp` (`addr`,`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `addr_pool_history`
--

LOCK TABLES `addr_pool_history` WRITE;
/*!40000 ALTER TABLE `addr_pool_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `addr_pool_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `address_ranges`
--

DROP TABLE IF EXISTS `address_ranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `address_ranges` (
  `baseaddr` varchar(40) NOT NULL DEFAULT '',
  `prefix` tinyint unsigned NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `role` enum('public','internal') NOT NULL DEFAULT 'internal',
  PRIMARY KEY (`baseaddr`,`prefix`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `address_ranges`
--

LOCK TABLES `address_ranges` WRITE;
/*!40000 ALTER TABLE `address_ranges` DISABLE KEYS */;
/*!40000 ALTER TABLE `address_ranges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_events`
--

DROP TABLE IF EXISTS `apt_aggregate_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_events` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `event` enum('up','down','offline','unknown') NOT NULL DEFAULT 'unknown',
  `stamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`urn`,`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_events`
--

LOCK TABLES `apt_aggregate_events` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_nodes`
--

DROP TABLE IF EXISTS `apt_aggregate_nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_nodes` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `available` tinyint(1) NOT NULL DEFAULT '0',
  `reservable` tinyint(1) NOT NULL DEFAULT '0',
  `updated` datetime DEFAULT NULL,
  PRIMARY KEY (`urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_nodes`
--

LOCK TABLES `apt_aggregate_nodes` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_nodes` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_nodetype_attributes`
--

DROP TABLE IF EXISTS `apt_aggregate_nodetype_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_nodetype_attributes` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY (`urn`,`type`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_nodetype_attributes`
--

LOCK TABLES `apt_aggregate_nodetype_attributes` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_nodetype_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_nodetype_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_nodetypes`
--

DROP TABLE IF EXISTS `apt_aggregate_nodetypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_nodetypes` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `count` int DEFAULT '0',
  `free` int DEFAULT '0',
  `updated` datetime DEFAULT NULL,
  PRIMARY KEY (`urn`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_nodetypes`
--

LOCK TABLES `apt_aggregate_nodetypes` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_nodetypes` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_nodetypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_radio_frontends`
--

DROP TABLE IF EXISTS `apt_aggregate_radio_frontends`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_radio_frontends` (
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `iface` varchar(32) NOT NULL DEFAULT '',
  `frontend` enum('TDD','FDD','none') NOT NULL DEFAULT 'none',
  `transmit_frequencies` text,
  `receive_frequencies` text,
  `monitored` tinyint(1) NOT NULL DEFAULT '0',
  `notes` text,
  PRIMARY KEY (`aggregate_urn`,`node_id`,`iface`,`frontend`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_radio_frontends`
--

LOCK TABLES `apt_aggregate_radio_frontends` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_radio_frontends` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_radio_frontends` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_radio_info`
--

DROP TABLE IF EXISTS `apt_aggregate_radio_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_radio_info` (
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `location` varchar(64) NOT NULL DEFAULT '',
  `radio_type` tinytext,
  `power_id` varchar(32) DEFAULT NULL,
  `cnuc_id` varchar(32) DEFAULT NULL,
  `grouping` varchar(32) DEFAULT NULL,
  `notes` text,
  PRIMARY KEY (`aggregate_urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_radio_info`
--

LOCK TABLES `apt_aggregate_radio_info` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_radio_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_radio_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_radio_locations`
--

DROP TABLE IF EXISTS `apt_aggregate_radio_locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_radio_locations` (
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `location` varchar(64) NOT NULL DEFAULT '',
  `itype` enum('FE','ME','BS','PE','unknown') NOT NULL DEFAULT 'unknown',
  `latitude` float(8,5) DEFAULT NULL,
  `longitude` float(8,5) DEFAULT NULL,
  `mapurl` tinytext,
  `streeturl` tinytext,
  `notes` text,
  PRIMARY KEY (`aggregate_urn`,`location`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_radio_locations`
--

LOCK TABLES `apt_aggregate_radio_locations` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_radio_locations` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_radio_locations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_radioinfo`
--

DROP TABLE IF EXISTS `apt_aggregate_radioinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_radioinfo` (
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `location` varchar(64) NOT NULL DEFAULT '',
  `installation_type` enum('FE','ME','BS','unknown') NOT NULL DEFAULT 'unknown',
  `radio_type` tinytext,
  `transmit_frequencies` text,
  `receive_frequencies` text,
  `power_id` varchar(32) DEFAULT NULL,
  `cnuc_id` varchar(32) DEFAULT NULL,
  `monitored` tinyint(1) NOT NULL DEFAULT '0',
  `notes` text,
  PRIMARY KEY (`aggregate_urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_radioinfo`
--

LOCK TABLES `apt_aggregate_radioinfo` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_radioinfo` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_radioinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_reservable_nodes`
--

DROP TABLE IF EXISTS `apt_aggregate_reservable_nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_reservable_nodes` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `available` tinyint(1) NOT NULL DEFAULT '0',
  `updated` datetime DEFAULT NULL,
  PRIMARY KEY (`urn`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_reservable_nodes`
--

LOCK TABLES `apt_aggregate_reservable_nodes` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_reservable_nodes` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_reservable_nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregate_status`
--

DROP TABLE IF EXISTS `apt_aggregate_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregate_status` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `status` enum('up','down','offline','unknown') NOT NULL DEFAULT 'unknown',
  `last_success` datetime DEFAULT NULL,
  `last_attempt` datetime DEFAULT NULL,
  `pcount` int DEFAULT '0',
  `pfree` int DEFAULT '0',
  `vcount` int DEFAULT '0',
  `vfree` int DEFAULT '0',
  `last_error` text,
  PRIMARY KEY (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregate_status`
--

LOCK TABLES `apt_aggregate_status` WRITE;
/*!40000 ALTER TABLE `apt_aggregate_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregate_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_aggregates`
--

DROP TABLE IF EXISTS `apt_aggregates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_aggregates` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `name` varchar(32) NOT NULL DEFAULT '',
  `nickname` varchar(32) NOT NULL DEFAULT '',
  `abbreviation` varchar(32) NOT NULL DEFAULT '',
  `adminonly` tinyint(1) NOT NULL DEFAULT '0',
  `isfederate` tinyint(1) NOT NULL DEFAULT '0',
  `isFE` tinyint(1) NOT NULL DEFAULT '0',
  `ismobile` tinyint(1) NOT NULL DEFAULT '0',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  `noupdate` tinyint(1) NOT NULL DEFAULT '0',
  `nomonitor` tinyint(1) NOT NULL DEFAULT '0',
  `nolocalimages` tinyint(1) NOT NULL DEFAULT '0',
  `prestageimages` tinyint(1) NOT NULL DEFAULT '0',
  `deferrable` tinyint(1) NOT NULL DEFAULT '0',
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `weburl` tinytext,
  `has_datasets` tinyint(1) NOT NULL DEFAULT '0',
  `does_syncthing` tinyint(1) NOT NULL DEFAULT '0',
  `reservations` tinyint(1) NOT NULL DEFAULT '0',
  `panicpoweroff` tinyint(1) NOT NULL DEFAULT '0',
  `precalcmaxext` tinyint(1) NOT NULL DEFAULT '0',
  `portals` set('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `canuse_feature` varchar(64) DEFAULT NULL,
  `latitude` float(8,5) DEFAULT NULL,
  `longitude` float(8,5) DEFAULT NULL,
  `required_license` int DEFAULT NULL,
  `jsondata` text,
  PRIMARY KEY (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_aggregates`
--

LOCK TABLES `apt_aggregates` WRITE;
/*!40000 ALTER TABLE `apt_aggregates` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_aggregates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_announcement_info`
--

DROP TABLE IF EXISTS `apt_announcement_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_announcement_info` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `aid` int NOT NULL DEFAULT '0',
  `uid_idx` int DEFAULT NULL,
  `dismissed` tinyint(1) NOT NULL DEFAULT '0',
  `clicked` tinyint(1) NOT NULL DEFAULT '0',
  `seen_count` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_announcement_info`
--

LOCK TABLES `apt_announcement_info` WRITE;
/*!40000 ALTER TABLE `apt_announcement_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_announcement_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_announcements`
--

DROP TABLE IF EXISTS `apt_announcements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_announcements` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL,
  `created` datetime DEFAULT NULL,
  `uid_idx` int DEFAULT NULL,
  `pid_idx` int DEFAULT NULL,
  `genesis` varchar(64) NOT NULL DEFAULT 'emulab',
  `portal` varchar(64) NOT NULL DEFAULT 'emulab',
  `priority` tinyint(1) NOT NULL DEFAULT '3',
  `retired` tinyint(1) NOT NULL DEFAULT '0',
  `max_seen` int NOT NULL DEFAULT '20',
  `text` mediumtext,
  `style` varchar(64) NOT NULL DEFAULT 'alert-info',
  `link_label` tinytext,
  `link_url` tinytext,
  `display_start` datetime DEFAULT NULL,
  `display_end` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_announcements`
--

LOCK TABLES `apt_announcements` WRITE;
/*!40000 ALTER TABLE `apt_announcements` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_announcements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_datasets`
--

DROP TABLE IF EXISTS `apt_datasets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_datasets` (
  `idx` int unsigned NOT NULL DEFAULT '0',
  `dataset_id` varchar(32) NOT NULL DEFAULT '',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator_uid` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `aggregate_urn` varchar(128) DEFAULT NULL,
  `remote_urn` varchar(128) NOT NULL DEFAULT '',
  `remote_uuid` varchar(40) NOT NULL DEFAULT '',
  `remote_url` tinytext,
  `created` datetime DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `expires` datetime DEFAULT NULL,
  `last_used` datetime DEFAULT NULL,
  `state` enum('new','valid','unapproved','grace','locked','expired','busy','failed') NOT NULL DEFAULT 'new',
  `type` enum('stdataset','ltdataset','imdataset','unknown') NOT NULL DEFAULT 'unknown',
  `fstype` varchar(40) NOT NULL DEFAULT 'none',
  `size` int unsigned NOT NULL DEFAULT '0',
  `read_access` enum('project','global') NOT NULL DEFAULT 'project',
  `write_access` enum('creator','project') NOT NULL DEFAULT 'creator',
  `public` tinyint(1) NOT NULL DEFAULT '0',
  `shared` tinyint(1) NOT NULL DEFAULT '0',
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  `webtask_id` varchar(128) DEFAULT NULL,
  `error` text,
  `credential_string` text,
  PRIMARY KEY (`idx`),
  UNIQUE KEY `plid` (`pid_idx`,`dataset_id`),
  UNIQUE KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_datasets`
--

LOCK TABLES `apt_datasets` WRITE;
/*!40000 ALTER TABLE `apt_datasets` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_datasets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_deferred_instances`
--

DROP TABLE IF EXISTS `apt_deferred_instances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_deferred_instances` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `start_at` datetime DEFAULT NULL,
  `last_retry` datetime DEFAULT NULL,
  `retry_until` datetime DEFAULT NULL,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_deferred_instances`
--

LOCK TABLES `apt_deferred_instances` WRITE;
/*!40000 ALTER TABLE `apt_deferred_instances` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_deferred_instances` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_extension_group_policies`
--

DROP TABLE IF EXISTS `apt_extension_group_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_extension_group_policies` (
  `pid` varchar(48) DEFAULT NULL,
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator` varchar(8) DEFAULT NULL,
  `creator_idx` mediumint unsigned DEFAULT NULL,
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  `limit` int unsigned DEFAULT NULL,
  `admin_after_limit` tinyint(1) NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `reason` mediumtext,
  PRIMARY KEY (`pid_idx`,`gid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_extension_group_policies`
--

LOCK TABLES `apt_extension_group_policies` WRITE;
/*!40000 ALTER TABLE `apt_extension_group_policies` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_extension_group_policies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_extension_user_policies`
--

DROP TABLE IF EXISTS `apt_extension_user_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_extension_user_policies` (
  `uid` varchar(8) DEFAULT NULL,
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator` varchar(8) DEFAULT NULL,
  `creator_idx` mediumint unsigned DEFAULT NULL,
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  `limit` int unsigned DEFAULT NULL,
  `admin_after_limit` tinyint(1) NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `reason` mediumtext,
  PRIMARY KEY (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_extension_user_policies`
--

LOCK TABLES `apt_extension_user_policies` WRITE;
/*!40000 ALTER TABLE `apt_extension_user_policies` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_extension_user_policies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_global_rfranges`
--

DROP TABLE IF EXISTS `apt_global_rfranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_global_rfranges` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `range_id` varchar(32) DEFAULT NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_global_rfranges`
--

LOCK TABLES `apt_global_rfranges` WRITE;
/*!40000 ALTER TABLE `apt_global_rfranges` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_global_rfranges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_aggregate_history`
--

DROP TABLE IF EXISTS `apt_instance_aggregate_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_aggregate_history` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `status` varchar(32) DEFAULT NULL,
  `added` datetime DEFAULT NULL,
  `started` datetime DEFAULT NULL,
  `destroyed` datetime DEFAULT NULL,
  `physnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `virtnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `deferred` tinyint(1) NOT NULL DEFAULT '0',
  `deferred_reason` tinytext,
  `retry_count` smallint unsigned NOT NULL DEFAULT '0',
  `last_retry` datetime DEFAULT NULL,
  `public_url` tinytext,
  `webtask_id` varchar(128) NOT NULL DEFAULT '',
  `extension_needpush` datetime DEFAULT NULL,
  `manifest_needpush` datetime DEFAULT NULL,
  `prestage_data` mediumtext,
  `manifest` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_aggregate_history`
--

LOCK TABLES `apt_instance_aggregate_history` WRITE;
/*!40000 ALTER TABLE `apt_instance_aggregate_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_aggregate_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_aggregates`
--

DROP TABLE IF EXISTS `apt_instance_aggregates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_aggregates` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `status` varchar(32) DEFAULT NULL,
  `added` datetime DEFAULT NULL,
  `started` datetime DEFAULT NULL,
  `destroyed` datetime DEFAULT NULL,
  `physnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `virtnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `deferred` tinyint(1) NOT NULL DEFAULT '0',
  `deferred_reason` tinytext,
  `retry_count` smallint unsigned NOT NULL DEFAULT '0',
  `last_retry` datetime DEFAULT NULL,
  `public_url` tinytext,
  `webtask_id` varchar(128) NOT NULL DEFAULT '',
  `extension_needpush` datetime DEFAULT NULL,
  `manifest_needpush` datetime DEFAULT NULL,
  `prestage_data` mediumtext,
  `manifest` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_aggregates`
--

LOCK TABLES `apt_instance_aggregates` WRITE;
/*!40000 ALTER TABLE `apt_instance_aggregates` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_aggregates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_bus_routes`
--

DROP TABLE IF EXISTS `apt_instance_bus_routes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_bus_routes` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `routeid` smallint NOT NULL DEFAULT '0',
  `routedescription` tinytext,
  PRIMARY KEY (`uuid`,`routeid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_bus_routes`
--

LOCK TABLES `apt_instance_bus_routes` WRITE;
/*!40000 ALTER TABLE `apt_instance_bus_routes` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_bus_routes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_extension_info`
--

DROP TABLE IF EXISTS `apt_instance_extension_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_extension_info` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(16) NOT NULL DEFAULT '',
  `tstamp` datetime DEFAULT NULL,
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `action` enum('request','deny','info') NOT NULL DEFAULT 'request',
  `wanted` int unsigned NOT NULL DEFAULT '0',
  `granted` int unsigned DEFAULT NULL,
  `needapproval` tinyint(1) NOT NULL DEFAULT '0',
  `autoapproved` tinyint(1) NOT NULL DEFAULT '0',
  `autoapproved_reason` tinytext,
  `autoapproved_metrics` mediumtext,
  `maxextension` datetime DEFAULT NULL,
  `expiration` datetime DEFAULT NULL,
  `admin` tinyint(1) NOT NULL DEFAULT '0',
  `reason` mediumtext,
  `message` mediumtext,
  PRIMARY KEY (`uuid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_extension_info`
--

LOCK TABLES `apt_instance_extension_info` WRITE;
/*!40000 ALTER TABLE `apt_instance_extension_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_extension_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_failures`
--

DROP TABLE IF EXISTS `apt_instance_failures`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_failures` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `profile_id` int unsigned NOT NULL DEFAULT '0',
  `profile_version` int unsigned NOT NULL DEFAULT '0',
  `slice_uuid` varchar(40) DEFAULT NULL,
  `creator` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator_uuid` varchar(40) NOT NULL DEFAULT '',
  `pid` varchar(48) DEFAULT NULL,
  `pid_idx` mediumint unsigned DEFAULT NULL,
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `start_at` datetime DEFAULT NULL,
  `started` datetime DEFAULT NULL,
  `stop_at` datetime DEFAULT NULL,
  `exitcode` int DEFAULT '0',
  `exitmessage` mediumtext,
  `public_url` tinytext,
  `logfileid` varchar(40) DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_failures`
--

LOCK TABLES `apt_instance_failures` WRITE;
/*!40000 ALTER TABLE `apt_instance_failures` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_failures` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_history`
--

DROP TABLE IF EXISTS `apt_instance_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_history` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `profile_id` int unsigned NOT NULL DEFAULT '0',
  `profile_version` int unsigned NOT NULL DEFAULT '0',
  `slice_uuid` varchar(40) NOT NULL DEFAULT '',
  `creator` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator_uuid` varchar(40) NOT NULL DEFAULT '',
  `pid` varchar(48) DEFAULT NULL,
  `pid_idx` mediumint unsigned DEFAULT NULL,
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `aggregate_urn` varchar(128) DEFAULT NULL,
  `public_url` tinytext,
  `logfileid` varchar(40) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `start_at` datetime DEFAULT NULL,
  `started` datetime DEFAULT NULL,
  `stop_at` datetime DEFAULT NULL,
  `destroyed` datetime DEFAULT NULL,
  `expired` tinyint(1) NOT NULL DEFAULT '0',
  `extension_count` smallint unsigned NOT NULL DEFAULT '0',
  `extension_days` smallint unsigned NOT NULL DEFAULT '0',
  `extension_hours` int unsigned NOT NULL DEFAULT '0',
  `physnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `virtnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `servername` tinytext,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `repourl` tinytext,
  `reponame` varchar(40) DEFAULT NULL,
  `reporef` varchar(128) DEFAULT NULL,
  `repohash` varchar(64) DEFAULT NULL,
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
  KEY `destroyed` (`destroyed`),
  KEY `profile_id_created` (`profile_id`,`created`),
  KEY `portal_started` (`portal`,`started`),
  KEY `portal_creator` (`portal`,`creator_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_history`
--

LOCK TABLES `apt_instance_history` WRITE;
/*!40000 ALTER TABLE `apt_instance_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_rfrange_history`
--

DROP TABLE IF EXISTS `apt_instance_rfrange_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_rfrange_history` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`uuid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_rfrange_history`
--

LOCK TABLES `apt_instance_rfrange_history` WRITE;
/*!40000 ALTER TABLE `apt_instance_rfrange_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_rfrange_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_rfranges`
--

DROP TABLE IF EXISTS `apt_instance_rfranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_rfranges` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`uuid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_rfranges`
--

LOCK TABLES `apt_instance_rfranges` WRITE;
/*!40000 ALTER TABLE `apt_instance_rfranges` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_rfranges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_slice_status`
--

DROP TABLE IF EXISTS `apt_instance_slice_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_slice_status` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `timestamp` int unsigned NOT NULL DEFAULT '0',
  `modified` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `slice_data` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_slice_status`
--

LOCK TABLES `apt_instance_slice_status` WRITE;
/*!40000 ALTER TABLE `apt_instance_slice_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_slice_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instance_sliver_status`
--

DROP TABLE IF EXISTS `apt_instance_sliver_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instance_sliver_status` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `sliver_urn` varchar(128) NOT NULL DEFAULT '',
  `resource_id` varchar(32) NOT NULL DEFAULT '',
  `client_id` varchar(32) NOT NULL DEFAULT '',
  `timestamp` int unsigned NOT NULL DEFAULT '0',
  `modified` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `sliver_data` mediumtext,
  `frisbee_data` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`,`sliver_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instance_sliver_status`
--

LOCK TABLES `apt_instance_sliver_status` WRITE;
/*!40000 ALTER TABLE `apt_instance_sliver_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instance_sliver_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_instances`
--

DROP TABLE IF EXISTS `apt_instances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_instances` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `name` varchar(16) DEFAULT NULL,
  `profile_id` int unsigned NOT NULL DEFAULT '0',
  `profile_version` int unsigned NOT NULL DEFAULT '0',
  `slice_uuid` varchar(40) NOT NULL DEFAULT '',
  `creator` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator_uuid` varchar(40) NOT NULL DEFAULT '',
  `pid` varchar(48) DEFAULT NULL,
  `pid_idx` mediumint unsigned DEFAULT NULL,
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `aggregate_urn` varchar(128) DEFAULT NULL,
  `public_url` tinytext,
  `webtask_id` varchar(128) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `start_at` datetime DEFAULT NULL,
  `started` datetime DEFAULT NULL,
  `stop_at` datetime DEFAULT NULL,
  `maxextension` datetime DEFAULT NULL,
  `maxextension_timestamp` datetime DEFAULT NULL,
  `status` varchar(32) DEFAULT NULL,
  `status_timestamp` datetime DEFAULT NULL,
  `canceled` tinyint NOT NULL DEFAULT '0',
  `canceled_timestamp` datetime DEFAULT NULL,
  `paniced` tinyint NOT NULL DEFAULT '0',
  `paniced_timestamp` datetime DEFAULT NULL,
  `admin_lockdown` tinyint(1) NOT NULL DEFAULT '0',
  `user_lockdown` tinyint(1) NOT NULL DEFAULT '0',
  `admin_notes` mediumtext,
  `extension_code` varchar(32) DEFAULT NULL,
  `extension_reason` mediumtext,
  `extension_history` mediumtext,
  `extension_adminonly` tinyint(1) NOT NULL DEFAULT '0',
  `extension_disabled` tinyint(1) NOT NULL DEFAULT '0',
  `extension_disabled_reason` mediumtext,
  `extension_limit` int unsigned DEFAULT NULL,
  `extension_limit_reason` mediumtext,
  `extension_admin_after_limit` tinyint(1) NOT NULL DEFAULT '0',
  `extension_requested` tinyint(1) NOT NULL DEFAULT '0',
  `extension_denied` tinyint(1) NOT NULL DEFAULT '0',
  `extension_denied_reason` mediumtext,
  `extension_count` smallint unsigned NOT NULL DEFAULT '0',
  `extension_days` smallint unsigned NOT NULL DEFAULT '0',
  `extension_hours` int unsigned NOT NULL DEFAULT '0',
  `physnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `virtnode_count` smallint unsigned NOT NULL DEFAULT '0',
  `servername` tinytext,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `monitor_pid` int DEFAULT '0',
  `needupdate` tinyint NOT NULL DEFAULT '0',
  `isopenstack` tinyint(1) NOT NULL DEFAULT '0',
  `logfileid` varchar(40) DEFAULT NULL,
  `cert` mediumtext,
  `privkey` mediumtext,
  `repourl` tinytext,
  `reponame` varchar(40) DEFAULT NULL,
  `reporef` varchar(128) DEFAULT NULL,
  `repohash` varchar(64) DEFAULT NULL,
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_instances`
--

LOCK TABLES `apt_instances` WRITE;
/*!40000 ALTER TABLE `apt_instances` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_instances` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_mobile_aggregates`
--

DROP TABLE IF EXISTS `apt_mobile_aggregates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_mobile_aggregates` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `type` enum('bus') DEFAULT NULL,
  PRIMARY KEY (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_mobile_aggregates`
--

LOCK TABLES `apt_mobile_aggregates` WRITE;
/*!40000 ALTER TABLE `apt_mobile_aggregates` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_mobile_aggregates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_mobile_bus_route_change_history`
--

DROP TABLE IF EXISTS `apt_mobile_bus_route_change_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_mobile_bus_route_change_history` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `urn` varchar(128) NOT NULL DEFAULT '',
  `busid` int NOT NULL DEFAULT '0',
  `routeid` smallint DEFAULT NULL,
  `routedescription` tinytext,
  `route_changed` datetime DEFAULT NULL,
  PRIMARY KEY (`busid`,`idx`),
  KEY `urn` (`urn`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_mobile_bus_route_change_history`
--

LOCK TABLES `apt_mobile_bus_route_change_history` WRITE;
/*!40000 ALTER TABLE `apt_mobile_bus_route_change_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_mobile_bus_route_change_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_mobile_bus_routes`
--

DROP TABLE IF EXISTS `apt_mobile_bus_routes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_mobile_bus_routes` (
  `routeid` smallint NOT NULL DEFAULT '0',
  `description` tinytext,
  PRIMARY KEY (`routeid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_mobile_bus_routes`
--

LOCK TABLES `apt_mobile_bus_routes` WRITE;
/*!40000 ALTER TABLE `apt_mobile_bus_routes` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_mobile_bus_routes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_mobile_buses`
--

DROP TABLE IF EXISTS `apt_mobile_buses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_mobile_buses` (
  `urn` varchar(128) NOT NULL DEFAULT '',
  `busid` int NOT NULL DEFAULT '0',
  `last_ping` datetime DEFAULT NULL,
  `last_control_ping` datetime DEFAULT NULL,
  `last_report` datetime DEFAULT NULL,
  `routeid` smallint DEFAULT NULL,
  `routedescription` tinytext,
  `route_changed` datetime DEFAULT NULL,
  `latitude` float(8,5) NOT NULL DEFAULT '0.00000',
  `longitude` float(8,5) NOT NULL DEFAULT '0.00000',
  `speed` float(8,2) NOT NULL DEFAULT '0.00',
  `heading` smallint NOT NULL DEFAULT '0',
  `location_stamp` datetime DEFAULT NULL,
  `gpsd_latitude` float(12,8) NOT NULL DEFAULT '0.00000000',
  `gpsd_longitude` float(12,8) NOT NULL DEFAULT '0.00000000',
  `gpsd_speed` float(8,2) NOT NULL DEFAULT '0.00',
  `gpsd_heading` float(8,2) NOT NULL DEFAULT '0.00',
  `gpsd_stamp` datetime DEFAULT NULL,
  PRIMARY KEY (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_mobile_buses`
--

LOCK TABLES `apt_mobile_buses` WRITE;
/*!40000 ALTER TABLE `apt_mobile_buses` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_mobile_buses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_named_rfranges`
--

DROP TABLE IF EXISTS `apt_named_rfranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_named_rfranges` (
  `range_id` varchar(32) NOT NULL DEFAULT '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`range_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_named_rfranges`
--

LOCK TABLES `apt_named_rfranges` WRITE;
/*!40000 ALTER TABLE `apt_named_rfranges` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_named_rfranges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_news`
--

DROP TABLE IF EXISTS `apt_news`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_news` (
  `idx` int NOT NULL AUTO_INCREMENT,
  `title` tinytext,
  `created` datetime DEFAULT NULL,
  `author` varchar(32) DEFAULT NULL,
  `author_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `portals` set('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `body` text,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_news`
--

LOCK TABLES `apt_news` WRITE;
/*!40000 ALTER TABLE `apt_news` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_news` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_parameter_sets`
--

DROP TABLE IF EXISTS `apt_parameter_sets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_parameter_sets` (
  `uuid` varchar(40) NOT NULL,
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `description` text,
  `public` tinyint(1) NOT NULL DEFAULT '0',
  `global` tinyint(1) NOT NULL DEFAULT '0',
  `profileid` int unsigned NOT NULL DEFAULT '0',
  `version_uuid` varchar(40) DEFAULT NULL,
  `reporef` varchar(128) DEFAULT NULL,
  `repohash` varchar(64) DEFAULT NULL,
  `bindings` mediumtext,
  `hashkey` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`uuid`),
  UNIQUE KEY `uid_idx` (`uid_idx`,`profileid`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_parameter_sets`
--

LOCK TABLES `apt_parameter_sets` WRITE;
/*!40000 ALTER TABLE `apt_parameter_sets` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_parameter_sets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_profile_favorites`
--

DROP TABLE IF EXISTS `apt_profile_favorites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_profile_favorites` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `profileid` int unsigned NOT NULL DEFAULT '0',
  `marked` datetime DEFAULT NULL,
  PRIMARY KEY (`uid_idx`,`profileid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_profile_favorites`
--

LOCK TABLES `apt_profile_favorites` WRITE;
/*!40000 ALTER TABLE `apt_profile_favorites` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_profile_favorites` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_profile_images`
--

DROP TABLE IF EXISTS `apt_profile_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_profile_images` (
  `name` varchar(64) NOT NULL DEFAULT '',
  `profileid` int unsigned NOT NULL DEFAULT '0',
  `version` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `client_id` varchar(32) NOT NULL DEFAULT '',
  `authority` varchar(64) DEFAULT NULL,
  `ospid` varchar(64) DEFAULT NULL,
  `os` varchar(128) DEFAULT NULL,
  `osvers` int DEFAULT NULL,
  `local_pid` varchar(48) DEFAULT NULL,
  `image` varchar(256) NOT NULL DEFAULT '',
  PRIMARY KEY (`profileid`,`version`,`client_id`),
  KEY `image` (`image`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_profile_images`
--

LOCK TABLES `apt_profile_images` WRITE;
/*!40000 ALTER TABLE `apt_profile_images` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_profile_images` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_profile_versions`
--

DROP TABLE IF EXISTS `apt_profile_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_profile_versions` (
  `name` varchar(64) NOT NULL DEFAULT '',
  `profileid` int unsigned NOT NULL DEFAULT '0',
  `version` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `updater` varchar(8) NOT NULL DEFAULT '',
  `updater_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `last_use` datetime DEFAULT NULL,
  `published` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  `nodelete` tinyint(1) NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL,
  `parent_profileid` int unsigned DEFAULT NULL,
  `parent_version` int unsigned DEFAULT NULL,
  `status` varchar(32) DEFAULT NULL,
  `repourl` tinytext,
  `reponame` varchar(40) DEFAULT NULL,
  `reporef` varchar(128) DEFAULT NULL,
  `repohash` varchar(64) DEFAULT NULL,
  `repokey` varchar(64) DEFAULT NULL,
  `portal_converted` tinyint(1) NOT NULL DEFAULT '0',
  `rspec` mediumtext,
  `script` mediumtext,
  `paramdefs` mediumtext,
  `hashkey` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`profileid`,`version`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `hashkey` (`hashkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_profile_versions`
--

LOCK TABLES `apt_profile_versions` WRITE;
/*!40000 ALTER TABLE `apt_profile_versions` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_profile_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_profiles`
--

DROP TABLE IF EXISTS `apt_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_profiles` (
  `name` varchar(64) NOT NULL DEFAULT '',
  `profileid` int unsigned NOT NULL DEFAULT '0',
  `version` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL,
  `webtask_id` varchar(128) DEFAULT NULL,
  `public` tinyint(1) NOT NULL DEFAULT '0',
  `shared` tinyint(1) NOT NULL DEFAULT '0',
  `listed` tinyint(1) NOT NULL DEFAULT '0',
  `topdog` tinyint(1) NOT NULL DEFAULT '0',
  `no_image_versions` tinyint(1) NOT NULL DEFAULT '0',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  `nodelete` tinyint(1) NOT NULL DEFAULT '0',
  `project_write` tinyint(1) NOT NULL DEFAULT '0',
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  `lastused` datetime DEFAULT NULL,
  `usecount` int DEFAULT '0',
  `examples_portals` set('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `hashkey` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`profileid`),
  UNIQUE KEY `pidname` (`pid_idx`,`name`,`version`),
  KEY `profileid_version` (`profileid`,`version`),
  KEY `hashkey` (`hashkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_profiles`
--

LOCK TABLES `apt_profiles` WRITE;
/*!40000 ALTER TABLE `apt_profiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_profiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_project_rfranges`
--

DROP TABLE IF EXISTS `apt_project_rfranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_project_rfranges` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `range_id` varchar(32) DEFAULT NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid_idx`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_project_rfranges`
--

LOCK TABLES `apt_project_rfranges` WRITE;
/*!40000 ALTER TABLE `apt_project_rfranges` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_project_rfranges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_group_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_group_history` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator_uid` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `reason` mediumtext,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_group_history`
--

LOCK TABLES `apt_reservation_group_history` WRITE;
/*!40000 ALTER TABLE `apt_reservation_group_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_group_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_group_reservation_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_reservation_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_group_reservation_history` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `remote_uuid` varchar(40) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `count` smallint unsigned NOT NULL DEFAULT '0',
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `agguuid` (`uuid`,`aggregate_urn`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_group_reservation_history`
--

LOCK TABLES `apt_reservation_group_reservation_history` WRITE;
/*!40000 ALTER TABLE `apt_reservation_group_reservation_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_group_reservation_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_group_reservations`
--

DROP TABLE IF EXISTS `apt_reservation_group_reservations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_group_reservations` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `remote_uuid` varchar(40) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `count` smallint unsigned NOT NULL DEFAULT '0',
  `using` smallint unsigned DEFAULT NULL,
  `utilization` smallint unsigned DEFAULT NULL,
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `approved_pushed` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `canceled_pushed` datetime DEFAULT NULL,
  `cancel_canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `deleted_pushed` datetime DEFAULT NULL,
  `noidledetection_needpush` tinyint(1) NOT NULL DEFAULT '0',
  `jsondata` mediumtext,
  PRIMARY KEY (`uuid`,`aggregate_urn`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_group_reservations`
--

LOCK TABLES `apt_reservation_group_reservations` WRITE;
/*!40000 ALTER TABLE `apt_reservation_group_reservations` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_group_reservations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_group_rf_reservation_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_rf_reservation_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_group_rf_reservation_history` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `freq_uuid` varchar(40) NOT NULL DEFAULT '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `uuids` (`uuid`,`freq_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_group_rf_reservation_history`
--

LOCK TABLES `apt_reservation_group_rf_reservation_history` WRITE;
/*!40000 ALTER TABLE `apt_reservation_group_rf_reservation_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_group_rf_reservation_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_group_rf_reservations`
--

DROP TABLE IF EXISTS `apt_reservation_group_rf_reservations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_group_rf_reservations` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `freq_uuid` varchar(40) NOT NULL DEFAULT '',
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  PRIMARY KEY (`uuid`,`freq_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_group_rf_reservations`
--

LOCK TABLES `apt_reservation_group_rf_reservations` WRITE;
/*!40000 ALTER TABLE `apt_reservation_group_rf_reservations` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_group_rf_reservations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_group_route_reservation_history`
--

DROP TABLE IF EXISTS `apt_reservation_group_route_reservation_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_group_route_reservation_history` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `route_uuid` varchar(40) NOT NULL DEFAULT '',
  `routeid` smallint NOT NULL DEFAULT '0',
  `routename` tinytext,
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `uuids` (`uuid`,`route_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_group_route_reservation_history`
--

LOCK TABLES `apt_reservation_group_route_reservation_history` WRITE;
/*!40000 ALTER TABLE `apt_reservation_group_route_reservation_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_group_route_reservation_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_group_route_reservations`
--

DROP TABLE IF EXISTS `apt_reservation_group_route_reservations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_group_route_reservations` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `route_uuid` varchar(40) NOT NULL DEFAULT '',
  `routeid` smallint NOT NULL DEFAULT '0',
  `routename` tinytext,
  `submitted` datetime DEFAULT NULL,
  `approved` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  PRIMARY KEY (`uuid`,`route_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_group_route_reservations`
--

LOCK TABLES `apt_reservation_group_route_reservations` WRITE;
/*!40000 ALTER TABLE `apt_reservation_group_route_reservations` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_group_route_reservations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_groups`
--

DROP TABLE IF EXISTS `apt_reservation_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_groups` (
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator_uid` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `noidledetection` datetime DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  `notified` datetime DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `reason` mediumtext,
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_groups`
--

LOCK TABLES `apt_reservation_groups` WRITE;
/*!40000 ALTER TABLE `apt_reservation_groups` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_history_actions`
--

DROP TABLE IF EXISTS `apt_reservation_history_actions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_history_actions` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `reservation_uuid` varchar(40) DEFAULT NULL,
  `stamp` datetime DEFAULT NULL,
  `action` enum('validate','submit','approve','delete','cancel','restore') NOT NULL DEFAULT 'validate',
  PRIMARY KEY (`idx`),
  KEY `agguuid` (`aggregate_urn`,`reservation_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_history_actions`
--

LOCK TABLES `apt_reservation_history_actions` WRITE;
/*!40000 ALTER TABLE `apt_reservation_history_actions` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_history_actions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_reservation_history_details`
--

DROP TABLE IF EXISTS `apt_reservation_history_details`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_reservation_history_details` (
  `idx` mediumint unsigned NOT NULL DEFAULT '0',
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `reservation_uuid` varchar(40) DEFAULT NULL,
  `pid` varchar(48) DEFAULT NULL,
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid` varchar(8) DEFAULT NULL,
  `uid_idx` mediumint unsigned DEFAULT NULL,
  `stamp` datetime DEFAULT NULL,
  `nodes` smallint NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `refused` tinyint(1) NOT NULL DEFAULT '0',
  `approved` tinyint(1) NOT NULL DEFAULT '0',
  `reason` mediumtext,
  PRIMARY KEY (`idx`),
  KEY `agguuid` (`aggregate_urn`,`reservation_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_reservation_history_details`
--

LOCK TABLES `apt_reservation_history_details` WRITE;
/*!40000 ALTER TABLE `apt_reservation_history_details` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_reservation_history_details` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_rfrange_sets`
--

DROP TABLE IF EXISTS `apt_rfrange_sets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_rfrange_sets` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `setname` varchar(32) NOT NULL DEFAULT '',
  `range_id` varchar(32) DEFAULT NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`setname`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_rfrange_sets`
--

LOCK TABLES `apt_rfrange_sets` WRITE;
/*!40000 ALTER TABLE `apt_rfrange_sets` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_rfrange_sets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_sas_grant_state`
--

DROP TABLE IF EXISTS `apt_sas_grant_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_sas_grant_state` (
  `cbsdid` varchar(128) NOT NULL DEFAULT '',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `grantid` varchar(128) NOT NULL DEFAULT '',
  `state` enum('granted','authorized','suspended','terminated') DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `freq_low` int DEFAULT '0',
  `freq_high` int DEFAULT '0',
  `interval` int DEFAULT '0',
  `expires` datetime DEFAULT NULL,
  `transmitExpires` datetime DEFAULT NULL,
  PRIMARY KEY (`cbsdid`,`idx`),
  UNIQUE KEY `grantid` (`cbsdid`,`grantid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_sas_grant_state`
--

LOCK TABLES `apt_sas_grant_state` WRITE;
/*!40000 ALTER TABLE `apt_sas_grant_state` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_sas_grant_state` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `apt_sas_radio_state`
--

DROP TABLE IF EXISTS `apt_sas_radio_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `apt_sas_radio_state` (
  `aggregate_urn` varchar(128) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `fccid` varchar(32) NOT NULL DEFAULT '',
  `serial` varchar(32) NOT NULL DEFAULT '',
  `state` enum('idle','unregistered','registered') DEFAULT 'idle',
  `updated` datetime DEFAULT NULL,
  `cbsdid` varchar(128) DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  PRIMARY KEY (`aggregate_urn`,`node_id`),
  UNIQUE KEY `cbsdid` (`cbsdid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `apt_sas_radio_state`
--

LOCK TABLES `apt_sas_radio_state` WRITE;
/*!40000 ALTER TABLE `apt_sas_radio_state` DISABLE KEYS */;
/*!40000 ALTER TABLE `apt_sas_radio_state` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `archive_revisions`
--

DROP TABLE IF EXISTS `archive_revisions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `archive_revisions` (
  `archive_idx` int unsigned NOT NULL DEFAULT '0',
  `revision` int unsigned NOT NULL AUTO_INCREMENT,
  `parent_revision` int unsigned DEFAULT NULL,
  `tag` varchar(64) NOT NULL DEFAULT '',
  `view` varchar(64) NOT NULL DEFAULT '',
  `date_created` int unsigned NOT NULL DEFAULT '0',
  `converted` tinyint(1) DEFAULT '0',
  `description` text,
  PRIMARY KEY (`archive_idx`,`revision`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `archive_revisions`
--

LOCK TABLES `archive_revisions` WRITE;
/*!40000 ALTER TABLE `archive_revisions` DISABLE KEYS */;
/*!40000 ALTER TABLE `archive_revisions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `archive_tags`
--

DROP TABLE IF EXISTS `archive_tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `archive_tags` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `tag` varchar(64) NOT NULL DEFAULT '',
  `archive_idx` int unsigned NOT NULL DEFAULT '0',
  `view` varchar(64) NOT NULL DEFAULT '',
  `date_created` int unsigned NOT NULL DEFAULT '0',
  `tagtype` enum('user','commit','savepoint','internal') NOT NULL DEFAULT 'internal',
  `version` tinyint(1) DEFAULT '0',
  `description` text,
  PRIMARY KEY (`idx`),
  UNIQUE KEY `tag` (`tag`,`archive_idx`,`view`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `archive_tags`
--

LOCK TABLES `archive_tags` WRITE;
/*!40000 ALTER TABLE `archive_tags` DISABLE KEYS */;
/*!40000 ALTER TABLE `archive_tags` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `archive_views`
--

DROP TABLE IF EXISTS `archive_views`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `archive_views` (
  `view` varchar(64) NOT NULL DEFAULT '',
  `archive_idx` int unsigned NOT NULL DEFAULT '0',
  `revision` int unsigned DEFAULT NULL,
  `current_tag` varchar(64) DEFAULT NULL,
  `previous_tag` varchar(64) DEFAULT NULL,
  `date_created` int unsigned NOT NULL DEFAULT '0',
  `branch_tag` varchar(64) DEFAULT NULL,
  `parent_view` varchar(64) DEFAULT NULL,
  `parent_revision` int unsigned DEFAULT NULL,
  PRIMARY KEY (`view`,`archive_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `archive_views`
--

LOCK TABLES `archive_views` WRITE;
/*!40000 ALTER TABLE `archive_views` DISABLE KEYS */;
/*!40000 ALTER TABLE `archive_views` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `archives`
--

DROP TABLE IF EXISTS `archives`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `archives` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `directory` tinytext,
  `date_created` int unsigned NOT NULL DEFAULT '0',
  `archived` tinyint(1) DEFAULT '0',
  `date_archived` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `archives`
--

LOCK TABLES `archives` WRITE;
/*!40000 ALTER TABLE `archives` DISABLE KEYS */;
/*!40000 ALTER TABLE `archives` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blob_files`
--

DROP TABLE IF EXISTS `blob_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blob_files` (
  `filename` varchar(255) NOT NULL,
  `hash` varchar(64) DEFAULT NULL,
  `hash_mtime` datetime DEFAULT NULL,
  PRIMARY KEY (`filename`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blob_files`
--

LOCK TABLES `blob_files` WRITE;
/*!40000 ALTER TABLE `blob_files` DISABLE KEYS */;
/*!40000 ALTER TABLE `blob_files` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blobs`
--

DROP TABLE IF EXISTS `blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blobs` (
  `uuid` varchar(40) NOT NULL,
  `filename` tinytext,
  `owner_uid` varchar(8) NOT NULL DEFAULT '',
  `vblob_id` varchar(40) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blobs`
--

LOCK TABLES `blobs` WRITE;
/*!40000 ALTER TABLE `blobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `blobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blockstore_attributes`
--

DROP TABLE IF EXISTS `blockstore_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blockstore_attributes` (
  `bsidx` int unsigned NOT NULL,
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') DEFAULT 'string',
  PRIMARY KEY (`bsidx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blockstore_attributes`
--

LOCK TABLES `blockstore_attributes` WRITE;
/*!40000 ALTER TABLE `blockstore_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `blockstore_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blockstore_state`
--

DROP TABLE IF EXISTS `blockstore_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blockstore_state` (
  `bsidx` int unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `bs_id` varchar(32) NOT NULL DEFAULT '',
  `remaining_capacity` int unsigned NOT NULL DEFAULT '0',
  `ready` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`bsidx`),
  UNIQUE KEY `nidbid` (`node_id`,`bs_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blockstore_state`
--

LOCK TABLES `blockstore_state` WRITE;
/*!40000 ALTER TABLE `blockstore_state` DISABLE KEYS */;
/*!40000 ALTER TABLE `blockstore_state` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blockstore_trees`
--

DROP TABLE IF EXISTS `blockstore_trees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blockstore_trees` (
  `bsidx` int unsigned NOT NULL,
  `aggidx` int unsigned NOT NULL DEFAULT '0',
  `hint` tinytext NOT NULL,
  PRIMARY KEY (`bsidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blockstore_trees`
--

LOCK TABLES `blockstore_trees` WRITE;
/*!40000 ALTER TABLE `blockstore_trees` DISABLE KEYS */;
/*!40000 ALTER TABLE `blockstore_trees` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blockstore_type_attributes`
--

DROP TABLE IF EXISTS `blockstore_type_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blockstore_type_attributes` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') DEFAULT 'string',
  `isfeature` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`type`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blockstore_type_attributes`
--

LOCK TABLES `blockstore_type_attributes` WRITE;
/*!40000 ALTER TABLE `blockstore_type_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `blockstore_type_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `blockstores`
--

DROP TABLE IF EXISTS `blockstores`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blockstores` (
  `bsidx` int unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `bs_id` varchar(32) NOT NULL DEFAULT '',
  `lease_idx` int unsigned NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `role` enum('element','compound','partition') NOT NULL DEFAULT 'element',
  `total_size` int unsigned NOT NULL DEFAULT '0',
  `exported` tinyint(1) NOT NULL DEFAULT '0',
  `inception` datetime DEFAULT NULL,
  PRIMARY KEY (`bsidx`),
  UNIQUE KEY `nidbid` (`node_id`,`bs_id`,`lease_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blockstores`
--

LOCK TABLES `blockstores` WRITE;
/*!40000 ALTER TABLE `blockstores` DISABLE KEYS */;
/*!40000 ALTER TABLE `blockstores` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bridges`
--

DROP TABLE IF EXISTS `bridges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bridges` (
  `pid` varchar(48) DEFAULT NULL,
  `eid` varchar(32) DEFAULT NULL,
  `exptidx` int NOT NULL DEFAULT '0',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `bridx` mediumint unsigned NOT NULL DEFAULT '0',
  `iface` varchar(8) NOT NULL DEFAULT '',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `vnode` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`node_id`,`bridx`,`iface`),
  KEY `pid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bridges`
--

LOCK TABLES `bridges` WRITE;
/*!40000 ALTER TABLE `bridges` DISABLE KEYS */;
/*!40000 ALTER TABLE `bridges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `buildings`
--

DROP TABLE IF EXISTS `buildings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `buildings` (
  `building` varchar(32) NOT NULL DEFAULT '',
  `image_path` tinytext,
  `title` tinytext NOT NULL,
  PRIMARY KEY (`building`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `buildings`
--

LOCK TABLES `buildings` WRITE;
/*!40000 ALTER TABLE `buildings` DISABLE KEYS */;
/*!40000 ALTER TABLE `buildings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cameras`
--

DROP TABLE IF EXISTS `cameras`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cameras` (
  `name` varchar(32) NOT NULL DEFAULT '',
  `building` varchar(32) NOT NULL DEFAULT '',
  `floor` varchar(32) NOT NULL DEFAULT '',
  `hostname` varchar(255) DEFAULT NULL,
  `port` smallint unsigned NOT NULL DEFAULT '6100',
  `device` varchar(64) NOT NULL DEFAULT '',
  `loc_x` float NOT NULL DEFAULT '0',
  `loc_y` float NOT NULL DEFAULT '0',
  `width` float NOT NULL DEFAULT '0',
  `height` float NOT NULL DEFAULT '0',
  `config` tinytext,
  `fixed_x` float NOT NULL DEFAULT '0',
  `fixed_y` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`name`,`building`,`floor`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cameras`
--

LOCK TABLES `cameras` WRITE;
/*!40000 ALTER TABLE `cameras` DISABLE KEYS */;
/*!40000 ALTER TABLE `cameras` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `causes`
--

DROP TABLE IF EXISTS `causes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `causes` (
  `cause` varchar(16) NOT NULL DEFAULT '',
  `cause_desc` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`cause`),
  UNIQUE KEY `cause_desc` (`cause_desc`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `causes`
--

LOCK TABLES `causes` WRITE;
/*!40000 ALTER TABLE `causes` DISABLE KEYS */;
INSERT INTO `causes` VALUES ('temp','Temp Resource Shortage'),('user','User Error'),('internal','Internal Error'),('software','Software Problem'),('hardware','Hardware Problem'),('unknown','Cause Unknown'),('canceled','Canceled');
/*!40000 ALTER TABLE `causes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cdroms`
--

DROP TABLE IF EXISTS `cdroms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cdroms` (
  `cdkey` varchar(64) NOT NULL DEFAULT '',
  `user_name` tinytext NOT NULL,
  `user_email` tinytext NOT NULL,
  `ready` tinyint NOT NULL DEFAULT '0',
  `requested` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `version` int unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`cdkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cdroms`
--

LOCK TABLES `cdroms` WRITE;
/*!40000 ALTER TABLE `cdroms` DISABLE KEYS */;
/*!40000 ALTER TABLE `cdroms` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `checkup_types`
--

DROP TABLE IF EXISTS `checkup_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `checkup_types` (
  `object_type` varchar(64) NOT NULL DEFAULT '',
  `checkup_type` varchar(64) NOT NULL DEFAULT '',
  `major_type` varchar(64) NOT NULL DEFAULT '',
  `expiration` int NOT NULL DEFAULT '86400',
  PRIMARY KEY (`object_type`,`checkup_type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `checkup_types`
--

LOCK TABLES `checkup_types` WRITE;
/*!40000 ALTER TABLE `checkup_types` DISABLE KEYS */;
/*!40000 ALTER TABLE `checkup_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `checkups`
--

DROP TABLE IF EXISTS `checkups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `checkups` (
  `object` varchar(128) NOT NULL DEFAULT '',
  `object_type` varchar(64) NOT NULL DEFAULT '',
  `type` varchar(64) NOT NULL DEFAULT '',
  `next` datetime DEFAULT NULL,
  PRIMARY KEY (`object`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `checkups`
--

LOCK TABLES `checkups` WRITE;
/*!40000 ALTER TABLE `checkups` DISABLE KEYS */;
/*!40000 ALTER TABLE `checkups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `checkups_temp`
--

DROP TABLE IF EXISTS `checkups_temp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `checkups_temp` (
  `object` varchar(128) NOT NULL DEFAULT '',
  `object_type` varchar(64) NOT NULL DEFAULT '',
  `type` varchar(64) NOT NULL DEFAULT '',
  `next` datetime DEFAULT NULL,
  PRIMARY KEY (`object`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `checkups_temp`
--

LOCK TABLES `checkups_temp` WRITE;
/*!40000 ALTER TABLE `checkups_temp` DISABLE KEYS */;
/*!40000 ALTER TABLE `checkups_temp` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `client_service_ctl`
--

DROP TABLE IF EXISTS `client_service_ctl`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_service_ctl` (
  `obj_type` enum('node_type','node','osid') NOT NULL DEFAULT 'node_type',
  `obj_name` varchar(64) NOT NULL DEFAULT '',
  `service_idx` int NOT NULL DEFAULT '0',
  `env` enum('load','boot') NOT NULL DEFAULT 'boot',
  `whence` enum('first','every') NOT NULL DEFAULT 'every',
  `alt_blob_id` varchar(40) NOT NULL DEFAULT '',
  `enable` tinyint(1) NOT NULL DEFAULT '1',
  `enable_hooks` tinyint(1) NOT NULL DEFAULT '1',
  `fatal` tinyint(1) NOT NULL DEFAULT '1',
  `user_can_override` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`obj_type`,`obj_name`,`service_idx`,`env`,`whence`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `client_service_ctl`
--

LOCK TABLES `client_service_ctl` WRITE;
/*!40000 ALTER TABLE `client_service_ctl` DISABLE KEYS */;
/*!40000 ALTER TABLE `client_service_ctl` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `client_service_hooks`
--

DROP TABLE IF EXISTS `client_service_hooks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_service_hooks` (
  `obj_type` enum('node_type','node','osid') NOT NULL DEFAULT 'node_type',
  `obj_name` varchar(64) NOT NULL DEFAULT '',
  `service_idx` int NOT NULL DEFAULT '0',
  `env` enum('load','boot') NOT NULL DEFAULT 'boot',
  `whence` enum('first','every') NOT NULL DEFAULT 'every',
  `hook_blob_id` varchar(40) NOT NULL DEFAULT '',
  `hook_op` enum('boot','shutdown','reconfig','reset') NOT NULL DEFAULT 'boot',
  `hook_point` enum('pre','post') NOT NULL DEFAULT 'post',
  `argv` varchar(255) NOT NULL DEFAULT '',
  `fatal` tinyint(1) NOT NULL DEFAULT '0',
  `user_can_override` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`obj_type`,`obj_name`,`service_idx`,`env`,`whence`,`hook_blob_id`,`hook_op`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `client_service_hooks`
--

LOCK TABLES `client_service_hooks` WRITE;
/*!40000 ALTER TABLE `client_service_hooks` DISABLE KEYS */;
/*!40000 ALTER TABLE `client_service_hooks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `client_services`
--

DROP TABLE IF EXISTS `client_services`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_services` (
  `idx` int NOT NULL DEFAULT '0',
  `service` varchar(64) NOT NULL DEFAULT 'isup',
  `env` enum('load','boot') NOT NULL DEFAULT 'boot',
  `whence` enum('first','every') NOT NULL DEFAULT 'every',
  `hooks_only` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`,`service`,`env`,`whence`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `client_services`
--

LOCK TABLES `client_services` WRITE;
/*!40000 ALTER TABLE `client_services` DISABLE KEYS */;
INSERT INTO `client_services` VALUES (10,'rc.tbsetup','boot','every',1),(20,'rc.ipod','boot','every',0),(30,'rc.healthd','boot','every',0),(40,'rc.slothd','boot','every',0),(50,'rc.firewall','boot','every',0),(60,'rc.tpmsetup','boot','every',0),(70,'rc.misc','boot','every',0),(80,'rc.localize','boot','every',0),(90,'rc.keys','boot','every',0),(100,'rc.mounts','boot','every',0),(110,'rc.blobs','boot','every',0),(120,'rc.topomap','boot','every',0),(130,'rc.accounts','boot','every',0),(140,'rc.route','boot','every',0),(150,'rc.tunnels','boot','every',0),(160,'rc.ifconfig','boot','every',0),(170,'rc.delays','boot','every',0),(180,'rc.hostnames','boot','every',0),(190,'rc.lmhosts','boot','every',0),(200,'rc.trace','boot','every',0),(210,'rc.syncserver','boot','every',0),(220,'rc.trafgen','boot','every',0),(230,'rc.tarfiles','boot','every',0),(240,'rc.rpms','boot','every',0),(250,'rc.progagent','boot','every',0),(260,'rc.linkagent','boot','every',0),(270,'rc.tiptunnels','boot','every',0),(280,'rc.motelog','boot','every',0),(290,'rc.simulator','boot','every',0),(1000,'rc.canaryd','boot','every',1),(1010,'rc.linktest','boot','every',1),(1020,'rc.isup','boot','every',1),(1030,'rc.startcmd','boot','every',0),(1040,'rc.vnodes','boot','every',1),(1050,'rc.subnodes','boot','every',1);
/*!40000 ALTER TABLE `client_services` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `comments`
--

DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `table_name` varchar(64) NOT NULL DEFAULT '',
  `column_name` varchar(64) NOT NULL DEFAULT '',
  `description` text NOT NULL,
  UNIQUE KEY `table_name` (`table_name`,`column_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `comments`
--

LOCK TABLES `comments` WRITE;
/*!40000 ALTER TABLE `comments` DISABLE KEYS */;
INSERT INTO `comments` VALUES ('users','','testbed user accounts'),('experiments','','user experiments'),('images','','available disk images'),('current_reloads','','currently pending disk reloads'),('delays','','delay nodes'),('loginmessage','','appears under login button in web interface'),('nodes','','hardware, software, and status of testbed machines'),('projects','','projects using the testbed'),('partitions','','loaded operating systems on node partitions'),('os_info','','available operating system features and information'),('reserved','','node reservation'),('wires','','physical wire types and connections'),('nologins','','presence of a row will disallow non-admin web logins'),('nsfiles','','NS simulator files used to configure experiments'),('tiplines','','serial control \'TIP\' lines'),('proj_memb','','project membership'),('group_membership','','group membership'),('node_types','','specifications regarding types of node hardware available'),('last_reservation','','the last project to have reserved listed nodes'),('groups','','groups information'),('vlans','','configured router VLANs'),('tipservers','','machines driving serial control \'TIP\' lines'),('uidnodelastlogin','','last node logged into by users'),('nodeuidlastlogin','','last user logged in to nodes'),('scheduled_reloads','','pending disk reloads'),('tmcd_redirect','','used to redirect node configuration client (TMCC) to \'fake\' database for testing purposes'),('deltas','','user filesystem deltas'),('delta_compat','','delta/OS compatibilities'),('delta_inst','','nodes on which listed deltas are installed'),('delta_proj','','projects which own listed deltas'),('next_reserve','','scheduled reservations (e.g. by sched_reserve)'),('outlets','','power controller and outlet connections for nodes'),('exppid_access','','allows access to one project\'s experiment by another project'),('lastlogin','','list of recently logged in web interface users'),('switch_stacks','','switch stack membership'),('switch_stack_types','','types of each switch stack'),('nodelog','','log entries for nodes'),('unixgroup_membership','','Unix group memberships for control (non-experiment) nodes'),('interface_types','','network interface types'),('foo','bar','baz'),('login','','currently active web logins'),('portmap','','provides consistency of ports across swaps'),('webdb_table_permissions','','table access permissions for WebDB interface '),('comments','','database table and row descriptions (such as this)'),('interfaces','','node network interfaces'),('foreign_keys','','foreign key constraints for use by the dbcheck script'),('nseconfigs','','Table for storing NSE configurations'),('widearea_delays','','Delay and bandwidth metrics between WAN nodes'),('virt_nodes','','Experiment virtual nodes');
/*!40000 ALTER TABLE `comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `current_reloads`
--

DROP TABLE IF EXISTS `current_reloads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `current_reloads` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `idx` smallint unsigned NOT NULL DEFAULT '0',
  `image_id` int unsigned NOT NULL DEFAULT '0',
  `imageid_version` int unsigned NOT NULL DEFAULT '0',
  `mustwipe` tinyint NOT NULL DEFAULT '0',
  `prepare` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `current_reloads`
--

LOCK TABLES `current_reloads` WRITE;
/*!40000 ALTER TABLE `current_reloads` DISABLE KEYS */;
/*!40000 ALTER TABLE `current_reloads` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `daily_stats`
--

DROP TABLE IF EXISTS `daily_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `daily_stats` (
  `theday` date NOT NULL DEFAULT '0000-00-00',
  `exptstart_count` int unsigned DEFAULT '0',
  `exptpreload_count` int unsigned DEFAULT '0',
  `exptswapin_count` int unsigned DEFAULT '0',
  `exptswapout_count` int unsigned DEFAULT '0',
  `exptswapmod_count` int unsigned DEFAULT '0',
  `allexpt_duration` int unsigned DEFAULT '0',
  `allexpt_vnodes` int unsigned DEFAULT '0',
  `allexpt_vnode_duration` int unsigned DEFAULT '0',
  `allexpt_pnodes` int unsigned DEFAULT '0',
  `allexpt_pnode_duration` int unsigned DEFAULT '0',
  PRIMARY KEY (`theday`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `daily_stats`
--

LOCK TABLES `daily_stats` WRITE;
/*!40000 ALTER TABLE `daily_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `daily_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `datapository_databases`
--

DROP TABLE IF EXISTS `datapository_databases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `datapository_databases` (
  `dbname` varchar(64) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  PRIMARY KEY (`dbname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `datapository_databases`
--

LOCK TABLES `datapository_databases` WRITE;
/*!40000 ALTER TABLE `datapository_databases` DISABLE KEYS */;
/*!40000 ALTER TABLE `datapository_databases` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `default_firewall_rules`
--

DROP TABLE IF EXISTS `default_firewall_rules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `default_firewall_rules` (
  `type` enum('ipfw','ipfw2','iptables','ipfw2-vlan','iptables-vlan','iptables-dom0','iptables-domU') NOT NULL DEFAULT 'ipfw',
  `style` enum('open','closed','basic','emulab') NOT NULL DEFAULT 'basic',
  `enabled` tinyint NOT NULL DEFAULT '0',
  `ruleno` int unsigned NOT NULL DEFAULT '0',
  `rule` text NOT NULL,
  PRIMARY KEY (`type`,`style`,`ruleno`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `default_firewall_rules`
--

LOCK TABLES `default_firewall_rules` WRITE;
/*!40000 ALTER TABLE `default_firewall_rules` DISABLE KEYS */;
/*!40000 ALTER TABLE `default_firewall_rules` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `default_firewall_vars`
--

DROP TABLE IF EXISTS `default_firewall_vars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `default_firewall_vars` (
  `name` varchar(255) NOT NULL DEFAULT '',
  `value` text,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `default_firewall_vars`
--

LOCK TABLES `default_firewall_vars` WRITE;
/*!40000 ALTER TABLE `default_firewall_vars` DISABLE KEYS */;
/*!40000 ALTER TABLE `default_firewall_vars` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `delays`
--

DROP TABLE IF EXISTS `delays`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delays` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `pipe0` smallint unsigned NOT NULL DEFAULT '0',
  `delay0` float(10,2) NOT NULL DEFAULT '0.00',
  `bandwidth0` int unsigned NOT NULL DEFAULT '100',
  `backfill0` int unsigned NOT NULL DEFAULT '0',
  `lossrate0` float(10,8) NOT NULL DEFAULT '0.00000000',
  `q0_limit` int DEFAULT '0',
  `q0_maxthresh` int DEFAULT '0',
  `q0_minthresh` int DEFAULT '0',
  `q0_weight` float DEFAULT '0',
  `q0_linterm` int DEFAULT '0',
  `q0_qinbytes` tinyint DEFAULT '0',
  `q0_bytes` tinyint DEFAULT '0',
  `q0_meanpsize` int DEFAULT '0',
  `q0_wait` int DEFAULT '0',
  `q0_setbit` int DEFAULT '0',
  `q0_droptail` int DEFAULT '0',
  `q0_red` tinyint DEFAULT '0',
  `q0_gentle` tinyint DEFAULT '0',
  `pipe1` smallint unsigned NOT NULL DEFAULT '0',
  `delay1` float(10,2) NOT NULL DEFAULT '0.00',
  `bandwidth1` int unsigned NOT NULL DEFAULT '100',
  `backfill1` int unsigned NOT NULL DEFAULT '0',
  `lossrate1` float(10,8) NOT NULL DEFAULT '0.00000000',
  `q1_limit` int DEFAULT '0',
  `q1_maxthresh` int DEFAULT '0',
  `q1_minthresh` int DEFAULT '0',
  `q1_weight` float DEFAULT '0',
  `q1_linterm` int DEFAULT '0',
  `q1_qinbytes` tinyint DEFAULT '0',
  `q1_bytes` tinyint DEFAULT '0',
  `q1_meanpsize` int DEFAULT '0',
  `q1_wait` int DEFAULT '0',
  `q1_setbit` int DEFAULT '0',
  `q1_droptail` int DEFAULT '0',
  `q1_red` tinyint DEFAULT '0',
  `q1_gentle` tinyint DEFAULT '0',
  `iface0` varchar(8) NOT NULL DEFAULT '',
  `iface1` varchar(8) NOT NULL DEFAULT '',
  `viface_unit0` int DEFAULT NULL,
  `viface_unit1` int DEFAULT NULL,
  `exptidx` int NOT NULL DEFAULT '0',
  `eid` varchar(32) DEFAULT NULL,
  `pid` varchar(48) DEFAULT NULL,
  `vname` varchar(32) DEFAULT NULL,
  `vlan0` varchar(32) NOT NULL DEFAULT '',
  `vlan1` varchar(32) NOT NULL DEFAULT '',
  `vnode0` varchar(32) NOT NULL DEFAULT '',
  `vnode1` varchar(32) NOT NULL DEFAULT '',
  `card0` tinyint unsigned DEFAULT NULL,
  `card1` tinyint unsigned DEFAULT NULL,
  `noshaping` tinyint(1) DEFAULT '0',
  `isbridge` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`node_id`,`iface0`,`iface1`,`vlan0`,`vlan1`,`vnode0`,`vnode1`),
  KEY `pid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `delays`
--

LOCK TABLES `delays` WRITE;
/*!40000 ALTER TABLE `delays` DISABLE KEYS */;
/*!40000 ALTER TABLE `delays` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deleted_users`
--

DROP TABLE IF EXISTS `deleted_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deleted_users` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `usr_created` datetime DEFAULT NULL,
  `usr_deleted` datetime DEFAULT NULL,
  `usr_name` tinytext,
  `usr_title` tinytext,
  `usr_affil` tinytext,
  `usr_affil_abbrev` varchar(16) DEFAULT NULL,
  `usr_email` tinytext,
  `usr_URL` tinytext,
  `usr_addr` tinytext,
  `usr_addr2` tinytext,
  `usr_city` tinytext,
  `usr_state` tinytext,
  `usr_zip` tinytext,
  `usr_country` tinytext,
  `usr_phone` tinytext,
  `webonly` tinyint(1) DEFAULT '0',
  `wikionly` tinyint(1) DEFAULT '0',
  `notes` text,
  PRIMARY KEY (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deleted_users`
--

LOCK TABLES `deleted_users` WRITE;
/*!40000 ALTER TABLE `deleted_users` DISABLE KEYS */;
/*!40000 ALTER TABLE `deleted_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `delta_inst`
--

DROP TABLE IF EXISTS `delta_inst`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delta_inst` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `partition` tinyint NOT NULL DEFAULT '0',
  `delta_id` varchar(10) NOT NULL DEFAULT '',
  PRIMARY KEY (`node_id`,`partition`,`delta_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `delta_inst`
--

LOCK TABLES `delta_inst` WRITE;
/*!40000 ALTER TABLE `delta_inst` DISABLE KEYS */;
/*!40000 ALTER TABLE `delta_inst` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `delta_proj`
--

DROP TABLE IF EXISTS `delta_proj`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delta_proj` (
  `delta_id` varchar(10) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  PRIMARY KEY (`delta_id`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `delta_proj`
--

LOCK TABLES `delta_proj` WRITE;
/*!40000 ALTER TABLE `delta_proj` DISABLE KEYS */;
/*!40000 ALTER TABLE `delta_proj` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deltas`
--

DROP TABLE IF EXISTS `deltas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deltas` (
  `delta_id` varchar(10) NOT NULL DEFAULT '',
  `delta_desc` text,
  `delta_path` text NOT NULL,
  `private` enum('yes','no') NOT NULL DEFAULT 'no',
  PRIMARY KEY (`delta_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deltas`
--

LOCK TABLES `deltas` WRITE;
/*!40000 ALTER TABLE `deltas` DISABLE KEYS */;
/*!40000 ALTER TABLE `deltas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `elabinelab_attributes`
--

DROP TABLE IF EXISTS `elabinelab_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `elabinelab_attributes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `role` enum('boss','router','ops','fs','node') NOT NULL DEFAULT 'node',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  `ordering` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`role`,`attrkey`,`ordering`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `elabinelab_attributes`
--

LOCK TABLES `elabinelab_attributes` WRITE;
/*!40000 ALTER TABLE `elabinelab_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `elabinelab_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `elabinelab_vlans`
--

DROP TABLE IF EXISTS `elabinelab_vlans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `elabinelab_vlans` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `inner_id` varchar(32) NOT NULL DEFAULT '',
  `outer_id` varchar(32) NOT NULL DEFAULT '',
  `stack` enum('Control','Experimental') NOT NULL DEFAULT 'Experimental',
  PRIMARY KEY (`exptidx`,`inner_id`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`inner_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `elabinelab_vlans`
--

LOCK TABLES `elabinelab_vlans` WRITE;
/*!40000 ALTER TABLE `elabinelab_vlans` DISABLE KEYS */;
/*!40000 ALTER TABLE `elabinelab_vlans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emulab_features`
--

DROP TABLE IF EXISTS `emulab_features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emulab_features` (
  `feature` varchar(64) NOT NULL DEFAULT '',
  `description` mediumtext,
  `added` datetime NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '0',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`feature`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emulab_features`
--

LOCK TABLES `emulab_features` WRITE;
/*!40000 ALTER TABLE `emulab_features` DISABLE KEYS */;
/*!40000 ALTER TABLE `emulab_features` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emulab_indicies`
--

DROP TABLE IF EXISTS `emulab_indicies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emulab_indicies` (
  `name` varchar(64) NOT NULL DEFAULT '',
  `idx` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emulab_indicies`
--

LOCK TABLES `emulab_indicies` WRITE;
/*!40000 ALTER TABLE `emulab_indicies` DISABLE KEYS */;
/*!40000 ALTER TABLE `emulab_indicies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emulab_locks`
--

DROP TABLE IF EXISTS `emulab_locks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emulab_locks` (
  `name` varchar(64) NOT NULL DEFAULT '',
  `value` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emulab_locks`
--

LOCK TABLES `emulab_locks` WRITE;
/*!40000 ALTER TABLE `emulab_locks` DISABLE KEYS */;
/*!40000 ALTER TABLE `emulab_locks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emulab_peers`
--

DROP TABLE IF EXISTS `emulab_peers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emulab_peers` (
  `name` varchar(64) NOT NULL DEFAULT '',
  `urn` varchar(128) NOT NULL DEFAULT '',
  `is_primary` tinyint(1) NOT NULL DEFAULT '0',
  `weburl` tinytext,
  PRIMARY KEY (`name`),
  UNIQUE KEY `urn` (`urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emulab_peers`
--

LOCK TABLES `emulab_peers` WRITE;
/*!40000 ALTER TABLE `emulab_peers` DISABLE KEYS */;
/*!40000 ALTER TABLE `emulab_peers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emulab_pubs`
--

DROP TABLE IF EXISTS `emulab_pubs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emulab_pubs` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(40) NOT NULL,
  `created` datetime NOT NULL,
  `owner` mediumint unsigned NOT NULL,
  `submitted_by` mediumint unsigned NOT NULL,
  `last_edit` datetime NOT NULL,
  `last_edit_by` mediumint unsigned NOT NULL,
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
  `cite_osdi02` tinyint(1) DEFAULT NULL,
  `no_cite_why` tinytext NOT NULL,
  `notes` text NOT NULL,
  `visible` tinyint(1) NOT NULL DEFAULT '1',
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `editable_owner` tinyint(1) NOT NULL DEFAULT '1',
  `editable_proj` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`idx`),
  UNIQUE KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emulab_pubs`
--

LOCK TABLES `emulab_pubs` WRITE;
/*!40000 ALTER TABLE `emulab_pubs` DISABLE KEYS */;
/*!40000 ALTER TABLE `emulab_pubs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emulab_pubs_month_map`
--

DROP TABLE IF EXISTS `emulab_pubs_month_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emulab_pubs_month_map` (
  `display_order` int unsigned NOT NULL AUTO_INCREMENT,
  `month` float(3,1) NOT NULL,
  `month_name` char(8) NOT NULL,
  PRIMARY KEY (`month`),
  UNIQUE KEY `display_order` (`display_order`)
) ENGINE=MyISAM AUTO_INCREMENT=26 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emulab_pubs_month_map`
--

LOCK TABLES `emulab_pubs_month_map` WRITE;
/*!40000 ALTER TABLE `emulab_pubs_month_map` DISABLE KEYS */;
INSERT INTO `emulab_pubs_month_map` VALUES (1,0.0,''),(2,1.0,'Jan'),(3,2.0,'Feb'),(4,3.0,'Mar'),(5,4.0,'Apr'),(6,5.0,'May'),(7,6.0,'Jun'),(8,7.0,'Jul'),(9,8.0,'Aug'),(10,9.0,'Sep'),(11,10.0,'Oct'),(12,11.0,'Nov'),(13,12.0,'Dec'),(14,1.5,'Jan-Feb'),(15,2.5,'Feb-Mar'),(16,3.5,'Mar-Apr'),(17,4.5,'Apr-May'),(18,5.5,'May-Jun'),(19,6.5,'Jun-Jul'),(20,7.5,'Jul-Aug'),(21,8.5,'Aug-Sep'),(22,9.5,'Sep-Oct'),(23,10.5,'Oct-Nov'),(24,11.5,'Nov-Dec'),(25,12.5,'Dec-Jan');
/*!40000 ALTER TABLE `emulab_pubs_month_map` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emulab_sites`
--

DROP TABLE IF EXISTS `emulab_sites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emulab_sites` (
  `urn` varchar(128) NOT NULL DEFAULT '',
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emulab_sites`
--

LOCK TABLES `emulab_sites` WRITE;
/*!40000 ALTER TABLE `emulab_sites` DISABLE KEYS */;
/*!40000 ALTER TABLE `emulab_sites` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `errors`
--

DROP TABLE IF EXISTS `errors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `errors` (
  `session` int unsigned NOT NULL DEFAULT '0',
  `rank` tinyint(1) NOT NULL DEFAULT '0',
  `stamp` int unsigned NOT NULL DEFAULT '0',
  `exptidx` int NOT NULL DEFAULT '0',
  `script` smallint NOT NULL DEFAULT '0',
  `cause` varchar(16) NOT NULL DEFAULT '',
  `confidence` float NOT NULL DEFAULT '0',
  `inferred` tinyint(1) DEFAULT NULL,
  `need_more_info` tinyint(1) DEFAULT NULL,
  `mesg` text NOT NULL,
  `tblog_revision` varchar(8) NOT NULL DEFAULT '',
  PRIMARY KEY (`session`,`rank`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `errors`
--

LOCK TABLES `errors` WRITE;
/*!40000 ALTER TABLE `errors` DISABLE KEYS */;
/*!40000 ALTER TABLE `errors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_eventtypes`
--

DROP TABLE IF EXISTS `event_eventtypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_eventtypes` (
  `idx` smallint unsigned NOT NULL DEFAULT '0',
  `type` tinytext NOT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_eventtypes`
--

LOCK TABLES `event_eventtypes` WRITE;
/*!40000 ALTER TABLE `event_eventtypes` DISABLE KEYS */;
INSERT INTO `event_eventtypes` VALUES (0,'REBOOT'),(1,'START'),(2,'STOP'),(3,'UP'),(4,'DOWN'),(5,'UPDATE'),(6,'MODIFY'),(7,'SET'),(8,'TIME'),(9,'RESET'),(10,'KILL'),(11,'HALT'),(12,'SWAPOUT'),(13,'NSEEVENT'),(14,'REPORT'),(15,'ALERT'),(16,'SETDEST'),(17,'COMPLETE'),(18,'MESSAGE'),(19,'LOG'),(20,'RUN'),(21,'SNAPSHOT'),(22,'RELOAD'),(23,'CLEAR'),(24,'CREATE'),(25,'STOPRUN');
/*!40000 ALTER TABLE `event_eventtypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_groups`
--

DROP TABLE IF EXISTS `event_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_groups` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `group_name` varchar(64) NOT NULL DEFAULT '',
  `agent_name` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`idx`),
  KEY `group_name` (`group_name`),
  KEY `agent_name` (`agent_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_groups`
--

LOCK TABLES `event_groups` WRITE;
/*!40000 ALTER TABLE `event_groups` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_objecttypes`
--

DROP TABLE IF EXISTS `event_objecttypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_objecttypes` (
  `idx` smallint unsigned NOT NULL DEFAULT '0',
  `type` tinytext NOT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_objecttypes`
--

LOCK TABLES `event_objecttypes` WRITE;
/*!40000 ALTER TABLE `event_objecttypes` DISABLE KEYS */;
INSERT INTO `event_objecttypes` VALUES (0,'TBCONTROL'),(1,'LINK'),(2,'TRAFGEN'),(3,'TIME'),(4,'PROGRAM'),(5,'FRISBEE'),(6,'SIMULATOR'),(7,'LINKTEST'),(8,'NSE'),(9,'SLOTHD'),(10,'NODE'),(11,'SEQUENCE'),(12,'TIMELINE'),(13,'CONSOLE'),(14,'TOPOGRAPHY'),(15,'LINKTRACE'),(16,'EVPROXY'),(17,'BGMON'),(18,'DISK'),(19,'CUSTOM'),(20,'BSTORE');
/*!40000 ALTER TABLE `event_objecttypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_triggertypes`
--

DROP TABLE IF EXISTS `event_triggertypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_triggertypes` (
  `idx` smallint unsigned NOT NULL,
  `type` tinytext NOT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_triggertypes`
--

LOCK TABLES `event_triggertypes` WRITE;
/*!40000 ALTER TABLE `event_triggertypes` DISABLE KEYS */;
INSERT INTO `event_triggertypes` VALUES (0,'TIMER'),(2,'SWAPOUT');
/*!40000 ALTER TABLE `event_triggertypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `eventlist`
--

DROP TABLE IF EXISTS `eventlist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventlist` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `time` float(10,3) NOT NULL DEFAULT '0.000',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(64) NOT NULL DEFAULT '',
  `objecttype` smallint unsigned NOT NULL DEFAULT '0',
  `eventtype` smallint unsigned NOT NULL DEFAULT '0',
  `triggertype` smallint unsigned NOT NULL DEFAULT '0',
  `isgroup` tinyint unsigned DEFAULT '0',
  `arguments` text,
  `atstring` text,
  `parent` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`idx`),
  KEY `vnode` (`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `eventlist`
--

LOCK TABLES `eventlist` WRITE;
/*!40000 ALTER TABLE `eventlist` DISABLE KEYS */;
/*!40000 ALTER TABLE `eventlist` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_blobs`
--

DROP TABLE IF EXISTS `experiment_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_blobs` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `path` varchar(255) NOT NULL DEFAULT '',
  `action` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`idx`),
  UNIQUE KEY `exptidx` (`exptidx`,`path`,`action`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_blobs`
--

LOCK TABLES `experiment_blobs` WRITE;
/*!40000 ALTER TABLE `experiment_blobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_blobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_features`
--

DROP TABLE IF EXISTS `experiment_features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_features` (
  `feature` varchar(64) NOT NULL DEFAULT '',
  `added` datetime NOT NULL,
  `exptidx` int NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`feature`,`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_features`
--

LOCK TABLES `experiment_features` WRITE;
/*!40000 ALTER TABLE `experiment_features` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_features` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_input_data`
--

DROP TABLE IF EXISTS `experiment_input_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_input_data` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `md5` varchar(32) NOT NULL DEFAULT '',
  `compressed` tinyint unsigned DEFAULT '0',
  `input` mediumblob,
  PRIMARY KEY (`idx`),
  UNIQUE KEY `md5` (`md5`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_input_data`
--

LOCK TABLES `experiment_input_data` WRITE;
/*!40000 ALTER TABLE `experiment_input_data` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_input_data` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_inputs`
--

DROP TABLE IF EXISTS `experiment_inputs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_inputs` (
  `rsrcidx` int unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `input_data_idx` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`rsrcidx`,`input_data_idx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_inputs`
--

LOCK TABLES `experiment_inputs` WRITE;
/*!40000 ALTER TABLE `experiment_inputs` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_inputs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_keys`
--

DROP TABLE IF EXISTS `experiment_keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_keys` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `rsa_privkey` text,
  `rsa_pubkey` text,
  `ssh_pubkey` text,
  PRIMARY KEY (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_keys`
--

LOCK TABLES `experiment_keys` WRITE;
/*!40000 ALTER TABLE `experiment_keys` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_keys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_pmapping`
--

DROP TABLE IF EXISTS `experiment_pmapping`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_pmapping` (
  `rsrcidx` int unsigned NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `node_type` varchar(30) NOT NULL DEFAULT '',
  `node_erole` varchar(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`rsrcidx`,`vname`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_pmapping`
--

LOCK TABLES `experiment_pmapping` WRITE;
/*!40000 ALTER TABLE `experiment_pmapping` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_pmapping` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_resources`
--

DROP TABLE IF EXISTS `experiment_resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_resources` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `lastidx` int unsigned DEFAULT NULL,
  `tstamp` datetime DEFAULT NULL,
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `swapin_time` int unsigned NOT NULL DEFAULT '0',
  `swapout_time` int unsigned NOT NULL DEFAULT '0',
  `swapmod_time` int unsigned NOT NULL DEFAULT '0',
  `byswapmod` tinyint unsigned DEFAULT '0',
  `byswapin` tinyint unsigned DEFAULT '0',
  `vnodes` smallint unsigned DEFAULT '0',
  `pnodes` smallint unsigned DEFAULT '0',
  `wanodes` smallint unsigned DEFAULT '0',
  `plabnodes` smallint unsigned DEFAULT '0',
  `simnodes` smallint unsigned DEFAULT '0',
  `jailnodes` smallint unsigned DEFAULT '0',
  `delaynodes` smallint unsigned DEFAULT '0',
  `linkdelays` smallint unsigned DEFAULT '0',
  `walinks` smallint unsigned DEFAULT '0',
  `links` smallint unsigned DEFAULT '0',
  `lans` smallint unsigned DEFAULT '0',
  `shapedlinks` smallint unsigned DEFAULT '0',
  `shapedlans` smallint unsigned DEFAULT '0',
  `wirelesslans` smallint unsigned DEFAULT '0',
  `minlinks` tinyint unsigned DEFAULT '0',
  `maxlinks` tinyint unsigned DEFAULT '0',
  `delay_capacity` tinyint unsigned DEFAULT NULL,
  `batchmode` tinyint unsigned DEFAULT '0',
  `archive_tag` varchar(64) DEFAULT NULL,
  `input_data_idx` int unsigned DEFAULT NULL,
  `thumbnail` mediumblob,
  PRIMARY KEY (`idx`),
  KEY `exptidx` (`exptidx`),
  KEY `lastidx` (`lastidx`),
  KEY `inputdata` (`input_data_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_resources`
--

LOCK TABLES `experiment_resources` WRITE;
/*!40000 ALTER TABLE `experiment_resources` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_resources` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_run_bindings`
--

DROP TABLE IF EXISTS `experiment_run_bindings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_run_bindings` (
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `runidx` int unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL DEFAULT '',
  `value` tinytext NOT NULL,
  PRIMARY KEY (`exptidx`,`runidx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_run_bindings`
--

LOCK TABLES `experiment_run_bindings` WRITE;
/*!40000 ALTER TABLE `experiment_run_bindings` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_run_bindings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_runs`
--

DROP TABLE IF EXISTS `experiment_runs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_runs` (
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `runid` varchar(32) NOT NULL DEFAULT '',
  `description` tinytext,
  `starting_archive_tag` varchar(64) DEFAULT NULL,
  `ending_archive_tag` varchar(64) DEFAULT NULL,
  `archive_tag` varchar(64) DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `stop_time` datetime DEFAULT NULL,
  `swapmod` tinyint(1) NOT NULL DEFAULT '0',
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_runs`
--

LOCK TABLES `experiment_runs` WRITE;
/*!40000 ALTER TABLE `experiment_runs` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_runs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_stats`
--

DROP TABLE IF EXISTS `experiment_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_stats` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `eid_uuid` varchar(40) NOT NULL DEFAULT '',
  `creator` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `rsrcidx` int unsigned NOT NULL DEFAULT '0',
  `lastrsrc` int unsigned DEFAULT NULL,
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `destroyed` datetime DEFAULT NULL,
  `last_activity` datetime DEFAULT NULL,
  `swapin_count` smallint unsigned DEFAULT '0',
  `swapin_last` datetime DEFAULT NULL,
  `swapout_count` smallint unsigned DEFAULT '0',
  `swapout_last` datetime DEFAULT NULL,
  `swapmod_count` smallint unsigned DEFAULT '0',
  `swapmod_last` datetime DEFAULT NULL,
  `swap_errors` smallint unsigned DEFAULT '0',
  `swap_exitcode` tinyint DEFAULT '0',
  `idle_swaps` smallint unsigned DEFAULT '0',
  `swapin_duration` int unsigned DEFAULT '0',
  `batch` tinyint unsigned DEFAULT '0',
  `elabinelab` tinyint(1) NOT NULL DEFAULT '0',
  `elabinelab_exptidx` int unsigned DEFAULT NULL,
  `security_level` tinyint(1) NOT NULL DEFAULT '0',
  `archive_idx` int unsigned DEFAULT NULL,
  `last_error` int unsigned DEFAULT NULL,
  `dpdbname` varchar(64) DEFAULT NULL,
  `geniflags` int unsigned DEFAULT NULL,
  `slice_uuid` varchar(40) DEFAULT NULL,
  `nonlocal_id` varchar(128) DEFAULT NULL,
  `nonlocal_user_id` varchar(128) DEFAULT NULL,
  `nonlocal_type` tinytext,
  PRIMARY KEY (`exptidx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `pideid` (`pid`,`eid`),
  KEY `eid_uuid` (`eid_uuid`),
  KEY `pid_idx` (`pid_idx`),
  KEY `creator_idx` (`creator_idx`),
  KEY `geniflags` (`geniflags`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_stats`
--

LOCK TABLES `experiment_stats` WRITE;
/*!40000 ALTER TABLE `experiment_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_events`
--

DROP TABLE IF EXISTS `experiment_template_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_events` (
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `vname` varchar(64) NOT NULL DEFAULT '',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `time` float(10,3) NOT NULL DEFAULT '0.000',
  `objecttype` smallint unsigned NOT NULL DEFAULT '0',
  `eventtype` smallint unsigned NOT NULL DEFAULT '0',
  `arguments` text,
  PRIMARY KEY (`parent_guid`,`parent_vers`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_events`
--

LOCK TABLES `experiment_template_events` WRITE;
/*!40000 ALTER TABLE `experiment_template_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_graphs`
--

DROP TABLE IF EXISTS `experiment_template_graphs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_graphs` (
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `scale` float(10,3) NOT NULL DEFAULT '1.000',
  `image` mediumblob,
  `imap` mediumtext,
  PRIMARY KEY (`parent_guid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_graphs`
--

LOCK TABLES `experiment_template_graphs` WRITE;
/*!40000 ALTER TABLE `experiment_template_graphs` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_graphs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_input_data`
--

DROP TABLE IF EXISTS `experiment_template_input_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_input_data` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `md5` varchar(32) NOT NULL DEFAULT '',
  `input` mediumtext,
  PRIMARY KEY (`idx`),
  UNIQUE KEY `md5` (`md5`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_input_data`
--

LOCK TABLES `experiment_template_input_data` WRITE;
/*!40000 ALTER TABLE `experiment_template_input_data` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_input_data` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_inputs`
--

DROP TABLE IF EXISTS `experiment_template_inputs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_inputs` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `tid` varchar(32) NOT NULL DEFAULT '',
  `input_idx` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`parent_guid`,`parent_vers`,`idx`),
  KEY `pidtid` (`pid`,`tid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_inputs`
--

LOCK TABLES `experiment_template_inputs` WRITE;
/*!40000 ALTER TABLE `experiment_template_inputs` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_inputs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_instance_bindings`
--

DROP TABLE IF EXISTS `experiment_template_instance_bindings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_instance_bindings` (
  `instance_idx` int unsigned NOT NULL DEFAULT '0',
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `value` tinytext NOT NULL,
  PRIMARY KEY (`instance_idx`,`name`),
  KEY `parent_guid` (`parent_guid`,`parent_vers`),
  KEY `pidtid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_instance_bindings`
--

LOCK TABLES `experiment_template_instance_bindings` WRITE;
/*!40000 ALTER TABLE `experiment_template_instance_bindings` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_instance_bindings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_instance_deadnodes`
--

DROP TABLE IF EXISTS `experiment_template_instance_deadnodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_instance_deadnodes` (
  `instance_idx` int unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `runidx` int unsigned NOT NULL DEFAULT '0',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`instance_idx`,`runidx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_instance_deadnodes`
--

LOCK TABLES `experiment_template_instance_deadnodes` WRITE;
/*!40000 ALTER TABLE `experiment_template_instance_deadnodes` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_instance_deadnodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_instances`
--

DROP TABLE IF EXISTS `experiment_template_instances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_instances` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `logfileid` varchar(40) DEFAULT NULL,
  `description` tinytext,
  `start_time` datetime DEFAULT NULL,
  `stop_time` datetime DEFAULT NULL,
  `continue_time` datetime DEFAULT NULL,
  `runtime` int unsigned DEFAULT '0',
  `pause_time` datetime DEFAULT NULL,
  `runidx` int unsigned DEFAULT NULL,
  `template_tag` varchar(64) DEFAULT NULL,
  `export_time` datetime DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  PRIMARY KEY (`idx`),
  KEY `exptidx` (`exptidx`),
  KEY `parent_guid` (`parent_guid`,`parent_vers`),
  KEY `pid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_instances`
--

LOCK TABLES `experiment_template_instances` WRITE;
/*!40000 ALTER TABLE `experiment_template_instances` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_instances` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_metadata`
--

DROP TABLE IF EXISTS `experiment_template_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_metadata` (
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `metadata_guid` varchar(16) NOT NULL DEFAULT '',
  `metadata_vers` smallint unsigned NOT NULL DEFAULT '0',
  `internal` tinyint(1) NOT NULL DEFAULT '0',
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `metadata_type` enum('tid','template_description','parameter_description','annotation','instance_description','run_description') DEFAULT NULL,
  PRIMARY KEY (`parent_guid`,`parent_vers`,`metadata_guid`,`metadata_vers`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_metadata`
--

LOCK TABLES `experiment_template_metadata` WRITE;
/*!40000 ALTER TABLE `experiment_template_metadata` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_metadata` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_metadata_items`
--

DROP TABLE IF EXISTS `experiment_template_metadata_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_metadata_items` (
  `guid` varchar(16) NOT NULL DEFAULT '',
  `vers` smallint unsigned NOT NULL DEFAULT '0',
  `parent_guid` varchar(16) DEFAULT NULL,
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `template_guid` varchar(16) NOT NULL DEFAULT '',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL DEFAULT '',
  `value` mediumtext,
  `created` datetime DEFAULT NULL,
  PRIMARY KEY (`guid`,`vers`),
  KEY `parent` (`parent_guid`,`parent_vers`),
  KEY `template` (`template_guid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_metadata_items`
--

LOCK TABLES `experiment_template_metadata_items` WRITE;
/*!40000 ALTER TABLE `experiment_template_metadata_items` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_metadata_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_parameters`
--

DROP TABLE IF EXISTS `experiment_template_parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_parameters` (
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `tid` varchar(32) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `value` tinytext,
  `metadata_guid` varchar(16) DEFAULT NULL,
  `metadata_vers` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`parent_guid`,`parent_vers`,`name`),
  KEY `pidtid` (`pid`,`tid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_parameters`
--

LOCK TABLES `experiment_template_parameters` WRITE;
/*!40000 ALTER TABLE `experiment_template_parameters` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_parameters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_searches`
--

DROP TABLE IF EXISTS `experiment_template_searches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_searches` (
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL DEFAULT '',
  `expr` mediumtext,
  `created` datetime DEFAULT NULL,
  PRIMARY KEY (`parent_guid`,`parent_vers`,`uid_idx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_searches`
--

LOCK TABLES `experiment_template_searches` WRITE;
/*!40000 ALTER TABLE `experiment_template_searches` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_searches` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_template_settings`
--

DROP TABLE IF EXISTS `experiment_template_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_template_settings` (
  `parent_guid` varchar(16) NOT NULL DEFAULT '',
  `parent_vers` smallint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `tid` varchar(32) NOT NULL DEFAULT '',
  `uselinkdelays` tinyint NOT NULL DEFAULT '0',
  `forcelinkdelays` tinyint NOT NULL DEFAULT '0',
  `multiplex_factor` smallint DEFAULT NULL,
  `uselatestwadata` tinyint NOT NULL DEFAULT '0',
  `usewatunnels` tinyint NOT NULL DEFAULT '1',
  `wa_delay_solverweight` float DEFAULT '0',
  `wa_bw_solverweight` float DEFAULT '0',
  `wa_plr_solverweight` float DEFAULT '0',
  `sync_server` varchar(32) DEFAULT NULL,
  `cpu_usage` tinyint unsigned NOT NULL DEFAULT '0',
  `mem_usage` tinyint unsigned NOT NULL DEFAULT '0',
  `veth_encapsulate` tinyint NOT NULL DEFAULT '1',
  `allowfixnode` tinyint NOT NULL DEFAULT '1',
  `jail_osname` varchar(30) DEFAULT NULL,
  `delay_osname` varchar(30) DEFAULT NULL,
  `use_ipassign` tinyint NOT NULL DEFAULT '0',
  `ipassign_args` varchar(255) DEFAULT NULL,
  `linktest_level` tinyint NOT NULL DEFAULT '0',
  `linktest_pid` int DEFAULT '0',
  `useprepass` tinyint(1) NOT NULL DEFAULT '0',
  `elab_in_elab` tinyint(1) NOT NULL DEFAULT '0',
  `elabinelab_eid` varchar(32) DEFAULT NULL,
  `elabinelab_cvstag` varchar(64) DEFAULT NULL,
  `elabinelab_nosetup` tinyint(1) NOT NULL DEFAULT '0',
  `security_level` tinyint(1) NOT NULL DEFAULT '0',
  `delay_capacity` tinyint unsigned DEFAULT NULL,
  `savedisk` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`parent_guid`,`parent_vers`),
  KEY `pidtid` (`pid`,`tid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_template_settings`
--

LOCK TABLES `experiment_template_settings` WRITE;
/*!40000 ALTER TABLE `experiment_template_settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_template_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiment_templates`
--

DROP TABLE IF EXISTS `experiment_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiment_templates` (
  `guid` varchar(16) NOT NULL DEFAULT '',
  `vers` smallint unsigned NOT NULL DEFAULT '0',
  `parent_guid` varchar(16) DEFAULT NULL,
  `parent_vers` smallint unsigned DEFAULT NULL,
  `child_guid` varchar(16) DEFAULT NULL,
  `child_vers` smallint unsigned DEFAULT NULL,
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `tid` varchar(32) NOT NULL DEFAULT '',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `description` mediumtext,
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `archive_idx` int unsigned DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `modified` datetime DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  `state` varchar(16) NOT NULL DEFAULT 'new',
  `path` tinytext,
  `maximum_nodes` int unsigned DEFAULT NULL,
  `minimum_nodes` int unsigned DEFAULT NULL,
  `logfile` tinytext,
  `logfile_open` tinyint NOT NULL DEFAULT '0',
  `prerender_pid` int DEFAULT '0',
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `active` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`vers`),
  KEY `pidtid` (`pid`,`tid`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiment_templates`
--

LOCK TABLES `experiment_templates` WRITE;
/*!40000 ALTER TABLE `experiment_templates` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiment_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `experiments`
--

DROP TABLE IF EXISTS `experiments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `experiments` (
  `eid` varchar(32) NOT NULL DEFAULT '',
  `eid_uuid` varchar(40) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `swapper_idx` mediumint unsigned DEFAULT NULL,
  `expt_created` datetime DEFAULT NULL,
  `expt_expires` datetime DEFAULT NULL,
  `expt_name` tinytext,
  `expt_head_uid` varchar(8) NOT NULL DEFAULT '',
  `expt_start` datetime DEFAULT NULL,
  `expt_end` datetime DEFAULT NULL,
  `expt_terminating` datetime DEFAULT NULL,
  `expt_locked` datetime DEFAULT NULL,
  `expt_swapped` datetime DEFAULT NULL,
  `expt_swap_uid` varchar(8) NOT NULL DEFAULT '',
  `swappable` tinyint NOT NULL DEFAULT '0',
  `priority` tinyint NOT NULL DEFAULT '0',
  `noswap_reason` tinytext,
  `idleswap` tinyint NOT NULL DEFAULT '0',
  `idleswap_timeout` int NOT NULL DEFAULT '0',
  `noidleswap_reason` tinytext,
  `autoswap` tinyint NOT NULL DEFAULT '0',
  `autoswap_timeout` int NOT NULL DEFAULT '0',
  `batchmode` tinyint NOT NULL DEFAULT '0',
  `shared` tinyint NOT NULL DEFAULT '0',
  `state` varchar(16) NOT NULL DEFAULT 'new',
  `maximum_nodes` int unsigned DEFAULT NULL,
  `minimum_nodes` int unsigned DEFAULT NULL,
  `virtnode_count` int unsigned DEFAULT NULL,
  `testdb` tinytext,
  `path` tinytext,
  `logfile` tinytext,
  `logfile_open` tinyint NOT NULL DEFAULT '0',
  `attempts` smallint unsigned NOT NULL DEFAULT '0',
  `canceled` tinyint NOT NULL DEFAULT '0',
  `batchstate` varchar(16) DEFAULT NULL,
  `event_sched_pid` int DEFAULT '0',
  `prerender_pid` int DEFAULT '0',
  `uselinkdelays` tinyint NOT NULL DEFAULT '0',
  `forcelinkdelays` tinyint NOT NULL DEFAULT '0',
  `multiplex_factor` smallint DEFAULT NULL,
  `packing_strategy` enum('pack','balance') DEFAULT NULL,
  `uselatestwadata` tinyint NOT NULL DEFAULT '0',
  `usewatunnels` tinyint NOT NULL DEFAULT '1',
  `wa_delay_solverweight` float DEFAULT '0',
  `wa_bw_solverweight` float DEFAULT '0',
  `wa_plr_solverweight` float DEFAULT '0',
  `swap_requests` tinyint NOT NULL DEFAULT '0',
  `last_swap_req` datetime DEFAULT NULL,
  `idle_ignore` tinyint NOT NULL DEFAULT '0',
  `sync_server` varchar(32) DEFAULT NULL,
  `cpu_usage` tinyint unsigned NOT NULL DEFAULT '0',
  `mem_usage` tinyint unsigned NOT NULL DEFAULT '0',
  `keyhash` varchar(64) DEFAULT NULL,
  `eventkey` varchar(64) DEFAULT NULL,
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `sim_reswap_count` smallint unsigned NOT NULL DEFAULT '0',
  `veth_encapsulate` tinyint NOT NULL DEFAULT '1',
  `encap_style` enum('alias','veth','veth-ne','vlan','vtun','egre','gre','default') NOT NULL DEFAULT 'default',
  `allowfixnode` tinyint NOT NULL DEFAULT '1',
  `jail_osname` varchar(30) DEFAULT NULL,
  `delay_osname` varchar(30) DEFAULT NULL,
  `use_ipassign` tinyint NOT NULL DEFAULT '0',
  `ipassign_args` varchar(255) DEFAULT NULL,
  `linktest_level` tinyint NOT NULL DEFAULT '0',
  `linktest_pid` int DEFAULT '0',
  `useprepass` tinyint(1) NOT NULL DEFAULT '0',
  `usemodelnet` tinyint(1) NOT NULL DEFAULT '0',
  `modelnet_cores` tinyint unsigned NOT NULL DEFAULT '0',
  `modelnet_edges` tinyint unsigned NOT NULL DEFAULT '0',
  `modelnetcore_osname` varchar(30) DEFAULT NULL,
  `modelnetedge_osname` varchar(30) DEFAULT NULL,
  `elab_in_elab` tinyint(1) NOT NULL DEFAULT '0',
  `elabinelab_eid` varchar(32) DEFAULT NULL,
  `elabinelab_exptidx` int DEFAULT NULL,
  `elabinelab_cvstag` varchar(64) DEFAULT NULL,
  `elabinelab_nosetup` tinyint(1) NOT NULL DEFAULT '0',
  `elabinelab_singlenet` tinyint(1) NOT NULL DEFAULT '0',
  `security_level` tinyint(1) NOT NULL DEFAULT '0',
  `lockdown` tinyint(1) NOT NULL DEFAULT '0',
  `paniced` tinyint(1) NOT NULL DEFAULT '0',
  `panic_date` datetime DEFAULT NULL,
  `delay_capacity` tinyint unsigned DEFAULT NULL,
  `savedisk` tinyint(1) NOT NULL DEFAULT '0',
  `skipvlans` tinyint(1) NOT NULL DEFAULT '0',
  `locpiper_pid` int DEFAULT '0',
  `locpiper_port` int DEFAULT '0',
  `instance_idx` int unsigned NOT NULL DEFAULT '0',
  `dpdb` tinyint(1) NOT NULL DEFAULT '0',
  `dpdbname` varchar(64) DEFAULT NULL,
  `dpdbpassword` varchar(64) DEFAULT NULL,
  `geniflags` int NOT NULL DEFAULT '0',
  `nonlocal_id` varchar(128) DEFAULT NULL,
  `nonlocal_user_id` varchar(128) DEFAULT NULL,
  `nonlocal_type` tinytext,
  `nonfsmounts` tinyint(1) NOT NULL DEFAULT '0',
  `nfsmounts` enum('emulabdefault','genidefault','all','none') NOT NULL DEFAULT 'emulabdefault',
  PRIMARY KEY (`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`),
  UNIQUE KEY `pididxeid` (`pid_idx`,`eid`),
  UNIQUE KEY `keyhash` (`keyhash`),
  KEY `batchmode` (`batchmode`),
  KEY `state` (`state`),
  KEY `eid_uuid` (`eid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `experiments`
--

LOCK TABLES `experiments` WRITE;
/*!40000 ALTER TABLE `experiments` DISABLE KEYS */;
/*!40000 ALTER TABLE `experiments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `exported_tables`
--

DROP TABLE IF EXISTS `exported_tables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `exported_tables` (
  `table_name` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`table_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `exported_tables`
--

LOCK TABLES `exported_tables` WRITE;
/*!40000 ALTER TABLE `exported_tables` DISABLE KEYS */;
INSERT INTO `exported_tables` VALUES ('causes'),('client_services'),('comments'),('emulab_pubs_month_map'),('event_eventtypes'),('event_objecttypes'),('event_triggertypes'),('exported_tables'),('foreign_keys'),('mode_transitions'),('priorities'),('state_timeouts'),('state_transitions'),('state_triggers'),('table_regex'),('testsuite_preentables'),('webdb_table_permissions');
/*!40000 ALTER TABLE `exported_tables` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `exppid_access`
--

DROP TABLE IF EXISTS `exppid_access`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `exppid_access` (
  `exp_eid` varchar(32) NOT NULL DEFAULT '',
  `exp_pid` varchar(48) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  PRIMARY KEY (`exp_eid`,`exp_pid`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `exppid_access`
--

LOCK TABLES `exppid_access` WRITE;
/*!40000 ALTER TABLE `exppid_access` DISABLE KEYS */;
/*!40000 ALTER TABLE `exppid_access` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `external_networks`
--

DROP TABLE IF EXISTS `external_networks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `external_networks` (
  `network_id` varchar(32) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `node_type` varchar(30) NOT NULL DEFAULT '',
  `external_manager` tinytext,
  `external_interface` tinytext,
  `external_wire` tinytext,
  `external_subport` tinytext,
  `mode` enum('chain','tree') NOT NULL DEFAULT 'tree',
  `vlans` tinytext,
  PRIMARY KEY (`network_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `external_networks`
--

LOCK TABLES `external_networks` WRITE;
/*!40000 ALTER TABLE `external_networks` DISABLE KEYS */;
/*!40000 ALTER TABLE `external_networks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `firewall_rules`
--

DROP TABLE IF EXISTS `firewall_rules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firewall_rules` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `fwname` varchar(32) NOT NULL DEFAULT '',
  `ruleno` int unsigned NOT NULL DEFAULT '0',
  `rule` text NOT NULL,
  PRIMARY KEY (`exptidx`,`fwname`,`ruleno`),
  KEY `fwname` (`fwname`),
  KEY `pideid` (`pid`,`eid`,`fwname`,`ruleno`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `firewall_rules`
--

LOCK TABLES `firewall_rules` WRITE;
/*!40000 ALTER TABLE `firewall_rules` DISABLE KEYS */;
/*!40000 ALTER TABLE `firewall_rules` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `firewalls`
--

DROP TABLE IF EXISTS `firewalls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `firewalls` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `fwname` varchar(32) NOT NULL DEFAULT '',
  `vlan` int DEFAULT NULL,
  `vlanid` int DEFAULT NULL,
  PRIMARY KEY (`exptidx`,`fwname`),
  KEY `vlan` (`vlan`),
  KEY `pideid` (`pid`,`eid`,`fwname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `firewalls`
--

LOCK TABLES `firewalls` WRITE;
/*!40000 ALTER TABLE `firewalls` DISABLE KEYS */;
/*!40000 ALTER TABLE `firewalls` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `floorimages`
--

DROP TABLE IF EXISTS `floorimages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `floorimages` (
  `building` varchar(32) NOT NULL DEFAULT '',
  `floor` varchar(32) NOT NULL DEFAULT '',
  `image_path` tinytext,
  `thumb_path` tinytext,
  `x1` int NOT NULL DEFAULT '0',
  `y1` int NOT NULL DEFAULT '0',
  `x2` int NOT NULL DEFAULT '0',
  `y2` int NOT NULL DEFAULT '0',
  `scale` tinyint NOT NULL DEFAULT '1',
  `pixels_per_meter` float(10,3) NOT NULL DEFAULT '0.000',
  PRIMARY KEY (`building`,`floor`,`scale`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `floorimages`
--

LOCK TABLES `floorimages` WRITE;
/*!40000 ALTER TABLE `floorimages` DISABLE KEYS */;
/*!40000 ALTER TABLE `floorimages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `foreign_keys`
--

DROP TABLE IF EXISTS `foreign_keys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `foreign_keys` (
  `table1` varchar(30) NOT NULL DEFAULT '',
  `column1` varchar(30) NOT NULL DEFAULT '',
  `table2` varchar(30) NOT NULL DEFAULT '',
  `column2` varchar(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`table1`,`column1`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `foreign_keys`
--

LOCK TABLES `foreign_keys` WRITE;
/*!40000 ALTER TABLE `foreign_keys` DISABLE KEYS */;
INSERT INTO `foreign_keys` VALUES ('projects','head_uid','users','uid'),('groups','pid','projects','pid'),('groups','leader','users','uid'),('experiments','expt_head_uid','users','uid'),('experiments','pid','projects','pid'),('experiments','pid,gid','groups','pid,gid'),('os_info','pid','projects','pid'),('node_types','osid','os_info','osid'),('node_types','delay_osid','os_info','osid'),('nodes','def_boot_osid','os_info','osid'),('nodes','next_boot_osid','os_info','osid'),('nodes','type','node_types','type'),('images','pid','projects','pid'),('images','part1_osid','os_info','osid'),('images','part2_osid','os_info','osid'),('images','part3_osid','os_info','osid'),('images','part4_osid','os_info','osid'),('images','default_osid','os_info','osid'),('current_reloads','node_id','nodes','node_id'),('current_reloads','image_id','images','imageid'),('delays','node_id','nodes','node_id'),('delays','eid,pid','experiments','eid,pid'),('partitions','node_id','nodes','node_id'),('partitions','osid','os_info','osid'),('exppid_access','exp_pid,exp_eid','experiments','pid,eid'),('group_membership','uid','users','uid'),('group_membership','pid,gid','groups','pid,gid'),('interfaces','interface_type','interface_types','type'),('interfaces','node_id','nodes','node_id'),('last_reservation','node_id','nodes','node_id'),('last_reservation','pid','projects','pid'),('lastlogin','uid','users','uid'),('login','uid','users','uid'),('newdelays','node_id','nodes','node_id'),('newdelays','eid,pid','experiments','eid,pid'),('next_reserve','eid,pid','experiments','eid,pid'),('next_reserve','node_id','nodes','node_id'),('nodeuidlastlogin','uid','users','uid'),('nodeuidlastlogin','node_id','nodes','node_id'),('nsfiles','eid,pid','experiments','eid,pid'),('proj_memb','pid','projects','pid'),('reserved','eid,pid','experiments','eid,pid'),('reserved','node_id','nodes','node_id'),('scheduled_reloads','node_id','nodes','node_id'),('scheduled_reloads','image_id','images','imageid'),('tiplines','node_id','nodes','node_id'),('tmcd_redirect','node_id','nodes','node_id'),('uidnodelastlogin','uid','users','uid'),('uidnodelastlogin','node_id','nodes','node_id'),('virt_lans','pid,eid','experiments','pid,eid'),('virt_nodes','pid,eid','experiments','pid,eid'),('virt_nodes','osname','os_info','osname'),('vlans','pid,eid','experiments','pid,eid'),('nseconfigs','eid,pid,vname','virt_nodes','eid,pid,vname'),('nseconfigs','eid,pid','experiments','eid,pid'),('virt_nodes','parent_osname','os_info','osname');
/*!40000 ALTER TABLE `foreign_keys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `frisbee_blobs`
--

DROP TABLE IF EXISTS `frisbee_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `frisbee_blobs` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `path` varchar(255) NOT NULL DEFAULT '',
  `imageid` int unsigned DEFAULT NULL,
  `imageid_version` int unsigned DEFAULT NULL,
  `load_address` text,
  `frisbee_pid` int DEFAULT '0',
  `load_busy` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`),
  UNIQUE KEY `path` (`path`),
  UNIQUE KEY `imageid` (`imageid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `frisbee_blobs`
--

LOCK TABLES `frisbee_blobs` WRITE;
/*!40000 ALTER TABLE `frisbee_blobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `frisbee_blobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `fs_resources`
--

DROP TABLE IF EXISTS `fs_resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `fs_resources` (
  `rsrcidx` int unsigned NOT NULL DEFAULT '0',
  `fileidx` int unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `type` enum('r','w','rw','l') DEFAULT 'r',
  `size` int unsigned DEFAULT '0',
  PRIMARY KEY (`rsrcidx`,`fileidx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `fileidx` (`fileidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fs_resources`
--

LOCK TABLES `fs_resources` WRITE;
/*!40000 ALTER TABLE `fs_resources` DISABLE KEYS */;
/*!40000 ALTER TABLE `fs_resources` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `future_reservation_attributes`
--

DROP TABLE IF EXISTS `future_reservation_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `future_reservation_attributes` (
  `reservation_idx` mediumint unsigned NOT NULL,
  `attrkey` varchar(32) NOT NULL,
  `attrvalue` tinytext,
  PRIMARY KEY (`reservation_idx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `future_reservation_attributes`
--

LOCK TABLES `future_reservation_attributes` WRITE;
/*!40000 ALTER TABLE `future_reservation_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `future_reservation_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `future_reservations`
--

DROP TABLE IF EXISTS `future_reservations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `future_reservations` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `nodes` smallint unsigned NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `cancel` datetime DEFAULT NULL,
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `notes` mediumtext,
  `admin_notes` mediumtext,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `approved` datetime DEFAULT NULL,
  `approver` varchar(8) DEFAULT NULL,
  `notified` datetime DEFAULT NULL,
  `notified_unused` datetime DEFAULT NULL,
  `override_unused` tinyint(1) NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `future_reservations`
--

LOCK TABLES `future_reservations` WRITE;
/*!40000 ALTER TABLE `future_reservations` DISABLE KEYS */;
/*!40000 ALTER TABLE `future_reservations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `global_ipalloc`
--

DROP TABLE IF EXISTS `global_ipalloc`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `global_ipalloc` (
  `exptidx` int NOT NULL DEFAULT '0',
  `lanidx` int NOT NULL DEFAULT '0',
  `member` int NOT NULL DEFAULT '0',
  `fabric_idx` int NOT NULL DEFAULT '0',
  `ipint` int unsigned NOT NULL DEFAULT '0',
  `ip` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`exptidx`,`lanidx`,`ipint`),
  UNIQUE KEY `fabip` (`fabric_idx`,`ipint`),
  KEY `ipint` (`ipint`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `global_ipalloc`
--

LOCK TABLES `global_ipalloc` WRITE;
/*!40000 ALTER TABLE `global_ipalloc` DISABLE KEYS */;
/*!40000 ALTER TABLE `global_ipalloc` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `global_policies`
--

DROP TABLE IF EXISTS `global_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `global_policies` (
  `policy` varchar(32) NOT NULL DEFAULT '',
  `auxdata` varchar(128) NOT NULL DEFAULT '',
  `test` varchar(32) NOT NULL DEFAULT '',
  `count` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`policy`,`auxdata`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `global_policies`
--

LOCK TABLES `global_policies` WRITE;
/*!40000 ALTER TABLE `global_policies` DISABLE KEYS */;
/*!40000 ALTER TABLE `global_policies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `global_vtypes`
--

DROP TABLE IF EXISTS `global_vtypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `global_vtypes` (
  `vtype` varchar(30) NOT NULL DEFAULT '',
  `weight` float NOT NULL DEFAULT '0.5',
  `types` text NOT NULL,
  PRIMARY KEY (`vtype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `global_vtypes`
--

LOCK TABLES `global_vtypes` WRITE;
/*!40000 ALTER TABLE `global_vtypes` DISABLE KEYS */;
/*!40000 ALTER TABLE `global_vtypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_exports`
--

DROP TABLE IF EXISTS `group_exports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `group_exports` (
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `peer` varchar(64) NOT NULL DEFAULT '',
  `exported` datetime DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  PRIMARY KEY (`pid_idx`,`gid_idx`,`peer`),
  UNIQUE KEY `pidpeer` (`pid`,`gid`,`peer`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_exports`
--

LOCK TABLES `group_exports` WRITE;
/*!40000 ALTER TABLE `group_exports` DISABLE KEYS */;
/*!40000 ALTER TABLE `group_exports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_features`
--

DROP TABLE IF EXISTS `group_features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `group_features` (
  `feature` varchar(64) NOT NULL DEFAULT '',
  `added` datetime NOT NULL,
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`feature`,`gid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_features`
--

LOCK TABLES `group_features` WRITE;
/*!40000 ALTER TABLE `group_features` DISABLE KEYS */;
/*!40000 ALTER TABLE `group_features` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_membership`
--

DROP TABLE IF EXISTS `group_membership`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `group_membership` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `trust` enum('none','user','local_root','group_root','project_root') DEFAULT NULL,
  `date_applied` date DEFAULT NULL,
  `date_approved` datetime DEFAULT NULL,
  `date_nagged` datetime DEFAULT NULL,
  PRIMARY KEY (`uid_idx`,`gid_idx`),
  UNIQUE KEY `uid` (`uid`,`pid`,`gid`),
  KEY `pid` (`pid`),
  KEY `gid` (`gid`),
  KEY `pid_idx_gid_idx` (`pid_idx`,`gid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_membership`
--

LOCK TABLES `group_membership` WRITE;
/*!40000 ALTER TABLE `group_membership` DISABLE KEYS */;
/*!40000 ALTER TABLE `group_membership` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_policies`
--

DROP TABLE IF EXISTS `group_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `group_policies` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `policy` varchar(32) NOT NULL DEFAULT '',
  `auxdata` varchar(64) NOT NULL DEFAULT '',
  `count` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`pid_idx`,`gid_idx`,`policy`,`auxdata`),
  UNIQUE KEY `pid` (`pid`,`gid`,`policy`,`auxdata`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_policies`
--

LOCK TABLES `group_policies` WRITE;
/*!40000 ALTER TABLE `group_policies` DISABLE KEYS */;
/*!40000 ALTER TABLE `group_policies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_stats`
--

DROP TABLE IF EXISTS `group_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `group_stats` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_uuid` varchar(40) NOT NULL DEFAULT '',
  `exptstart_count` int unsigned DEFAULT '0',
  `exptstart_last` datetime DEFAULT NULL,
  `exptpreload_count` int unsigned DEFAULT '0',
  `exptpreload_last` datetime DEFAULT NULL,
  `exptswapin_count` int unsigned DEFAULT '0',
  `exptswapin_last` datetime DEFAULT NULL,
  `exptswapout_count` int unsigned DEFAULT '0',
  `exptswapout_last` datetime DEFAULT NULL,
  `exptswapmod_count` int unsigned DEFAULT '0',
  `exptswapmod_last` datetime DEFAULT NULL,
  `last_activity` datetime DEFAULT NULL,
  `allexpt_duration` double(14,0) unsigned DEFAULT '0',
  `allexpt_vnodes` int unsigned DEFAULT '0',
  `allexpt_vnode_duration` double(14,0) unsigned DEFAULT '0',
  `allexpt_pnodes` int unsigned DEFAULT '0',
  `allexpt_pnode_duration` double(14,0) unsigned DEFAULT '0',
  PRIMARY KEY (`gid_idx`),
  UNIQUE KEY `pidgid` (`pid`,`gid`),
  KEY `gid_uuid` (`gid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_stats`
--

LOCK TABLES `group_stats` WRITE;
/*!40000 ALTER TABLE `group_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `group_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `groups` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_uuid` varchar(40) NOT NULL DEFAULT '',
  `leader` varchar(8) NOT NULL DEFAULT '',
  `leader_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `description` tinytext,
  `unix_gid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `unix_name` varchar(16) NOT NULL DEFAULT '',
  `expt_count` mediumint unsigned DEFAULT '0',
  `expt_last` date DEFAULT NULL,
  `wikiname` tinytext,
  `mailman_password` tinytext,
  PRIMARY KEY (`gid_idx`),
  UNIQUE KEY `pidgid` (`pid`,`gid`),
  KEY `unix_gid` (`unix_gid`),
  KEY `gid` (`gid`),
  KEY `pid` (`pid`),
  KEY `pididx` (`pid_idx`,`gid_idx`),
  KEY `gid_uuid` (`gid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `groups`
--

LOCK TABLES `groups` WRITE;
/*!40000 ALTER TABLE `groups` DISABLE KEYS */;
/*!40000 ALTER TABLE `groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `iface_counters`
--

DROP TABLE IF EXISTS `iface_counters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `iface_counters` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `tstamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `mac` varchar(12) NOT NULL DEFAULT '0',
  `ipkts` int NOT NULL DEFAULT '0',
  `opkts` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`tstamp`,`mac`),
  KEY `macindex` (`mac`),
  KEY `node_idindex` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `iface_counters`
--

LOCK TABLES `iface_counters` WRITE;
/*!40000 ALTER TABLE `iface_counters` DISABLE KEYS */;
/*!40000 ALTER TABLE `iface_counters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ifaces`
--

DROP TABLE IF EXISTS `ifaces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ifaces` (
  `lanid` int NOT NULL DEFAULT '0',
  `ifaceid` int NOT NULL DEFAULT '0',
  `exptidx` int NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `vidx` int NOT NULL DEFAULT '0',
  `vport` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`lanid`,`ifaceid`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`),
  KEY `lanid` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ifaces`
--

LOCK TABLES `ifaces` WRITE;
/*!40000 ALTER TABLE `ifaces` DISABLE KEYS */;
/*!40000 ALTER TABLE `ifaces` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_aliases`
--

DROP TABLE IF EXISTS `image_aliases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_aliases` (
  `imagename` varchar(30) NOT NULL DEFAULT '',
  `imageid` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `target_imagename` varchar(30) NOT NULL DEFAULT '',
  `target_imageid` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`imageid`,`target_imageid`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_aliases`
--

LOCK TABLES `image_aliases` WRITE;
/*!40000 ALTER TABLE `image_aliases` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_aliases` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_boot_status`
--

DROP TABLE IF EXISTS `image_boot_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_boot_status` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `stamp` int unsigned NOT NULL,
  `exptidx` int NOT NULL DEFAULT '0',
  `rsrcidx` int unsigned DEFAULT NULL,
  `node_id` varchar(32) NOT NULL,
  `node_type` varchar(30) NOT NULL,
  `imageid` int DEFAULT NULL,
  `imageid_version` int DEFAULT NULL,
  `status` enum('success','reloadfail','bootfail','timedout','tbfailed') NOT NULL DEFAULT 'success',
  PRIMARY KEY (`idx`),
  KEY `stamp` (`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_boot_status`
--

LOCK TABLES `image_boot_status` WRITE;
/*!40000 ALTER TABLE `image_boot_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_boot_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_deletions`
--

DROP TABLE IF EXISTS `image_deletions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_deletions` (
  `urn` varchar(128) DEFAULT NULL,
  `image_uuid` varchar(40) NOT NULL DEFAULT '',
  `deleted` datetime DEFAULT NULL,
  PRIMARY KEY (`image_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_deletions`
--

LOCK TABLES `image_deletions` WRITE;
/*!40000 ALTER TABLE `image_deletions` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_deletions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_history`
--

DROP TABLE IF EXISTS `image_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_history` (
  `history_id` int unsigned NOT NULL AUTO_INCREMENT,
  `stamp` int unsigned NOT NULL,
  `node_history_id` int unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL,
  `action` varchar(8) NOT NULL,
  `newly_alloc` int DEFAULT NULL,
  `rsrcidx` int unsigned DEFAULT NULL,
  `log_session` int unsigned DEFAULT NULL,
  `req_type` varchar(30) DEFAULT NULL,
  `phys_type` varchar(30) NOT NULL,
  `req_os` int DEFAULT NULL,
  `osid` int DEFAULT NULL,
  `osid_vers` int DEFAULT NULL,
  `imageid` int DEFAULT NULL,
  `imageid_version` int DEFAULT NULL,
  PRIMARY KEY (`history_id`),
  KEY `node_id` (`node_id`,`history_id`),
  KEY `stamp` (`stamp`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `node_history_id` (`node_history_id`),
  KEY `imagestamp` (`imageid`,`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_history`
--

LOCK TABLES `image_history` WRITE;
/*!40000 ALTER TABLE `image_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_incoming_relocations`
--

DROP TABLE IF EXISTS `image_incoming_relocations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_incoming_relocations` (
  `imagename` varchar(30) NOT NULL DEFAULT '',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `remote_urn` varchar(128) DEFAULT NULL,
  `metadata_url` tinytext,
  `created` datetime DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  PRIMARY KEY (`pid_idx`,`imagename`),
  UNIQUE KEY `remote_urn` (`remote_urn`),
  UNIQUE KEY `metadata_url` (`metadata_url`(128))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_incoming_relocations`
--

LOCK TABLES `image_incoming_relocations` WRITE;
/*!40000 ALTER TABLE `image_incoming_relocations` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_incoming_relocations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_notifications`
--

DROP TABLE IF EXISTS `image_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_notifications` (
  `imageid` int unsigned NOT NULL DEFAULT '0',
  `version` int unsigned NOT NULL DEFAULT '0',
  `origin_uuid` varchar(64) DEFAULT NULL,
  `notified` datetime DEFAULT NULL,
  PRIMARY KEY (`imageid`,`version`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_notifications`
--

LOCK TABLES `image_notifications` WRITE;
/*!40000 ALTER TABLE `image_notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_pending_imports`
--

DROP TABLE IF EXISTS `image_pending_imports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_pending_imports` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `imagename` varchar(30) NOT NULL DEFAULT '',
  `imageid` int unsigned DEFAULT NULL,
  `imageuuid` varchar(40) DEFAULT NULL,
  `uid` varchar(8) DEFAULT NULL,
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid_urn` varchar(128) DEFAULT NULL,
  `pid` varchar(48) DEFAULT NULL,
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) DEFAULT NULL,
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `type` enum('import','copyback','relocation') DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  `failed` datetime DEFAULT NULL,
  `failure_message` text,
  `remote_urn` varchar(128) DEFAULT NULL,
  `metadata_url` varchar(256) DEFAULT '',
  `credential_string` text,
  PRIMARY KEY (`idx`),
  UNIQUE KEY `url` (`metadata_url`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_pending_imports`
--

LOCK TABLES `image_pending_imports` WRITE;
/*!40000 ALTER TABLE `image_pending_imports` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_pending_imports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_permissions`
--

DROP TABLE IF EXISTS `image_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_permissions` (
  `imageid` int unsigned NOT NULL DEFAULT '0',
  `imagename` varchar(30) NOT NULL DEFAULT '',
  `permission_type` enum('user','group') NOT NULL DEFAULT 'user',
  `permission_id` varchar(128) NOT NULL DEFAULT '',
  `permission_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `allow_write` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`imageid`,`permission_type`,`permission_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_permissions`
--

LOCK TABLES `image_permissions` WRITE;
/*!40000 ALTER TABLE `image_permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_updates`
--

DROP TABLE IF EXISTS `image_updates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_updates` (
  `imageid` int unsigned NOT NULL DEFAULT '0',
  `updater` varchar(8) DEFAULT NULL,
  `updater_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `updater_urn` varchar(128) DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `url` varchar(255) NOT NULL DEFAULT '',
  `credential_string` text,
  PRIMARY KEY (`imageid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_updates`
--

LOCK TABLES `image_updates` WRITE;
/*!40000 ALTER TABLE `image_updates` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_updates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `image_versions`
--

DROP TABLE IF EXISTS `image_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `image_versions` (
  `imagename` varchar(30) NOT NULL DEFAULT '',
  `version` int unsigned NOT NULL DEFAULT '0',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `imageid` int unsigned NOT NULL DEFAULT '0',
  `parent_imageid` int unsigned DEFAULT NULL,
  `parent_version` int unsigned DEFAULT NULL,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `old_imageid` varchar(45) NOT NULL DEFAULT '',
  `creator` varchar(8) DEFAULT NULL,
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `creator_urn` varchar(128) DEFAULT NULL,
  `created` datetime DEFAULT NULL,
  `updater` varchar(8) DEFAULT NULL,
  `updater_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `updater_urn` varchar(128) DEFAULT NULL,
  `description` tinytext NOT NULL,
  `loadpart` tinyint NOT NULL DEFAULT '0',
  `loadlength` tinyint NOT NULL DEFAULT '0',
  `part1_osid` int unsigned DEFAULT NULL,
  `part1_vers` int unsigned NOT NULL DEFAULT '0',
  `part2_osid` int unsigned DEFAULT NULL,
  `part2_vers` int unsigned NOT NULL DEFAULT '0',
  `part3_osid` int unsigned DEFAULT NULL,
  `part3_vers` int unsigned NOT NULL DEFAULT '0',
  `part4_osid` int unsigned DEFAULT NULL,
  `part4_vers` int unsigned NOT NULL DEFAULT '0',
  `default_osid` int unsigned NOT NULL DEFAULT '0',
  `default_vers` int unsigned NOT NULL DEFAULT '0',
  `path` tinytext,
  `magic` tinytext,
  `ezid` tinyint NOT NULL DEFAULT '0',
  `shared` tinyint NOT NULL DEFAULT '0',
  `global` tinyint NOT NULL DEFAULT '0',
  `mbr_version` varchar(50) NOT NULL DEFAULT '1',
  `updated` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `last_used` datetime DEFAULT NULL,
  `format` varchar(8) NOT NULL DEFAULT 'ndz',
  `access_key` varchar(64) DEFAULT NULL,
  `auth_uuid` varchar(64) DEFAULT NULL,
  `auth_key` varchar(512) DEFAULT NULL,
  `decryption_key` varchar(256) DEFAULT NULL,
  `hash` varchar(64) DEFAULT NULL,
  `deltahash` varchar(64) DEFAULT NULL,
  `size` bigint unsigned NOT NULL DEFAULT '0',
  `deltasize` bigint unsigned NOT NULL DEFAULT '0',
  `lba_low` bigint unsigned NOT NULL DEFAULT '0',
  `lba_high` bigint unsigned NOT NULL DEFAULT '0',
  `lba_size` int unsigned NOT NULL DEFAULT '512',
  `relocatable` tinyint(1) NOT NULL DEFAULT '0',
  `metadata_url` tinytext,
  `imagefile_url` tinytext,
  `origin_urn` varchar(128) DEFAULT NULL,
  `origin_name` varchar(128) DEFAULT NULL,
  `origin_uuid` varchar(64) DEFAULT NULL,
  `origin_neednotify` tinyint(1) NOT NULL DEFAULT '0',
  `origin_needupdate` tinyint(1) NOT NULL DEFAULT '0',
  `authority_urn` varchar(128) DEFAULT NULL,
  `credential_string_save` text,
  `logfileid` varchar(40) DEFAULT NULL,
  `noexport` tinyint(1) NOT NULL DEFAULT '0',
  `noclone` tinyint(1) NOT NULL DEFAULT '0',
  `ready` tinyint(1) NOT NULL DEFAULT '0',
  `isdelta` tinyint(1) NOT NULL DEFAULT '0',
  `isdataset` tinyint(1) NOT NULL DEFAULT '0',
  `released` tinyint(1) NOT NULL DEFAULT '0',
  `ims_reported` datetime DEFAULT NULL,
  `ims_update` datetime DEFAULT NULL,
  `ims_noreport` tinyint(1) NOT NULL DEFAULT '0',
  `nodetypes` text,
  `uploader_path` tinytext,
  `uploader_status` tinytext,
  `notes` mediumtext,
  `deprecated` datetime DEFAULT NULL,
  `deprecated_iserror` tinyint(1) NOT NULL DEFAULT '0',
  `deprecated_message` mediumtext,
  PRIMARY KEY (`imageid`,`version`),
  KEY `pid` (`pid`,`imagename`,`version`),
  KEY `gid` (`gid`),
  KEY `old_imageid` (`old_imageid`),
  KEY `uuid` (`uuid`),
  FULLTEXT KEY `imagesearch` (`imagename`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `image_versions`
--

LOCK TABLES `image_versions` WRITE;
/*!40000 ALTER TABLE `image_versions` DISABLE KEYS */;
/*!40000 ALTER TABLE `image_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `images`
--

DROP TABLE IF EXISTS `images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `images` (
  `imagename` varchar(30) NOT NULL DEFAULT '',
  `architecture` varchar(30) DEFAULT NULL,
  `version` int unsigned NOT NULL DEFAULT '0',
  `imageid` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `webtask_id` varchar(128) DEFAULT NULL,
  `listed` tinyint(1) NOT NULL DEFAULT '1',
  `nodelta` tinyint(1) NOT NULL DEFAULT '0',
  `noversioning` tinyint(1) NOT NULL DEFAULT '0',
  `metadata_url` tinytext,
  `relocate_urn` tinytext,
  `credential_string` text,
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  PRIMARY KEY (`imageid`),
  UNIQUE KEY `pid` (`pid`,`imagename`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `images`
--

LOCK TABLES `images` WRITE;
/*!40000 ALTER TABLE `images` DISABLE KEYS */;
/*!40000 ALTER TABLE `images` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `interface_capabilities`
--

DROP TABLE IF EXISTS `interface_capabilities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interface_capabilities` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `capkey` varchar(64) NOT NULL DEFAULT '',
  `capval` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`type`,`capkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `interface_capabilities`
--

LOCK TABLES `interface_capabilities` WRITE;
/*!40000 ALTER TABLE `interface_capabilities` DISABLE KEYS */;
/*!40000 ALTER TABLE `interface_capabilities` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `interface_settings`
--

DROP TABLE IF EXISTS `interface_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interface_settings` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `iface` varchar(32) NOT NULL DEFAULT '',
  `capkey` varchar(32) NOT NULL DEFAULT '',
  `capval` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`node_id`,`iface`,`capkey`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `interface_settings`
--

LOCK TABLES `interface_settings` WRITE;
/*!40000 ALTER TABLE `interface_settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `interface_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `interface_state`
--

DROP TABLE IF EXISTS `interface_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interface_state` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `card_saved` tinyint unsigned NOT NULL DEFAULT '0',
  `port_saved` smallint unsigned NOT NULL DEFAULT '0',
  `iface` varchar(32) NOT NULL,
  `enabled` tinyint(1) DEFAULT '1',
  `tagged` tinyint(1) DEFAULT '0',
  `remaining_bandwidth` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`iface`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `interface_state`
--

LOCK TABLES `interface_state` WRITE;
/*!40000 ALTER TABLE `interface_state` DISABLE KEYS */;
/*!40000 ALTER TABLE `interface_state` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `interface_types`
--

DROP TABLE IF EXISTS `interface_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interface_types` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `max_speed` int DEFAULT NULL,
  `full_duplex` tinyint(1) DEFAULT NULL,
  `manufacturer` varchar(30) DEFAULT NULL,
  `model` varchar(30) DEFAULT NULL,
  `ports` smallint unsigned DEFAULT NULL,
  `connector` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `interface_types`
--

LOCK TABLES `interface_types` WRITE;
/*!40000 ALTER TABLE `interface_types` DISABLE KEYS */;
/*!40000 ALTER TABLE `interface_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `interfaces`
--

DROP TABLE IF EXISTS `interfaces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interfaces` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `card_saved` tinyint unsigned NOT NULL DEFAULT '0',
  `port_saved` smallint unsigned NOT NULL DEFAULT '0',
  `mac` varchar(12) NOT NULL DEFAULT '000000000000',
  `guid` varchar(16) DEFAULT NULL,
  `IP` varchar(15) DEFAULT NULL,
  `IPaliases` text,
  `mask` varchar(15) DEFAULT NULL,
  `interface_type` varchar(30) DEFAULT NULL,
  `iface` text NOT NULL,
  `role` enum('ctrl','expt','jail','fake','other','gw','outer_ctrl','mngmnt') DEFAULT NULL,
  `current_speed` varchar(12) NOT NULL DEFAULT '0',
  `duplex` enum('full','half') NOT NULL DEFAULT 'full',
  `noportcontrol` tinyint(1) NOT NULL DEFAULT '0',
  `rtabid` smallint unsigned NOT NULL DEFAULT '0',
  `vnode_id` varchar(32) DEFAULT NULL,
  `whol` tinyint NOT NULL DEFAULT '0',
  `trunk` tinyint(1) NOT NULL DEFAULT '0',
  `trunk_mode` enum('equal','dual') NOT NULL DEFAULT 'equal',
  `LAG` tinyint(1) NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `logical` tinyint unsigned NOT NULL DEFAULT '0',
  `autocreated` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`iface`(128)),
  KEY `mac` (`mac`),
  KEY `IP` (`IP`),
  KEY `uuid` (`uuid`),
  KEY `role` (`role`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `interfaces`
--

LOCK TABLES `interfaces` WRITE;
/*!40000 ALTER TABLE `interfaces` DISABLE KEYS */;
INSERT INTO `interfaces` VALUES ('pow1',0,0,'000000000000',NULL,'127.0.0.0',NULL,NULL,NULL,'0',NULL,'0','full',0,0,NULL,0,0,'equal',0,'',0,0),('1',0,0,'000000000000',NULL,'127.0.0.0',NULL,NULL,NULL,'1',NULL,'0','full',0,0,NULL,0,0,'equal',0,'',0,0),('2',0,0,'000000000000',NULL,'127.0.0.0',NULL,NULL,NULL,'2',NULL,'0','full',0,0,NULL,0,0,'equal',0,'',0,0),('pow2',0,0,'000000000000',NULL,'127.0.0.0',NULL,NULL,NULL,'4',NULL,'0','full',0,0,NULL,0,0,'equal',0,'',0,0),('pow3',0,0,'000000000000',NULL,'127.0.0.0',NULL,NULL,NULL,'5',NULL,'0','full',0,0,NULL,0,0,'equal',0,'',0,0);
/*!40000 ALTER TABLE `interfaces` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `interfaces_rf_limit`
--

DROP TABLE IF EXISTS `interfaces_rf_limit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `interfaces_rf_limit` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `iface` text NOT NULL,
  `freq_low` float(8,2) NOT NULL DEFAULT '0.00',
  `freq_high` float(8,2) NOT NULL DEFAULT '0.00',
  `power` float(8,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`node_id`,`iface`(128),`freq_low`,`freq_high`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `interfaces_rf_limit`
--

LOCK TABLES `interfaces_rf_limit` WRITE;
/*!40000 ALTER TABLE `interfaces_rf_limit` DISABLE KEYS */;
/*!40000 ALTER TABLE `interfaces_rf_limit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ipport_ranges`
--

DROP TABLE IF EXISTS `ipport_ranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ipport_ranges` (
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `low` int NOT NULL DEFAULT '0',
  `high` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ipport_ranges`
--

LOCK TABLES `ipport_ranges` WRITE;
/*!40000 ALTER TABLE `ipport_ranges` DISABLE KEYS */;
/*!40000 ALTER TABLE `ipport_ranges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ipsubnets`
--

DROP TABLE IF EXISTS `ipsubnets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ipsubnets` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `idx` smallint unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`idx`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ipsubnets`
--

LOCK TABLES `ipsubnets` WRITE;
/*!40000 ALTER TABLE `ipsubnets` DISABLE KEYS */;
/*!40000 ALTER TABLE `ipsubnets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `knowledge_base_entries`
--

DROP TABLE IF EXISTS `knowledge_base_entries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `knowledge_base_entries` (
  `idx` int NOT NULL AUTO_INCREMENT,
  `creator_uid` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `date_created` datetime DEFAULT NULL,
  `section` tinytext,
  `title` tinytext,
  `body` text,
  `xref_tag` varchar(64) DEFAULT NULL,
  `faq_entry` tinyint(1) NOT NULL DEFAULT '0',
  `date_modified` datetime DEFAULT NULL,
  `modifier_uid` varchar(8) DEFAULT NULL,
  `modifier_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `archived` tinyint(1) NOT NULL DEFAULT '0',
  `date_archived` datetime DEFAULT NULL,
  `archiver_uid` varchar(8) DEFAULT NULL,
  `archiver_idx` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `knowledge_base_entries`
--

LOCK TABLES `knowledge_base_entries` WRITE;
/*!40000 ALTER TABLE `knowledge_base_entries` DISABLE KEYS */;
/*!40000 ALTER TABLE `knowledge_base_entries` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lan_attributes`
--

DROP TABLE IF EXISTS `lan_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lan_attributes` (
  `lanid` int NOT NULL DEFAULT '0',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` text NOT NULL,
  `attrtype` enum('integer','float','boolean','string') DEFAULT 'string',
  PRIMARY KEY (`lanid`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lan_attributes`
--

LOCK TABLES `lan_attributes` WRITE;
/*!40000 ALTER TABLE `lan_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `lan_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lan_member_attributes`
--

DROP TABLE IF EXISTS `lan_member_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lan_member_attributes` (
  `lanid` int NOT NULL DEFAULT '0',
  `memberid` int NOT NULL DEFAULT '0',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') DEFAULT 'string',
  PRIMARY KEY (`lanid`,`memberid`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lan_member_attributes`
--

LOCK TABLES `lan_member_attributes` WRITE;
/*!40000 ALTER TABLE `lan_member_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `lan_member_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lan_members`
--

DROP TABLE IF EXISTS `lan_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lan_members` (
  `lanid` int NOT NULL DEFAULT '0',
  `memberid` int NOT NULL AUTO_INCREMENT,
  `node_id` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`lanid`,`memberid`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lan_members`
--

LOCK TABLES `lan_members` WRITE;
/*!40000 ALTER TABLE `lan_members` DISABLE KEYS */;
/*!40000 ALTER TABLE `lan_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lans`
--

DROP TABLE IF EXISTS `lans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lans` (
  `lanid` int NOT NULL AUTO_INCREMENT,
  `exptidx` int NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(64) NOT NULL DEFAULT '',
  `vidx` int NOT NULL DEFAULT '0',
  `type` varchar(32) NOT NULL DEFAULT '',
  `link` int DEFAULT NULL,
  `ready` tinyint(1) DEFAULT '0',
  `locked` datetime DEFAULT NULL,
  PRIMARY KEY (`lanid`),
  KEY `pideid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lans`
--

LOCK TABLES `lans` WRITE;
/*!40000 ALTER TABLE `lans` DISABLE KEYS */;
/*!40000 ALTER TABLE `lans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `last_reservation`
--

DROP TABLE IF EXISTS `last_reservation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `last_reservation` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`pid_idx`),
  UNIQUE KEY `pid` (`node_id`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `last_reservation`
--

LOCK TABLES `last_reservation` WRITE;
/*!40000 ALTER TABLE `last_reservation` DISABLE KEYS */;
/*!40000 ALTER TABLE `last_reservation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lease_attributes`
--

DROP TABLE IF EXISTS `lease_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lease_attributes` (
  `lease_idx` int unsigned NOT NULL DEFAULT '0',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrval` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') DEFAULT 'string',
  PRIMARY KEY (`lease_idx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lease_attributes`
--

LOCK TABLES `lease_attributes` WRITE;
/*!40000 ALTER TABLE `lease_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `lease_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lease_permissions`
--

DROP TABLE IF EXISTS `lease_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lease_permissions` (
  `lease_idx` int unsigned NOT NULL DEFAULT '0',
  `lease_id` varchar(32) NOT NULL DEFAULT '',
  `permission_type` enum('user','group','global') NOT NULL DEFAULT 'user',
  `permission_id` varchar(128) NOT NULL DEFAULT '',
  `permission_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `allow_modify` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`lease_idx`,`permission_type`,`permission_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lease_permissions`
--

LOCK TABLES `lease_permissions` WRITE;
/*!40000 ALTER TABLE `lease_permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `lease_permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `licenses`
--

DROP TABLE IF EXISTS `licenses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `licenses` (
  `license_idx` int NOT NULL AUTO_INCREMENT,
  `license_name` varchar(48) NOT NULL DEFAULT '',
  `license_level` enum('project','user') NOT NULL DEFAULT 'project',
  `license_target` enum('signup','usage') NOT NULL DEFAULT 'signup',
  `created` datetime DEFAULT NULL,
  `validfor` int NOT NULL DEFAULT '0',
  `form_text` tinytext,
  `license_text` text,
  `license_type` enum('md','text','html') NOT NULL DEFAULT 'md',
  `description_text` text,
  `description_type` enum('md','text','html') NOT NULL DEFAULT 'md',
  PRIMARY KEY (`license_idx`),
  UNIQUE KEY `license_name` (`license_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `licenses`
--

LOCK TABLES `licenses` WRITE;
/*!40000 ALTER TABLE `licenses` DISABLE KEYS */;
/*!40000 ALTER TABLE `licenses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `linkdelays`
--

DROP TABLE IF EXISTS `linkdelays`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `linkdelays` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `iface` varchar(8) NOT NULL DEFAULT '',
  `ip` varchar(15) NOT NULL DEFAULT '',
  `netmask` varchar(15) NOT NULL DEFAULT '255.255.255.0',
  `type` enum('simplex','duplex') NOT NULL DEFAULT 'duplex',
  `exptidx` int NOT NULL DEFAULT '0',
  `eid` varchar(32) DEFAULT NULL,
  `pid` varchar(48) DEFAULT NULL,
  `vlan` varchar(32) NOT NULL DEFAULT '',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `pipe` smallint unsigned NOT NULL DEFAULT '0',
  `delay` float(10,2) NOT NULL DEFAULT '0.00',
  `bandwidth` int unsigned NOT NULL DEFAULT '100',
  `lossrate` float(10,8) NOT NULL DEFAULT '0.00000000',
  `rpipe` smallint unsigned NOT NULL DEFAULT '0',
  `rdelay` float(10,2) NOT NULL DEFAULT '0.00',
  `rbandwidth` int unsigned NOT NULL DEFAULT '100',
  `rlossrate` float(10,8) NOT NULL DEFAULT '0.00000000',
  `q_limit` int DEFAULT '0',
  `q_maxthresh` int DEFAULT '0',
  `q_minthresh` int DEFAULT '0',
  `q_weight` float DEFAULT '0',
  `q_linterm` int DEFAULT '0',
  `q_qinbytes` tinyint DEFAULT '0',
  `q_bytes` tinyint DEFAULT '0',
  `q_meanpsize` int DEFAULT '0',
  `q_wait` int DEFAULT '0',
  `q_setbit` int DEFAULT '0',
  `q_droptail` int DEFAULT '0',
  `q_red` tinyint DEFAULT '0',
  `q_gentle` tinyint DEFAULT '0',
  PRIMARY KEY (`exptidx`,`node_id`,`vlan`,`vnode`),
  KEY `id` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `linkdelays`
--

LOCK TABLES `linkdelays` WRITE;
/*!40000 ALTER TABLE `linkdelays` DISABLE KEYS */;
/*!40000 ALTER TABLE `linkdelays` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `location_info`
--

DROP TABLE IF EXISTS `location_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `location_info` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `floor` varchar(32) NOT NULL DEFAULT '',
  `building` varchar(32) NOT NULL DEFAULT '',
  `loc_x` int unsigned NOT NULL DEFAULT '0',
  `loc_y` int unsigned NOT NULL DEFAULT '0',
  `loc_z` float DEFAULT NULL,
  `orientation` float DEFAULT NULL,
  `contact` tinytext,
  `email` tinytext,
  `phone` tinytext,
  `room` varchar(32) DEFAULT NULL,
  `stamp` int unsigned DEFAULT NULL,
  PRIMARY KEY (`node_id`,`building`,`floor`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `location_info`
--

LOCK TABLES `location_info` WRITE;
/*!40000 ALTER TABLE `location_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `location_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `log`
--

DROP TABLE IF EXISTS `log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `log` (
  `seq` int unsigned NOT NULL DEFAULT '0',
  `stamp` int unsigned NOT NULL DEFAULT '0',
  `session` int unsigned NOT NULL DEFAULT '0',
  `attempt` tinyint(1) NOT NULL DEFAULT '0',
  `cleanup` tinyint(1) NOT NULL DEFAULT '0',
  `invocation` int unsigned NOT NULL DEFAULT '0',
  `parent` int unsigned NOT NULL DEFAULT '0',
  `script` smallint NOT NULL DEFAULT '0',
  `level` tinyint NOT NULL DEFAULT '0',
  `sublevel` tinyint NOT NULL DEFAULT '0',
  `priority` smallint NOT NULL DEFAULT '0',
  `inferred` tinyint(1) NOT NULL DEFAULT '0',
  `cause` varchar(16) NOT NULL DEFAULT '',
  `type` enum('normal','entering','exiting','thecause','extra','summary','primary','secondary') DEFAULT 'normal',
  `relevant` tinyint(1) NOT NULL DEFAULT '0',
  `mesg` text NOT NULL,
  PRIMARY KEY (`seq`),
  KEY `session` (`session`),
  KEY `stamp` (`stamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `log`
--

LOCK TABLES `log` WRITE;
/*!40000 ALTER TABLE `log` DISABLE KEYS */;
/*!40000 ALTER TABLE `log` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logfile_metadata`
--

DROP TABLE IF EXISTS `logfile_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `logfile_metadata` (
  `logidx` int unsigned NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `metakey` tinytext,
  `metaval` tinytext,
  PRIMARY KEY (`logidx`,`idx`),
  UNIQUE KEY `logidxkey` (`logidx`,`metakey`(128)),
  KEY `headervalue` (`metakey`(64),`metaval`(128))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logfile_metadata`
--

LOCK TABLES `logfile_metadata` WRITE;
/*!40000 ALTER TABLE `logfile_metadata` DISABLE KEYS */;
/*!40000 ALTER TABLE `logfile_metadata` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logfiles`
--

DROP TABLE IF EXISTS `logfiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `logfiles` (
  `logid` varchar(40) NOT NULL DEFAULT '',
  `logidx` int unsigned NOT NULL DEFAULT '0',
  `filename` tinytext,
  `isopen` tinyint NOT NULL DEFAULT '0',
  `gid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `date_created` datetime DEFAULT NULL,
  `public` tinyint(1) NOT NULL DEFAULT '0',
  `compressed` tinyint(1) NOT NULL DEFAULT '0',
  `stored` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`logid`),
  KEY `logidx` (`logidx`),
  KEY `filename` (`filename`(128)),
  KEY `isopen` (`isopen`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logfiles`
--

LOCK TABLES `logfiles` WRITE;
/*!40000 ALTER TABLE `logfiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `logfiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logical_wires`
--

DROP TABLE IF EXISTS `logical_wires`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `logical_wires` (
  `type` enum('Node','Trunk','Unused') NOT NULL DEFAULT 'Unused',
  `node_id1` char(32) NOT NULL DEFAULT '',
  `iface1` char(128) NOT NULL DEFAULT '',
  `physiface1` char(128) NOT NULL DEFAULT '',
  `node_id2` char(32) NOT NULL DEFAULT '',
  `iface2` char(128) NOT NULL DEFAULT '',
  `physiface2` char(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`node_id1`,`iface1`,`node_id2`,`iface2`),
  UNIQUE KEY `physiface` (`node_id1`,`physiface1`,`node_id2`,`physiface2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logical_wires`
--

LOCK TABLES `logical_wires` WRITE;
/*!40000 ALTER TABLE `logical_wires` DISABLE KEYS */;
/*!40000 ALTER TABLE `logical_wires` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `login`
--

DROP TABLE IF EXISTS `login`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `login` (
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid` varchar(10) NOT NULL DEFAULT '',
  `hashkey` varchar(64) NOT NULL DEFAULT '',
  `hashhash` varchar(64) NOT NULL DEFAULT '',
  `timeout` varchar(10) NOT NULL DEFAULT '',
  `adminon` tinyint(1) NOT NULL DEFAULT '0',
  `opskey` varchar(64) NOT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') NOT NULL DEFAULT 'emulab',
  PRIMARY KEY (`uid_idx`,`hashkey`),
  UNIQUE KEY `hashhash` (`uid_idx`,`hashhash`),
  UNIQUE KEY `uidkey` (`uid`,`hashkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `login`
--

LOCK TABLES `login` WRITE;
/*!40000 ALTER TABLE `login` DISABLE KEYS */;
/*!40000 ALTER TABLE `login` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `login_failures`
--

DROP TABLE IF EXISTS `login_failures`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_failures` (
  `IP` varchar(15) NOT NULL DEFAULT '1.1.1.1',
  `frozen` tinyint unsigned NOT NULL DEFAULT '0',
  `failcount` smallint unsigned NOT NULL DEFAULT '0',
  `failstamp` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `login_failures`
--

LOCK TABLES `login_failures` WRITE;
/*!40000 ALTER TABLE `login_failures` DISABLE KEYS */;
/*!40000 ALTER TABLE `login_failures` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `login_history`
--

DROP TABLE IF EXISTS `login_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_history` (
  `idx` int NOT NULL AUTO_INCREMENT,
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid` varchar(10) NOT NULL DEFAULT '',
  `tstamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `IP` varchar(16) DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `idxstamp` (`uid_idx`,`tstamp`),
  KEY `uidstamp` (`uid`,`tstamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `login_history`
--

LOCK TABLES `login_history` WRITE;
/*!40000 ALTER TABLE `login_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `login_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `loginmessage`
--

DROP TABLE IF EXISTS `loginmessage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `loginmessage` (
  `valid` tinyint NOT NULL DEFAULT '1',
  `message` tinytext NOT NULL,
  PRIMARY KEY (`valid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `loginmessage`
--

LOCK TABLES `loginmessage` WRITE;
/*!40000 ALTER TABLE `loginmessage` DISABLE KEYS */;
/*!40000 ALTER TABLE `loginmessage` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mailman_listnames`
--

DROP TABLE IF EXISTS `mailman_listnames`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mailman_listnames` (
  `listname` varchar(64) NOT NULL DEFAULT '',
  `owner_uid` varchar(8) NOT NULL DEFAULT '',
  `owner_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  PRIMARY KEY (`listname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mailman_listnames`
--

LOCK TABLES `mailman_listnames` WRITE;
/*!40000 ALTER TABLE `mailman_listnames` DISABLE KEYS */;
/*!40000 ALTER TABLE `mailman_listnames` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mode_transitions`
--

DROP TABLE IF EXISTS `mode_transitions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mode_transitions` (
  `op_mode1` varchar(20) NOT NULL DEFAULT '',
  `state1` varchar(20) NOT NULL DEFAULT '',
  `op_mode2` varchar(20) NOT NULL DEFAULT '',
  `state2` varchar(20) NOT NULL DEFAULT '',
  `label` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`op_mode1`,`state1`,`op_mode2`,`state2`),
  KEY `op_mode1` (`op_mode1`,`state1`),
  KEY `op_mode2` (`op_mode2`,`state2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mode_transitions`
--

LOCK TABLES `mode_transitions` WRITE;
/*!40000 ALTER TABLE `mode_transitions` DISABLE KEYS */;
INSERT INTO `mode_transitions` VALUES ('MINIMAL','SHUTDOWN','NETBOOT','SHUTDOWN',''),('MINIMAL','SHUTDOWN','NORMAL','REBOOTING',''),('MINIMAL','SHUTDOWN','NORMALv1','SHUTDOWN',''),('MINIMAL','SHUTDOWN','RELOAD','SHUTDOWN',''),('NETBOOT','SHUTDOWN','MINIMAL','SHUTDOWN',''),('NETBOOT','SHUTDOWN','NORMAL','REBOOTING',''),('NETBOOT','SHUTDOWN','NORMALv1','SHUTDOWN',''),('NETBOOT','SHUTDOWN','RELOAD','SHUTDOWN',''),('NORMAL','REBOOTING','MINIMAL','SHUTDOWN',''),('NORMAL','REBOOTING','NETBOOT','SHUTDOWN',''),('NORMAL','REBOOTING','NORMALv1','SHUTDOWN',''),('NORMAL','REBOOTING','RELOAD','SHUTDOWN',''),('NORMAL','SHUTDOWN','MINIMAL','SHUTDOWN',''),('NORMAL','SHUTDOWN','NETBOOT','SHUTDOWN',''),('NORMAL','SHUTDOWN','NORMALv1','SHUTDOWN',''),('NORMAL','SHUTDOWN','RELOAD','SHUTDOWN',''),('NORMALv1','SHUTDOWN','MINIMAL','SHUTDOWN',''),('NORMALv1','SHUTDOWN','NETBOOT','SHUTDOWN',''),('NORMALv1','SHUTDOWN','NORMAL','REBOOTING',''),('NORMALv1','SHUTDOWN','RELOAD','SHUTDOWN',''),('RELOAD','RELOADDONE','MINIMAL','SHUTDOWN',''),('RELOAD','RELOADDONEV2','MINIMAL','SHUTDOWN',''),('RELOAD','RELOADDONE','NETBOOT','SHUTDOWN',''),('RELOAD','RELOADDONE','NORMAL','REBOOTING',''),('RELOAD','RELOADDONEV2','NORMAL','REBOOTING',''),('RELOAD','RELOADDONE','NORMALv1','SHUTDOWN',''),('RELOAD','RELOADDONEV2','NORMALv1','SHUTDOWN',''),('RELOAD','SHUTDOWN','MINIMAL','SHUTDOWN',''),('RELOAD','SHUTDOWN','NETBOOT','SHUTDOWN',''),('RELOAD','SHUTDOWN','NORMAL','REBOOTING',''),('RELOAD','SHUTDOWN','NORMALv1','SHUTDOWN',''),('MINIMAL','SHUTDOWN','NORMALv2','SHUTDOWN',''),('NORMALv2','SHUTDOWN','NORMALv1','SHUTDOWN',''),('NETBOOT','SHUTDOWN','NORMALv2','SHUTDOWN',''),('PXEFBSD','SHUTDOWN','NORMAL','REBOOTING',''),('PXEFBSD','SHUTDOWN','NORMALv1','SHUTDOWN',''),('PXEFBSD','SHUTDOWN','NORMAL','SHUTDOWN',''),('PXEFBSD','SHUTDOWN','MINIMAL','SHUTDOWN',''),('PXEFBSD','SHUTDOWN','NETBOOT','SHUTDOWN',''),('PXEFBSD','SHUTDOWN','NORMALv2','SHUTDOWN',''),('PXEFBSD','SHUTDOWN','RELOAD','SHUTDOWN',''),('NORMALv2','SHUTDOWN','MINIMAL','SHUTDOWN',''),('NORMALv2','SHUTDOWN','NETBOOT','SHUTDOWN',''),('NORMALv2','SHUTDOWN','RELOAD','SHUTDOWN',''),('RELOAD','SHUTDOWN','PXEFBSD','SHUTDOWN',''),('RELOAD','RELOADDONE','NORMALv2','SHUTDOWN',''),('RELOAD','RELOADDONEV2','NORMALv2','SHUTDOWN',''),('NORMALv2','SHUTDOWN','PXEFBSD','SHUTDOWN',''),('RELOAD','SHUTDOWN','NORMALv2','SHUTDOWN',''),('NORMALv1','SHUTDOWN','PXEFBSD','SHUTDOWN',''),('NORMAL','SHUTDOWN','PXEFBSD','SHUTDOWN',''),('NETBOOT','SHUTDOWN','PXEFBSD','SHUTDOWN',''),('MINIMAL','SHUTDOWN','PXEFBSD','SHUTDOWN',''),('NORMAL','REBOOTING','NORMALv2','SHUTDOWN',''),('NORMALv2','SHUTDOWN','NORMAL','REBOOTING',''),('NORMALv2','SHUTDOWN','RELOAD-PCVM','SHUTDOWN','vnodereload'),('NORMALv1','SHUTDOWN','NORMALv2','SHUTDOWN',''),('ALWAYSUP','SHUTDOWN','RELOAD-MOTE','SHUTDOWN','ReloadStart'),('ALWAYSUP','ISUP','RELOAD-MOTE','SHUTDOWN','ReloadStart'),('ALWAYSUP','ISUP','RELOAD-MOTE','ISUP','ReloadStart'),('RELOAD-MOTE','SHUTDOWN','ALWAYSUP','ISUP','ReloadDone'),('PCVM','SHUTDOWN','RELOAD-PCVM','SHUTDOWN','ReloadSetup'),('RELOAD-PCVM','SHUTDOWN','PCVM','SHUTDOWN','ReloadDone'),('RELOAD-PCVM','RELOADDONE','NORMALv2','SHUTDOWN',''),('RELOAD-PCVM','SHUTDOWN','NORMALv2','SHUTDOWN',''),('RELOAD-PUSH','SHUTDOWN','MINIMAL','SHUTDOWN','ReloadDone'),('MINIMAL','SHUTDOWN','RELOAD-PUSH','SHUTDOWN','ReloadStart'),('SECUREBOOT','TPMSIGNOFF','MINIMAL','SHUTDOWN',''),('SECUREBOOT','TPMSIGNOFF','NORMAL','SHUTDOWN',''),('SECUREBOOT','TPMSIGNOFF','NORMALv2','SHUTDOWN',''),('SECUREBOOT','TPMSIGNOFF','PXEFBSD','SHUTDOWN',''),('SECUREBOOT','TPMSIGNOFF','PXEKERNEL','SHUTDOWN','SecureBootDone'),('NORMALv2','SHUTDOWN','SECURELOAD','SHUTDOWN','SecureLoadStart'),('PXEFBSD','SHUTDOWN','WIMRELOAD','SHUTDOWN',''),('MINIMAL','SHUTDOWN','WIMRELOAD','SHUTDOWN',''),('NETBOOT','SHUTDOWN','WIMRELOAD','SHUTDOWN',''),('NORMAL','SHUTDOWN','WIMRELOAD','SHUTDOWN',''),('NORMALv1','SHUTDOWN','WIMRELOAD','SHUTDOWN',''),('NORMALv2','SHUTDOWN','WIMRELOAD','SHUTDOWN',''),('WIMRELOAD','SHUTDOWN','PXEFBSD','SHUTDOWN',''),('WIMRELOAD','SHUTDOWN','MINIMAL','SHUTDOWN',''),('WIMRELOAD','SHUTDOWN','NETBOOT','SHUTDOWN',''),('WIMRELOAD','SHUTDOWN','NORMAL','REBOOTING',''),('WIMRELOAD','SHUTDOWN','NORMALv1','SHUTDOWN',''),('WIMRELOAD','SHUTDOWN','NORMALv2','SHUTDOWN',''),('WIMRELOAD','RELOADDONE','MINIMAL','SHUTDOWN',''),('WIMRELOAD','RELOADDONE','NETBOOT','SHUTDOWN',''),('WIMRELOAD','RELOADDONE','NORMAL','SHUTDOWN',''),('WIMRELOAD','RELOADDONE','NORMALv1','SHUTDOWN',''),('WIMRELOAD','RELOADDONE','NORMALv2','SHUTDOWN',''),('ALWAYSUP','SHUTDOWN','RELOAD-UE','SHUTDOWN','ReloadStart'),('ALWAYSUP','ISUP','RELOAD-UE','SHUTDOWN','ReloadStart'),('ALWAYSUP','ISUP','RELOAD-UE','ISUP','ReloadStart'),('RELOAD-UE','SHUTDOWN','ALWAYSUP','ISUP','ReloadDone'),('ALWAYSUP','SHUTDOWN','RELOAD','SHUTDOWN',''),('RELOAD','SHUTDOWN','ALWAYSUP','SHUTDOWN',''),('RELOAD','RELOADDONE','ALWAYSUP','SHUTDOWN',''),('ONIE','SHUTDOWN','RELOAD','SHUTDOWN',''),('RELOAD','SHUTDOWN','ONIE','SHUTDOWN',''),('RELOAD','RELOADDONE','ONIE','SHUTDOWN','');
/*!40000 ALTER TABLE `mode_transitions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `motelogfiles`
--

DROP TABLE IF EXISTS `motelogfiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `motelogfiles` (
  `logfileid` varchar(45) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(32) NOT NULL DEFAULT '',
  `creator` varchar(8) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated` datetime DEFAULT NULL,
  `description` tinytext NOT NULL,
  `classfilepath` tinytext NOT NULL,
  `specfilepath` tinytext,
  `mote_type` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`logfileid`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `motelogfiles`
--

LOCK TABLES `motelogfiles` WRITE;
/*!40000 ALTER TABLE `motelogfiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `motelogfiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `network_fabrics`
--

DROP TABLE IF EXISTS `network_fabrics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `network_fabrics` (
  `idx` int NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL DEFAULT '',
  `created` datetime DEFAULT NULL,
  `ipalloc` tinyint(1) NOT NULL DEFAULT '0',
  `ipalloc_onenet` tinyint(1) NOT NULL DEFAULT '0',
  `ipalloc_subnet` varchar(15) NOT NULL DEFAULT '',
  `ipalloc_netmask` varchar(15) NOT NULL DEFAULT '',
  `ipalloc_submask` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `network_fabrics`
--

LOCK TABLES `network_fabrics` WRITE;
/*!40000 ALTER TABLE `network_fabrics` DISABLE KEYS */;
/*!40000 ALTER TABLE `network_fabrics` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `new_interface_types`
--

DROP TABLE IF EXISTS `new_interface_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `new_interface_types` (
  `new_interface_type_id` int NOT NULL AUTO_INCREMENT,
  `type` varchar(30) DEFAULT NULL,
  `max_speed` int DEFAULT NULL,
  `full_duplex` tinyint(1) DEFAULT NULL,
  `manufacturer` varchar(30) DEFAULT NULL,
  `model` varchar(30) DEFAULT NULL,
  `ports` smallint unsigned DEFAULT NULL,
  `connector` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`new_interface_type_id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `new_interface_types`
--

LOCK TABLES `new_interface_types` WRITE;
/*!40000 ALTER TABLE `new_interface_types` DISABLE KEYS */;
/*!40000 ALTER TABLE `new_interface_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `new_interfaces`
--

DROP TABLE IF EXISTS `new_interfaces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `new_interfaces` (
  `new_interface_id` int NOT NULL AUTO_INCREMENT,
  `new_node_id` int NOT NULL DEFAULT '0',
  `card` int NOT NULL DEFAULT '0',
  `port` smallint unsigned DEFAULT NULL,
  `mac` varchar(12) NOT NULL DEFAULT '',
  `guid` varchar(16) DEFAULT NULL,
  `interface_type` varchar(15) DEFAULT NULL,
  `switch_id` varchar(32) DEFAULT NULL,
  `switch_card` tinyint DEFAULT NULL,
  `switch_port` smallint unsigned DEFAULT NULL,
  `cable` smallint DEFAULT NULL,
  `len` tinyint DEFAULT NULL,
  `role` tinytext,
  `IP` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`new_interface_id`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `new_interfaces`
--

LOCK TABLES `new_interfaces` WRITE;
/*!40000 ALTER TABLE `new_interfaces` DISABLE KEYS */;
/*!40000 ALTER TABLE `new_interfaces` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `new_nodes`
--

DROP TABLE IF EXISTS `new_nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `new_nodes` (
  `new_node_id` int NOT NULL AUTO_INCREMENT,
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `type` varchar(30) DEFAULT NULL,
  `IP` varchar(15) DEFAULT NULL,
  `temporary_IP` varchar(15) DEFAULT NULL,
  `dmesg` text,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `identifier` varchar(255) DEFAULT NULL,
  `floor` varchar(32) DEFAULT NULL,
  `building` varchar(32) DEFAULT NULL,
  `loc_x` int unsigned NOT NULL DEFAULT '0',
  `loc_y` int unsigned NOT NULL DEFAULT '0',
  `contact` tinytext,
  `phone` tinytext,
  `room` varchar(32) DEFAULT NULL,
  `role` varchar(32) NOT NULL DEFAULT 'testnode',
  PRIMARY KEY (`new_node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `new_nodes`
--

LOCK TABLES `new_nodes` WRITE;
/*!40000 ALTER TABLE `new_nodes` DISABLE KEYS */;
/*!40000 ALTER TABLE `new_nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `new_wires`
--

DROP TABLE IF EXISTS `new_wires`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `new_wires` (
  `new_wire_id` int NOT NULL AUTO_INCREMENT,
  `cable` smallint unsigned DEFAULT NULL,
  `len` tinyint unsigned DEFAULT NULL,
  `type` enum('Node','Serial','Power','Dnard','Control','Trunk','OuterControl','Unused','Management') DEFAULT NULL,
  `node_id1` char(32) DEFAULT NULL,
  `card1` tinyint unsigned DEFAULT NULL,
  `port1` smallint unsigned DEFAULT NULL,
  `node_id2` char(32) DEFAULT NULL,
  `card2` tinyint unsigned DEFAULT NULL,
  `port2` smallint unsigned DEFAULT NULL,
  PRIMARY KEY (`new_wire_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `new_wires`
--

LOCK TABLES `new_wires` WRITE;
/*!40000 ALTER TABLE `new_wires` DISABLE KEYS */;
/*!40000 ALTER TABLE `new_wires` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `newdelays`
--

DROP TABLE IF EXISTS `newdelays`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `newdelays` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `pipe0` smallint unsigned NOT NULL DEFAULT '0',
  `delay0` int unsigned NOT NULL DEFAULT '0',
  `bandwidth0` int unsigned NOT NULL DEFAULT '100',
  `lossrate0` float(10,3) NOT NULL DEFAULT '0.000',
  `pipe1` smallint unsigned NOT NULL DEFAULT '0',
  `delay1` int unsigned NOT NULL DEFAULT '0',
  `bandwidth1` int unsigned NOT NULL DEFAULT '100',
  `lossrate1` float(10,3) NOT NULL DEFAULT '0.000',
  `iface0` varchar(8) NOT NULL DEFAULT '',
  `iface1` varchar(8) NOT NULL DEFAULT '',
  `eid` varchar(32) DEFAULT NULL,
  `pid` varchar(48) DEFAULT NULL,
  `vname` varchar(32) DEFAULT NULL,
  `card0` tinyint unsigned DEFAULT NULL,
  `card1` tinyint unsigned DEFAULT NULL,
  PRIMARY KEY (`node_id`,`iface0`,`iface1`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `newdelays`
--

LOCK TABLES `newdelays` WRITE;
/*!40000 ALTER TABLE `newdelays` DISABLE KEYS */;
/*!40000 ALTER TABLE `newdelays` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `next_reserve`
--

DROP TABLE IF EXISTS `next_reserve`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `next_reserve` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `next_reserve`
--

LOCK TABLES `next_reserve` WRITE;
/*!40000 ALTER TABLE `next_reserve` DISABLE KEYS */;
/*!40000 ALTER TABLE `next_reserve` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nextfreenode`
--

DROP TABLE IF EXISTS `nextfreenode`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nextfreenode` (
  `nodetype` varchar(30) NOT NULL DEFAULT '',
  `nextid` int unsigned NOT NULL DEFAULT '1',
  `nextpri` int unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`nodetype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nextfreenode`
--

LOCK TABLES `nextfreenode` WRITE;
/*!40000 ALTER TABLE `nextfreenode` DISABLE KEYS */;
/*!40000 ALTER TABLE `nextfreenode` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_activity`
--

DROP TABLE IF EXISTS `node_activity`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_activity` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `last_tty_act` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_net_act` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_cpu_act` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_ext_act` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_report` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_activity`
--

LOCK TABLES `node_activity` WRITE;
/*!40000 ALTER TABLE `node_activity` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_activity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_attributes`
--

DROP TABLE IF EXISTS `node_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_attributes` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`attrkey`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_attributes`
--

LOCK TABLES `node_attributes` WRITE;
/*!40000 ALTER TABLE `node_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_auxtypes`
--

DROP TABLE IF EXISTS `node_auxtypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_auxtypes` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `count` int DEFAULT '1',
  PRIMARY KEY (`node_id`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_auxtypes`
--

LOCK TABLES `node_auxtypes` WRITE;
/*!40000 ALTER TABLE `node_auxtypes` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_auxtypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_bootlogs`
--

DROP TABLE IF EXISTS `node_bootlogs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_bootlogs` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `bootlog` text,
  `bootlog_timestamp` datetime DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_bootlogs`
--

LOCK TABLES `node_bootlogs` WRITE;
/*!40000 ALTER TABLE `node_bootlogs` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_bootlogs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_features`
--

DROP TABLE IF EXISTS `node_features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_features` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `feature` varchar(30) NOT NULL DEFAULT '',
  `weight` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`feature`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_features`
--

LOCK TABLES `node_features` WRITE;
/*!40000 ALTER TABLE `node_features` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_features` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_hardware`
--

DROP TABLE IF EXISTS `node_hardware`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_hardware` (
  `node_id` varchar(30) NOT NULL DEFAULT '',
  `updated` datetime DEFAULT NULL,
  `uname` text,
  `rawjson` mediumtext,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_hardware`
--

LOCK TABLES `node_hardware` WRITE;
/*!40000 ALTER TABLE `node_hardware` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_hardware` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_hardware_paths`
--

DROP TABLE IF EXISTS `node_hardware_paths`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_hardware_paths` (
  `node_id` varchar(30) NOT NULL DEFAULT '',
  `path` varchar(255) NOT NULL DEFAULT '',
  `value` text,
  PRIMARY KEY (`node_id`,`path`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_hardware_paths`
--

LOCK TABLES `node_hardware_paths` WRITE;
/*!40000 ALTER TABLE `node_hardware_paths` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_hardware_paths` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_history`
--

DROP TABLE IF EXISTS `node_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_history` (
  `history_id` int unsigned NOT NULL AUTO_INCREMENT,
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `op` enum('alloc','free','move','create','destroy') NOT NULL DEFAULT 'alloc',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `exptidx` int unsigned DEFAULT NULL,
  `stamp` int unsigned DEFAULT NULL,
  `cnet_IP` varchar(15) DEFAULT NULL,
  `cnet_mac` varchar(12) DEFAULT NULL,
  `phys_nodeid` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`history_id`),
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_history`
--

LOCK TABLES `node_history` WRITE;
/*!40000 ALTER TABLE `node_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_hostkeys`
--

DROP TABLE IF EXISTS `node_hostkeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_hostkeys` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `sshrsa_v1` mediumtext,
  `sshrsa_v2` mediumtext,
  `sshdsa_v2` mediumtext,
  `sfshostid` varchar(128) DEFAULT NULL,
  `tpmblob` mediumtext,
  `tpmx509` mediumtext,
  `tpmidentity` mediumtext,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_hostkeys`
--

LOCK TABLES `node_hostkeys` WRITE;
/*!40000 ALTER TABLE `node_hostkeys` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_hostkeys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_idlestats`
--

DROP TABLE IF EXISTS `node_idlestats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_idlestats` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `tstamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_tty` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `load_1min` float NOT NULL DEFAULT '0',
  `load_5min` float NOT NULL DEFAULT '0',
  `load_15min` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`tstamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_idlestats`
--

LOCK TABLES `node_idlestats` WRITE;
/*!40000 ALTER TABLE `node_idlestats` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_idlestats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_ip_changes`
--

DROP TABLE IF EXISTS `node_ip_changes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_ip_changes` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `oldIP` varchar(15) DEFAULT NULL,
  `newIP` varchar(15) DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_ip_changes`
--

LOCK TABLES `node_ip_changes` WRITE;
/*!40000 ALTER TABLE `node_ip_changes` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_ip_changes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_licensekeys`
--

DROP TABLE IF EXISTS `node_licensekeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_licensekeys` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `keytype` varchar(16) NOT NULL DEFAULT '',
  `keydata` mediumtext,
  PRIMARY KEY (`node_id`,`keytype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_licensekeys`
--

LOCK TABLES `node_licensekeys` WRITE;
/*!40000 ALTER TABLE `node_licensekeys` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_licensekeys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_reservations`
--

DROP TABLE IF EXISTS `node_reservations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_reservations` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `reservation_name` varchar(48) NOT NULL DEFAULT 'default',
  PRIMARY KEY (`node_id`,`pid_idx`,`reservation_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_reservations`
--

LOCK TABLES `node_reservations` WRITE;
/*!40000 ALTER TABLE `node_reservations` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_reservations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_rf_reports`
--

DROP TABLE IF EXISTS `node_rf_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_rf_reports` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `tstamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `which` enum('system','user') NOT NULL DEFAULT 'user',
  `report` mediumtext NOT NULL,
  PRIMARY KEY (`node_id`,`which`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_rf_reports`
--

LOCK TABLES `node_rf_reports` WRITE;
/*!40000 ALTER TABLE `node_rf_reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_rf_reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_rf_violations`
--

DROP TABLE IF EXISTS `node_rf_violations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_rf_violations` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `iface` text NOT NULL,
  `tstamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `frequency` float(8,3) NOT NULL DEFAULT '0.000',
  `power` float(8,3) NOT NULL DEFAULT '0.000',
  KEY `nodeiface` (`node_id`,`iface`(128)),
  KEY `nodestamp` (`node_id`,`iface`(128),`tstamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_rf_violations`
--

LOCK TABLES `node_rf_violations` WRITE;
/*!40000 ALTER TABLE `node_rf_violations` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_rf_violations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_rusage`
--

DROP TABLE IF EXISTS `node_rusage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_rusage` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `load_1min` float NOT NULL DEFAULT '0',
  `load_5min` float NOT NULL DEFAULT '0',
  `load_15min` float NOT NULL DEFAULT '0',
  `disk_used` float NOT NULL DEFAULT '0',
  `status_timestamp` datetime DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_rusage`
--

LOCK TABLES `node_rusage` WRITE;
/*!40000 ALTER TABLE `node_rusage` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_rusage` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_startloc`
--

DROP TABLE IF EXISTS `node_startloc`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_startloc` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `building` varchar(32) NOT NULL DEFAULT '',
  `floor` varchar(32) NOT NULL DEFAULT '',
  `loc_x` float NOT NULL DEFAULT '0',
  `loc_y` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`building`,`floor`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_startloc`
--

LOCK TABLES `node_startloc` WRITE;
/*!40000 ALTER TABLE `node_startloc` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_startloc` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_status`
--

DROP TABLE IF EXISTS `node_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_status` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `status` enum('up','possibly down','down','unpingable') DEFAULT NULL,
  `status_timestamp` datetime DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_status`
--

LOCK TABLES `node_status` WRITE;
/*!40000 ALTER TABLE `node_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_type_attributes`
--

DROP TABLE IF EXISTS `node_type_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_type_attributes` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') DEFAULT 'string',
  PRIMARY KEY (`type`,`attrkey`),
  KEY `node_id` (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_type_attributes`
--

LOCK TABLES `node_type_attributes` WRITE;
/*!40000 ALTER TABLE `node_type_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_type_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_type_features`
--

DROP TABLE IF EXISTS `node_type_features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_type_features` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `feature` varchar(30) NOT NULL DEFAULT '',
  `weight` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`type`,`feature`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_type_features`
--

LOCK TABLES `node_type_features` WRITE;
/*!40000 ALTER TABLE `node_type_features` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_type_features` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_type_hardware`
--

DROP TABLE IF EXISTS `node_type_hardware`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_type_hardware` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `updated` datetime DEFAULT NULL,
  `uname` text,
  `rawjson` mediumtext,
  PRIMARY KEY (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_type_hardware`
--

LOCK TABLES `node_type_hardware` WRITE;
/*!40000 ALTER TABLE `node_type_hardware` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_type_hardware` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_type_hardware_paths`
--

DROP TABLE IF EXISTS `node_type_hardware_paths`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_type_hardware_paths` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `path` varchar(255) NOT NULL DEFAULT '',
  `value` text,
  PRIMARY KEY (`type`,`path`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_type_hardware_paths`
--

LOCK TABLES `node_type_hardware_paths` WRITE;
/*!40000 ALTER TABLE `node_type_hardware_paths` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_type_hardware_paths` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_types`
--

DROP TABLE IF EXISTS `node_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_types` (
  `class` varchar(30) DEFAULT NULL,
  `type` varchar(30) NOT NULL DEFAULT '',
  `architecture` varchar(30) DEFAULT NULL,
  `modelnetcore_osid` varchar(35) DEFAULT NULL,
  `modelnetedge_osid` varchar(35) DEFAULT NULL,
  `isvirtnode` tinyint NOT NULL DEFAULT '0',
  `ismodelnet` tinyint(1) NOT NULL DEFAULT '0',
  `isjailed` tinyint(1) NOT NULL DEFAULT '0',
  `isdynamic` tinyint(1) NOT NULL DEFAULT '0',
  `isremotenode` tinyint NOT NULL DEFAULT '0',
  `issubnode` tinyint NOT NULL DEFAULT '0',
  `isplabdslice` tinyint NOT NULL DEFAULT '0',
  `isplabphysnode` tinyint NOT NULL DEFAULT '0',
  `issimnode` tinyint NOT NULL DEFAULT '0',
  `isgeninode` tinyint NOT NULL DEFAULT '0',
  `isfednode` tinyint NOT NULL DEFAULT '0',
  `isswitch` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_types`
--

LOCK TABLES `node_types` WRITE;
/*!40000 ALTER TABLE `node_types` DISABLE KEYS */;
INSERT INTO `node_types` VALUES ('class1','esi',NULL,NULL,NULL,0,0,0,0,0,0,0,0,0,0,0,0);
/*!40000 ALTER TABLE `node_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_types_auxtypes`
--

DROP TABLE IF EXISTS `node_types_auxtypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_types_auxtypes` (
  `auxtype` varchar(30) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`auxtype`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_types_auxtypes`
--

LOCK TABLES `node_types_auxtypes` WRITE;
/*!40000 ALTER TABLE `node_types_auxtypes` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_types_auxtypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `node_utilization`
--

DROP TABLE IF EXISTS `node_utilization`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `node_utilization` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `allocated` int unsigned NOT NULL DEFAULT '0',
  `down` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `node_utilization`
--

LOCK TABLES `node_utilization` WRITE;
/*!40000 ALTER TABLE `node_utilization` DISABLE KEYS */;
/*!40000 ALTER TABLE `node_utilization` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nodeipportnum`
--

DROP TABLE IF EXISTS `nodeipportnum`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nodeipportnum` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `port` smallint unsigned NOT NULL DEFAULT '11000',
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nodeipportnum`
--

LOCK TABLES `nodeipportnum` WRITE;
/*!40000 ALTER TABLE `nodeipportnum` DISABLE KEYS */;
/*!40000 ALTER TABLE `nodeipportnum` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nodelog`
--

DROP TABLE IF EXISTS `nodelog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nodelog` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `log_id` int unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('misc') NOT NULL DEFAULT 'misc',
  `reporting_uid` varchar(8) NOT NULL DEFAULT '',
  `reporting_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `entry` tinytext NOT NULL,
  `reported` datetime DEFAULT NULL,
  PRIMARY KEY (`node_id`,`log_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nodelog`
--

LOCK TABLES `nodelog` WRITE;
/*!40000 ALTER TABLE `nodelog` DISABLE KEYS */;
/*!40000 ALTER TABLE `nodelog` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nodes`
--

DROP TABLE IF EXISTS `nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nodes` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `type` varchar(30) NOT NULL DEFAULT '',
  `phys_nodeid` varchar(32) DEFAULT NULL,
  `role` enum('testnode','virtnode','ctrlnode','testswitch','ctrlswitch','powerctrl','widearea_switch','unused') NOT NULL DEFAULT 'unused',
  `inception` datetime DEFAULT NULL,
  `def_boot_osid` int unsigned DEFAULT NULL,
  `def_boot_osid_vers` int unsigned DEFAULT '0',
  `def_boot_path` text,
  `def_boot_cmd_line` text,
  `temp_boot_osid` int unsigned DEFAULT NULL,
  `temp_boot_osid_vers` int unsigned DEFAULT '0',
  `next_boot_osid` int unsigned DEFAULT NULL,
  `next_boot_osid_vers` int unsigned DEFAULT '0',
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
  `ready` tinyint unsigned NOT NULL DEFAULT '0',
  `priority` int NOT NULL DEFAULT '-1',
  `bootstatus` enum('okay','failed','unknown') DEFAULT 'unknown',
  `status` enum('up','possibly down','down','unpingable') DEFAULT NULL,
  `status_timestamp` datetime DEFAULT NULL,
  `failureaction` enum('fatal','nonfatal','ignore') NOT NULL DEFAULT 'fatal',
  `routertype` enum('none','ospf','static','manual','static-ddijk','static-old') NOT NULL DEFAULT 'none',
  `eventstate` varchar(20) DEFAULT NULL,
  `state_timestamp` int unsigned DEFAULT NULL,
  `op_mode` varchar(20) DEFAULT NULL,
  `op_mode_timestamp` int unsigned DEFAULT NULL,
  `allocstate` varchar(20) DEFAULT NULL,
  `allocstate_timestamp` int unsigned DEFAULT NULL,
  `update_accounts` smallint DEFAULT '0',
  `next_op_mode` varchar(20) NOT NULL DEFAULT '',
  `ipodhash` varchar(64) DEFAULT NULL,
  `osid` int unsigned DEFAULT NULL,
  `ntpdrift` float DEFAULT NULL,
  `ipport_low` int NOT NULL DEFAULT '11000',
  `ipport_next` int NOT NULL DEFAULT '11000',
  `ipport_high` int NOT NULL DEFAULT '20000',
  `sshdport` int NOT NULL DEFAULT '11000',
  `jailflag` tinyint unsigned NOT NULL DEFAULT '0',
  `jailip` varchar(15) DEFAULT NULL,
  `jailipmask` varchar(15) DEFAULT NULL,
  `sfshostid` varchar(128) DEFAULT NULL,
  `stated_tag` varchar(32) DEFAULT NULL,
  `rtabid` smallint unsigned NOT NULL DEFAULT '0',
  `cd_version` varchar(32) DEFAULT NULL,
  `battery_voltage` float DEFAULT NULL,
  `battery_percentage` float DEFAULT NULL,
  `battery_timestamp` int unsigned DEFAULT NULL,
  `boot_errno` int NOT NULL DEFAULT '0',
  `destination_x` float DEFAULT NULL,
  `destination_y` float DEFAULT NULL,
  `destination_orientation` float DEFAULT NULL,
  `reserved_pid` varchar(48) DEFAULT NULL,
  `reservation_name` varchar(48) DEFAULT NULL,
  `reservable` tinyint(1) NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `reserved_memory` int unsigned DEFAULT '0',
  `nonfsmounts` tinyint(1) NOT NULL DEFAULT '0',
  `nfsmounts` enum('emulabdefault','genidefault','all','none') DEFAULT NULL,
  `taint_states` set('useronly','blackbox','dangerous','mustreload') DEFAULT NULL,
  PRIMARY KEY (`node_id`),
  KEY `phys_nodeid` (`phys_nodeid`),
  KEY `node_id` (`node_id`,`phys_nodeid`),
  KEY `role` (`role`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nodes`
--

LOCK TABLES `nodes` WRITE;
/*!40000 ALTER TABLE `nodes` DISABLE KEYS */;
INSERT INTO `nodes` VALUES ('pow1','esi',NULL,'unused',NULL,NULL,0,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,-1,'unknown',NULL,NULL,'fatal','none',NULL,NULL,NULL,NULL,NULL,NULL,0,'',NULL,NULL,NULL,11000,11000,20000,11000,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL,0,'',0,0,NULL,NULL),('2','esi',NULL,'unused',NULL,NULL,0,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,-1,'unknown',NULL,NULL,'fatal','none',NULL,NULL,NULL,NULL,NULL,NULL,0,'',NULL,NULL,NULL,11000,11000,20000,11000,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL,0,'',0,0,NULL,NULL),('1','esi',NULL,'unused',NULL,NULL,0,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,-1,'unknown',NULL,NULL,'fatal','none',NULL,NULL,NULL,NULL,NULL,NULL,0,'',NULL,NULL,NULL,11000,11000,20000,11000,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL,0,'',0,0,NULL,NULL),('pow2','esi',NULL,'unused',NULL,NULL,0,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,-1,'unknown',NULL,NULL,'fatal','none',NULL,NULL,NULL,NULL,NULL,NULL,0,'',NULL,NULL,NULL,11000,11000,20000,11000,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL,0,'',0,0,NULL,NULL),('pow3','esi',NULL,'unused',NULL,NULL,0,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,-1,'unknown',NULL,NULL,'fatal','none',NULL,NULL,NULL,NULL,NULL,NULL,0,'',NULL,NULL,NULL,11000,11000,20000,11000,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL,0,'',0,0,NULL,NULL);
/*!40000 ALTER TABLE `nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nodetypeXpid_permissions`
--

DROP TABLE IF EXISTS `nodetypeXpid_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nodetypeXpid_permissions` (
  `type` varchar(30) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`type`,`pid_idx`),
  UNIQUE KEY `typepid` (`type`,`pid`),
  KEY `pid` (`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nodetypeXpid_permissions`
--

LOCK TABLES `nodetypeXpid_permissions` WRITE;
/*!40000 ALTER TABLE `nodetypeXpid_permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `nodetypeXpid_permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nodeuidlastlogin`
--

DROP TABLE IF EXISTS `nodeuidlastlogin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nodeuidlastlogin` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `uid` varchar(10) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `date` date DEFAULT NULL,
  `time` time DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nodeuidlastlogin`
--

LOCK TABLES `nodeuidlastlogin` WRITE;
/*!40000 ALTER TABLE `nodeuidlastlogin` DISABLE KEYS */;
/*!40000 ALTER TABLE `nodeuidlastlogin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nologins`
--

DROP TABLE IF EXISTS `nologins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nologins` (
  `nologins` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`nologins`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nologins`
--

LOCK TABLES `nologins` WRITE;
/*!40000 ALTER TABLE `nologins` DISABLE KEYS */;
/*!40000 ALTER TABLE `nologins` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nonces`
--

DROP TABLE IF EXISTS `nonces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nonces` (
  `node_id` varchar(32) NOT NULL,
  `purpose` varchar(64) NOT NULL,
  `nonce` mediumtext,
  `expires` int NOT NULL,
  PRIMARY KEY (`node_id`,`purpose`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nonces`
--

LOCK TABLES `nonces` WRITE;
/*!40000 ALTER TABLE `nonces` DISABLE KEYS */;
/*!40000 ALTER TABLE `nonces` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nonlocal_user_accounts`
--

DROP TABLE IF EXISTS `nonlocal_user_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nonlocal_user_accounts` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid_uuid` varchar(40) NOT NULL DEFAULT '',
  `unix_uid` int unsigned NOT NULL AUTO_INCREMENT,
  `created` datetime DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `privs` enum('user','local_root') DEFAULT 'local_root',
  `shell` enum('tcsh','bash','sh') DEFAULT 'bash',
  `urn` tinytext,
  `name` tinytext,
  `email` tinytext,
  `exptidx` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`unix_uid`),
  KEY `uid` (`uid`),
  KEY `urn` (`urn`(255)),
  KEY `uid_uuid` (`uid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nonlocal_user_accounts`
--

LOCK TABLES `nonlocal_user_accounts` WRITE;
/*!40000 ALTER TABLE `nonlocal_user_accounts` DISABLE KEYS */;
/*!40000 ALTER TABLE `nonlocal_user_accounts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nonlocal_user_bindings`
--

DROP TABLE IF EXISTS `nonlocal_user_bindings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nonlocal_user_bindings` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `exptidx` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid_idx`,`exptidx`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nonlocal_user_bindings`
--

LOCK TABLES `nonlocal_user_bindings` WRITE;
/*!40000 ALTER TABLE `nonlocal_user_bindings` DISABLE KEYS */;
/*!40000 ALTER TABLE `nonlocal_user_bindings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nonlocal_user_pubkeys`
--

DROP TABLE IF EXISTS `nonlocal_user_pubkeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nonlocal_user_pubkeys` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `pubkey` text,
  `stamp` datetime DEFAULT NULL,
  `comment` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`uid_idx`,`idx`),
  KEY `uid` (`uid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nonlocal_user_pubkeys`
--

LOCK TABLES `nonlocal_user_pubkeys` WRITE;
/*!40000 ALTER TABLE `nonlocal_user_pubkeys` DISABLE KEYS */;
/*!40000 ALTER TABLE `nonlocal_user_pubkeys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nonlocal_users`
--

DROP TABLE IF EXISTS `nonlocal_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nonlocal_users` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid_uuid` varchar(40) NOT NULL DEFAULT '',
  `created` datetime DEFAULT NULL,
  `name` tinytext,
  `email` tinytext,
  PRIMARY KEY (`uid_idx`),
  UNIQUE KEY `uid_uuid` (`uid_uuid`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nonlocal_users`
--

LOCK TABLES `nonlocal_users` WRITE;
/*!40000 ALTER TABLE `nonlocal_users` DISABLE KEYS */;
/*!40000 ALTER TABLE `nonlocal_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nseconfigs`
--

DROP TABLE IF EXISTS `nseconfigs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nseconfigs` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `nseconfig` mediumtext,
  PRIMARY KEY (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nseconfigs`
--

LOCK TABLES `nseconfigs` WRITE;
/*!40000 ALTER TABLE `nseconfigs` DISABLE KEYS */;
/*!40000 ALTER TABLE `nseconfigs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nsfiles`
--

DROP TABLE IF EXISTS `nsfiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `nsfiles` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `nsfile` mediumtext,
  PRIMARY KEY (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nsfiles`
--

LOCK TABLES `nsfiles` WRITE;
/*!40000 ALTER TABLE `nsfiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `nsfiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ntpinfo`
--

DROP TABLE IF EXISTS `ntpinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ntpinfo` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `IP` varchar(64) NOT NULL DEFAULT '',
  `type` enum('server','peer') NOT NULL DEFAULT 'peer',
  PRIMARY KEY (`node_id`,`IP`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ntpinfo`
--

LOCK TABLES `ntpinfo` WRITE;
/*!40000 ALTER TABLE `ntpinfo` DISABLE KEYS */;
/*!40000 ALTER TABLE `ntpinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `obstacles`
--

DROP TABLE IF EXISTS `obstacles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `obstacles` (
  `obstacle_id` int unsigned NOT NULL AUTO_INCREMENT,
  `floor` varchar(32) DEFAULT NULL,
  `building` varchar(32) DEFAULT NULL,
  `x1` int unsigned NOT NULL DEFAULT '0',
  `y1` int unsigned NOT NULL DEFAULT '0',
  `z1` int unsigned NOT NULL DEFAULT '0',
  `x2` int unsigned NOT NULL DEFAULT '0',
  `y2` int unsigned NOT NULL DEFAULT '0',
  `z2` int unsigned NOT NULL DEFAULT '0',
  `description` tinytext,
  `label` tinytext,
  `draw` tinyint(1) NOT NULL DEFAULT '0',
  `no_exclusion` tinyint(1) NOT NULL DEFAULT '0',
  `no_tooltip` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`obstacle_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `obstacles`
--

LOCK TABLES `obstacles` WRITE;
/*!40000 ALTER TABLE `obstacles` DISABLE KEYS */;
/*!40000 ALTER TABLE `obstacles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `os_boot_cmd`
--

DROP TABLE IF EXISTS `os_boot_cmd`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `os_boot_cmd` (
  `OS` enum('Unknown','Linux','Fedora','FreeBSD','NetBSD','OSKit','Windows','TinyOS','Other') NOT NULL DEFAULT 'Unknown',
  `version` varchar(12) NOT NULL DEFAULT '',
  `role` enum('default','delay','linkdelay','vnodehost') NOT NULL DEFAULT 'default',
  `boot_cmd_line` text,
  PRIMARY KEY (`OS`,`version`,`role`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `os_boot_cmd`
--

LOCK TABLES `os_boot_cmd` WRITE;
/*!40000 ALTER TABLE `os_boot_cmd` DISABLE KEYS */;
/*!40000 ALTER TABLE `os_boot_cmd` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `os_info`
--

DROP TABLE IF EXISTS `os_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `os_info` (
  `osname` varchar(30) NOT NULL DEFAULT '',
  `version` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `osid` int unsigned NOT NULL DEFAULT '0',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`osid`),
  UNIQUE KEY `pid` (`pid`,`osname`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `os_info`
--

LOCK TABLES `os_info` WRITE;
/*!40000 ALTER TABLE `os_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `os_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `os_info_versions`
--

DROP TABLE IF EXISTS `os_info_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `os_info_versions` (
  `osname` varchar(30) NOT NULL DEFAULT '',
  `vers` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `osid` int unsigned NOT NULL DEFAULT '0',
  `parent_osid` int unsigned DEFAULT NULL,
  `parent_vers` int unsigned DEFAULT NULL,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `old_osid` varchar(35) NOT NULL DEFAULT '',
  `creator` varchar(8) DEFAULT NULL,
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `description` tinytext NOT NULL,
  `OS` enum('Unknown','Linux','Fedora','FreeBSD','NetBSD','OSKit','Windows','TinyOS','Other') DEFAULT 'Unknown',
  `version` varchar(12) DEFAULT '',
  `path` tinytext,
  `magic` tinytext,
  `machinetype` varchar(30) NOT NULL DEFAULT '',
  `osfeatures` set('ping','ssh','ipod','isup','veths','veth-ne','veth-en','mlinks','linktest','linkdelays','vlans','suboses','ontrustedboot','no-usb-boot','egre','loc-bstore','rem-bstore','openvz-host','xen-host','docker-host') DEFAULT NULL,
  `ezid` tinyint NOT NULL DEFAULT '0',
  `shared` tinyint NOT NULL DEFAULT '0',
  `mustclean` tinyint NOT NULL DEFAULT '1',
  `op_mode` varchar(20) NOT NULL DEFAULT 'MINIMAL',
  `nextosid` int unsigned DEFAULT NULL,
  `def_parentosid` int unsigned DEFAULT NULL,
  `old_nextosid` varchar(35) NOT NULL DEFAULT '',
  `max_concurrent` int DEFAULT NULL,
  `mfs` tinyint NOT NULL DEFAULT '0',
  `reboot_waittime` int unsigned DEFAULT NULL,
  `protogeni_export` tinyint(1) NOT NULL DEFAULT '0',
  `taint_states` set('useronly','blackbox','dangerous','mustreload') DEFAULT NULL,
  PRIMARY KEY (`osid`,`vers`),
  KEY `pid` (`pid`,`osname`,`vers`),
  KEY `OS` (`OS`),
  KEY `path` (`path`(255)),
  KEY `old_osid` (`old_osid`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `os_info_versions`
--

LOCK TABLES `os_info_versions` WRITE;
/*!40000 ALTER TABLE `os_info_versions` DISABLE KEYS */;
/*!40000 ALTER TABLE `os_info_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `os_submap`
--

DROP TABLE IF EXISTS `os_submap`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `os_submap` (
  `osid` int unsigned NOT NULL DEFAULT '0',
  `parent_osid` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`osid`,`parent_osid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `os_submap`
--

LOCK TABLES `os_submap` WRITE;
/*!40000 ALTER TABLE `os_submap` DISABLE KEYS */;
/*!40000 ALTER TABLE `os_submap` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `osconfig_files`
--

DROP TABLE IF EXISTS `osconfig_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `osconfig_files` (
  `file_idx` int unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('script','scriptdep','archive','file') NOT NULL DEFAULT 'file',
  `path` varchar(255) NOT NULL DEFAULT '',
  `dest` varchar(255) NOT NULL DEFAULT '',
  `prio` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`file_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `osconfig_files`
--

LOCK TABLES `osconfig_files` WRITE;
/*!40000 ALTER TABLE `osconfig_files` DISABLE KEYS */;
/*!40000 ALTER TABLE `osconfig_files` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `osconfig_targets`
--

DROP TABLE IF EXISTS `osconfig_targets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `osconfig_targets` (
  `constraint_idx` int unsigned NOT NULL AUTO_INCREMENT,
  `target_apply` enum('premfs','postload') NOT NULL DEFAULT 'postload',
  `target_file_idx` int unsigned NOT NULL DEFAULT '0',
  `constraint_name` varchar(16) NOT NULL DEFAULT '',
  `constraint_value` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`constraint_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `osconfig_targets`
--

LOCK TABLES `osconfig_targets` WRITE;
/*!40000 ALTER TABLE `osconfig_targets` DISABLE KEYS */;
/*!40000 ALTER TABLE `osconfig_targets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `osid_map`
--

DROP TABLE IF EXISTS `osid_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `osid_map` (
  `osid` int unsigned NOT NULL DEFAULT '0',
  `btime` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
  `etime` datetime NOT NULL DEFAULT '9999-12-31 23:59:59',
  `nextosid` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`osid`,`btime`,`etime`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `osid_map`
--

LOCK TABLES `osid_map` WRITE;
/*!40000 ALTER TABLE `osid_map` DISABLE KEYS */;
/*!40000 ALTER TABLE `osid_map` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `osidtoimageid`
--

DROP TABLE IF EXISTS `osidtoimageid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `osidtoimageid` (
  `osid` int unsigned NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `imageid` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`osid`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `osidtoimageid`
--

LOCK TABLES `osidtoimageid` WRITE;
/*!40000 ALTER TABLE `osidtoimageid` DISABLE KEYS */;
/*!40000 ALTER TABLE `osidtoimageid` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `outlets`
--

DROP TABLE IF EXISTS `outlets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outlets` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `power_id` varchar(32) NOT NULL DEFAULT '',
  `outlet` tinyint unsigned NOT NULL DEFAULT '0',
  `last_power` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `outlets`
--

LOCK TABLES `outlets` WRITE;
/*!40000 ALTER TABLE `outlets` DISABLE KEYS */;
INSERT INTO `outlets` VALUES ('node1','pow1',0,'2021-12-02 21:37:34'),('1','1',1,'2021-12-05 20:11:48'),('2','2',2,'2021-12-02 22:40:29');
/*!40000 ALTER TABLE `outlets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `outlets_remoteauth`
--

DROP TABLE IF EXISTS `outlets_remoteauth`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outlets_remoteauth` (
  `node_id` varchar(32) NOT NULL,
  `key_type` varchar(64) NOT NULL,
  `key_role` varchar(64) NOT NULL DEFAULT '',
  `key_uid` varchar(64) NOT NULL DEFAULT '',
  `mykey` text NOT NULL,
  `key_privlvl` enum('CALLBACK','USER','OPERATOR','ADMINISTRATOR','OTHER') DEFAULT NULL,
  PRIMARY KEY (`node_id`,`key_type`,`key_role`,`key_uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `outlets_remoteauth`
--

LOCK TABLES `outlets_remoteauth` WRITE;
/*!40000 ALTER TABLE `outlets_remoteauth` DISABLE KEYS */;
/*!40000 ALTER TABLE `outlets_remoteauth` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `partitions`
--

DROP TABLE IF EXISTS `partitions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `partitions` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `partition` tinyint NOT NULL DEFAULT '0',
  `osid` int unsigned DEFAULT NULL,
  `osid_vers` int unsigned DEFAULT NULL,
  `imageid` int unsigned DEFAULT NULL,
  `imageid_version` int unsigned DEFAULT NULL,
  `imagepid` varchar(48) NOT NULL DEFAULT '',
  PRIMARY KEY (`node_id`,`partition`),
  KEY `osid` (`osid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `partitions`
--

LOCK TABLES `partitions` WRITE;
/*!40000 ALTER TABLE `partitions` DISABLE KEYS */;
/*!40000 ALTER TABLE `partitions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_attributes`
--

DROP TABLE IF EXISTS `plab_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_attributes` (
  `attr_idx` int unsigned NOT NULL AUTO_INCREMENT,
  `plc_idx` int unsigned DEFAULT NULL,
  `slicename` varchar(64) DEFAULT NULL,
  `nodegroup_idx` int unsigned DEFAULT NULL,
  `node_id` varchar(32) DEFAULT NULL,
  `attrkey` varchar(64) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY (`attr_idx`),
  UNIQUE KEY `realattrkey` (`plc_idx`,`slicename`,`nodegroup_idx`,`node_id`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_attributes`
--

LOCK TABLES `plab_attributes` WRITE;
/*!40000 ALTER TABLE `plab_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_comondata`
--

DROP TABLE IF EXISTS `plab_comondata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_comondata` (
  `node_id` varchar(32) NOT NULL,
  `resptime` float DEFAULT NULL,
  `uptime` float DEFAULT NULL,
  `lastcotop` float DEFAULT NULL,
  `date` double DEFAULT NULL,
  `drift` float DEFAULT NULL,
  `cpuspeed` float DEFAULT NULL,
  `busycpu` float DEFAULT NULL,
  `syscpu` float DEFAULT NULL,
  `freecpu` float DEFAULT NULL,
  `1minload` float DEFAULT NULL,
  `5minload` float DEFAULT NULL,
  `numslices` int DEFAULT NULL,
  `liveslices` int DEFAULT NULL,
  `connmax` float DEFAULT NULL,
  `connavg` float DEFAULT NULL,
  `timermax` float DEFAULT NULL,
  `timeravg` float DEFAULT NULL,
  `memsize` float DEFAULT NULL,
  `memact` float DEFAULT NULL,
  `freemem` float DEFAULT NULL,
  `swapin` int DEFAULT NULL,
  `swapout` int DEFAULT NULL,
  `diskin` int DEFAULT NULL,
  `diskout` int DEFAULT NULL,
  `gbfree` float DEFAULT NULL,
  `swapused` float DEFAULT NULL,
  `bwlimit` float DEFAULT NULL,
  `txrate` float DEFAULT NULL,
  `rxrate` float DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_comondata`
--

LOCK TABLES `plab_comondata` WRITE;
/*!40000 ALTER TABLE `plab_comondata` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_comondata` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_mapping`
--

DROP TABLE IF EXISTS `plab_mapping`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_mapping` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `plab_id` varchar(32) NOT NULL DEFAULT '',
  `hostname` varchar(255) NOT NULL DEFAULT '',
  `IP` varchar(15) NOT NULL DEFAULT '',
  `mac` varchar(17) NOT NULL DEFAULT '',
  `create_time` datetime DEFAULT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_mapping`
--

LOCK TABLES `plab_mapping` WRITE;
/*!40000 ALTER TABLE `plab_mapping` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_mapping` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_nodegroup_members`
--

DROP TABLE IF EXISTS `plab_nodegroup_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_nodegroup_members` (
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  `nodegroup_idx` int unsigned NOT NULL DEFAULT '0',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`plc_idx`,`nodegroup_idx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_nodegroup_members`
--

LOCK TABLES `plab_nodegroup_members` WRITE;
/*!40000 ALTER TABLE `plab_nodegroup_members` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_nodegroup_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_nodegroups`
--

DROP TABLE IF EXISTS `plab_nodegroups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_nodegroups` (
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  `nodegroup_idx` int unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL DEFAULT '',
  `description` text NOT NULL,
  PRIMARY KEY (`plc_idx`,`nodegroup_idx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_nodegroups`
--

LOCK TABLES `plab_nodegroups` WRITE;
/*!40000 ALTER TABLE `plab_nodegroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_nodegroups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_nodehist`
--

DROP TABLE IF EXISTS `plab_nodehist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_nodehist` (
  `idx` mediumint unsigned NOT NULL AUTO_INCREMENT,
  `node_id` varchar(32) NOT NULL,
  `phys_node_id` varchar(32) NOT NULL,
  `timestamp` datetime NOT NULL,
  `component` varchar(64) NOT NULL,
  `operation` varchar(64) NOT NULL,
  `status` enum('success','failure','unknown') NOT NULL DEFAULT 'unknown',
  `msg` text,
  PRIMARY KEY (`idx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_nodehist`
--

LOCK TABLES `plab_nodehist` WRITE;
/*!40000 ALTER TABLE `plab_nodehist` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_nodehist` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_nodehiststats`
--

DROP TABLE IF EXISTS `plab_nodehiststats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_nodehiststats` (
  `node_id` varchar(32) NOT NULL,
  `unavail` float DEFAULT NULL,
  `jitdeduct` float DEFAULT NULL,
  `succtime` int DEFAULT NULL,
  `succnum` int DEFAULT NULL,
  `succjitnum` int DEFAULT NULL,
  `failtime` int DEFAULT NULL,
  `failnum` int DEFAULT NULL,
  `failjitnum` int DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_nodehiststats`
--

LOCK TABLES `plab_nodehiststats` WRITE;
/*!40000 ALTER TABLE `plab_nodehiststats` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_nodehiststats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_objmap`
--

DROP TABLE IF EXISTS `plab_objmap`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_objmap` (
  `plc_idx` int unsigned NOT NULL,
  `objtype` varchar(32) NOT NULL,
  `elab_id` varchar(64) NOT NULL,
  `plab_id` varchar(255) NOT NULL,
  `plab_name` tinytext NOT NULL,
  PRIMARY KEY (`plc_idx`,`objtype`,`elab_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_objmap`
--

LOCK TABLES `plab_objmap` WRITE;
/*!40000 ALTER TABLE `plab_objmap` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_objmap` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_plc_attributes`
--

DROP TABLE IF EXISTS `plab_plc_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_plc_attributes` (
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  `attrkey` varchar(64) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY (`plc_idx`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_plc_attributes`
--

LOCK TABLES `plab_plc_attributes` WRITE;
/*!40000 ALTER TABLE `plab_plc_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_plc_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_plc_info`
--

DROP TABLE IF EXISTS `plab_plc_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_plc_info` (
  `plc_idx` int unsigned NOT NULL AUTO_INCREMENT,
  `plc_name` varchar(64) NOT NULL DEFAULT '',
  `api_url` varchar(255) NOT NULL DEFAULT '',
  `def_slice_prefix` varchar(32) NOT NULL DEFAULT '',
  `nodename_prefix` varchar(30) NOT NULL DEFAULT '',
  `node_type` varchar(30) NOT NULL DEFAULT '',
  `svc_slice_name` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`plc_idx`),
  KEY `plc_name` (`plc_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_plc_info`
--

LOCK TABLES `plab_plc_info` WRITE;
/*!40000 ALTER TABLE `plab_plc_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_plc_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_site_mapping`
--

DROP TABLE IF EXISTS `plab_site_mapping`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_site_mapping` (
  `site_name` varchar(255) NOT NULL DEFAULT '',
  `site_idx` smallint unsigned NOT NULL AUTO_INCREMENT,
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `node_idx` tinyint unsigned NOT NULL DEFAULT '0',
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`site_name`,`site_idx`,`node_idx`,`plc_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_site_mapping`
--

LOCK TABLES `plab_site_mapping` WRITE;
/*!40000 ALTER TABLE `plab_site_mapping` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_site_mapping` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_slice_attributes`
--

DROP TABLE IF EXISTS `plab_slice_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_slice_attributes` (
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  `slicename` varchar(64) NOT NULL DEFAULT '',
  `attrkey` varchar(64) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  PRIMARY KEY (`plc_idx`,`slicename`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_slice_attributes`
--

LOCK TABLES `plab_slice_attributes` WRITE;
/*!40000 ALTER TABLE `plab_slice_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_slice_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_slice_nodes`
--

DROP TABLE IF EXISTS `plab_slice_nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_slice_nodes` (
  `slicename` varchar(64) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `leaseend` datetime DEFAULT NULL,
  `nodemeta` text,
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`slicename`,`plc_idx`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_slice_nodes`
--

LOCK TABLES `plab_slice_nodes` WRITE;
/*!40000 ALTER TABLE `plab_slice_nodes` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_slice_nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `plab_slices`
--

DROP TABLE IF EXISTS `plab_slices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `plab_slices` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `slicename` varchar(64) NOT NULL DEFAULT '',
  `slicemeta` text,
  `slicemeta_legacy` text,
  `leaseend` datetime DEFAULT NULL,
  `admin` tinyint(1) DEFAULT '0',
  `plc_idx` int unsigned NOT NULL DEFAULT '0',
  `is_created` tinyint(1) DEFAULT '0',
  `is_configured` tinyint(1) DEFAULT '0',
  `no_cleanup` tinyint(1) DEFAULT '0',
  `no_destroy` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`exptidx`,`slicename`,`plc_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `plab_slices`
--

LOCK TABLES `plab_slices` WRITE;
/*!40000 ALTER TABLE `plab_slices` DISABLE KEYS */;
/*!40000 ALTER TABLE `plab_slices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `port_counters`
--

DROP TABLE IF EXISTS `port_counters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `port_counters` (
  `node_id` char(32) NOT NULL DEFAULT '',
  `card_saved` tinyint unsigned NOT NULL DEFAULT '0',
  `port_saved` smallint unsigned NOT NULL DEFAULT '0',
  `iface` text NOT NULL,
  `ifInOctets` int unsigned NOT NULL DEFAULT '0',
  `ifInUcastPkts` int unsigned NOT NULL DEFAULT '0',
  `ifInNUcastPkts` int unsigned NOT NULL DEFAULT '0',
  `ifInDiscards` int unsigned NOT NULL DEFAULT '0',
  `ifInErrors` int unsigned NOT NULL DEFAULT '0',
  `ifInUnknownProtos` int unsigned NOT NULL DEFAULT '0',
  `ifOutOctets` int unsigned NOT NULL DEFAULT '0',
  `ifOutUcastPkts` int unsigned NOT NULL DEFAULT '0',
  `ifOutNUcastPkts` int unsigned NOT NULL DEFAULT '0',
  `ifOutDiscards` int unsigned NOT NULL DEFAULT '0',
  `ifOutErrors` int unsigned NOT NULL DEFAULT '0',
  `ifOutQLen` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`iface`(128))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `port_counters`
--

LOCK TABLES `port_counters` WRITE;
/*!40000 ALTER TABLE `port_counters` DISABLE KEYS */;
/*!40000 ALTER TABLE `port_counters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `port_registration`
--

DROP TABLE IF EXISTS `port_registration`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `port_registration` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `service` varchar(64) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `port` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`service`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`service`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `port_registration`
--

LOCK TABLES `port_registration` WRITE;
/*!40000 ALTER TABLE `port_registration` DISABLE KEYS */;
/*!40000 ALTER TABLE `port_registration` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `portmap`
--

DROP TABLE IF EXISTS `portmap`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `portmap` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `vport` tinyint NOT NULL DEFAULT '0',
  `pport` varchar(32) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `portmap`
--

LOCK TABLES `portmap` WRITE;
/*!40000 ALTER TABLE `portmap` DISABLE KEYS */;
/*!40000 ALTER TABLE `portmap` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `priorities`
--

DROP TABLE IF EXISTS `priorities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `priorities` (
  `priority` smallint NOT NULL DEFAULT '0',
  `priority_name` varchar(8) NOT NULL DEFAULT '',
  PRIMARY KEY (`priority`),
  UNIQUE KEY `name` (`priority_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `priorities`
--

LOCK TABLES `priorities` WRITE;
/*!40000 ALTER TABLE `priorities` DISABLE KEYS */;
INSERT INTO `priorities` VALUES (0,'EMERG'),(100,'ALERT'),(200,'CRIT'),(300,'ERR'),(400,'WARNING'),(500,'NOTICE'),(600,'INFO'),(700,'DEBUG');
/*!40000 ALTER TABLE `priorities` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `proj_memb`
--

DROP TABLE IF EXISTS `proj_memb`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `proj_memb` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `trust` enum('none','user','local_root','group_root') DEFAULT NULL,
  `date_applied` date DEFAULT NULL,
  `date_approved` date DEFAULT NULL,
  PRIMARY KEY (`uid`,`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `proj_memb`
--

LOCK TABLES `proj_memb` WRITE;
/*!40000 ALTER TABLE `proj_memb` DISABLE KEYS */;
/*!40000 ALTER TABLE `proj_memb` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_leases`
--

DROP TABLE IF EXISTS `project_leases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_leases` (
  `lease_idx` int unsigned NOT NULL DEFAULT '0',
  `lease_id` varchar(32) NOT NULL DEFAULT '',
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `owner_uid` varchar(8) NOT NULL DEFAULT '',
  `owner_urn` varchar(128) DEFAULT NULL,
  `pid` varchar(48) NOT NULL DEFAULT '',
  `gid` varchar(48) NOT NULL DEFAULT '',
  `type` enum('stdataset','ltdataset','unknown') NOT NULL DEFAULT 'unknown',
  `inception` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lease_end` timestamp NOT NULL DEFAULT '2037-01-19 03:14:07',
  `last_used` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `last_checked` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `state` enum('valid','unapproved','grace','locked','expired','failed') NOT NULL DEFAULT 'unapproved',
  `statestamp` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `renewals` int unsigned NOT NULL DEFAULT '0',
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  PRIMARY KEY (`lease_idx`),
  UNIQUE KEY `plid` (`pid`,`lease_id`),
  UNIQUE KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_leases`
--

LOCK TABLES `project_leases` WRITE;
/*!40000 ALTER TABLE `project_leases` DISABLE KEYS */;
/*!40000 ALTER TABLE `project_leases` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_licenses`
--

DROP TABLE IF EXISTS `project_licenses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_licenses` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `license_idx` int NOT NULL DEFAULT '0',
  `accepted` datetime DEFAULT NULL,
  `expiration` datetime DEFAULT NULL,
  PRIMARY KEY (`pid_idx`,`license_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_licenses`
--

LOCK TABLES `project_licenses` WRITE;
/*!40000 ALTER TABLE `project_licenses` DISABLE KEYS */;
/*!40000 ALTER TABLE `project_licenses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_nsf_awards`
--

DROP TABLE IF EXISTS `project_nsf_awards`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_nsf_awards` (
  `idx` smallint unsigned NOT NULL AUTO_INCREMENT,
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `award` varchar(32) NOT NULL DEFAULT '',
  `supplement` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`pid_idx`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_nsf_awards`
--

LOCK TABLES `project_nsf_awards` WRITE;
/*!40000 ALTER TABLE `project_nsf_awards` DISABLE KEYS */;
/*!40000 ALTER TABLE `project_nsf_awards` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_quotas`
--

DROP TABLE IF EXISTS `project_quotas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_quotas` (
  `quota_idx` int unsigned NOT NULL,
  `quota_id` varchar(32) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `type` enum('ltdataset','unknown') NOT NULL DEFAULT 'unknown',
  `size` int unsigned NOT NULL DEFAULT '0',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `locked` datetime DEFAULT NULL,
  `locker_pid` int DEFAULT '0',
  `notes` tinytext,
  PRIMARY KEY (`quota_idx`),
  UNIQUE KEY `qpid` (`pid`,`quota_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_quotas`
--

LOCK TABLES `project_quotas` WRITE;
/*!40000 ALTER TABLE `project_quotas` DISABLE KEYS */;
/*!40000 ALTER TABLE `project_quotas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_reservations`
--

DROP TABLE IF EXISTS `project_reservations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_reservations` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `name` varchar(48) NOT NULL DEFAULT 'default',
  `priority` smallint NOT NULL DEFAULT '0',
  `count` smallint NOT NULL DEFAULT '0',
  `types` varchar(128) DEFAULT NULL,
  `creator` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `terminal` tinyint(1) NOT NULL DEFAULT '0',
  `approved` datetime DEFAULT NULL,
  `approver` varchar(8) DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  `notes` mediumtext,
  PRIMARY KEY (`pid_idx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_reservations`
--

LOCK TABLES `project_reservations` WRITE;
/*!40000 ALTER TABLE `project_reservations` DISABLE KEYS */;
/*!40000 ALTER TABLE `project_reservations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `project_stats`
--

DROP TABLE IF EXISTS `project_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_stats` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `exptstart_count` int unsigned DEFAULT '0',
  `exptstart_last` datetime DEFAULT NULL,
  `exptpreload_count` int unsigned DEFAULT '0',
  `exptpreload_last` datetime DEFAULT NULL,
  `exptswapin_count` int unsigned DEFAULT '0',
  `exptswapin_last` datetime DEFAULT NULL,
  `exptswapout_count` int unsigned DEFAULT '0',
  `exptswapout_last` datetime DEFAULT NULL,
  `exptswapmod_count` int unsigned DEFAULT '0',
  `exptswapmod_last` datetime DEFAULT NULL,
  `last_activity` datetime DEFAULT NULL,
  `allexpt_duration` double(14,0) unsigned DEFAULT '0',
  `allexpt_vnodes` int unsigned DEFAULT '0',
  `allexpt_vnode_duration` double(14,0) unsigned DEFAULT '0',
  `allexpt_pnodes` int unsigned DEFAULT '0',
  `allexpt_pnode_duration` double(14,0) unsigned DEFAULT '0',
  PRIMARY KEY (`pid_idx`),
  UNIQUE KEY `pid` (`pid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `project_stats`
--

LOCK TABLES `project_stats` WRITE;
/*!40000 ALTER TABLE `project_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `project_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `projects`
--

DROP TABLE IF EXISTS `projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `projects` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `expires` date DEFAULT NULL,
  `nagged` datetime DEFAULT NULL,
  `name` tinytext,
  `URL` tinytext,
  `funders` tinytext,
  `addr` tinytext,
  `head_uid` varchar(8) NOT NULL DEFAULT '',
  `head_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `num_members` int DEFAULT '0',
  `num_pcs` int DEFAULT '0',
  `num_sharks` int DEFAULT '0',
  `num_pcplab` int DEFAULT '0',
  `num_ron` int DEFAULT '0',
  `why` text,
  `control_node` varchar(10) DEFAULT NULL,
  `unix_gid` smallint unsigned NOT NULL AUTO_INCREMENT,
  `approved` tinyint DEFAULT '0',
  `hidden` tinyint(1) DEFAULT '0',
  `disabled` tinyint(1) DEFAULT '0',
  `inactive` tinyint DEFAULT '0',
  `forClass` tinyint(1) DEFAULT '0',
  `date_inactive` datetime DEFAULT NULL,
  `public` tinyint NOT NULL DEFAULT '0',
  `public_whynot` tinytext,
  `expt_count` mediumint unsigned DEFAULT '0',
  `expt_last` date DEFAULT NULL,
  `pcremote_ok` set('pcplabphys','pcron','pcwa') DEFAULT NULL,
  `default_user_interface` enum('emulab','plab') NOT NULL DEFAULT 'emulab',
  `linked_to_us` tinyint NOT NULL DEFAULT '0',
  `cvsrepo_public` tinyint(1) NOT NULL DEFAULT '0',
  `allow_workbench` tinyint(1) NOT NULL DEFAULT '0',
  `nonlocal_id` varchar(128) DEFAULT NULL,
  `nonlocal_type` tinytext,
  `manager_urn` varchar(128) DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `bound_portal` tinyint(1) DEFAULT '0',
  `experiment_accounts` enum('none','swapper') DEFAULT NULL,
  `nfsmounts` enum('emulabdefault','genidefault','none') DEFAULT 'emulabdefault',
  `reservations_disabled` tinyint(1) NOT NULL DEFAULT '0',
  `nsf_funded` tinyint(1) DEFAULT '0',
  `nsf_updated` datetime DEFAULT NULL,
  `nsf_awards` tinytext,
  `industry` tinyint(1) DEFAULT '0',
  `consortium` tinyint(1) DEFAULT '0',
  `expert_mode` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`pid_idx`),
  UNIQUE KEY `pid` (`pid`),
  KEY `unix_gid` (`unix_gid`),
  KEY `approved` (`approved`),
  KEY `approved_2` (`approved`),
  KEY `pcremote_ok` (`pcremote_ok`),
  KEY `portal` (`portal`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `projects`
--

LOCK TABLES `projects` WRITE;
/*!40000 ALTER TABLE `projects` DISABLE KEYS */;
/*!40000 ALTER TABLE `projects` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `report_assign_violation`
--

DROP TABLE IF EXISTS `report_assign_violation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `report_assign_violation` (
  `seq` int unsigned NOT NULL DEFAULT '0',
  `unassigned` int DEFAULT NULL,
  `pnode_load` int DEFAULT NULL,
  `no_connect` int DEFAULT NULL,
  `link_users` int DEFAULT NULL,
  `bandwidth` int DEFAULT NULL,
  `desires` int DEFAULT NULL,
  `vclass` int DEFAULT NULL,
  `delay` int DEFAULT NULL,
  `trivial_mix` int DEFAULT NULL,
  `subnodes` int DEFAULT NULL,
  `max_types` int DEFAULT NULL,
  `endpoints` int DEFAULT NULL,
  PRIMARY KEY (`seq`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `report_assign_violation`
--

LOCK TABLES `report_assign_violation` WRITE;
/*!40000 ALTER TABLE `report_assign_violation` DISABLE KEYS */;
/*!40000 ALTER TABLE `report_assign_violation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `report_context`
--

DROP TABLE IF EXISTS `report_context`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `report_context` (
  `seq` int unsigned NOT NULL DEFAULT '0',
  `i0` int DEFAULT NULL,
  `i1` int DEFAULT NULL,
  `i2` int DEFAULT NULL,
  `vc0` varchar(255) DEFAULT NULL,
  `vc1` varchar(255) DEFAULT NULL,
  `vc2` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`seq`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `report_context`
--

LOCK TABLES `report_context` WRITE;
/*!40000 ALTER TABLE `report_context` DISABLE KEYS */;
/*!40000 ALTER TABLE `report_context` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `report_error`
--

DROP TABLE IF EXISTS `report_error`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `report_error` (
  `seq` int unsigned NOT NULL DEFAULT '0',
  `stamp` int unsigned NOT NULL DEFAULT '0',
  `session` int unsigned NOT NULL DEFAULT '0',
  `invocation` int unsigned NOT NULL DEFAULT '0',
  `attempt` tinyint(1) NOT NULL DEFAULT '0',
  `severity` smallint NOT NULL DEFAULT '0',
  `script` smallint NOT NULL DEFAULT '0',
  `error_type` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`seq`),
  KEY `session` (`session`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `report_error`
--

LOCK TABLES `report_error` WRITE;
/*!40000 ALTER TABLE `report_error` DISABLE KEYS */;
/*!40000 ALTER TABLE `report_error` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reposition_status`
--

DROP TABLE IF EXISTS `reposition_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reposition_status` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `attempts` tinyint NOT NULL DEFAULT '0',
  `distance_remaining` float DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reposition_status`
--

LOCK TABLES `reposition_status` WRITE;
/*!40000 ALTER TABLE `reposition_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `reposition_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reservation_history`
--

DROP TABLE IF EXISTS `reservation_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservation_history` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `pid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `nodes` smallint NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `created` datetime DEFAULT NULL,
  `deleted` datetime DEFAULT NULL,
  `canceled` datetime DEFAULT NULL,
  `start` datetime DEFAULT NULL,
  `end` datetime DEFAULT NULL,
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `notes` mediumtext,
  `admin_notes` mediumtext,
  `uuid` varchar(40) NOT NULL DEFAULT '',
  KEY `start` (`start`),
  KEY `uuid` (`uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reservation_history`
--

LOCK TABLES `reservation_history` WRITE;
/*!40000 ALTER TABLE `reservation_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `reservation_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reservation_version`
--

DROP TABLE IF EXISTS `reservation_version`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservation_version` (
  `version` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`version`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reservation_version`
--

LOCK TABLES `reservation_version` WRITE;
/*!40000 ALTER TABLE `reservation_version` DISABLE KEYS */;
/*!40000 ALTER TABLE `reservation_version` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reserved`
--

DROP TABLE IF EXISTS `reserved`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reserved` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `rsrv_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `vname` varchar(32) DEFAULT NULL,
  `erole` enum('node','virthost','delaynode','simhost','sharedhost','subboss','storagehost') NOT NULL DEFAULT 'node',
  `simhost_violation` tinyint unsigned NOT NULL DEFAULT '0',
  `old_pid` varchar(48) NOT NULL DEFAULT '',
  `old_eid` varchar(32) NOT NULL DEFAULT '',
  `old_exptidx` int NOT NULL DEFAULT '0',
  `cnet_vlan` int DEFAULT NULL,
  `inner_elab_role` tinytext,
  `inner_elab_boot` tinyint(1) DEFAULT '0',
  `plab_role` enum('plc','node','none') NOT NULL DEFAULT 'none',
  `plab_boot` tinyint(1) DEFAULT '0',
  `mustwipe` tinyint NOT NULL DEFAULT '0',
  `genisliver_idx` int unsigned DEFAULT NULL,
  `external_resource_index` int unsigned DEFAULT NULL,
  `external_resource_id` tinytext,
  `external_resource_key` tinytext,
  `tmcd_redirect` tinytext,
  `sharing_mode` varchar(32) DEFAULT NULL,
  `rootkey_private` tinyint(1) NOT NULL DEFAULT '0',
  `rootkey_public` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`),
  UNIQUE KEY `vname` (`pid`,`eid`,`vname`),
  UNIQUE KEY `vname2` (`exptidx`,`vname`),
  KEY `old_pid` (`old_pid`,`old_eid`),
  KEY `old_exptidx` (`old_exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reserved`
--

LOCK TABLES `reserved` WRITE;
/*!40000 ALTER TABLE `reserved` DISABLE KEYS */;
/*!40000 ALTER TABLE `reserved` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reserved_addresses`
--

DROP TABLE IF EXISTS `reserved_addresses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reserved_addresses` (
  `rsrvidx` int unsigned NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `rsrv_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `baseaddr` varchar(40) NOT NULL DEFAULT '',
  `prefix` tinyint unsigned NOT NULL DEFAULT '0',
  `type` varchar(30) NOT NULL DEFAULT '',
  `role` enum('public','internal') NOT NULL DEFAULT 'internal',
  PRIMARY KEY (`rsrvidx`),
  UNIQUE KEY `type_base` (`type`,`baseaddr`,`prefix`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reserved_addresses`
--

LOCK TABLES `reserved_addresses` WRITE;
/*!40000 ALTER TABLE `reserved_addresses` DISABLE KEYS */;
/*!40000 ALTER TABLE `reserved_addresses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reserved_blockstores`
--

DROP TABLE IF EXISTS `reserved_blockstores`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reserved_blockstores` (
  `bsidx` int unsigned NOT NULL,
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `bs_id` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `size` int unsigned NOT NULL DEFAULT '0',
  `vnode_id` varchar(32) NOT NULL DEFAULT '',
  `rsrv_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`exptidx`,`bsidx`,`vname`),
  UNIQUE KEY `vname` (`exptidx`,`vname`),
  KEY `nidbid` (`node_id`,`bs_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reserved_blockstores`
--

LOCK TABLES `reserved_blockstores` WRITE;
/*!40000 ALTER TABLE `reserved_blockstores` DISABLE KEYS */;
/*!40000 ALTER TABLE `reserved_blockstores` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reserved_vlantags`
--

DROP TABLE IF EXISTS `reserved_vlantags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reserved_vlantags` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `lanid` int NOT NULL DEFAULT '0',
  `vname` varchar(128) NOT NULL DEFAULT '',
  `tag` smallint NOT NULL DEFAULT '0',
  `reserve_time` datetime DEFAULT NULL,
  `locked` datetime DEFAULT NULL,
  `state` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`lanid`,`tag`),
  UNIQUE KEY `vname` (`pid`,`eid`,`vname`,`tag`),
  UNIQUE KEY `lanid` (`pid`,`eid`,`lanid`,`tag`),
  UNIQUE KEY `tag` (`tag`),
  KEY `id` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reserved_vlantags`
--

LOCK TABLES `reserved_vlantags` WRITE;
/*!40000 ALTER TABLE `reserved_vlantags` DISABLE KEYS */;
/*!40000 ALTER TABLE `reserved_vlantags` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `scheduled_reloads`
--

DROP TABLE IF EXISTS `scheduled_reloads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scheduled_reloads` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `image_id` int unsigned NOT NULL DEFAULT '0',
  `reload_type` enum('netdisk','frisbee') DEFAULT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `scheduled_reloads`
--

LOCK TABLES `scheduled_reloads` WRITE;
/*!40000 ALTER TABLE `scheduled_reloads` DISABLE KEYS */;
/*!40000 ALTER TABLE `scheduled_reloads` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `scopus_paper_authors`
--

DROP TABLE IF EXISTS `scopus_paper_authors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scopus_paper_authors` (
  `abstract_id` varchar(32) NOT NULL DEFAULT '',
  `author_id` varchar(32) NOT NULL DEFAULT '',
  `author` tinytext,
  PRIMARY KEY (`abstract_id`,`author_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `scopus_paper_authors`
--

LOCK TABLES `scopus_paper_authors` WRITE;
/*!40000 ALTER TABLE `scopus_paper_authors` DISABLE KEYS */;
/*!40000 ALTER TABLE `scopus_paper_authors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `scopus_paper_info`
--

DROP TABLE IF EXISTS `scopus_paper_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scopus_paper_info` (
  `scopus_id` varchar(32) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `pubdate` date NOT NULL DEFAULT '0000-00-00',
  `pubtype` varchar(64) NOT NULL DEFAULT '',
  `pubname` text,
  `doi` varchar(128) DEFAULT NULL,
  `url` text,
  `title` text,
  `authors` text,
  `cites` enum('emulab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `uses` enum('yes','no','unknown') DEFAULT NULL,
  `citedby_count` int DEFAULT '0',
  PRIMARY KEY (`scopus_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `scopus_paper_info`
--

LOCK TABLES `scopus_paper_info` WRITE;
/*!40000 ALTER TABLE `scopus_paper_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `scopus_paper_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `scripts`
--

DROP TABLE IF EXISTS `scripts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scripts` (
  `script` smallint NOT NULL AUTO_INCREMENT,
  `script_name` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`script`),
  UNIQUE KEY `id` (`script_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `scripts`
--

LOCK TABLES `scripts` WRITE;
/*!40000 ALTER TABLE `scripts` DISABLE KEYS */;
/*!40000 ALTER TABLE `scripts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `session_info`
--

DROP TABLE IF EXISTS `session_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `session_info` (
  `session` int NOT NULL DEFAULT '0',
  `uid` int NOT NULL DEFAULT '0',
  `exptidx` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`session`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `session_info`
--

LOCK TABLES `session_info` WRITE;
/*!40000 ALTER TABLE `session_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `session_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `shared_vlans`
--

DROP TABLE IF EXISTS `shared_vlans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `shared_vlans` (
  `pid` varchar(48) DEFAULT NULL,
  `eid` varchar(32) DEFAULT NULL,
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `lanid` int NOT NULL DEFAULT '0',
  `token` varchar(128) NOT NULL DEFAULT '',
  `created` datetime DEFAULT NULL,
  `creator` varchar(8) NOT NULL DEFAULT '',
  `creator_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `open` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`token`),
  UNIQUE KEY `lan` (`exptidx`,`vname`),
  UNIQUE KEY `lanid` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `shared_vlans`
--

LOCK TABLES `shared_vlans` WRITE;
/*!40000 ALTER TABLE `shared_vlans` DISABLE KEYS */;
/*!40000 ALTER TABLE `shared_vlans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sitevariables`
--

DROP TABLE IF EXISTS `sitevariables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sitevariables` (
  `name` varchar(255) NOT NULL DEFAULT '',
  `value` text,
  `defaultvalue` text NOT NULL,
  `description` text,
  `ns_include` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sitevariables`
--

LOCK TABLES `sitevariables` WRITE;
/*!40000 ALTER TABLE `sitevariables` DISABLE KEYS */;
INSERT INTO `sitevariables` VALUES ('general/testvar',NULL,'43','A test variable',0),('web/nologins',NULL,'0','Non-zero value indicates that no user may log into the Web Interface; non-admin users are auto logged out.',0),('web/message',NULL,'','Message to place in large lettering under the login message on the Web Interface.',0),('idle/threshold','2','4','Number of hours of inactivity for a node/expt to be considered idle.',0),('idle/mailinterval',NULL,'4','Number of hours since sending a swap request before sending another one. (Timing of first one is determined by idle/threshold.)',0),('idle/cc_grp_ldrs',NULL,'3','Start CC\'ing group and project leaders on idle messages on the Nth message.',0),('batch/retry_wait','90','900','Number of seconds to wait before retrying a failed batch experiment.',0),('swap/idleswap_warn',NULL,'30','Number of minutes before an Idle-Swap to send a warning message. Set to 0 for no warning.',0),('swap/autoswap_warn',NULL,'60','Number of minutes before an Auto-Swap to send a warning message. Set to 0 for no warning.',0),('plab/stale_age',NULL,'60','Age in minutes at which to consider site data stale and thus node down (0==always use data)',0),('idle/batch_threshold',NULL,'30','Number of minutes of inactivity for a batch node/expt to be considered idle.',0),('general/recently_active','7','14','Number of days to be considered a recently active user of the testbed.',0),('plab/load_metric','load_five','load_fifteen','GMOND load metric to use (load_one, load_five, load_fifteen)',0),('plab/max_load','10','5.0','Load at which to stop admitting jobs (0==admit nothing, 1000==admit all)',0),('plab/min_disk',NULL,'10.0','Minimum disk space free at which to stop admitting jobs (0==admit all, 100==admit none)',0),('watchdog/interval','30','60','Interval in minutes between checks for changes in timeout values (0==never check)',0),('watchdog/ntpdrift',NULL,'240','Interval in minutes between reporting back NTP drift changes (0==never report)',0),('watchdog/cvsup',NULL,'720','Interval in minutes between remote node checks for software updates (0==never check)',0),('watchdog/isalive/local',NULL,'3','Interval in minutes between local node status reports (0==never report)',0),('watchdog/isalive/vnode',NULL,'5','Interval in minutes between virtual node status reports (0==never report)',0),('watchdog/isalive/plab',NULL,'10','Interval in minutes between planetlab node status reports (0==never report)',0),('watchdog/isalive/wa',NULL,'1','Interval in minutes between widearea node status reports (0==never report)',0),('watchdog/isalive/dead_time','10','120','Time, in minutes, after which to consider a node dead if it has not checked in via tha watchdog',0),('watchdog/dhcpdconf',NULL,'5','Time in minutes between DHCPD configuration updates (0==never update)',0),('plab/setup/vnode_batch_size',NULL,'40','Number of plab nodes to setup simultaneously',0),('plab/setup/vnode_wait_time','300','960','Number of seconds to wait for a plab node to setup',0),('watchdog/rusage','30','300','Interval in _seconds_ between node resource usage reports (0==never report)',0),('watchdog/hostkeys',NULL,'999999','Interval in minutes between host key reports (0=never report, 999999=once only)',0),('watchdog/rootpswd',NULL,'60','Interval in minutes between forced resets of root password to Emulab-assigned value (0=never reset)',0),('plab/message',NULL,'','Message to display at the top of the plab_ez page',0),('node/ssh_pubkey','ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA5pIVUkDhVdgGUcsUTQgmI/N4AhJba05gGn7/Ja46OorcKH12sbn9uH4XImdXRF16VVPMTytcOUAqsMsQ20cUcGyvXHnmmNANrLO2htCzNUdrbPkx5X63FNujjp7mLgdlnwzh/Zuoxw65DVXeVp3T5+9Ad25O4u9ybYsHFc8RmBM= root@boss.emulab.net','','Boss SSH public key to install on nodes',0),('web/banner',NULL,'','Message to place in large lettering at top of home page (typically a special message)',0),('general/autoswap_threshold',NULL,'16','Number of hours before an experiment is forcibly swapped',0),('general/autoswap_mode','1','0','Control whether autoswap defaults to on or off in the Begin Experiment page',0),('webcam/anyone_can_view','1','0','Turn webcam viewing on/off for mere users; default is off',0),('webcam/admins_can_view',NULL,'1','Turn webcam viewing on/off for admin users; default is on',0),('swap/use_admission_control',NULL,'1','Use admission control when swapping in experiments',0),('robotlab/override','open','','Turn the Robot Lab on/off (open/close). This is an override over other settings',0),('robotlab/exclusive','0','1','Only one experiment at a time; do not turn this off!',0),('robotlab/opentime','08:00','07:00','Time the Robot lab opens for use.',0),('robotlab/closetime',NULL,'18:00','Time the Robot lab closes down for the night.',0),('robotlab/open','1','0','Turn the Robot Lab on/off for weekends and holidays. Overrides the open/close times.',0),('swap/admission_control_debug',NULL,'0','Turn on/off admission control debugging (lots of output!)',0),('elabinelab/boss_pkg',NULL,'emulab-boss-1.8','Name of boss node install package (DEPRECATED)',0),('elabinelab/boss_pkg_dir',NULL,'/share/freebsd/packages/FreeBSD-4.10-20041102','Path from which to fetch boss packages (DEPRECATED)',0),('elabinelab/ops_pkg',NULL,'emulab-ops-1.4','Name of ops node install package (DEPRECATED)',0),('elabinelab/ops_pkg_dir',NULL,'/share/freebsd/packages/FreeBSD-4.10-20041102','Path from which to fetch ops packages (DEPRECATED)',0),('elabinelab/windows','1','0','Turn on Windows support in inner Emulab',0),('elabinelab/singlenet',NULL,'0','Default control net config. 0==use inner cnet, 1==use real cnet',1),('elabinelab/boss_osid',NULL,'','Default (emulab-ops) OSID to boot on boss node. Empty string means use node_type default OSID',1),('elabinelab/ops_osid',NULL,'','Default (emulab-ops) OSID to boot on ops node. Empty string means use node_type default OSID',1),('elabinelab/fs_osid',NULL,'','Default (emulab-ops) OSID to boot on fs node. Empty string means use node_type default OSID',1),('general/firstinit/state',NULL,'Ready','Indicates that a new emulab is not setup yet. Moves through several states.',0),('general/firstinit/pid',NULL,'testbed','The Project Name of the first project.',0),('general/version/minor','168','','Source code minor revision number',0),('general/version/build','12/22/2009','','Build version number',0),('general/version/major','4','','Source code major revision number',0),('general/mailman/password','MessyBoy','','Admin password for Emulab generated lists',0),('swap/swapout_command_failaction',NULL,'warn','What to do if swapout command fails (warn == continue, fail == fail swapout).',0),('general/open_showexplist',NULL,'','Allow members of this project to view all running experiments on the experiment list page',0),('general/linux_endnodeshaping',NULL,'1','Use this sitevar to disable endnodeshaping on linux globally on your testbed',0),('swap/swapout_command','/usr/local/bin/create-swapimage -s','','Command to run in admin MFS on each node of an experiment at swapout time. Runs as swapout user.',0),('swap/swapout_command_timeout','360','120','Time (in seconds) to allow for command completion',0),('general/arplockdown','','none','Lock down ARP entries on servers (none == let servers dynamically ARP, static == insert static ARP entries for important nodes, staticonly == allow only static entries)',0),('node/gw_mac','','','MAC address of the control net router (NULL if none)',0),('node/gw_ip','','','IP address of the control net router (NULL if none)',0),('node/boss_mac','','','MAC address of the boss node (NULL if behind GW)',0),('node/boss_ip','','','IP address of the boss node',0),('node/ops_mac','','','MAC address of the ops node (NULL if behind GW)',0),('node/ops_ip','','','IP address of the ops node',0),('node/fs_mac','','','MAC address of the fs node (NULL if behind GW, same as ops if same node)',0),('node/fs_ip','','','IP address of the fs node (same as ops if same node)',0),('general/default_imagename','FBSD410+RHL90-STD','','Name of the default image for new nodes, assumed to be in the emulab-ops project.',0),('general/joinproject/admincheck','1','0','When set, a project may not have a mix of admin and non-admin users',0),('protogeni/allow_externalusers','1','1','When set, external users may allocate slivers on your testbed.',0),('protogeni/max_externalnodes',NULL,'1024','When set, external users may allocate slivers on your testbed.',0),('protogeni/cm_uuid','28a10955-aa00-11dd-ad1f-001143e453fe','','The UUID of the local Component Manager.',0),('protogeni/max_sliver_lifetime','90','90','The maximum sliver lifetime. When set limits the lifetime of a sliver on your CM. Also see protogeni/max_slice_lifetime.',0),('protogeni/initial_sliver_lifetime','6','6','The initial sliver lifetime. In hours. Also see protogeni/max_sliver_lifetime.',0),('protogeni/max_slice_lifetime','90','90','The maximum slice credential lifetime. When set limits the lifetime of a slice credential. Also see protogeni/max_sliver_lifetime.',0),('protogeni/default_slice_lifetime','6','6','The default slice credential lifetime. In hours. Also see protogeni/max_slice_lifetime.',0),('protogeni/max_components','-1','-1','Maximum number of components that can be allocated. -1 indicates any number of components can be allocated.',0),('protogeni/warn_short_slices','0','0','When set, warn users about shortlived slices (see the sa_daemon).',0),('general/minpoolsize','3','1','The Minimum size of the shared pool',0),('general/maxpoolsize','5','1','The maximum size of the shared pool',0),('protogeni/sa_uuid','2b437faa-aa00-11dd-ad1f-001143e453fe','','The UUID of the local Slice Authority.',0),('general/poolnodetype','pc3000','','The preferred node type of the shared pool',0),('general/default_country','US','','The default country of your site',0),('general/default_latitude','40.768652','','The default latitude of your site',0),('general/default_longitude','-111.84581','','The default longitude of your site',0),('oml/default_osid',NULL,'','Default OSID to use for OML server',1),('oml/default_server_startcmd',NULL,'','Default command line to use to start OML server',1),('images/create/maxwait',NULL,'72','Max time (minutes) to allow for saving an image',0),('images/create/idlewait',NULL,'8','Max time (minutes) to allow between periods of progress (image file getting larger) when saving an image (should be <= maxwait)',0),('images/create/maxsize',NULL,'6','Max size (GB) of a created image',0),('general/testbed_shutdown',NULL,'0','Non-zero value indicates that the testbed is shutdown and scripts should not do anything when they run. DO NOT SET THIS BY HAND!',0),('images/frisbee/maxrate_std',NULL,'72000000','Max bandwidth (Bits/sec) at which to distribute standard images from the /usr/testbed/images directory.',0),('images/frisbee/maxrate_usr',NULL,'54000000','Max bandwidth (Bits/sec) at which to distribute user-defined images from the /proj/.../images directory.',0),('images/frisbee/maxrate_dyn',NULL,'0','If non-zero, use bandwidth throttling on all frisbee servers; maxrate_{std,usr} serve as initial BW values.',0),('images/frisbee/maxlinger',NULL,'180','Seconds to wait after last request before exiting; 0 means never exit, -1 means exit after last client leaves.',0),('images/frisbee/heartbeat',NULL,'15','Interval at which frisbee client should report progress (0==never report).',0),('general/idlepower_enable',NULL,'0','Enable idle power down to conserve electricity',0),('general/idlepower_idletime',NULL,'3600','Maximum number of seconds idle before a node is powered down to conserve electricity',0),('general/autoswap_max',NULL,'120','Maximum number of hours for the experiment autoswap limit.',0),('protogeni/show_sslcertbox','1','1','When set, users see option on join/start project pages to create SSL certificate.',0),('protogeni/default_osname','','','The default os name used for ProtoGENI slivers when no os is specified on a node.',0),('images/root_password',NULL,'','The encryption hash of the root password to use in the MFSs.',0),('protogeni/idlecheck',NULL,'0','When set, do idle checks and send email about idle slices.',0),('protogeni/idlecheck_terminate',NULL,'0','When set, do idle checks and terminate idle slices after email warning.',0),('protogeni/idlecheck_norenew',NULL,'0','When set, refuse too allow idle slices to be renewed.',0),('protogeni/idlecheck_threshold',NULL,'3','Number of hours after which a slice is considered idle.',0),('protogeni/wrapper_sa_debug_level',NULL,'0','When set, send debugging email for SA wrapper calls',0),('protogeni/wrapper_ch_debug_level',NULL,'0','When set, send debugging email for CH wrapper calls',0),('protogeni/wrapper_cm_debug_level',NULL,'1','When set, send debugging email for CM wrapper calls',0),('protogeni/wrapper_am_debug_level',NULL,'1','When set, send debugging email for AM wrapper calls',0),('protogeni/wrapper_debug_sendlog',NULL,'1','When set, wrapper debugging email will send log files in addition to the metadata',0),('protogeni/plc_url',NULL,'https://www.planet-lab.org:12345','PlanetLab does not put a URL in their certificates.',0),('nodecheck/collect',NULL,'0','When set, collect and record node hardware info in /proj/<pid>/nodecheck/.',0),('nodecheck/check',NULL,'0','When set, perform nodecheck at swapin.',0),('general/xenvifrouting',NULL,'0','Non-zero value says to use vif routing on XEN shared nodes.',0),('general/default_xen_parentosid',NULL,'emulab-ops,XEN43-64-STD','The default parent OSID to use for XEN capable images.',0),('storage/stdataset/usequotas',NULL,'0','If non-zero, enforce per-project dataset quotas',0),('storage/stdataset/default_quota',NULL,'0','Default quota (in MiB) to use for a project if no current quota is set. Only applies if usequotas is set for this type (0 == pid must have explicit quota, -1 == unlimited)',0),('storage/stdataset/maxextend',NULL,'2','Number of times a user can extend the lease (0 == unlimited)',0),('storage/stdataset/extendperiod',NULL,'1','Length (days) of each user-requested extention (0 == do not allow extensions)',0),('storage/stdataset/maxidle',NULL,'0','Max time (days) from last use before lease is marked expired (0 == unlimited)',0),('storage/stdataset/graceperiod',NULL,'1','Time (days) before an expired dataset will be destroyed (0 == no grace period)',0),('storage/ltdataset/maxextend',NULL,'1','Number of times a user can extend the lease (0 == unlimited)',0),('storage/stdataset/maxlease',NULL,'7','Max time (days) from creation before lease is marked expired (0 == unlimited)',0),('storage/ltdataset/autodestroy',NULL,'0','If non-zero, destroy expired datasets after grace period, otherwise lock them',0),('storage/stdataset/maxsize',NULL,'1048576','Max size (MiB) of a dataset (0 == unlimited)',0),('storage/ltdataset/extendperiod',NULL,'0','Length (days) of each user-requested extention (0 == do not allow extensions)',0),('storage/ltdataset/maxlease',NULL,'0','Max time (days) from creation before lease is marked expired (0 == unlimited)',0),('storage/stdataset/autodestroy',NULL,'1','If non-zero, destroy expired datasets after grace period, otherwise lock them',0),('storage/ltdataset/usequotas',NULL,'1','If non-zero, enforce per-project dataset quotas',0),('storage/ltdataset/default_quota',NULL,'0','Default quota (in MiB) to use for a project if no current quota is set. Only applies if usequotas is set for this type (0 == pid must have explicit quota, -1 == unlimited)',0),('storage/ltdataset/maxsize',NULL,'0','Max size (MiB) of a dataset (0 == unlimited)',0),('storage/ltdataset/graceperiod',NULL,'180','Time (days) before an expired dataset will be destroyed (0 == no grace period)',0),('storage/ltdataset/maxidle',NULL,'180','Max time (days) from last use before lease is marked expired (0 == unlimited)',0),('general/disk_trim_interval',NULL,'0','If non-zero, minimum interval (seconds) between attempts to TRIM boot disk during disk reloading. Zero disables all TRIM activity. Node must also have non-zero bootdisk_trim attribute.',0),('storage/simultaneous_ro_datasets',NULL,'0','If set, allow simultaneous read-only mounts of datasets',0),('storage/local/disktypes',NULL,'Any','Types of local disks used to provision blockstores. One of: any, hdd-only, ssd-only.',0),('aptlab/message',NULL,'','Message to display at the top of the APT interface',0),('cloudlab/message',NULL,'','Message to display at the top of the CloudLab interface',0),('aptui/autoextend_maximum',NULL,'7','Maximum number of days requested that will automaticaly be granted; zero means only admins can extend an experiment.',0),('aptui/autoextend_maxage',NULL,'14','Maximum age (in days) of an experiment before all extension requests require admin approval.',0),('node/nfs_transport',NULL,'udp','Transport protocol to be used by NFS mounts on clients. One of: udp, tcp, or osdefault, where osdefault means use the client OS default setting.',0),('node/user_passwords',NULL,'0','If non-zero, password hashes for users are passed to nodes allow user logins on the console. For better security, you should leave this zero.',0),('images/default_typelist',NULL,'','List of types to associate with an imported image when it is not appropriate to associate all existing types.',0),('protogeni/use_imagetracker',NULL,'0','Enable use of the image tracker.',0),('protogeni/disable_experiments',NULL,'0','When set, experiments are disabled on the protogeni path.',0),('general/no_openflow',NULL,'0','Disallow topologies that specify openflow controllers, there is no local support for it.',0),('phantomnet/message',NULL,'','Message to display at the top of the PhantomNet portal.',0),('ue/sim_sequence_default',NULL,'1000000','Default initial sequence number for PhantomNet UE SIMs',0),('ue/sim_sequence_increment',NULL,'1000000','Sequence number increment amount for PhantomNet UE SIMs',0),('portal/default_profile',NULL,'emulab-ops,OneVM','Default profile for portal instantiate page.',0),('cloudlab/default_profile',NULL,'emulab-ops,OpenStack','Default profile for portal instantiate page.',0),('phantomnet/default_profile',NULL,'emulab-ops,OneVM','Default profile for portal instantiate page.',0),('reload/retrytime',NULL,'20','If a node has been in reloading for longer than this period (minutes), try rebooting it. If zero, never try reboot.',0),('reload/failtime',NULL,'0','If a node has been in reloading for longer than this period (minutes), send it to hwdown. If zero, leave nodes in reloading.',0),('reload/warnonretry',NULL,'1','If non-zero send e-mail to testbed-ops when a retry is attempted.',0),('reload/hwdownaction',NULL,'nothing','What to do when nodes are moved to hwdown. One of: poweroff, adminmode, or nothing.',0),('general/architecture_priority',NULL,'x86_64,aarch64','Default mapper ordering for multi architecture testbeds.',0),('general/admission_control','0','0','When set, refuse node allocation if reservation admission control fails.',0),('general/cnet_firewalls','0','0','When set, control network firewalls are supported via control network vlans.',0),('general/export_active',NULL,'0','Stop exporting shared user and project directories when they have been inactive for this number of days or longer (0==do not inactivate).',0),('general/root_keypair',NULL,'-1','Default distribution of per-experiment root keypairs (-1==disable root keypair mechanism, 0==do not distribute to any nodes, 1==distribute to all nodes).',0),('cnetwatch/enable',NULL,'0','Enable control network watcher; only works on clusters that support portstats on the control switches.',0),('cnetwatch/reportlog',NULL,'','Full path of logfile for periodic port counts of all nodes.',0),('cnetwatch/check_interval',NULL,'600','Interval in seconds at which to collect info (should be at least 10 seconds, 0 means do not run cnetwatch)',0),('cnetwatch/alert_interval',NULL,'600','Interval in seconds over which to calculate packet/bit rates and to log alerts (should be an integer multiple of check_interval)',0),('cnetwatch/pps_threshold',NULL,'50000','Packet rate in packets/sec in excess of which to log an alert (0 means do not generate packet rate alerts)',0),('cnetwatch/bps_threshold',NULL,'500000000','Data rate in bits/sec in excess of which to log an alert (0 means do not generate data rate alerts)',0),('cnetwatch/mail_interval',NULL,'600','Interval in seconds at which to send email for all alerts logged during the interval (0 means do not send alert email)',0),('cnetwatch/mail_max',NULL,'1000','Maximum number of alert emails to send; after this alerts are only logged (0 means no limit to the emails)',0),('reservations/approval_threshold',NULL,'128','Maximum number of node hours for automatic approval of reservation requests (0 means no limit).',0),('docker/registry',NULL,'','The URL of the Docker registry where this Emulab stores its custom Docker images; the empty string signifies that users cannot create custom Docker images',0),('general/allowjumboframes',NULL,'0','Set non-zero to allow experiments to specify jumbo frames on links/lans. NOTE: the experimental network fabric switches must have jumbo frames enabled!',0),('hwcollect/interval',NULL,'0','If non-zero, interval in minutes between HW collection events for any node. Whenever a node is in emulab-ops/hwcheckup and more than the interval has passed since the last collection, new data will be collected. Set to zero to disable collection.',0),('hwcollect/experiment',NULL,'emulab-ops/hwcheckup','Project (pid) or experiment (pid/eid) in which the node must reside to run collection.',0),('hwcollect/outputdir',NULL,'/proj/emulab-ops/hwcollect','NFS-shared filesystem into which HW info command output is stored. Directory must exist.',0),('hwcollect/commands',NULL,'Any,dmesg,dmesg;Linux,lshw,lshw','Collection programs to run. A semi-colon separated list of OS,program,cmdline triples.',0),('rfmonitor/noisefloor',NULL,'-110.0','Noise floor threshold for determining if a radio is transmitting.',0),('powder/deadman_enable',NULL,'0','Set to non-zero to enable Powder deadman operation.',0),('powder/mobile_update',NULL,'1','Set to zero to disable automated software update at boot time.',0),('images/listed_default',NULL,'1','By default, newly created or imported global images in the emulab-ops project will be listed for users to see (and use). Set this to zero to prevent automatic listing.',0);
/*!40000 ALTER TABLE `sitevariables` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `state_timeouts`
--

DROP TABLE IF EXISTS `state_timeouts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `state_timeouts` (
  `op_mode` varchar(20) NOT NULL DEFAULT '',
  `state` varchar(20) NOT NULL DEFAULT '',
  `timeout` int NOT NULL DEFAULT '0',
  `action` mediumtext NOT NULL,
  PRIMARY KEY (`op_mode`,`state`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `state_timeouts`
--

LOCK TABLES `state_timeouts` WRITE;
/*!40000 ALTER TABLE `state_timeouts` DISABLE KEYS */;
INSERT INTO `state_timeouts` VALUES ('NORMAL','REBOOTING',120,'REBOOT'),('NORMAL','REBOOTED',60,'NOTIFY'),('MINIMAL','SHUTDOWN',120,'REBOOT'),('NORMALv1','TBSETUP',600,'NOTIFY'),('RELOAD','RELOADDONE',60,'NOTIFY'),('RELOAD','RELOADDONEV2',60,'NOTIFY'),('EXPTSTATUS','ACTIVATING',0,''),('EXPTSTATUS','ACTIVE',0,''),('EXPTSTATUS','NEW',0,''),('EXPTSTATUS','PRERUN',0,''),('EXPTSTATUS','SWAPPED',0,''),('EXPTSTATUS','SWAPPING',0,''),('EXPTSTATUS','TERMINATING',0,''),('EXPTSTATUS','TESTING',0,''),('MINIMAL','BOOTING',180,'REBOOT'),('NODEALLOC','FREE_CLEAN',0,''),('NODEALLOC','FREE_DIRTY',0,''),('NODEALLOC','REBOOT',0,''),('NODEALLOC','RELOAD',0,''),('NODEALLOC','RESERVED',0,''),('NORMAL','BOOTING',180,'REBOOT'),('NORMALv1','BOOTING',180,'REBOOT'),('RELOAD','BOOTING',180,'REBOOT'),('RELOAD','RELOADING',600,'NOTIFY'),('RELOAD','RELOADSETUP',60,'STATE:RELOADFAILED'),('RELOAD','SHUTDOWN',600,'REBOOT'),('USERSTATUS','ACTIVE',0,''),('USERSTATUS','FROZEN',0,''),('USERSTATUS','NEWUSER',0,''),('USERSTATUS','UNAPPROVED',0,''),('TBCOMMAND','REBOOT',75,'CMDRETRY'),('TBCOMMAND','POWEROFF',0,'CMDRETRY'),('TBCOMMAND','POWERON',0,'CMDRETRY'),('TBCOMMAND','POWERCYCLE',0,'CMDRETRY'),('PCVM','BOOTING',1200,'NOTIFY'),('PCVM','SHUTDOWN',0,''),('PCVM','ISUP',0,''),('PCVM','TBSETUP',600,'NOTIFY'),('PXEFBSD','REBOOTING',120,'REBOOT'),('PXEFBSD','REBOOTED',60,'NOTIFY'),('PXEFBSD','BOOTING',180,'REBOOT'),('NORMALv2','TBSETUP',600,'NOTIFY'),('NORMALv2','BOOTING',300,'REBOOT'),('GARCIA-STARGATEv1','TBSETUP',600,'NOTIFY'),('PXEKERNEL','PXEWAKEUP',120,'REBOOT'),('SECUREBOOT','BOOTING',300,'STATE:SECVIOLATION'),('SECUREBOOT','GPXEBOOTING',60,'STATE:SECVIOLATION'),('SECUREBOOT','PXEBOOTING',60,'STATE:SECVIOLATION'),('SECUREBOOT','SHUTDOWN',300,'STATE:SECVIOLATION'),('SECUREBOOT','TPMSIGNOFF',60,'STATE:SECVIOLATION'),('SECUREBOOT','PXEWAIT',10,'STATE:SECVIOLATION'),('SECURELOAD','BOOTING',300,'STATE:SECVIOLATION'),('SECURELOAD','GPXEBOOTING',60,'STATE:SECVIOLATION'),('SECURELOAD','PXEBOOTING',60,'STATE:SECVIOLATION'),('SECURELOAD','RELOADDONE',300,'STATE:SECVIOLATION'),('SECURELOAD','RELOADING',3600,'STATE:SECVIOLATION'),('SECURELOAD','RELOADSETUP',60,'STATE:SECVIOLATION'),('SECURELOAD','SHUTDOWN',300,'STATE:SECVIOLATION'),('SECURELOAD','TPMSIGNOFF',300,'STATE:SECVIOLATION'),('WIMRELOAD','SHUTDOWN',240,'REBOOT'),('WIMRELOAD','RELOADSETUP',60,'NOTIFY'),('WIMRELOAD','RELOADING',1800,'NOTIFY'),('WIMRELOAD','RELOADDONE',60,'NOTIFY'),('PXEKERNEL','PXEBOOTING',240,'REBOOT');
/*!40000 ALTER TABLE `state_timeouts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `state_transitions`
--

DROP TABLE IF EXISTS `state_transitions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `state_transitions` (
  `op_mode` varchar(20) NOT NULL DEFAULT '',
  `state1` varchar(20) NOT NULL DEFAULT '',
  `state2` varchar(20) NOT NULL DEFAULT '',
  `label` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`op_mode`,`state1`,`state2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `state_transitions`
--

LOCK TABLES `state_transitions` WRITE;
/*!40000 ALTER TABLE `state_transitions` DISABLE KEYS */;
INSERT INTO `state_transitions` VALUES ('ONIE','ISUP','SHUTDOWN',''),('ONIE','SHUTDOWN','BOOTING',''),('ONIE','SHUTDOWN','PXEWAIT',''),('ONIE','BOOTING','ISUP',''),('ONIE','BOOTING','BOOTING',''),('ONIE','PXEWAIT','PXEWAIT','bootinfoclient'),('ONIE','PXEWAIT','PXEWAKEUP',''),('ONIE','PXEWAKEUP','BOOTING',''),('ONIE','ISUP','ISUP',''),('ALWAYSUP','ISUP','SHUTDOWN','Reboot'),('ALWAYSUP','SHUTDOWN','ISUP','BootDone'),('ALWAYSUP','ISUP','POWEROFF',''),('ALWAYSUP','POWEROFF','SHUTDOWN',''),('PCVM','ISUP','BOOTING','Crash'),('EXPTSTATE','TERMINATING','SWAPPED','Error'),('EXPTSTATE','TERMINATING','ENDED','NoError'),('EXPTSTATE','MODIFY_RESWAP','SWAPPING','Nonrecover Error'),('EXPTSTATE','MODIFY_PARSE','ACTIVE','Error'),('NETBOOT','SHUTDOWN','PXEBOOTING','DHCP'),('RELOAD','PXEBOOTING','BOOTING','BootInfo'),('RELOAD','SHUTDOWN','PXEBOOTING','DHCP'),('NETBOOT','BOOTING','ISUP','BootDone'),('NETBOOT','BOOTING','SHUTDOWN','Error'),('NETBOOT','ISUP','BOOTING','KernelChange'),('NETBOOT','ISUP','ISUP','Retry'),('NETBOOT','ISUP','SHUTDOWN','Reboot'),('NETBOOT','SHUTDOWN','BOOTING','DHCP'),('NETBOOT','SHUTDOWN','SHUTDOWN','Retry'),('MINIMAL','BOOTING','ISUP','BootDone'),('MINIMAL','BOOTING','SHUTDOWN','Error'),('MINIMAL','ISUP','BOOTING','SilentReboot'),('MINIMAL','ISUP','SHUTDOWN','Reboot'),('MINIMAL','SHUTDOWN','BOOTING','DHCP'),('NORMAL','REBOOTING','REBOOTING','Retry'),('NORMALv1','TBSETUP','ISUP','BootDone'),('NORMALv1','SHUTDOWN','SHUTDOWN','Retry'),('NORMALv1','SHUTDOWN','PXEBOOTING','DHCP'),('NORMALv1','ISUP','SHUTDOWN','Reboot'),('NORMALv1','BOOTING','SHUTDOWN','Error'),('RELOAD','BOOTING','BOOTING','DHCPRetry'),('RELOAD','BOOTING','RELOADSETUP','BootOK'),('RELOAD','BOOTING','SHUTDOWN','Error'),('RELOAD','RELOADING','RELOADDONE','ReloadDone'),('RELOAD','RELOADING','RELOADDONEV2','ReloadDone'),('RELOAD','RELOADING','SHUTDOWN','Error'),('RELOAD','RELOADSETUP','RELOADING','ReloadReady'),('RELOAD','RELOADSETUP','SHUTDOWN','Error'),('RELOAD','SHUTDOWN','BOOTING','DHCP'),('RELOAD','SHUTDOWN','SHUTDOWN','Retry'),('USERSTATUS','ACTIVE','FROZEN',''),('USERSTATUS','FROZEN','ACTIVE',''),('USERSTATUS','NEWUSER','UNAPPROVED',''),('USERSTATUS','UNAPPROVED','ACTIVE',''),('BATCHSTATE','SWAPPED','ACTIVATING','SwapIn'),('WIDEAREA','ISUP','REBOOTED','SilentReboot'),('WIDEAREA','ISUP','SHUTDOWN','Reboot'),('WIDEAREA','REBOOTED','ISUP','BootDone'),('WIDEAREA','REBOOTED','SHUTDOWN','Error'),('BATCHSTATE','ACTIVATING','ACTIVE','SwapIn'),('NORMALv2','SHUTDOWN','SHUTDOWN','Retry'),('BATCHSTATE','ACTIVATING','POSTED','Batch'),('WIDEAREA','SHUTDOWN','REBOOTED','BootOK'),('WIDEAREA','SHUTDOWN','SHUTDOWN','Retry'),('PCVM','BOOTING','SHUTDOWN','Error'),('PCVM','BOOTING','TBSETUP','BootOK'),('PCVM','ISUP','SHUTDOWN','Reboot'),('PCVM','SHUTDOWN','BOOTING','StartBoot'),('PCVM','TBSETUP','ISUP','BootDone'),('PCVM','TBSETUP','SHUTDOWN','Error'),('PCVM','BOOTING','ISUP','BootDone'),('ALWAYSUP','ISUP','ISUP','Retry'),('PCVM','SHUTDOWN','SHUTDOWN','Retry'),('NORMAL','BOOTING','REBOOTING','Error'),('NORMALv1','BOOTING','TBSETUP','BootOK'),('NODEALLOC','RELOAD_TO_FREE','FREE_CLEAN','ReloadDone'),('NORMAL','SHUTDOWN','REBOOTING','Reboot'),('NORMAL','REBOOTED','ISUP','BootDone'),('NORMAL','BOOTING','SHUTDOWN','Error'),('NORMAL','PXEBOOTING','BOOTING','BootInfo'),('NORMALv1','PXEBOOTING','BOOTING','BootInfo'),('BATCHSTATE','POSTED','ACTIVATING','SwapIn'),('NORMAL','REBOOTING','PXEBOOTING','DHCP'),('NORMALv1','ISUP','PXEBOOTING','KernelChange'),('NODEALLOC','FREE_CLEAN','RES_INIT_CLEAN','Reserve'),('PXEKERNEL','PXEWAIT','PXEBOOTING','Retry'),('PXEKERNEL','PXEBOOTING','PXEWAIT','Free'),('PXEKERNEL','PXELIMBO','PXEBOOTING','Bootinfo-Restart'),('BATCHSTATE','ACTIVATING','SWAPPED','NonBatch'),('NORMAL','ISUP','SHUTDOWN','Reboot'),('NORMAL','REBOOTING','SHUTDOWN','Reboot'),('NORMAL','REBOOTED','REBOOTING','Error'),('NORMAL','ISUP','REBOOTING','Reboot'),('NORMAL','BOOTING','REBOOTED','BootOK'),('NORMALv2','SHUTDOWN','PXEBOOTING','DHCP'),('NORMAL','SHUTDOWN','PXEBOOTING','DHCP'),('NORMAL','REBOOTED','SHUTDOWN','Error'),('EXAMPLE','NEW','VERIFIED','Verify'),('EXAMPLE','NEW','APPROVED','Approve'),('EXAMPLE','APPROVED','READY','Verify'),('EXAMPLE','VERIFIED','READY','Approve'),('EXAMPLE','FROZEN','READY','Thaw'),('EXAMPLE','READY','FROZEN','Freeze'),('EXAMPLE','LOCKED','READY','Unlock'),('EXAMPLE','READY','LOCKED','Lock'),('EXAMPLE','FROZEN','LOCKED','Lock'),('EXAMPLE','LOCKED','FROZEN','Freeze'),('EXAMPLE','READY','APPROVED','Un-Verify'),('EXAMPLE','READY','VERIFIED','Un-Approve'),('EXAMPLE','VERIFIED','NEW','Un-Verify'),('EXAMPLE','APPROVED','NEW','Un-Approve'),('BATCHSTATE','ACTIVE','TERMINATING','SwapOut'),('BATCHSTATE','TERMINATING','SWAPPED','SwapOut'),('BATCHSTATE','SWAPPED','POSTED','RePost'),('EXPTSTATE','MODIFY_PRERUN','SWAPPED','(No)Error'),('EXPTSTATE','SWAPPED','MODIFY_PRERUN','Modify'),('EXPTSTATE','SWAPPED','TERMINATING','EndExp'),('EXPTSTATE','SWAPPING','SWAPPED','(No)Error'),('EXPTSTATE','ACTIVATING','SWAPPED','Error'),('EXPTSTATE','ACTIVE','SWAPPING','SwapOut'),('EXPTSTATE','ACTIVE','RESTARTING','Restart'),('EXPTSTATE','RESTARTING','ACTIVE','(No)Error'),('EXPTSTATE','ACTIVATING','ACTIVE','NoError'),('EXPTSTATE','QUEUED','TERMINATING','Endexp'),('EXPTSTATE','SWAPPED','QUEUED','Queue'),('EXPTSTATE','QUEUED','ACTIVATING','BatchRun'),('EXPTSTATE','QUEUED','SWAPPED','Dequeue'),('EXPTSTATE','PRERUN','QUEUED','Batch'),('EXPTSTATE','PRERUN','SWAPPED','Immediate'),('EXPTSTATE','NEW','PRERUN','Create'),('EXPTSTATE','NEW','ENDED','Endexp'),('EXPTSTATE','SWAPPED','ACTIVATING','SwapIn'),('PXEKERNEL','PXEWAKEUP','PXEBOOTING','Wokeup'),('EXPTSTATE','MODIFY_PARSE','MODIFY_RESWAP','NoError'),('EXPTSTATE','ACTIVE','MODIFY_PARSE','Modify'),('EXPTSTATE','MODIFY_RESWAP','ACTIVE','(No)Error'),('PXEKERNEL','PXEWAIT','PXEWAKEUP','NodeAlloced'),('PXEKERNEL','SHUTDOWN','PXEBOOTING','BootInfo'),('PXEKERNEL','PXEBOOTING','PXEBOOTING','Retry'),('PXEKERNEL','PXEBOOTING','BOOTING','Not Free'),('NORMALv2','RECONFIG','SHUTDOWN','ReConfigFail'),('NODEALLOC','RELOAD_PENDING','RELOAD_TO_FREE','Reload'),('PXEKERNEL','PXEWAKEUP','PXEWAKEUP','Retry'),('NORMALv2','ISUP','SHUTDOWN','Reboot'),('NORMALv2','BOOTING','SHUTDOWN','Error'),('NORMALv2','SHUTDOWN','WEDGED','Error'),('NORMALv2','BOOTING','TBSETUP','BootOK'),('NORMALv2','PXEBOOTING','BOOTING','BootInfo'),('NORMALv2','ISUP','PXEBOOTING','KernelChange'),('NORMALv2','TBSETUP','SHUTDOWN','Error'),('NORMALv2','ISUP','RECONFIG','DoReConfig'),('NORMALv2','RECONFIG','TBSETUP','ReConfig'),('NORMALv2','TBSETUP','ISUP','BootDone'),('NORMALv1','TBSETUP','SHUTDOWN','Error'),('NORMALv2','BOOTING','VNODEBOOTSTART','xencreate'),('NORMALv2','VNODEBOOTSTART','TBSETUP','realboot'),('NORMALv2','VNODEBOOTSTART','SHUTDOWN','bootfail'),('NORMALv2','BOOTING','BOOTING','vnodesetup'),('NORMALv2','SHUTDOWN','BOOTING','vnode_setup'),('RELOAD-PCVM','SHUTDOWN','SHUTDOWN','vnodereload'),('NORMAL','SHUTDOWN','SHUTDOWN','Retry'),('NETBOOT','PXEBOOTING','BOOTING','BootInfo'),('NODEALLOC','RES_INIT_CLEAN','RES_CLEAN_REBOOT','Reboot'),('NODEALLOC','RES_INIT_CLEAN','RELOAD_TO_DIRTY','Reload'),('NODEALLOC','RES_CLEAN_REBOOT','RES_WAIT_CLEAN','Rebooting'),('NODEALLOC','RELOAD_TO_DIRTY','RES_DIRTY_REBOOT','Reboot'),('NODEALLOC','RES_DIRTY_REBOOT','RES_WAIT_DIRTY','Rebooting'),('NODEALLOC','RES_WAIT_CLEAN','RES_READY','IsUp'),('NODEALLOC','RES_WAIT_DIRTY','RES_READY','IsUp'),('NODEALLOC','RES_READY','RELOAD_PENDING','Free'),('MINIMAL','BOOTING','BOOTING','DHCPRetry'),('MINIMAL','SHUTDOWN','SHUTDOWN','Retry'),('NORMALv2','TBSETUP','TBSETUP','LongSetup'),('OPSNODEBSD','ISUP','SHUTDOWN','Reboot'),('OPSNODEBSD','SHUTDOWN','TBSETUP','Booting'),('OPSNODEBSD','TBSETUP','ISUP','BootDone'),('OPSNODEBSD','ISUP','TBSETUP','Crash'),('RELOAD-MOTE','RELOADING','RELOADDONE','ReloadDone'),('RELOAD-MOTE','SHUTDOWN','RELOADING','Booting'),('NORMALv2','TBSETUP','TBFAILED','BootFail'),('NORMALv2','TBFAILED','SHUTDOWN','RebootAfterFail'),('PCVM','TBSETUP','TBFAILED','BootError'),('PCVM','TBFAILED','SHUTDOWN','Reboot'),('GARCIA-STARGATEv1','SHUTDOWN','SHUTDOWN','Retry'),('GARCIA-STARGATEv1','SHUTDOWN','TBSETUP','DHCP'),('GARCIA-STARGATEv1','SHUTDOWN','POWEROFF','PowerOff'),('GARCIA-STARGATEv1','POWEROFF','TBSETUP','PowerOn'),('GARCIA-STARGATEv1','RECONFIG','SHUTDOWN','ReConfigFail'),('GARCIA-STARGATEv1','ISUP','SHUTDOWN','Reboot'),('GARCIA-STARGATEv1','TBSETUP','SHUTDOWN','Error'),('GARCIA-STARGATEv1','ISUP','RECONFIG','DoReConfig'),('GARCIA-STARGATEv1','RECONFIG','TBSETUP','ReConfig'),('GARCIA-STARGATEv1','TBSETUP','ISUP','BootDone'),('GARCIA-STARGATEv1','TBSETUP','TBSETUP','LongSetup'),('GARCIA-STARGATEv1','TBSETUP','TBFAILED','BootFail'),('GARCIA-STARGATEv1','TBFAILED','SHUTDOWN','RebootAfterFail'),('RELOAD','RELOADSETUP','RELOADOLDMFS',''),('RELOAD','RELOADOLDMFS','SHUTDOWN',''),('RELOAD-PCVM','RELOADSETUP','RELOADING','ReloadStart'),('RELOAD-PCVM','RELOADING','RELOADDONE','ReloadDone'),('RELOAD-PCVM','RELOADDONE','SHUTDOWN','ReloadDone'),('RELOAD-PCVM','BOOTING','RELOADSETUP','ReloadSetup'),('RELOAD-PCVM','SHUTDOWN','BOOTING','Booting'),('RELOAD','BOOTING','TBSETUP','FailedBoot'),('RELOAD','TBSETUP','ISUP','FailedBoot'),('RELOAD','TBSETUP','TBFAILED','FailedBoot'),('RELOAD','ISUP','SHUTDOWN','RebootAfterFail'),('RELOAD','TBFAILED','SHUTDOWN','RebootAfterFail'),('RELOAD-PUSH','SHUTDOWN','BOOTING','Booting'),('RELOAD-PUSH','BOOTING','BOOTING','BootRetry'),('RELOAD-PUSH','RELOADSETUP','RELOADING','ReloadStart'),('RELOAD-PUSH','RELOADING','RELOADDONE','ReloadDone'),('RELOAD-PUSH','RELOADDONE','SHUTDOWN','ReloadDone'),('RELOAD-PUSH','SHUTDOWN','RELOADSETUP','ReloadSetup'),('SECUREBOOT','BOOTING','SECVIOLATION','QuoteFailed'),('SECUREBOOT','BOOTING','TPMSIGNOFF','QuoteOK'),('SECUREBOOT','BOOTING','PXEBOOTING','re-BootInfo'),('SECUREBOOT','GPXEBOOTING','PXEBOOTING','DHCP'),('SECUREBOOT','PXEBOOTING','BOOTING','BootInfo'),('SECUREBOOT','PXEBOOTING','PXEWAIT','BootInfoFree'),('SECUREBOOT','PXEWAIT','SECVIOLATION','QuoteFailed'),('SECUREBOOT','PXEWAIT','TPMSIGNOFF','QuoteOK'),('SECURELOAD','BOOTING','PXEBOOTING','re-BootInfo'),('SECURELOAD','BOOTING','RELOADSETUP','QuoteOK'),('SECURELOAD','BOOTING','SECVIOLATION','QuoteFailed'),('SECURELOAD','GPXEBOOTING','PXEBOOTING','DHCP'),('SECURELOAD','PXEBOOTING','BOOTING','BootInfo'),('SECURELOAD','RELOADDONE','SECVIOLATION','QuoteFailed'),('SECURELOAD','RELOADDONE','TPMSIGNOFF','QuoteOK'),('SECURELOAD','RELOADING','RELOADDONE','ImageOK'),('SECURELOAD','RELOADING','SECVIOLATION','ImageBad'),('SECURELOAD','RELOADSETUP','RELOADING','ReloadReady'),('SECURELOAD','SHUTDOWN','SHUTDOWN','Retry'),('SECURELOAD','SHUTDOWN','GPXEBOOTING','QuoteOK'),('SECURELOAD','SHUTDOWN','SECVIOLATION','QuoteFailed'),('PXEKERNEL','PXEWAIT','POWEROFF','Power Save'),('PXEKERNEL','POWEROFF','SHUTDOWN','Power Recovery'),('NORMAL','*','POWEROFF','Power Off'),('NORMALv1','*','POWEROFF','Power Off'),('NORMALv2','*','POWEROFF','Power Off'),('NORMAL','POWEROFF','SHUTDOWN','Power On'),('NORMALv1','POWEROFF','SHUTDOWN','Power On'),('NORMALv2','POWEROFF','SHUTDOWN','Power On'),('SECUREBOOT','SECVIOLATION','POWEROFF','Power Off'),('SECURELOAD','SECVIOLATION','POWEROFF','Power Off'),('SECUREBOOT','POWEROFF','SHUTDOWN','Power On'),('SECURELOAD','POWEROFF','SHUTDOWN','Power On'),('WIMRELOAD','SHUTDOWN','RELOADSETUP','BootOK'),('WIMRELOAD','RELOADSETUP','RELOADING','ReloadStart'),('WIMRELOAD','RELOADING','RELOADDONE','ReloadDone'),('WIMRELOAD','SHUTDOWN','SHUTDOWN','Retry'),('WIMRELOAD','SHUTDOWN','PXEBOOTING','WrongPXEboot'),('WIMRELOAD','RELOADSETUP','SHUTDOWN','Error'),('WIMRELOAD','RELOADING','SHUTDOWN','Error'),('PXEKERNEL','PXEBOOTING','REBOOTING','ForcedReboot'),('PXEFBSD','BOOTING','MFSSETUP','BootOK'),('PXEFBSD','BOOTING','SHUTDOWN','Error'),('PXEFBSD','MFSSETUP','ISUP','BootDone'),('PXEFBSD','MFSSETUP','SHUTDOWN','Error'),('PXEFBSD','ISUP','SHUTDOWN','Reboot'),('PXEFBSD','SHUTDOWN','PXEBOOTING','DHCP'),('SECURELOAD','TPMSIGNOFF','GPXEBOOTING','ReloadDone'),('SECUREBOOT','SHUTDOWN','GPXEBOOTING','QuoteOK'),('SECUREBOOT','SHUTDOWN','SECVIOLATION','QuoteFailed'),('RELOAD','RELOADSETUP','RELOADFAILED',''),('RELOAD','RELOADING','RELOADFAILED',''),('RELOAD','RELOADFAILED','SHUTDOWN',''),('RELOAD-PCVM','RELOADSETUP','RELOADFAILED',''),('RELOAD-PCVM','RELOADING','RELOADFAILED',''),('RELOAD-PCVM','RELOADFAILED','SHUTDOWN',''),('RELOAD-UE','RELOADING','RELOADDONE','ReloadDone'),('RELOAD-UE','SHUTDOWN','RELOADING','Booting'),('NORMALv2','BOOTING','PXEWAIT','MoonshotPxeWait'),('PXEKERNEL','PXEWAKEUP','SHUTDOWN','MoonshotBootDisk'),('PXEKERNEL','PXEWAKEUP','BOOTING','PxeBootWakeup');
/*!40000 ALTER TABLE `state_transitions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `state_triggers`
--

DROP TABLE IF EXISTS `state_triggers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `state_triggers` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `op_mode` varchar(20) NOT NULL DEFAULT '',
  `state` varchar(20) NOT NULL DEFAULT '',
  `trigger` tinytext NOT NULL,
  PRIMARY KEY (`node_id`,`op_mode`,`state`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `state_triggers`
--

LOCK TABLES `state_triggers` WRITE;
/*!40000 ALTER TABLE `state_triggers` DISABLE KEYS */;
INSERT INTO `state_triggers` VALUES ('*','RELOAD','RELOADDONE','RESET, RELOADDONE'),('*','RELOAD','RELOADDONEV2','RESET, RELOADDONEV2'),('*','ALWAYSUP','SHUTDOWN','ISUP'),('*','*','ISUP','RESET, CHECKPORTREG'),('*','*','PXEBOOTING','PXEBOOT'),('*','*','BOOTING','BOOTING, CHECKGENISUP'),('*','MINIMAL','ISUP','RESET'),('*','RELOAD-MOTE','RELOADDONE','RELOADDONE'),('*','OPSNODEBSD','ISUP','SCRIPT:opsreboot'),('*','NORMALv2','WEDGED','POWERCYCLE'),('*','RELOAD','RELOADOLDMFS','RELOADOLDMFS'),('*','RELOAD-PCVM','RELOADDONE','RESET, RELOADDONE'),('*','RELOAD','ISUP','REBOOT'),('*','RELOAD','TBFAILED','REBOOT'),('*','RELOAD-PUSH','RELOADDONE','RELOADDONE'),('*','*','GPXEBOOTING','SECUREBOOT'),('*','*','SECVIOLATION','POWEROFF, EMAILNOTIFY'),('*','SECUREBOOT','BOOTING',''),('*','SECUREBOOT','PXEBOOTING',''),('*','SECUREBOOT','TPMSIGNOFF','PXEBOOT'),('*','SECURELOAD','BOOTING','BOOTING'),('*','SECURELOAD','PXEBOOTING',''),('*','SECURELOAD','RELOADDONE','RESET, RELOADDONE'),('*','WIMRELOAD','RELOADDONE','PXERESET, RESET, RELOADDONE'),('*','WIMRELOAD','PXEBOOTING','REBOOT'),('*','WIMRELOAD','BOOTING','REBOOT'),('*','WIMRELOAD','ISUP','REBOOT'),('*','RELOAD-UE','RELOADDONE','RELOADDONE'),('*','NORMALv2','PXEWAIT','PXEBOOT');
/*!40000 ALTER TABLE `state_triggers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `subboss_attributes`
--

DROP TABLE IF EXISTS `subboss_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subboss_attributes` (
  `subboss_id` varchar(32) NOT NULL DEFAULT '',
  `service` varchar(20) NOT NULL DEFAULT '',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext,
  PRIMARY KEY (`subboss_id`,`service`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `subboss_attributes`
--

LOCK TABLES `subboss_attributes` WRITE;
/*!40000 ALTER TABLE `subboss_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `subboss_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `subboss_images`
--

DROP TABLE IF EXISTS `subboss_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subboss_images` (
  `subboss_id` varchar(32) NOT NULL DEFAULT '',
  `imageid` int unsigned NOT NULL DEFAULT '0',
  `load_address` text,
  `frisbee_pid` int DEFAULT '0',
  `load_busy` tinyint NOT NULL DEFAULT '0',
  `sync` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`subboss_id`,`imageid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `subboss_images`
--

LOCK TABLES `subboss_images` WRITE;
/*!40000 ALTER TABLE `subboss_images` DISABLE KEYS */;
/*!40000 ALTER TABLE `subboss_images` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `subbosses`
--

DROP TABLE IF EXISTS `subbosses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subbosses` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `service` varchar(20) NOT NULL DEFAULT '',
  `subboss_id` varchar(32) NOT NULL DEFAULT '',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`service`),
  KEY `active` (`disabled`,`subboss_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `subbosses`
--

LOCK TABLES `subbosses` WRITE;
/*!40000 ALTER TABLE `subbosses` DISABLE KEYS */;
/*!40000 ALTER TABLE `subbosses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sw_configfiles`
--

DROP TABLE IF EXISTS `sw_configfiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sw_configfiles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `node_id` varchar(32) NOT NULL,
  `connection_id` int NOT NULL DEFAULT '0',
  `file` varchar(4) NOT NULL,
  `data` text,
  `swid` varchar(20) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sw_configfiles`
--

LOCK TABLES `sw_configfiles` WRITE;
/*!40000 ALTER TABLE `sw_configfiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `sw_configfiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `switch_paths`
--

DROP TABLE IF EXISTS `switch_paths`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `switch_paths` (
  `pid` varchar(48) DEFAULT NULL,
  `eid` varchar(32) DEFAULT NULL,
  `vname` varchar(32) DEFAULT NULL,
  `node_id1` varchar(32) DEFAULT NULL,
  `node_id2` varchar(32) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `switch_paths`
--

LOCK TABLES `switch_paths` WRITE;
/*!40000 ALTER TABLE `switch_paths` DISABLE KEYS */;
/*!40000 ALTER TABLE `switch_paths` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `switch_stack_types`
--

DROP TABLE IF EXISTS `switch_stack_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `switch_stack_types` (
  `stack_id` varchar(32) NOT NULL DEFAULT '',
  `stack_type` varchar(10) DEFAULT NULL,
  `supports_private` tinyint(1) NOT NULL DEFAULT '0',
  `single_domain` tinyint(1) NOT NULL DEFAULT '1',
  `snmp_community` varchar(32) DEFAULT NULL,
  `min_vlan` int DEFAULT NULL,
  `max_vlan` int DEFAULT NULL,
  `leader` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`stack_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `switch_stack_types`
--

LOCK TABLES `switch_stack_types` WRITE;
/*!40000 ALTER TABLE `switch_stack_types` DISABLE KEYS */;
/*!40000 ALTER TABLE `switch_stack_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `switch_stacks`
--

DROP TABLE IF EXISTS `switch_stacks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `switch_stacks` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `stack_id` varchar(32) NOT NULL DEFAULT '',
  `is_primary` tinyint(1) NOT NULL DEFAULT '1',
  `snmp_community` varchar(32) DEFAULT NULL,
  `min_vlan` int DEFAULT NULL,
  `max_vlan` int DEFAULT NULL,
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `switch_stacks`
--

LOCK TABLES `switch_stacks` WRITE;
/*!40000 ALTER TABLE `switch_stacks` DISABLE KEYS */;
/*!40000 ALTER TABLE `switch_stacks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `table_regex`
--

DROP TABLE IF EXISTS `table_regex`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `table_regex` (
  `table_name` varchar(64) NOT NULL DEFAULT '',
  `column_name` varchar(64) NOT NULL DEFAULT '',
  `column_type` enum('text','int','float') DEFAULT NULL,
  `check_type` enum('regex','function','redirect') DEFAULT NULL,
  `check` tinytext NOT NULL,
  `min` int NOT NULL DEFAULT '0',
  `max` int NOT NULL DEFAULT '0',
  `comment` tinytext,
  UNIQUE KEY `table_name` (`table_name`,`column_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `table_regex`
--

LOCK TABLES `table_regex` WRITE;
/*!40000 ALTER TABLE `table_regex` DISABLE KEYS */;
INSERT INTO `table_regex` VALUES ('eventlist','pid','text','redirect','projects:pid',0,0,NULL),('eventlist','eid','text','redirect','experiments:eid',0,0,NULL),('eventlist','time','float','redirect','default:float',0,0,NULL),('eventlist','vnode','text','redirect','virt_agents:vnode',0,0,NULL),('eventlist','vname','text','regex','^[-\\w\\(\\)]+$',1,64,NULL),('eventlist','objecttype','int','redirect','default:tinyint',0,0,NULL),('eventlist','eventtype','int','redirect','default:tinyint',0,0,NULL),('eventlist','arguments','text','redirect','default:html_text',0,1024,NULL),('eventlist','atstring','text','redirect','default:html_text',0,1024,NULL),('eventlist','triggertype','int','redirect','default:tinyint',0,0,NULL),('experiments','eid','text','regex','^[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9]$',2,19,'Must ensure not too long for the database. PID is 12, and the max is 32, so the user is not allowed to specify an EID more than 19, since other parts of the system may concatenate them together with a hyphen'),('experiments','eid_idx','text','regex','^[\\d]+$',1,12,NULL),('experiments','multiplex_factor','int','redirect','default:tinyint',0,0,NULL),('experiments','forcelinkdelays','int','redirect','default:boolean',0,0,NULL),('experiments','uselinkdelays','int','redirect','default:boolean',0,0,NULL),('experiments','usewatunnels','int','redirect','default:boolean',0,0,NULL),('experiments','uselatestwadata','int','redirect','default:boolean',0,0,NULL),('experiments','wa_delay_solverweight','float','redirect','default:float',0,1024,NULL),('experiments','wa_bw_solverweight','float','redirect','default:float',0,1024,NULL),('experiments','wa_plr_solverweight','float','redirect','default:float',0,1024,NULL),('experiments','sync_server','text','redirect','virt_nodes:vname',0,0,NULL),('groups','project','text','redirect','projects:pid',0,0,NULL),('groups','pid_idx','text','redirect','projects:pid_idx',0,0,NULL),('groups','gid','text','regex','^[a-zA-Z][-\\w]+$',2,32,NULL),('groups','newgid','text','regex','^[a-zA-Z][-a-zA-Z0-9]+$',2,32,NULL),('groups','gid_idx','text','regex','^[\\d]+$',1,12,NULL),('groups','group_id','text','redirect','groups:gid',2,32,NULL),('groups','group_leader','text','redirect','users:uid',2,8,NULL),('groups','group_description','text','redirect','default:tinytext',0,256,NULL),('groups','change','text','regex','^permit$',0,0,NULL),('groups','add','text','regex','^permit$',0,0,NULL),('groups','trust','text','regex','^(user|local_root|group_root)$',0,0,NULL),('nodes','node_id','text','regex','^[-\\w]+$',1,32,NULL),('nseconfigs','pid','text','redirect','projects:pid',0,0,NULL),('nseconfigs','eid','text','redirect','experiments:eid',0,0,NULL),('nseconfigs','vname','text','redirect','virt_nodes:vname',0,0,NULL),('nseconfigs','nseconfig','text','redirect','default:fulltext',0,16777215,NULL),('project_leases','lease_id','text','redirect','virt_nodes:vname',1,32,NULL),('project_quotas','quota_id','text','regex','^[-_\\w\\.:+]+$',1,128,NULL),('project_quotas','notes','text','redirect','default:tinytext',0,256,NULL),('blockstores','node_id','text','redirect','nodes:node_id',0,0,NULL),('blockstores','bs_id','text','regex','^[-\\w]+$',1,32,NULL),('blockstores','type','text','regex','^[-\\w]+$',1,30,NULL),('projects','newuser_xml','text','regex','^[-_\\w\\.\\/:+]*$',1,256,NULL),('projects','newpid','text','regex','^[a-zA-Z][-a-zA-Z0-9]+$',2,48,NULL),('projects','head_uid','text','redirect','users:uid',0,0,NULL),('projects','name','text','redirect','default:tinytext',0,256,NULL),('projects','funders','text','redirect','default:tinytext',0,256,NULL),('projects','public','int','redirect','default:tinyint',0,1,NULL),('projects','linked_to_us','int','redirect','default:tinyint',0,1,NULL),('projects','forClass','int','redirect','default:tinyint',0,1,NULL),('projects','public_whynot','text','redirect','default:tinytext',0,256,NULL),('projects','default_user_interface','text','regex','^(emulab|plab)$',2,12,NULL),('projects','pid','text','regex','^[-\\w]+$',2,48,NULL),('projects','pid_idx','text','regex','^[\\d]+$',1,12,NULL),('projects','URL','text','redirect','default:tinytext',0,0,NULL),('projects','manager_urn','text','regex','^[-_\\w\\.\\/:+]*$',10,128,NULL),('projects','nonlocal_id','text','regex','^[-_\\w\\.\\/:+]*$',10,128,NULL),('projects','nonlocal_type','text','regex','^[-\\w]*$',1,64,NULL),('projects','nsf_funded','int','redirect','default:boolean',0,0,NULL),('projects','nsf_supplement','int','redirect','default:boolean',0,0,NULL),('projects','industry','int','redirect','default:boolean',0,0,NULL),('projects','consortium','int','redirect','default:boolean',0,0,NULL),('projects','nsf_awards','text','regex','^[-\\w,]*$',1,128,NULL),('reserved','vname','text','redirect','virt_nodes:vname',1,32,NULL),('users','manager_urn','text','regex','^[-_\\w\\.\\/:+]*$',10,128,NULL),('users','nonlocal_id','text','regex','^[-_\\w\\.\\/:+]*$',10,128,NULL),('users','nonlocal_type','text','regex','^[-\\w]*$',1,64,NULL),('users','uid','text','regex','^[a-zA-Z][\\w]+$',2,8,NULL),('users','uid_idx','text','regex','^[\\d]+$',1,12,NULL),('users','usr_phone','text','regex','^[-\\d\\(\\)\\+\\.x ]+$',7,64,NULL),('users','usr_name','text','regex','^[-\\w\\. ]+$',3,64,NULL),('users','usr_email','text','regex','^([-\\w\\+\\.]+)\\@([-\\w\\.]+)$',3,64,NULL),('users','usr_shell','text','regex','^(csh|sh|bash|tcsh|zsh)$',0,0,NULL),('users','usr_title','text','redirect','default:tinytext',0,0,NULL),('users','usr_affil','text','redirect','default:tinytext',0,0,NULL),('users','usr_affil_abbrev','text','redirect','default:tinytext',0,16,NULL),('users','usr_addr','text','redirect','default:tinytext',0,0,NULL),('users','usr_addr2','text','redirect','default:tinytext',0,0,NULL),('users','usr_state','text','redirect','default:tinytext',0,0,NULL),('users','usr_city','text','redirect','default:tinytext',0,0,NULL),('users','usr_zip','text','redirect','default:tinytext',0,0,NULL),('users','usr_country','text','redirect','default:tinytext',0,0,NULL),('users','usr_URL','text','redirect','default:tinytext',0,0,NULL),('users','usr_pswd','text','redirect','default:tinytext',0,0,NULL),('users','password1','text','redirect','default:tinytext',0,0,NULL),('users','password2','text','redirect','default:tinytext',0,0,NULL),('users','w_password1','text','redirect','default:tinytext',0,0,NULL),('users','w_password2','text','redirect','default:tinytext',0,0,NULL),('users','user_interface','text','regex','^(emulab|plab)$',0,0,NULL),('users','notes','text','redirect','default:fulltext',0,65535,NULL),('users','initial_passphrase','text','redirect','default:tinytext',0,128,NULL),('virt_address_allocation','pid','text','redirect','projects:pid',0,0,NULL),('virt_address_allocation','eid','text','redirect','experiments:eid',0,0,NULL),('virt_address_allocation','pool_id','text','redirect','default:tinytext',0,0,NULL),('virt_address_allocation','count','text','redirect','default:tinyint',0,0,NULL),('virt_address_allocation','restriction','text','regex','^(contiguous|cidr|any)$',0,0,NULL),('virt_address_allocation','version','text','regex','^(ipv4|ipv6)$',0,0,NULL),('virt_agents','pid','text','redirect','projects:pid',0,0,NULL),('virt_agents','eid','text','redirect','experiments:eid',0,0,NULL),('virt_agents','vname','text','redirect','eventlist:vname',0,0,NULL),('virt_agents','vnode','text','regex','^([-\\w]+)|(\\*{1})$',1,32,NULL),('virt_agents','objecttype','int','redirect','default:tinyint',0,0,NULL),('virt_lans','pid','text','redirect','projects:pid',0,0,NULL),('virt_lans','eid','text','redirect','experiments:eid',0,0,NULL),('virt_lans','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_lans','vindex','int','redirect','default:int',0,4098,NULL),('virt_lans','delay','float','redirect','default:float',0,0,NULL),('virt_lans','bandwidth','int','redirect','default:int',0,2147483647,NULL),('virt_lans','lossrate','float','function','_checklossrate',0,1,NULL),('virt_lans','q_limit','int','redirect','default:int',0,0,NULL),('virt_lans','q_maxthresh','int','redirect','default:int',0,0,NULL),('virt_lans','q_minthresh','int','redirect','default:int',0,0,NULL),('virt_lans','q_weight','float','redirect','default:float',0,0,NULL),('virt_lans','q_linterm','int','redirect','default:int',0,0,NULL),('virt_lans','q_qinbytes','int','redirect','default:tinyint',0,0,NULL),('virt_lans','q_bytes','int','redirect','default:tinyint',0,0,NULL),('virt_lans','q_meanpsize','int','redirect','default:int',0,0,NULL),('virt_lans','q_wait','int','redirect','default:int',0,0,NULL),('virt_lans','q_setbit','int','redirect','default:int',0,0,NULL),('virt_lans','q_droptail','int','redirect','default:int',0,0,NULL),('virt_lans','q_red','int','redirect','default:tinyint',0,0,NULL),('virt_lans','q_gentle','int','redirect','default:tinyint',0,0,NULL),('virt_lans','member','text','regex','^[-\\w]+:[\\d]+$',0,128,NULL),('virt_lans','mask','text','regex','^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$',0,15,NULL),('virt_lans','rdelay','float','redirect','virt_lans:delay',0,0,NULL),('virt_lans','rbandwidth','int','redirect','virt_lans:bandwidth',0,0,NULL),('virt_lans','rlossrate','float','function','_checklossrate',0,1,NULL),('virt_lans','cost','float','redirect','default:float',0,1,NULL),('virt_lans','widearea','int','redirect','default:boolean',0,0,NULL),('virt_lans','emulated','int','redirect','default:boolean',0,0,NULL),('virt_lans','uselinkdelay','int','redirect','default:boolean',0,0,NULL),('virt_lans','forcelinkdelay','int','redirect','default:boolean',0,0,NULL),('virt_lans','nobwshaping','int','redirect','default:boolean',0,0,NULL),('virt_lans','besteffort','int','redirect','default:boolean',0,0,NULL),('virt_lans','nointerswitch','int','redirect','default:boolean',0,0,NULL),('virt_lans','usevethiface','int','redirect','default:boolean',0,0,NULL),('virt_lans','encap_style','text','redirect','experiments:encap_style',0,0,NULL),('virt_lans','trivial_ok','int','redirect','default:boolean',0,0,NULL),('virt_lans','traced','int','redirect','default:boolean',0,0,NULL),('virt_lans','trace_type','text','regex','^(header|packet|monitor)$',0,0,NULL),('virt_lans','trace_expr','text','redirect','default:text',1,255,NULL),('virt_lans','trace_snaplen','int','redirect','default:int',0,0,NULL),('virt_lans','trace_endnode','int','redirect','default:tinyint',0,1,NULL),('virt_lans','trace_db','int','redirect','default:tinyint',0,1,NULL),('virt_lans','fixed_iface','text','redirect','default:tinytext',0,128,NULL),('virt_lans','modbase','int','redirect','default:boolean',0,0,NULL),('virt_lans','compat','int','redirect','default:boolean',0,0,NULL),('virt_lans','layer','int','redirect','default:tinyint',1,3,NULL),('virt_lans','ofenabled','int','redirect','default:boolean',0,0,NULL),('virt_lans','ofcontroller','text','regex','^tcp:(\\d+\\.+){3,3}\\d+:\\d+$',0,32,NULL),('virt_node_disks','pid','text','redirect','projects:pid',0,0,NULL),('virt_node_disks','eid','text','redirect','experiments:eid',0,0,NULL),('virt_node_disks','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_node_disks','diskname','text','regex','^[-\\w]+$',2,32,NULL),('virt_node_disks','disktype','text','regex','^[-\\w]+$',2,32,NULL),('virt_node_disks','disksize','int','redirect','default:int',0,0,NULL),('virt_node_disks','mountpoint','text','redirect','default:tinytext',1,255,NULL),('virt_node_disks','parameters','text','redirect','default:tinytext',1,255,NULL),('virt_node_disks','command','text','redirect','default:tinytext',1,255,NULL),('virt_node_attributes','pid','text','redirect','projects:pid',0,0,NULL),('virt_node_attributes','eid','text','redirect','experiments:eid',0,0,NULL),('virt_node_attributes','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_node_attributes','attrkey','text','regex','^[-\\w]+$',1,64,NULL),('virt_node_attributes','attrvalue','text','regex','^[-\\w\\.\\+,\\s\\/:]+$',0,255,NULL),('virt_node_desires','pid','text','redirect','projects:pid',0,0,NULL),('virt_node_desires','eid','text','redirect','experiments:eid',0,0,NULL),('virt_node_desires','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_node_desires','desire','text','regex','^[\\?\\*]?[\\+\\!\\&]?[-\\w?+]+$',1,64,NULL),('virt_node_desires','weight','int','redirect','default:float',0,0,NULL),('virt_nodes','pid','text','redirect','projects:pid',0,0,NULL),('virt_nodes','eid','text','redirect','experiments:eid',0,0,NULL),('virt_nodes','ips','text','regex','^(\\d{1,2}:\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3} {0,1})*$',0,2048,NULL),('virt_nodes','cmd_line','text','redirect','default:tinytext',0,0,NULL),('virt_nodes','rpms','text','regex','^([-\\w\\.\\/\\+:~]+;{0,1})*$',0,4096,NULL),('virt_nodes','deltas','text','regex','^([-\\w\\.\\/\\+]+:{0,1})*$',0,1024,NULL),('virt_nodes','startupcmd','text','redirect','default:html_tinytext',0,0,NULL),('virt_nodes','tarfiles','text','regex','^([-\\w\\.\\/\\+]+\\s+[-\\w\\.\\/\\+:~]+;{0,1})*$',0,1024,NULL),('virt_nodes','vname','text','regex','^[-\\w]+$',1,32,NULL),('virt_nodes','type','text','regex','^[-\\w]*$',0,30,NULL),('virt_nodes','failureaction','text','regex','^(fatal|nonfatal|ignore)$',0,0,NULL),('virt_nodes','routertype','text','regex','^(none|ospf|static|manual|static-ddijk|static-old)$',0,0,NULL),('virt_nodes','fixed','text','redirect','default:tinytext',0,128,NULL),('virt_nodes','sharing_mode','text','regex','^[-\\w]+$',1,32,NULL),('virt_nodes','osname','text','regex','^((([-\\w]+\\/{0,1})[-\\w\\.+]+(:\\d+){0,1})|((http|https|ftp)\\:\\/\\/[-\\w\\.\\/\\@\\:\\~\\?\\=\\&]*))$',2,128,NULL),('virt_nodes','parent_osname','text','redirect','virt_nodes:osname',2,128,NULL),('virt_nodes','nfsmounts','text','redirect','experiments:nfsmounts',0,0,NULL),('virt_nodes','rootkey_private','int','redirect','default:tinyint',0,0,NULL),('virt_nodes','rootkey_public','int','redirect','default:tinyint',0,0,NULL),('virt_programs','pid','text','redirect','projects:pid',0,0,NULL),('virt_programs','eid','text','redirect','experiments:eid',0,0,NULL),('virt_programs','vnode','text','redirect','virt_nodes:vname',0,0,NULL),('virt_programs','vname','text','regex','^[-\\w\\(\\)]+$',1,32,NULL),('virt_programs','command','text','redirect','default:html_tinytext',0,0,NULL),('virt_routes','pid','text','redirect','projects:pid',0,0,NULL),('virt_routes','eid','text','redirect','experiments:eid',0,0,NULL),('virt_routes','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_routes','src','text','regex','^(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}){0,1}$',0,32,NULL),('virt_routes','dst','text','regex','^(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})$',0,32,NULL),('virt_routes','dst_type','text','regex','^(host|net)$',0,0,NULL),('virt_routes','dst_mask','text','regex','^(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})$',1,15,NULL),('virt_routes','nexthop','text','regex','^(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})$',0,32,NULL),('virt_routes','cost','float','redirect','default:float',0,100,NULL),('virt_trafgens','pid','text','redirect','projects:pid',0,0,NULL),('virt_trafgens','eid','text','redirect','experiments:eid',0,0,NULL),('virt_trafgens','vnode','text','redirect','virt_nodes:vname',0,0,NULL),('virt_trafgens','vname','text','regex','^[-\\w\\(\\)]+$',1,32,NULL),('virt_trafgens','role','text','redirect','default:tinytext',0,0,NULL),('virt_trafgens','proto','text','redirect','default:tinytext',0,0,NULL),('virt_trafgens','port','text','redirect','default:int',0,0,NULL),('virt_trafgens','ip','text','regex','^(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})$',0,15,NULL),('virt_trafgens','target_vnode','text','redirect','virt_nodes:vname',0,0,NULL),('virt_trafgens','target_vname','text','regex','^[-\\w\\(\\)]+$',1,32,NULL),('virt_trafgens','target_port','text','redirect','virt_trafgens:port',0,0,NULL),('virt_trafgens','target_ip','text','redirect','virt_trafgens:ip',0,15,NULL),('virt_trafgens','generator','text','redirect','default:tinytext',0,0,NULL),('virt_vtypes','pid','text','redirect','projects:pid',0,0,NULL),('virt_vtypes','eid','text','redirect','experiments:eid',0,0,NULL),('virt_vtypes','name','text','regex','^[-\\w]+$',1,32,NULL),('virt_vtypes','weight','float','redirect','default:float',0,1,NULL),('virt_vtypes','members','text','regex','^( ?[-\\w]+ ?)+$',0,1024,NULL),('projects','why','text','redirect','default:fulltext',0,4096,NULL),('projects','num_members','int','redirect','default:int',0,256,NULL),('projects','num_pcs','int','redirect','default:int',0,2048,NULL),('projects','num_pcplab','int','redirect','default:int',0,2048,NULL),('projects','num_ron','int','redirect','default:int',0,1024,NULL),('experiments','encap_style','text','regex','^(alias|veth|veth-ne|vlan|vtun|egre|gre|default)$',0,0,NULL),('experiments','veth_encapsulate','int','redirect','default:boolean',0,0,NULL),('experiments','allowfixnode','int','redirect','default:boolean',0,0,NULL),('experiments','jail_osname','text','redirect','virt_nodes:osname',0,0,NULL),('experiments','delay_osname','text','redirect','virt_nodes:osname',0,0,NULL),('experiments','use_ipassign','int','redirect','default:boolean',0,0,NULL),('experiments','ipassign_args','text','regex','^[\\w\\s-]*$',0,255,NULL),('experiments','expt_name','text','redirect','default:fulltext',1,255,NULL),('experiments','dpdb','int','redirect','default:tinyint',0,1,NULL),('experiments','nonfsmounts','int','redirect','default:tinyint',0,1,NULL),('experiments','skipvlans','int','redirect','default:boolean',0,1,NULL),('experiments','nfsmounts','text','regex','^(emulabdefault|genidefault|all|none)$',0,0,NULL),('experiments','packing_strategy','text','regex','^(pack|balance)$',0,0,NULL),('experiments','description','text','redirect','default:fulltext',1,256,NULL),('experiments','idle_ignore','int','redirect','default:boolean',0,0,NULL),('experiments','swappable','int','redirect','default:boolean',0,0,NULL),('experiments','noswap_reason','text','redirect','default:tinytext',1,255,NULL),('experiments','idleswap','int','redirect','default:boolean',0,0,NULL),('experiments','idleswap_timeout','int','redirect','default:int',1,2147483647,NULL),('experiments','noidleswap_reason','text','redirect','default:tinytext',1,255,NULL),('experiments','autoswap','int','redirect','default:boolean',0,0,NULL),('experiments','autoswap_timeout','int','redirect','default:int',1,2147483647,NULL),('experiments','savedisk','int','redirect','default:boolean',0,0,NULL),('experiments','lockdown','int','redirect','default:boolean',0,0,NULL),('experiments','cpu_usage','int','redirect','default:tinyint',0,5,NULL),('experiments','mem_usage','int','redirect','default:tinyint',0,5,NULL),('experiments','batchmode','int','redirect','default:boolean',0,0,NULL),('experiments','linktest_level','int','redirect','default:tinyint',0,4,NULL),('virt_lans','protocol','text','redirect','default:tinytext',0,0,NULL),('virt_lans','is_accesspoint','int','redirect','default:boolean',0,0,NULL),('virt_lan_settings','pid','text','redirect','projects:pid',0,0,NULL),('virt_lan_settings','eid','text','redirect','experiments:eid',0,0,NULL),('virt_lan_settings','vname','text','redirect','virt_lans:vname',0,0,NULL),('virt_lan_settings','capkey','text','regex','^[-\\w]+$',1,32,NULL),('virt_lan_settings','capval','text','regex','^[-\\w\\.:+]+$',1,64,NULL),('virt_lan_member_settings','pid','text','redirect','projects:pid',0,0,NULL),('virt_lan_member_settings','eid','text','redirect','experiments:eid',0,0,NULL),('virt_lan_member_settings','vname','text','redirect','virt_lan_settings:vname',0,0,NULL),('virt_lan_member_settings','member','text','redirect','virt_lans:member',1,32,NULL),('virt_lan_member_settings','capkey','text','redirect','virt_lan_settings:capkey',0,0,NULL),('virt_lan_member_settings','capval','text','redirect','virt_lan_settings:capval',0,0,NULL),('virt_lans','est_bandwidth','int','redirect','default:int',0,2147483647,NULL),('virt_lans','rest_bandwidth','int','redirect','default:int',0,2147483647,NULL),('virt_lans','backfill','int','redirect','default:int',0,2147483647,NULL),('virt_lans','rbackfill','int','redirect','default:int',0,2147483647,NULL),('location_info','floor','text','regex','^[-\\w]+$',1,32,NULL),('location_info','building','text','regex','^[-\\w]+$',1,32,NULL),('location_info','loc_x','int','redirect','default:int',0,2048,NULL),('location_info','loc_y','int','redirect','default:int',0,2048,NULL),('location_info','contact','text','redirect','users:usr_name',0,64,NULL),('location_info','phone','text','regex','^[-\\d\\(\\)\\+\\.x ]+$',7,64,NULL),('location_info','room','text','redirect','default:tinytext',0,0,NULL),('virt_lans','vnode','text','redirect','virt_nodes:vname',0,0,NULL),('virt_lans','vport','int','redirect','default:tinyint',0,99,NULL),('virt_lans','bridge_vname','text','redirect','virt_lans:vname',0,0,NULL),('virt_lans','ip','text','regex','^(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})$',0,15,NULL),('experiments','usemodelnet','int','redirect','default:boolean',0,0,NULL),('experiments','modelnet_cores','int','redirect','default:tinyint',0,5,NULL),('experiments','modelnet_edges','int','redirect','default:tinyint',0,5,NULL),('virt_lans','mustdelay','int','redirect','default:boolean',0,0,NULL),('event_groups','pid','text','redirect','projects:pid',0,0,NULL),('event_groups','eid','text','redirect','experiments:eid',0,0,NULL),('event_groups','group_name','text','redirect','eventlist:vname',0,0,NULL),('event_groups','agent_name','text','redirect','eventlist:vname',0,0,NULL),('virt_lan_lans','pid','text','redirect','projects:pid',0,0,NULL),('virt_lan_lans','eid','text','redirect','experiments:eid',0,0,NULL),('virt_lan_lans','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_lan_lans','failureaction','text','regex','^(fatal|nonfatal)$',0,0,NULL),('firewall_rules','pid','text','redirect','projects:pid',0,0,NULL),('firewall_rules','eid','text','redirect','experimenets:eid',0,0,NULL),('firewall_rules','fwname','text','redirect','virt_nodes:vname',0,0,NULL),('firewall_rules','ruleno','int','redirect','default:int',0,50000,NULL),('firewall_rules','rule','text','regex','^\\w[-\\w \\t,/\\{\\}\\(\\)!:\\.]*$',0,1024,NULL),('virt_nodes','role','text','regex','^(node|bridge)$',0,0,NULL),('virt_nodes','inner_elab_role','text','regex','^(boss|boss\\+router|boss\\+fs\\+router|router|ops|ops\\+fs|fs|node)$',0,0,NULL),('virt_nodes','plab_role','text','regex','^(plc|node|none)$',0,0,NULL),('experiments','elab_in_elab','int','redirect','default:boolean',0,0,NULL),('experiments','elabinelab_singlenet','int','redirect','default:boolean',0,0,NULL),('experiments','elabinelab_cvstag','text','regex','^[-\\w\\@\\/\\.]+$',0,0,NULL),('images','imagename','text','regex','^[a-zA-Z0-9][-\\w\\.+]+$',2,30,NULL),('images','imageid','text','redirect','default:int',0,100000000,NULL),('images','pid','text','redirect','projects:pid',0,0,NULL),('images','gid','text','redirect','groups:gid',0,0,NULL),('images','description','text','redirect','default:fulltext',1,256,NULL),('images','loadpart','text','redirect','default:tinyint',0,4,NULL),('images','loadlength','text','redirect','default:tinyint',1,4,NULL),('images','part1_osid','text','redirect','os_info:osid',0,0,NULL),('images','part2_osid','text','redirect','os_info:osid',0,0,NULL),('images','part3_osid','text','redirect','os_info:osid',0,0,NULL),('images','part4_osid','text','redirect','os_info:osid',0,0,NULL),('images','default_osid','text','redirect','os_info:osid',0,0,NULL),('images','path','text','regex','^[-_\\w\\.\\/:+]*$',1,256,NULL),('images','shared','text','redirect','default:boolean',0,0,NULL),('images','global','text','redirect','default:boolean',0,0,NULL),('images','listed','text','redirect','default:boolean',0,0,NULL),('images','ims_noreport','text','redirect','default:boolean',0,0,NULL),('images','noexport','text','redirect','default:boolean',0,0,NULL),('images','makedefault','text','redirect','default:boolean',0,0,NULL),('images','mtype','text','redirect','default:boolean',0,0,NULL),('images','node_id','text','redirect','nodes:node_id',0,0,NULL),('images','load_address','text','redirect','default:text',0,0,NULL),('images','frisbee_pid','text','redirect','default:int',0,0,NULL),('images','metadata_url','text','redirect','default:tinytext',0,0,NULL),('images','imagefile_url','text','redirect','default:tinytext',0,0,NULL),('images','notes','text','redirect','default:fulltext',0,1024,NULL),('images','nodetype','text','redirect','node_types:node_type',0,0,NULL),('images','OS','text','redirect','os_info:OS',0,0,NULL),('images','version','text','redirect','os_info:version',0,0,NULL),('images','osfeatures','text','redirect','os_info:osfeatures',0,0,NULL),('images','op_mode','text','redirect','os_info:op_mode',0,0,NULL),('images','wholedisk','text','redirect','default:boolean',0,0,NULL),('images','mbr_version','text','redirect','default:int',0,0,NULL),('images','max_concurrent','text','redirect','default:int',0,0,NULL),('images','reboot_waittime','text','redirect','default:int',0,0,NULL),('images','format','text','regex','^[-\\w]+$',1,8,NULL),('images','hash','text','regex','^[\\w]+$',16,64,NULL),('images','deltahash','text','regex','^[\\w]+$',16,64,NULL),('images','size','int','redirect','default:bigint',0,0,NULL),('images','deltasize','int','redirect','default:bigint',0,0,NULL),('images','lba_low','int','redirect','default:bigint',0,0,NULL),('images','lba_high','int','redirect','default:bigint',0,0,NULL),('images','lba_size','int','redirect','default:int',0,0,NULL),('images','relocatable','text','redirect','default:boolean',0,0,NULL),('images','origin_uuid','text','regex','^\\w+\\-\\w+\\-\\w+\\-\\w+\\-\\w+$',0,64,NULL),('images','origin_name','text','regex','^[-\\w\\.+:\\/]+$',0,128,NULL),('images','origin_urn','text','redirect','projects:manager_urn',0,0,NULL),('images','architecture','text','regex','^[\\w,]*$',0,0,NULL),('node_types','new_type','text','redirect','default:tinytext',0,0,NULL),('node_types','node_type','text','regex','^[-\\w]+$',1,30,NULL),('node_types','class','text','regex','^[\\w]+$',1,30,NULL),('node_types','architecture','text','regex','^[\\w,]*$',0,0,NULL),('node_types','isvirtnode','text','redirect','default:boolean',0,0,NULL),('node_types','isjailed','text','redirect','default:boolean',0,0,NULL),('node_types','isswitch','text','redirect','default:boolean',0,0,NULL),('node_types','isdynamic','text','redirect','default:boolean',0,0,NULL),('node_types','isremotenode','text','redirect','default:boolean',0,0,NULL),('node_types','issubnode','text','redirect','default:boolean',0,0,NULL),('node_types','isplabdslice','text','redirect','default:boolean',0,0,NULL),('node_types','issimnode','text','redirect','default:boolean',0,0,NULL),('node_types','isgeninode','text','redirect','default:boolean',0,0,NULL),('node_types','isfednode','text','redirect','default:boolean',0,0,NULL),('node_types','attr_name','text','regex','^[-\\w]+$',1,32,NULL),('node_types','attr_osid','text','redirect','os_info:osid',0,0,NULL),('node_types','attr_imageid','text','redirect','images:imageid',0,0,NULL),('node_types','attr_boolean','int','redirect','default:boolean',0,0,NULL),('node_types','attr_integer','int','redirect','default:int',0,0,NULL),('node_types','attr_float','float','redirect','default:float',0,0,NULL),('node_types','attr_string','text','redirect','default:tinytext',0,0,NULL),('experiments','security_level','int','redirect','default:tinyuint',0,4,NULL),('experiments','elabinelab_eid','text','redirect','experiments:eid',0,0,NULL),('virt_node_startloc','pid','text','redirect','projects:pid',0,0,NULL),('virt_node_startloc','eid','text','redirect','experiments:eid',0,0,NULL),('virt_node_startloc','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_node_startloc','building','text','regex','^[-\\w]+$',1,32,NULL),('virt_node_startloc','floor','text','regex','^[-\\w]+$',1,32,NULL),('virt_node_startloc','loc_x','float','redirect','default:float',0,0,NULL),('virt_node_startloc','loc_y','float','redirect','default:float',0,0,NULL),('virt_node_startloc','orientation','float','redirect','default:float',0,0,NULL),('eventlist','parent','text','regex','^[-\\w\\(\\)]+$',1,64,NULL),('experiments','delay_capacity','int','redirect','default:tinyint',1,10,NULL),('virt_user_environment','pid','text','redirect','projects:pid',0,0,NULL),('virt_user_environment','eid','text','redirect','experiments:eid',0,0,NULL),('virt_user_environment','name','text','redirect','^[a-zA-Z][-\\w]+$',0,255,NULL),('virt_user_environment','value','text','redirect','default:text',1,512,NULL),('virt_programs','dir','text','redirect','default:tinytext',0,0,NULL),('virt_programs','timeout','int','redirect','default:int',0,0,NULL),('virt_programs','expected_exit_code','int','redirect','default:tinyint',0,0,NULL),('users','wikiname','text','regex','^[A-Z]+[a-z]+[A-Z]+[A-Za-z0-9]*$',4,64,NULL),('virt_tiptunnels','pid','text','redirect','projects:pid',0,0,NULL),('virt_tiptunnels','eid','text','redirect','experiments:eid',0,0,NULL),('virt_tiptunnels','host','text','redirect','virt_nodes:vname',0,0,NULL),('virt_tiptunnels','vnode','text','redirect','virt_nodes:vname',0,0,NULL),('virt_nodes','numeric_id','int','redirect','default:int',0,0,NULL),('virt_firewalls','pid','text','redirect','projects:pid',0,0,NULL),('virt_firewalls','eid','text','redirect','experimenets:eid',0,0,NULL),('virt_firewalls','fwname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_firewalls','type','text','regex','^(ipfw|ipfw2|iptables|ipfw2-vlan|iptables-vlan)$',0,0,NULL),('virt_firewalls','style','text','regex','^(open|closed|basic|emulab)$',0,0,NULL),('virt_nodes','firewall_style','text','regex','^(open|closed|basic|emulab)$',0,0,NULL),('mailman_lists','pid_idx','text','redirect','projects:pid_idx',0,0,NULL),('mailman_lists','password1','text','redirect','default:tinytext',0,0,NULL),('mailman_lists','password2','text','redirect','default:tinytext',0,0,NULL),('mailman_lists','fullname','text','redirect','users:usr_email',0,0,NULL),('mailman_lists','listname','text','redirect','mailman_listnames:listname',0,0,NULL),('mailman_listnames','listname','text','regex','^[-\\w\\.\\+]+$',3,64,NULL),('node_attributes','attrkey','text','regex','^[-\\w]+$',1,32,NULL),('node_attributes','attrvalue','text','regex','^[-\\w\\.\\+,\\s\\/:]+$',0,255,NULL),('archive_tags','description','text','redirect','projects:why',1,2048,NULL),('archive_tags','tag','text','regex','^[a-zA-Z][-\\w\\.\\+]+$',2,64,NULL),('experiment_templates','description','text','redirect','default:fulltext',1,4096,NULL),('experiment_templates','guid','text','regex','^[\\w]+$',1,32,NULL),('experiment_template_metadata','name','text','redirect','default:tinytext',1,64,NULL),('experiment_template_metadata','value','text','redirect','default:fulltext',0,4096,NULL),('experiment_template_metadata','metadata_type','text','regex','^[\\w]*$',1,64,NULL),('virt_parameters','pid','text','redirect','projects:pid',0,0,NULL),('virt_parameters','eid','text','redirect','experiments:eid',0,0,NULL),('virt_parameters','name','text','regex','^\\w[-\\w]+$',1,64,NULL),('virt_parameters','value','text','redirect','default:tinytext',0,256,NULL),('virt_parameters','description','text','redirect','experiment_templates:description',0,1024,NULL),('experiment_template_instance_bindings','name','text','regex','^\\w[-\\w]+$',1,64,NULL),('experiment_template_instance_bindings','value','text','redirect','default:tinytext',0,256,NULL),('experiment_runs','runid','text','redirect','experiments:eid',0,0,NULL),('experiment_runs','description','text','redirect','default:tinytext',1,256,NULL),('experiment_run_bindings','name','text','regex','^\\w[-\\w]+$',1,64,NULL),('experiment_run_bindings','value','text','redirect','default:tinytext',0,256,NULL),('experiment_template_instances','description','text','redirect','default:tinytext',1,256,NULL),('virt_node_motelog','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_node_motelog','logfileid','text','regex','^[-\\w\\.+]+$',2,45,NULL),('virt_node_motelog','pid','text','redirect','projects:pid',0,0,NULL),('virt_node_motelog','eid','text','redirect','experiments:eid',0,0,NULL),('virt_nodes','plab_plcnet','text','regex','^[\\w\\_\\d]+$',0,0,NULL),('virt_nodes','loadlist','text','regex','^[-\\w\\.+,]+$',2,256,NULL),('os_info','osid','text','regex','^[-\\w\\.+]+$',2,35,NULL),('os_info','pid','text','redirect','projects:pid',0,0,NULL),('os_info','pid_idx','text','redirect','projects:pid_idx',0,0,NULL),('os_info','osname','text','regex','^[-\\w\\.+]+$',2,30,NULL),('os_info','description','text','redirect','default:fulltext',1,256,NULL),('os_info','OS','text','regex','^[-\\w]*$',1,32,NULL),('os_info','version','text','regex','^[-\\w\\.]*$',1,12,NULL),('os_info','path','text','regex','^[-\\w\\.\\/:]*$',1,256,NULL),('os_info','magic','text','redirect','default:tinytext',0,256,NULL),('os_info','shared','int','redirect','default:tinyint',0,1,NULL),('os_info','mfs','int','redirect','default:tinyint',0,1,NULL),('os_info','mustclean','int','redirect','default:tinyint',0,1,NULL),('os_info','osfeatures','text','regex','^[-\\w,]*$',1,128,NULL),('os_info','op_mode','text','regex','^[-\\w]*$',1,20,NULL),('os_info','nextosid','text','redirect','os_info:osid',0,0,NULL),('os_info','def_parentosid','text','redirect','os_info:osid',0,0,NULL),('os_info','reboot_waittime','int','redirect','default:int',0,2000,NULL),('os_info','taint_states','text','regex','^[-\\w,]*$',1,128,NULL),('sitevariables','name','text','regex','^[\\w\\/]+$',1,255,NULL),('sitevariables','value','text','redirect','default:html_text',0,0,NULL),('sitevariables','reset','text','redirect','default:boolean',0,0,NULL),('sitevariables','defaultvalue','text','redirect','default:html_text',0,0,NULL),('sitevariables','description','text','redirect','default:html_text',0,0,NULL),('experiment_template_searches','name','text','regex','^[-\\w]*$',2,64,NULL),('user_pubkeys','verify','text','redirect','default:boolean',0,0,NULL),('user_pubkeys','user','text','redirect','users:uid',0,0,NULL),('user_pubkeys','keyfile','text','regex','^[-_\\w\\.\\/:+]*$',1,256,NULL),('virt_paths','pathname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_paths','segmentname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_paths','segmentindex','int','redirect','default:tinyuint',0,0,NULL),('virt_paths','layer','int','redirect','default:tinyint',0,0,NULL),('virt_bridges','pid','text','redirect','projects:pid',0,0,NULL),('virt_bridges','eid','text','redirect','experiments:eid',0,0,NULL),('virt_bridges','vname','text','redirect','virt_nodes:vname',0,0,NULL),('virt_bridges','vlink','text','redirect','virt_lans:vname',0,0,NULL),('virt_bridges','vport','int','redirect','default:tinyint',0,99,NULL),('virt_lans','implemented_by_path','text','redirect','virt_paths:pathname',1,128,NULL),('virt_lans','implemented_by_link','text','redirect','default:tinytext',0,0,NULL),('virt_lans','ip_aliases','text','redirect','default:tinytext',0,0,NULL),('elabinelab_attributes','role','text','regex','^(boss|router|ops|fs|node)$',0,0,NULL),('elabinelab_attributes','attrkey','text','regex','^[-\\w\\.]+$',1,32,NULL),('elabinelab_attributes','attrvalue','text','regex','^[-\\w\\.\\+,\\s\\/:\\@]+$',0,255,NULL),('elabinelab_attributes','ordering','int','redirect','default:tinyint',0,0,NULL),('images','auth_key','text','regex','^[0-9a-fA-F,]+$',0,0,NULL),('images','auth_uuid','text','regex','^[0-9a-fA-F]+$',0,0,NULL),('images','decryption_key','text','regex','^[0-9a-fA-F]+$',0,0,NULL),('images','isdataset','int','redirect','default:boolean',0,0,NULL),('experiment_blobs','path','text','redirect','default:text',0,0,NULL),('experiment_blobs','action','text','redirect','default:text',0,0,NULL),('virt_blobs','filename','text','redirect','default:tinytext',0,256,NULL),('virt_blobs','vblob_id','text','regex','^[-\\d\\w]+$',0,40,NULL),('virt_client_service_ctl','alt_vblob_id','text','regex','^[-\\d\\w]+$',0,40,NULL),('virt_client_service_ctl','eid','text','redirect','experiments:eid',0,0,NULL),('virt_client_service_ctl','enable','int','redirect','default:boolean',0,0,NULL),('virt_client_service_ctl','enable_hooks','int','redirect','default:boolean',0,0,NULL),('virt_client_service_ctl','env','text','regex','^(boot|load)$',0,0,NULL),('virt_client_service_ctl','fatal','int','redirect','default:boolean',0,0,NULL),('virt_client_service_ctl','pid','text','redirect','projects:pid',0,0,NULL),('virt_client_service_ctl','service_idx','int','redirect','default:int',0,0,NULL),('virt_client_service_ctl','vnode','text','redirect','virt_nodes:vname',0,0,NULL),('virt_client_service_ctl','whence','text','regex','^(first|every)$',0,0,NULL),('virt_client_service_hooks','argv','text','regex','^[-\\w\\s\"]*$',0,0,NULL),('virt_client_service_hooks','eid','text','redirect','experiments:eid',0,0,NULL),('virt_client_service_hooks','env','text','regex','^(boot|load)$',0,0,NULL),('virt_client_service_hooks','fatal','int','redirect','default:boolean',0,0,NULL),('virt_client_service_hooks','hook_op','text','regex','^(boot|shutdown|reconfig|reset)$',0,0,NULL),('virt_client_service_hooks','hook_point','text','regex','^(pre|post)$',0,0,NULL),('virt_client_service_hooks','hook_vblob_id','text','regex','^[-\\d\\w]+$',0,40,NULL),('virt_client_service_hooks','op','text','regex','^(boot|shutdown|reconfig|reset)$',0,0,NULL),('virt_client_service_hooks','pid','text','redirect','projects:pid',0,0,NULL),('virt_client_service_hooks','point','text','regex','^(pre|post)$',0,0,NULL),('virt_client_service_hooks','service_idx','int','redirect','default:int',0,0,NULL),('virt_client_service_hooks','vnode','text','redirect','virt_nodes:vname',0,0,NULL),('virt_client_service_hooks','whence','text','regex','^(first|every)$',0,0,NULL),('virt_blockstores','pid','text','redirect','projects:pid',0,0,NULL),('virt_blockstores','eid','text','redirect','experiments:eid',0,0,NULL),('virt_blockstores','vname','text','regex','^[-\\w]+$',1,32,NULL),('virt_blockstores','type','text','regex','^[-\\w]*$',0,30,NULL),('virt_blockstores','role','text','regex','^(remote|local|unknown)$',0,0,NULL),('virt_blockstores','size','int','redirect','default:int',0,0,NULL),('virt_blockstores','fixed','text','redirect','default:tinytext',0,128,NULL),('virt_blockstore_attributes','pid','text','redirect','projects:pid',0,0,NULL),('virt_blockstore_attributes','eid','text','redirect','experiments:eid',0,0,NULL),('virt_blockstore_attributes','vname','text','redirect','virt_blockstores:vname',0,0,NULL),('virt_blockstore_attributes','attrkey','text','regex','^[-\\w]+$',1,64,NULL),('virt_blockstore_attributes','attrvalue','text','redirect','default:tinytext',0,255,NULL),('virt_blockstore_attributes','isdesire','int','redirect','default:boolean',0,0,NULL),('emulab_sites','certificate','text','regex','^[\\012\\015\\040-\\176]*$',128,4096,NULL),('emulab_sites','url','text','redirect','default:tinytext',0,0,NULL),('emulab_sites','urn','text','regex','^[-_\\w\\.\\/:+]*$',10,255,NULL),('emulab_sites','commonname','text','redirect','default:tinytext',0,0,NULL),('emulab_sites','buildinfo','text','regex','^[-\\w\\/]*$',8,32,NULL),('emulab_sites','commithash','text','regex','^[\\w]*$',32,64,NULL),('emulab_sites','dbrev','float','redirect','default:float',0,0,NULL),('emulab_sites','install','float','redirect','default:float',0,0,NULL),('emulab_sites','os_version','text','redirect','default:tinytext',0,0,NULL),('emulab_sites','perl_version','text','redirect','default:tinytext',0,0,NULL),('emulab_sites','tbops','text','redirect','users:usr_email',0,0,NULL),('default','fulltext','text','regex','^[\\040-\\073\\075\\077-\\176\\012\\015\\011]*$',0,100000,NULL),('default','html_fulltext','text','regex','^[\\040-\\176\\012\\015\\011]*$',0,100000,NULL),('default','tinytext','text','regex','^[\\040-\\073\\075\\077-\\176]*$',0,256,NULL),('default','html_tinytext','text','regex','^[\\040-\\176]*$',0,256,NULL),('default','text','text','regex','^[\\040-\\073\\075\\077-\\176]*$',0,65535,NULL),('default','html_text','text','regex','^[\\040-\\176]*$',0,65535,NULL),('default','default','text','regex','^[\\040-\\073\\075\\077-\\176]*$',0,256,'Default regex if one is not defined for a table/slot. Allow any standard ascii character, but no binary data'),('default','tinyint','int','regex','^[-+]?[\\d]+$',-128,127,'Default regex for tiny int fields. Allow any standard ascii integer, but no binary data'),('default','boolean','int','regex','^(0|1)$',0,1,'Default regex for tiny int fields that are int booleans. Allow any 0 or 1'),('default','tinyuint','int','regex','^[\\d]+$',0,255,'Default regex for tiny int fields. Allow any standard ascii integer, but no binary data'),('default','int','int','regex','^[-+]?[\\d]+$',-2147483648,2147483647,'Default regex for int fields. Allow any standard ascii integer, but no binary data'),('default','float','float','regex','^[+-]?\\ *(\\d+(\\.\\d*)?|\\.\\d+)([eE][+-]?\\d+)?$',-2147483648,2147483647,'Default regex for float fields. Allow any digits and the decimal point'),('default','bigint','int','regex','^[-+]?[\\d]+$',0,0,'Allow any ascii 64-bit integer'),('default','tinytext_utf8','text','regex','^(?:[\\x20-\\x7E]|[\\xC2-\\xDF][\\x80-\\xBF]|\\xE0[\\xA0-\\xBF][\\x80-\\xBF]|[\\xE1-\\xEC\\xEE\\xEF][\\x80-\\xBF]{2}|\\xED[\\x80-\\x9F][\\x80-\\xBF])*$',0,256,'adopted from http://www.w3.org/International/questions/qa-forms-utf-8.en.php'),('default','text_utf8','text','regex','^(?:[\\x20-\\x7E]|[\\xC2-\\xDF][\\x80-\\xBF]|\\xE0[\\xA0-\\xBF][\\x80-\\xBF]|[\\xE1-\\xEC\\xEE\\xEF][\\x80-\\xBF]{2}|\\xED[\\x80-\\x9F][\\x80-\\xBF])*$',0,65535,'adopted from http://www.w3.org/International/questions/qa-forms-utf-8.en.php'),('default','fulltext_utf8','text','regex','^(?:[\\x09\\x0A\\x0D\\x20-\\x7E]|[\\xC2-\\xDF][\\x80-\\xBF]|\\xE0[\\xA0-\\xBF][\\x80-\\xBF]|[\\xE1-\\xEC\\xEE\\xEF][\\x80-\\xBF]{2}|\\xED[\\x80-\\x9F][\\x80-\\xBF])*$',0,65535,'adopted from http://www.w3.org/International/questions/qa-forms-utf-8.en.php'),('apt_profiles','pid','text','redirect','projects:pid',0,0,NULL),('apt_profiles','creator','text','redirect','users:uid',0,0,NULL),('apt_profiles','name','text','redirect','images:imagename',0,0,NULL),('apt_profiles','public','int','redirect','default:boolean',0,0,NULL),('apt_profiles','listed','int','redirect','default:boolean',0,0,NULL),('apt_profiles','shared','int','redirect','default:boolean',0,0,NULL),('apt_profiles','topdog','int','redirect','default:boolean',0,0,NULL),('apt_profiles','project_write','int','redirect','default:boolean',0,0,NULL),('apt_profiles','disabled','int','redirect','default:boolean',0,0,NULL),('apt_profiles','nodelete','int','redirect','default:boolean',0,0,NULL),('apt_profiles','description','text','redirect','default:html_fulltext',0,512,NULL),('apt_profiles','rspec','text','redirect','default:html_fulltext',0,262143,NULL),('apt_profiles','script','text','redirect','default:html_fulltext',0,262143,NULL),('apt_profiles','repourl','text','redirect','default:tinytext',0,0,NULL),('apt_profiles','repohash','text','regex','^[\\w]+$',0,64,NULL),('apt_profiles','portal_converted','int','redirect','default:boolean',0,0,NULL),('apt_profiles','examples_portals','text','regex','^((emulab|cloudlab|powder|phantomnet),?+){0,4}$',0,128,NULL);
/*!40000 ALTER TABLE `table_regex` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tcp_proxy`
--

DROP TABLE IF EXISTS `tcp_proxy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tcp_proxy` (
  `node_id` varchar(32) NOT NULL,
  `node_ip` varchar(15) NOT NULL,
  `node_port` int NOT NULL,
  `proxy_port` int NOT NULL,
  PRIMARY KEY (`node_id`,`node_ip`,`node_port`),
  UNIQUE KEY `proxy_port` (`proxy_port`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tcp_proxy`
--

LOCK TABLES `tcp_proxy` WRITE;
/*!40000 ALTER TABLE `tcp_proxy` DISABLE KEYS */;
/*!40000 ALTER TABLE `tcp_proxy` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `template_stamps`
--

DROP TABLE IF EXISTS `template_stamps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `template_stamps` (
  `guid` varchar(16) NOT NULL DEFAULT '',
  `vers` smallint unsigned NOT NULL DEFAULT '0',
  `id` smallint unsigned NOT NULL AUTO_INCREMENT,
  `instance` int unsigned DEFAULT NULL,
  `stamp_type` varchar(32) NOT NULL DEFAULT '',
  `modifier` varchar(32) DEFAULT NULL,
  `stamp` int unsigned DEFAULT NULL,
  `aux_type` varchar(32) DEFAULT NULL,
  `aux_data` float DEFAULT '0',
  PRIMARY KEY (`guid`,`vers`,`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `template_stamps`
--

LOCK TABLES `template_stamps` WRITE;
/*!40000 ALTER TABLE `template_stamps` DISABLE KEYS */;
/*!40000 ALTER TABLE `template_stamps` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `testbed_stats`
--

DROP TABLE IF EXISTS `testbed_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `testbed_stats` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `exptidx` int unsigned NOT NULL DEFAULT '0',
  `rsrcidx` int unsigned NOT NULL DEFAULT '0',
  `action` varchar(16) NOT NULL DEFAULT '',
  `exitcode` tinyint DEFAULT '0',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `log_session` int unsigned DEFAULT NULL,
  PRIMARY KEY (`idx`),
  KEY `rsrcidx` (`rsrcidx`),
  KEY `exptidx` (`exptidx`),
  KEY `uid_idx` (`uid_idx`),
  KEY `idxdate` (`end_time`,`idx`),
  KEY `end_time` (`end_time`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `testbed_stats`
--

LOCK TABLES `testbed_stats` WRITE;
/*!40000 ALTER TABLE `testbed_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `testbed_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `testsuite_preentables`
--

DROP TABLE IF EXISTS `testsuite_preentables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `testsuite_preentables` (
  `table_name` varchar(128) NOT NULL DEFAULT '',
  `action` enum('drop','clean','prune') DEFAULT 'drop',
  PRIMARY KEY (`table_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `testsuite_preentables`
--

LOCK TABLES `testsuite_preentables` WRITE;
/*!40000 ALTER TABLE `testsuite_preentables` DISABLE KEYS */;
INSERT INTO `testsuite_preentables` VALUES ('comments','drop'),('iface_counters','drop'),('experiment_resources','clean'),('login','drop'),('loginmessage','drop'),('node_idlestats','drop'),('nodelog','drop'),('nodeuidlastlogin','drop'),('nologins','drop'),('userslastlogin','drop'),('uidnodelastlogin','drop'),('next_reserve','clean'),('last_reservation','clean'),('current_reloads','clean'),('scheduled_reloads','clean'),('projects','prune'),('group_membership','prune'),('groups','prune'),('user_sfskeys','clean'),('user_pubkeys','clean'),('port_counters','drop'),('images','prune'),('os_info','prune'),('node_activity','clean'),('portmap','clean'),('webnews','clean'),('vis_nodes','clean'),('virt_routes','clean'),('group_stats','clean'),('project_stats','clean'),('user_stats','clean'),('experiment_stats','clean'),('testbed_stats','clean');
/*!40000 ALTER TABLE `testsuite_preentables` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tiplines`
--

DROP TABLE IF EXISTS `tiplines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tiplines` (
  `tipname` varchar(32) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `server` varchar(64) NOT NULL DEFAULT '',
  `disabled` tinyint(1) NOT NULL DEFAULT '0',
  `portnum` int NOT NULL DEFAULT '0',
  `keylen` smallint NOT NULL DEFAULT '0',
  `keydata` text,
  `urlhash` varchar(64) DEFAULT NULL,
  `urlstamp` int unsigned NOT NULL DEFAULT '0',
  `reuseurl` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`tipname`),
  KEY `node_id` (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tiplines`
--

LOCK TABLES `tiplines` WRITE;
/*!40000 ALTER TABLE `tiplines` DISABLE KEYS */;
/*!40000 ALTER TABLE `tiplines` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tipservers`
--

DROP TABLE IF EXISTS `tipservers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tipservers` (
  `server` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`server`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tipservers`
--

LOCK TABLES `tipservers` WRITE;
/*!40000 ALTER TABLE `tipservers` DISABLE KEYS */;
/*!40000 ALTER TABLE `tipservers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tmcd_redirect`
--

DROP TABLE IF EXISTS `tmcd_redirect`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tmcd_redirect` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `dbname` tinytext NOT NULL,
  PRIMARY KEY (`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tmcd_redirect`
--

LOCK TABLES `tmcd_redirect` WRITE;
/*!40000 ALTER TABLE `tmcd_redirect` DISABLE KEYS */;
/*!40000 ALTER TABLE `tmcd_redirect` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tpm_quote_values`
--

DROP TABLE IF EXISTS `tpm_quote_values`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tpm_quote_values` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `op_mode` varchar(20) NOT NULL,
  `state` varchar(20) NOT NULL,
  `pcr` int NOT NULL,
  `value` mediumtext,
  PRIMARY KEY (`node_id`,`op_mode`,`state`,`pcr`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tpm_quote_values`
--

LOCK TABLES `tpm_quote_values` WRITE;
/*!40000 ALTER TABLE `tpm_quote_values` DISABLE KEYS */;
/*!40000 ALTER TABLE `tpm_quote_values` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `traces`
--

DROP TABLE IF EXISTS `traces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `traces` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `iface0` varchar(8) NOT NULL DEFAULT '',
  `iface1` varchar(8) NOT NULL DEFAULT '',
  `pid` varchar(48) DEFAULT NULL,
  `eid` varchar(32) DEFAULT NULL,
  `exptidx` int NOT NULL DEFAULT '0',
  `linkvname` varchar(32) DEFAULT NULL,
  `vnode` varchar(32) DEFAULT NULL,
  `trace_type` tinytext,
  `trace_expr` tinytext,
  `trace_snaplen` int NOT NULL DEFAULT '0',
  `trace_db` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`idx`),
  KEY `pid` (`pid`,`eid`),
  KEY `exptidx` (`exptidx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `traces`
--

LOCK TABLES `traces` WRITE;
/*!40000 ALTER TABLE `traces` DISABLE KEYS */;
/*!40000 ALTER TABLE `traces` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `uidnodelastlogin`
--

DROP TABLE IF EXISTS `uidnodelastlogin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `uidnodelastlogin` (
  `uid` varchar(10) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `date` date DEFAULT NULL,
  `time` time DEFAULT NULL,
  PRIMARY KEY (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `uidnodelastlogin`
--

LOCK TABLES `uidnodelastlogin` WRITE;
/*!40000 ALTER TABLE `uidnodelastlogin` DISABLE KEYS */;
/*!40000 ALTER TABLE `uidnodelastlogin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `unixgroup_membership`
--

DROP TABLE IF EXISTS `unixgroup_membership`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `unixgroup_membership` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`uid`,`gid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `unixgroup_membership`
--

LOCK TABLES `unixgroup_membership` WRITE;
/*!40000 ALTER TABLE `unixgroup_membership` DISABLE KEYS */;
/*!40000 ALTER TABLE `unixgroup_membership` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_credentials`
--

DROP TABLE IF EXISTS `user_credentials`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_credentials` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `expires` datetime DEFAULT NULL,
  `credential_string` text,
  `certificate_string` text,
  PRIMARY KEY (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_credentials`
--

LOCK TABLES `user_credentials` WRITE;
/*!40000 ALTER TABLE `user_credentials` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_credentials` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_exports`
--

DROP TABLE IF EXISTS `user_exports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_exports` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `peer` varchar(64) NOT NULL DEFAULT '',
  `exported` datetime DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  PRIMARY KEY (`uid_idx`,`peer`),
  UNIQUE KEY `uidpeer` (`uid`,`peer`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_exports`
--

LOCK TABLES `user_exports` WRITE;
/*!40000 ALTER TABLE `user_exports` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_exports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_features`
--

DROP TABLE IF EXISTS `user_features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_features` (
  `feature` varchar(64) NOT NULL DEFAULT '',
  `added` datetime NOT NULL,
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid` varchar(8) NOT NULL DEFAULT '',
  PRIMARY KEY (`feature`,`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_features`
--

LOCK TABLES `user_features` WRITE;
/*!40000 ALTER TABLE `user_features` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_features` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_licenses`
--

DROP TABLE IF EXISTS `user_licenses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_licenses` (
  `uid` varchar(48) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `license_idx` int NOT NULL DEFAULT '0',
  `accepted` datetime DEFAULT NULL,
  `expiration` datetime DEFAULT NULL,
  PRIMARY KEY (`uid_idx`,`license_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_licenses`
--

LOCK TABLES `user_licenses` WRITE;
/*!40000 ALTER TABLE `user_licenses` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_licenses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_policies`
--

DROP TABLE IF EXISTS `user_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_policies` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `policy` varchar(32) NOT NULL DEFAULT '',
  `auxdata` varchar(64) NOT NULL DEFAULT '',
  `count` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`,`policy`,`auxdata`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_policies`
--

LOCK TABLES `user_policies` WRITE;
/*!40000 ALTER TABLE `user_policies` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_policies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_pubkeys`
--

DROP TABLE IF EXISTS `user_pubkeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_pubkeys` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `internal` tinyint(1) NOT NULL DEFAULT '0',
  `nodelete` tinyint(1) NOT NULL DEFAULT '0',
  `isaptkey` tinyint(1) NOT NULL DEFAULT '0',
  `pubkey` text,
  `stamp` datetime DEFAULT NULL,
  `comment` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`uid_idx`,`idx`),
  KEY `uid` (`uid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_pubkeys`
--

LOCK TABLES `user_pubkeys` WRITE;
/*!40000 ALTER TABLE `user_pubkeys` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_pubkeys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_scopus_info`
--

DROP TABLE IF EXISTS `user_scopus_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_scopus_info` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `scopus_id` varchar(32) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `validated` datetime DEFAULT NULL,
  `validation_state` enum('valid','invalid','unknown') DEFAULT 'unknown',
  `author_url` text,
  `latest_abstract_id` varchar(32) NOT NULL DEFAULT '',
  `latest_abstract_pubdate` date NOT NULL DEFAULT '0000-00-00',
  `latest_abstract_pubtype` varchar(64) NOT NULL DEFAULT '',
  `latest_abstract_pubname` text,
  `latest_abstract_doi` varchar(64) DEFAULT NULL,
  `latest_abstract_url` text,
  `latest_abstract_title` text,
  `latest_abstract_authors` text,
  `latest_abstract_cites` enum('emulab','cloudlab','phantomnet','powder') DEFAULT NULL,
  PRIMARY KEY (`uid_idx`,`scopus_id`),
  KEY `uid` (`uid`),
  KEY `scopus_id` (`scopus_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_scopus_info`
--

LOCK TABLES `user_scopus_info` WRITE;
/*!40000 ALTER TABLE `user_scopus_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_scopus_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_sfskeys`
--

DROP TABLE IF EXISTS `user_sfskeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_sfskeys` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `comment` varchar(128) NOT NULL DEFAULT '',
  `pubkey` text,
  `stamp` datetime DEFAULT NULL,
  PRIMARY KEY (`uid_idx`,`comment`),
  KEY `uid` (`uid`,`comment`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_sfskeys`
--

LOCK TABLES `user_sfskeys` WRITE;
/*!40000 ALTER TABLE `user_sfskeys` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_sfskeys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_sslcerts`
--

DROP TABLE IF EXISTS `user_sslcerts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_sslcerts` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `expires` datetime DEFAULT NULL,
  `revoked` datetime DEFAULT NULL,
  `warned` datetime DEFAULT NULL,
  `password` tinytext,
  `encrypted` tinyint(1) NOT NULL DEFAULT '0',
  `DN` text,
  `cert` text,
  `privkey` text,
  PRIMARY KEY (`idx`),
  KEY `uid` (`uid`),
  KEY `uid_idx` (`uid_idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_sslcerts`
--

LOCK TABLES `user_sslcerts` WRITE;
/*!40000 ALTER TABLE `user_sslcerts` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_sslcerts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_stats`
--

DROP TABLE IF EXISTS `user_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_stats` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid_uuid` varchar(40) NOT NULL DEFAULT '',
  `weblogin_count` int unsigned DEFAULT '0',
  `weblogin_last` datetime DEFAULT NULL,
  `exptstart_count` int unsigned DEFAULT '0',
  `exptstart_last` datetime DEFAULT NULL,
  `exptpreload_count` int unsigned DEFAULT '0',
  `exptpreload_last` datetime DEFAULT NULL,
  `exptswapin_count` int unsigned DEFAULT '0',
  `exptswapin_last` datetime DEFAULT NULL,
  `exptswapout_count` int unsigned DEFAULT '0',
  `exptswapout_last` datetime DEFAULT NULL,
  `exptswapmod_count` int unsigned DEFAULT '0',
  `exptswapmod_last` datetime DEFAULT NULL,
  `last_activity` datetime DEFAULT NULL,
  `allexpt_duration` double(14,0) unsigned DEFAULT '0',
  `allexpt_vnodes` int unsigned DEFAULT '0',
  `allexpt_vnode_duration` double(14,0) unsigned DEFAULT '0',
  `allexpt_pnodes` int unsigned DEFAULT '0',
  `allexpt_pnode_duration` double(14,0) unsigned DEFAULT '0',
  PRIMARY KEY (`uid_idx`),
  KEY `uid_uuid` (`uid_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_stats`
--

LOCK TABLES `user_stats` WRITE;
/*!40000 ALTER TABLE `user_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_token_passwords`
--

DROP TABLE IF EXISTS `user_token_passwords`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_token_passwords` (
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid` varchar(8) NOT NULL DEFAULT '',
  `subsystem` varchar(64) NOT NULL,
  `scope_type` tinytext,
  `scope_value` tinytext,
  `username` varchar(64) NOT NULL,
  `plaintext` varchar(64) NOT NULL DEFAULT '',
  `hash` varchar(64) NOT NULL,
  `issued` datetime NOT NULL,
  `expiration` datetime DEFAULT NULL,
  `token_lifetime` int unsigned NOT NULL,
  `token_onetime` tinyint(1) NOT NULL DEFAULT '0',
  `system` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`idx`),
  UNIQUE KEY `user_token` (`subsystem`,`username`,`plaintext`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_token_passwords`
--

LOCK TABLES `user_token_passwords` WRITE;
/*!40000 ALTER TABLE `user_token_passwords` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_token_passwords` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `uid_uuid` varchar(40) NOT NULL DEFAULT '',
  `usr_created` datetime DEFAULT NULL,
  `usr_expires` datetime DEFAULT NULL,
  `usr_modified` datetime DEFAULT NULL,
  `usr_name` tinytext,
  `usr_title` tinytext,
  `usr_affil` tinytext,
  `usr_affil_abbrev` varchar(16) DEFAULT NULL,
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
  `unix_uid` int unsigned NOT NULL DEFAULT '0',
  `status` enum('newuser','unapproved','unverified','active','frozen','archived','nonlocal','inactive','other') NOT NULL DEFAULT 'newuser',
  `frozen_stamp` datetime DEFAULT NULL,
  `frozen_by` varchar(8) DEFAULT NULL,
  `admin` tinyint DEFAULT '0',
  `foreign_admin` tinyint DEFAULT '0',
  `dbedit` tinyint DEFAULT '0',
  `stud` tinyint DEFAULT '0',
  `webonly` tinyint DEFAULT '0',
  `pswd_expires` date DEFAULT NULL,
  `cvsweb` tinyint NOT NULL DEFAULT '0',
  `emulab_pubkey` text,
  `home_pubkey` text,
  `adminoff` tinyint DEFAULT '0',
  `verify_key` varchar(64) DEFAULT NULL,
  `widearearoot` tinyint DEFAULT '0',
  `wideareajailroot` tinyint DEFAULT '0',
  `notes` text,
  `weblogin_frozen` tinyint unsigned NOT NULL DEFAULT '0',
  `weblogin_failcount` smallint unsigned NOT NULL DEFAULT '0',
  `weblogin_failstamp` int unsigned NOT NULL DEFAULT '0',
  `plab_user` tinyint(1) NOT NULL DEFAULT '0',
  `user_interface` enum('emulab','plab') NOT NULL DEFAULT 'emulab',
  `chpasswd_key` varchar(32) DEFAULT NULL,
  `chpasswd_expires` int unsigned NOT NULL DEFAULT '0',
  `wikiname` tinytext,
  `wikionly` tinyint(1) DEFAULT '0',
  `mailman_password` tinytext,
  `nonlocal_id` varchar(128) DEFAULT NULL,
  `nonlocal_type` tinytext,
  `manager_urn` varchar(128) DEFAULT NULL,
  `default_project` mediumint unsigned DEFAULT NULL,
  `nocollabtools` tinyint(1) DEFAULT '0',
  `initial_passphrase` varchar(128) DEFAULT NULL,
  `portal` enum('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `bound_portal` tinyint(1) DEFAULT '0',
  `require_aup` set('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `accepted_aup` set('emulab','aptlab','cloudlab','phantomnet','powder') DEFAULT NULL,
  `ga_userid` varchar(32) DEFAULT NULL,
  `portal_interface_warned` tinyint(1) NOT NULL DEFAULT '0',
  `news_read` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `affiliation_matched` tinyint(1) DEFAULT '0',
  `affiliation_updated` date NOT NULL DEFAULT '0000-00-00',
  `scopus_lastcheck` date NOT NULL DEFAULT '0000-00-00',
  `expert_mode` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`uid_idx`),
  KEY `unix_uid` (`unix_uid`),
  KEY `status` (`status`),
  KEY `uid_uuid` (`uid_uuid`),
  KEY `uid` (`uid`),
  KEY `nonlocal_id` (`nonlocal_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES ('achauhan',20001,'',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'1234','1234',20001,'newuser',NULL,NULL,1,0,0,0,0,NULL,0,NULL,NULL,0,NULL,0,0,NULL,0,0,0,0,'emulab',NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0,NULL,NULL,NULL,0,'0000-00-00 00:00:00',0,'0000-00-00','0000-00-00',0),('mshobana',20006,'',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'1234','1234',20006,'newuser',NULL,NULL,1,0,0,0,0,NULL,0,NULL,NULL,0,NULL,0,0,NULL,0,0,0,0,'emulab',NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0,NULL,NULL,NULL,0,'0000-00-00 00:00:00',0,'0000-00-00','0000-00-00',0);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `userslastlogin`
--

DROP TABLE IF EXISTS `userslastlogin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `userslastlogin` (
  `uid` varchar(10) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `date` date DEFAULT NULL,
  `time` time DEFAULT NULL,
  PRIMARY KEY (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `userslastlogin`
--

LOCK TABLES `userslastlogin` WRITE;
/*!40000 ALTER TABLE `userslastlogin` DISABLE KEYS */;
/*!40000 ALTER TABLE `userslastlogin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usrp_orders`
--

DROP TABLE IF EXISTS `usrp_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usrp_orders` (
  `order_id` varchar(32) NOT NULL DEFAULT '',
  `email` tinytext,
  `name` tinytext,
  `phone` tinytext,
  `affiliation` tinytext,
  `num_mobos` int DEFAULT '0',
  `num_dboards` int DEFAULT '0',
  `intended_use` tinytext,
  `comments` tinytext,
  `order_date` datetime DEFAULT NULL,
  `modify_date` datetime DEFAULT NULL,
  PRIMARY KEY (`order_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usrp_orders`
--

LOCK TABLES `usrp_orders` WRITE;
/*!40000 ALTER TABLE `usrp_orders` DISABLE KEYS */;
/*!40000 ALTER TABLE `usrp_orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `v2pmap`
--

DROP TABLE IF EXISTS `v2pmap`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `v2pmap` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `v2pmap`
--

LOCK TABLES `v2pmap` WRITE;
/*!40000 ALTER TABLE `v2pmap` DISABLE KEYS */;
/*!40000 ALTER TABLE `v2pmap` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `version_info`
--

DROP TABLE IF EXISTS `version_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `version_info` (
  `name` varchar(32) NOT NULL DEFAULT '',
  `value` tinytext NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `version_info`
--

LOCK TABLES `version_info` WRITE;
/*!40000 ALTER TABLE `version_info` DISABLE KEYS */;
/*!40000 ALTER TABLE `version_info` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `veth_interfaces`
--

DROP TABLE IF EXISTS `veth_interfaces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `veth_interfaces` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `veth_id` int unsigned NOT NULL AUTO_INCREMENT,
  `mac` varchar(12) NOT NULL DEFAULT '000000000000',
  `IP` varchar(15) DEFAULT NULL,
  `mask` varchar(15) DEFAULT NULL,
  `iface` varchar(10) DEFAULT NULL,
  `vnode_id` varchar(32) DEFAULT NULL,
  `rtabid` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`veth_id`),
  KEY `IP` (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `veth_interfaces`
--

LOCK TABLES `veth_interfaces` WRITE;
/*!40000 ALTER TABLE `veth_interfaces` DISABLE KEYS */;
/*!40000 ALTER TABLE `veth_interfaces` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vinterfaces`
--

DROP TABLE IF EXISTS `vinterfaces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vinterfaces` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `unit` int unsigned NOT NULL AUTO_INCREMENT,
  `mac` varchar(12) NOT NULL DEFAULT '000000000000',
  `IP` varchar(15) DEFAULT NULL,
  `mask` varchar(15) DEFAULT NULL,
  `type` enum('alias','veth','veth-ne','vlan') NOT NULL DEFAULT 'veth',
  `iface` varchar(10) DEFAULT NULL,
  `rtabid` smallint unsigned NOT NULL DEFAULT '0',
  `vnode_id` varchar(32) DEFAULT NULL,
  `exptidx` int NOT NULL DEFAULT '0',
  `virtlanidx` int NOT NULL DEFAULT '0',
  `vlanid` int NOT NULL DEFAULT '0',
  `bandwidth` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`node_id`,`unit`),
  KEY `bynode` (`node_id`,`iface`),
  KEY `type` (`type`),
  KEY `vnode_id` (`vnode_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vinterfaces`
--

LOCK TABLES `vinterfaces` WRITE;
/*!40000 ALTER TABLE `vinterfaces` DISABLE KEYS */;
/*!40000 ALTER TABLE `vinterfaces` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_address_allocation`
--

DROP TABLE IF EXISTS `virt_address_allocation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_address_allocation` (
  `pool_id` varchar(32) NOT NULL DEFAULT '',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `count` int NOT NULL DEFAULT '0',
  `restriction` enum('contiguous','cidr','any') NOT NULL DEFAULT 'any',
  `version` enum('ipv4','ipv6') NOT NULL DEFAULT 'ipv4',
  PRIMARY KEY (`exptidx`,`pool_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_address_allocation`
--

LOCK TABLES `virt_address_allocation` WRITE;
/*!40000 ALTER TABLE `virt_address_allocation` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_address_allocation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_agents`
--

DROP TABLE IF EXISTS `virt_agents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_agents` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(64) NOT NULL DEFAULT '',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `objecttype` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`,`vnode`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_agents`
--

LOCK TABLES `virt_agents` WRITE;
/*!40000 ALTER TABLE `virt_agents` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_agents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_blobs`
--

DROP TABLE IF EXISTS `virt_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_blobs` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vblob_id` varchar(40) NOT NULL DEFAULT '',
  `filename` tinytext,
  PRIMARY KEY (`exptidx`,`vblob_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_blobs`
--

LOCK TABLES `virt_blobs` WRITE;
/*!40000 ALTER TABLE `virt_blobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_blobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_blockstore_attributes`
--

DROP TABLE IF EXISTS `virt_blockstore_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_blockstore_attributes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `attrkey` varchar(32) NOT NULL DEFAULT '',
  `attrvalue` tinytext NOT NULL,
  `attrtype` enum('integer','float','boolean','string') DEFAULT 'string',
  `isdesire` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_blockstore_attributes`
--

LOCK TABLES `virt_blockstore_attributes` WRITE;
/*!40000 ALTER TABLE `virt_blockstore_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_blockstore_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_blockstores`
--

DROP TABLE IF EXISTS `virt_blockstores`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_blockstores` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `type` varchar(30) DEFAULT NULL,
  `role` enum('remote','local','unknown') NOT NULL DEFAULT 'unknown',
  `size` int unsigned NOT NULL DEFAULT '0',
  `fixed` text NOT NULL,
  PRIMARY KEY (`exptidx`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_blockstores`
--

LOCK TABLES `virt_blockstores` WRITE;
/*!40000 ALTER TABLE `virt_blockstores` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_blockstores` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_bridges`
--

DROP TABLE IF EXISTS `virt_bridges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_bridges` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `vlink` varchar(32) NOT NULL DEFAULT '',
  `vport` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`,`vlink`,`vport`),
  KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_bridges`
--

LOCK TABLES `virt_bridges` WRITE;
/*!40000 ALTER TABLE `virt_bridges` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_bridges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_client_service_ctl`
--

DROP TABLE IF EXISTS `virt_client_service_ctl`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_client_service_ctl` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `service_idx` int NOT NULL DEFAULT '0',
  `env` enum('load','boot') NOT NULL DEFAULT 'boot',
  `whence` enum('first','every') NOT NULL DEFAULT 'every',
  `alt_vblob_id` varchar(40) NOT NULL DEFAULT '',
  `enable` tinyint(1) NOT NULL DEFAULT '1',
  `enable_hooks` tinyint(1) NOT NULL DEFAULT '1',
  `fatal` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`exptidx`,`vnode`,`service_idx`,`env`,`whence`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_client_service_ctl`
--

LOCK TABLES `virt_client_service_ctl` WRITE;
/*!40000 ALTER TABLE `virt_client_service_ctl` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_client_service_ctl` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_client_service_hooks`
--

DROP TABLE IF EXISTS `virt_client_service_hooks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_client_service_hooks` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `service_idx` int NOT NULL DEFAULT '0',
  `env` enum('load','boot') NOT NULL DEFAULT 'boot',
  `whence` enum('first','every') NOT NULL DEFAULT 'every',
  `hook_vblob_id` varchar(40) NOT NULL DEFAULT '',
  `hook_op` enum('boot','shutdown','reconfig','reset') NOT NULL DEFAULT 'boot',
  `hook_point` enum('pre','post') NOT NULL DEFAULT 'post',
  `argv` varchar(255) NOT NULL DEFAULT '',
  `fatal` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vnode`,`service_idx`,`env`,`whence`,`hook_vblob_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_client_service_hooks`
--

LOCK TABLES `virt_client_service_hooks` WRITE;
/*!40000 ALTER TABLE `virt_client_service_hooks` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_client_service_hooks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_client_service_opts`
--

DROP TABLE IF EXISTS `virt_client_service_opts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_client_service_opts` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `opt_name` varchar(32) NOT NULL DEFAULT '',
  `opt_value` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`vnode`,`opt_name`,`opt_value`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_client_service_opts`
--

LOCK TABLES `virt_client_service_opts` WRITE;
/*!40000 ALTER TABLE `virt_client_service_opts` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_client_service_opts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_firewalls`
--

DROP TABLE IF EXISTS `virt_firewalls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_firewalls` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `fwname` varchar(32) NOT NULL DEFAULT '',
  `type` enum('ipfw','ipfw2','iptables','ipfw2-vlan','iptables-vlan') NOT NULL DEFAULT 'ipfw',
  `style` enum('open','closed','basic','emulab') NOT NULL DEFAULT 'basic',
  `log` tinytext NOT NULL,
  PRIMARY KEY (`exptidx`,`fwname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`fwname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_firewalls`
--

LOCK TABLES `virt_firewalls` WRITE;
/*!40000 ALTER TABLE `virt_firewalls` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_firewalls` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_lan_lans`
--

DROP TABLE IF EXISTS `virt_lan_lans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_lan_lans` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `idx` int NOT NULL AUTO_INCREMENT,
  `vname` varchar(32) NOT NULL DEFAULT '',
  `failureaction` enum('fatal','nonfatal') NOT NULL DEFAULT 'fatal',
  PRIMARY KEY (`exptidx`,`idx`),
  UNIQUE KEY `vname` (`pid`,`eid`,`vname`),
  UNIQUE KEY `idx` (`pid`,`eid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_lan_lans`
--

LOCK TABLES `virt_lan_lans` WRITE;
/*!40000 ALTER TABLE `virt_lan_lans` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_lan_lans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_lan_member_settings`
--

DROP TABLE IF EXISTS `virt_lan_member_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_lan_member_settings` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `member` varchar(32) NOT NULL DEFAULT '',
  `capkey` varchar(32) NOT NULL DEFAULT '',
  `capval` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`vname`,`member`,`capkey`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`member`,`capkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_lan_member_settings`
--

LOCK TABLES `virt_lan_member_settings` WRITE;
/*!40000 ALTER TABLE `virt_lan_member_settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_lan_member_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_lan_settings`
--

DROP TABLE IF EXISTS `virt_lan_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_lan_settings` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `capkey` varchar(32) NOT NULL DEFAULT '',
  `capval` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`vname`,`capkey`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`capkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_lan_settings`
--

LOCK TABLES `virt_lan_settings` WRITE;
/*!40000 ALTER TABLE `virt_lan_settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_lan_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_lans`
--

DROP TABLE IF EXISTS `virt_lans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_lans` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `vport` tinyint NOT NULL DEFAULT '0',
  `vindex` int NOT NULL DEFAULT '-1',
  `ip` varchar(15) NOT NULL DEFAULT '',
  `delay` float(10,2) DEFAULT '0.00',
  `bandwidth` int unsigned DEFAULT NULL,
  `backfill` int unsigned DEFAULT '0',
  `est_bandwidth` int unsigned DEFAULT NULL,
  `lossrate` float(10,8) DEFAULT NULL,
  `q_limit` int DEFAULT '0',
  `q_maxthresh` int DEFAULT '0',
  `q_minthresh` int DEFAULT '0',
  `q_weight` float DEFAULT '0',
  `q_linterm` int DEFAULT '0',
  `q_qinbytes` tinyint DEFAULT '0',
  `q_bytes` tinyint DEFAULT '0',
  `q_meanpsize` int DEFAULT '0',
  `q_wait` int DEFAULT '0',
  `q_setbit` int DEFAULT '0',
  `q_droptail` int DEFAULT '0',
  `q_red` tinyint DEFAULT '0',
  `q_gentle` tinyint DEFAULT '0',
  `member` text,
  `mask` varchar(15) DEFAULT '255.255.255.0',
  `rdelay` float(10,2) DEFAULT NULL,
  `rbandwidth` int unsigned DEFAULT NULL,
  `rbackfill` int unsigned DEFAULT '0',
  `rest_bandwidth` int unsigned DEFAULT NULL,
  `rlossrate` float(10,8) DEFAULT NULL,
  `cost` float NOT NULL DEFAULT '1',
  `widearea` tinyint DEFAULT '0',
  `emulated` tinyint DEFAULT '0',
  `uselinkdelay` tinyint DEFAULT '0',
  `forcelinkdelay` tinyint(1) DEFAULT '0',
  `nobwshaping` tinyint DEFAULT '0',
  `besteffort` tinyint(1) DEFAULT '0',
  `nointerswitch` tinyint(1) DEFAULT '0',
  `mustdelay` tinyint(1) DEFAULT '0',
  `usevethiface` tinyint DEFAULT '0',
  `encap_style` enum('alias','veth','veth-ne','vlan','vtun','egre','gre','default') NOT NULL DEFAULT 'default',
  `trivial_ok` tinyint DEFAULT '1',
  `protocol` varchar(30) NOT NULL DEFAULT 'ethernet',
  `is_accesspoint` tinyint DEFAULT '0',
  `traced` tinyint(1) DEFAULT '0',
  `trace_type` enum('header','packet','monitor') NOT NULL DEFAULT 'header',
  `trace_expr` tinytext,
  `trace_snaplen` int NOT NULL DEFAULT '0',
  `trace_endnode` tinyint(1) NOT NULL DEFAULT '0',
  `trace_db` tinyint(1) NOT NULL DEFAULT '0',
  `fixed_iface` varchar(128) DEFAULT '',
  `layer` tinyint NOT NULL DEFAULT '2',
  `implemented_by_path` tinytext,
  `implemented_by_link` tinytext,
  `ip_aliases` tinytext,
  `ofenabled` tinyint(1) DEFAULT '0',
  `ofcontroller` tinytext,
  `bridge_vname` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`exptidx`,`vname`,`vnode`,`vport`),
  UNIQUE KEY `vport` (`pid`,`eid`,`vname`,`vnode`,`vport`),
  KEY `pid` (`pid`,`eid`,`vname`),
  KEY `vnode` (`pid`,`eid`,`vnode`),
  KEY `pideid` (`pid`,`eid`,`vname`,`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_lans`
--

LOCK TABLES `virt_lans` WRITE;
/*!40000 ALTER TABLE `virt_lans` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_lans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_node_attributes`
--

DROP TABLE IF EXISTS `virt_node_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_node_attributes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `attrkey` varchar(64) NOT NULL DEFAULT '',
  `attrvalue` tinytext,
  PRIMARY KEY (`exptidx`,`vname`,`attrkey`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`attrkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_node_attributes`
--

LOCK TABLES `virt_node_attributes` WRITE;
/*!40000 ALTER TABLE `virt_node_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_node_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_node_desires`
--

DROP TABLE IF EXISTS `virt_node_desires`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_node_desires` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `desire` varchar(64) NOT NULL DEFAULT '',
  `weight` float DEFAULT NULL,
  PRIMARY KEY (`exptidx`,`vname`,`desire`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`desire`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_node_desires`
--

LOCK TABLES `virt_node_desires` WRITE;
/*!40000 ALTER TABLE `virt_node_desires` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_node_desires` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_node_disks`
--

DROP TABLE IF EXISTS `virt_node_disks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_node_disks` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `diskname` varchar(32) NOT NULL DEFAULT '',
  `disktype` varchar(32) NOT NULL DEFAULT '',
  `disksize` int unsigned NOT NULL DEFAULT '0',
  `mountpoint` tinytext,
  `parameters` tinytext,
  `command` tinytext,
  PRIMARY KEY (`exptidx`,`vname`,`diskname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`diskname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_node_disks`
--

LOCK TABLES `virt_node_disks` WRITE;
/*!40000 ALTER TABLE `virt_node_disks` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_node_disks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_node_motelog`
--

DROP TABLE IF EXISTS `virt_node_motelog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_node_motelog` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `logfileid` varchar(45) NOT NULL DEFAULT '',
  PRIMARY KEY (`pid`,`eid`,`vname`,`logfileid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_node_motelog`
--

LOCK TABLES `virt_node_motelog` WRITE;
/*!40000 ALTER TABLE `virt_node_motelog` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_node_motelog` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_node_public_addr`
--

DROP TABLE IF EXISTS `virt_node_public_addr`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_node_public_addr` (
  `IP` varchar(15) NOT NULL DEFAULT '',
  `mask` varchar(15) DEFAULT NULL,
  `node_id` varchar(32) DEFAULT NULL,
  `pool_id` varchar(32) DEFAULT NULL,
  `pid` varchar(48) DEFAULT NULL,
  `eid` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_node_public_addr`
--

LOCK TABLES `virt_node_public_addr` WRITE;
/*!40000 ALTER TABLE `virt_node_public_addr` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_node_public_addr` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_node_startloc`
--

DROP TABLE IF EXISTS `virt_node_startloc`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_node_startloc` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `building` varchar(32) NOT NULL DEFAULT '',
  `floor` varchar(32) NOT NULL DEFAULT '',
  `loc_x` float NOT NULL DEFAULT '0',
  `loc_y` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_node_startloc`
--

LOCK TABLES `virt_node_startloc` WRITE;
/*!40000 ALTER TABLE `virt_node_startloc` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_node_startloc` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_nodes`
--

DROP TABLE IF EXISTS `virt_nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_nodes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `ips` text,
  `osname` varchar(128) DEFAULT NULL,
  `loadlist` text,
  `parent_osname` varchar(128) DEFAULT NULL,
  `cmd_line` text,
  `rpms` text,
  `deltas` text,
  `startupcmd` tinytext,
  `tarfiles` text,
  `vname` varchar(32) NOT NULL DEFAULT '',
  `type` varchar(30) DEFAULT NULL,
  `failureaction` enum('fatal','nonfatal','ignore') NOT NULL DEFAULT 'fatal',
  `routertype` enum('none','ospf','static','manual','static-ddijk','static-old') NOT NULL DEFAULT 'none',
  `fixed` text NOT NULL,
  `inner_elab_role` tinytext,
  `plab_role` enum('plc','node','none') NOT NULL DEFAULT 'none',
  `plab_plcnet` varchar(32) NOT NULL DEFAULT 'none',
  `numeric_id` int DEFAULT NULL,
  `sharing_mode` varchar(32) DEFAULT NULL,
  `role` enum('node','bridge') NOT NULL DEFAULT 'node',
  `firewall_style` tinytext,
  `firewall_log` tinytext,
  `nfsmounts` enum('emulabdefault','genidefault','all','none') DEFAULT NULL,
  `rootkey_private` tinyint(1) NOT NULL DEFAULT '0',
  `rootkey_public` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`),
  KEY `pid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_nodes`
--

LOCK TABLES `virt_nodes` WRITE;
/*!40000 ALTER TABLE `virt_nodes` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_parameters`
--

DROP TABLE IF EXISTS `virt_parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_parameters` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL DEFAULT '',
  `value` tinytext,
  `description` text,
  PRIMARY KEY (`exptidx`,`name`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_parameters`
--

LOCK TABLES `virt_parameters` WRITE;
/*!40000 ALTER TABLE `virt_parameters` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_parameters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_paths`
--

DROP TABLE IF EXISTS `virt_paths`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_paths` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `pathname` varchar(32) NOT NULL DEFAULT '',
  `segmentname` varchar(32) NOT NULL DEFAULT '',
  `segmentindex` tinyint unsigned NOT NULL DEFAULT '0',
  `layer` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`pathname`,`segmentname`),
  UNIQUE KEY `segidx` (`exptidx`,`pathname`,`segmentindex`),
  KEY `pid` (`pid`,`eid`,`pathname`),
  KEY `pideid` (`pid`,`eid`,`pathname`,`segmentname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_paths`
--

LOCK TABLES `virt_paths` WRITE;
/*!40000 ALTER TABLE `virt_paths` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_paths` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_profile_parameters`
--

DROP TABLE IF EXISTS `virt_profile_parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_profile_parameters` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL,
  `value` text NOT NULL,
  PRIMARY KEY (`exptidx`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_profile_parameters`
--

LOCK TABLES `virt_profile_parameters` WRITE;
/*!40000 ALTER TABLE `virt_profile_parameters` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_profile_parameters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_programs`
--

DROP TABLE IF EXISTS `virt_programs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_programs` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `command` tinytext,
  `dir` tinytext,
  `timeout` int unsigned DEFAULT NULL,
  `expected_exit_code` tinyint unsigned DEFAULT NULL,
  PRIMARY KEY (`exptidx`,`vnode`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vnode`,`vname`),
  KEY `vnode` (`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_programs`
--

LOCK TABLES `virt_programs` WRITE;
/*!40000 ALTER TABLE `virt_programs` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_programs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_routes`
--

DROP TABLE IF EXISTS `virt_routes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_routes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `src` varchar(32) NOT NULL DEFAULT '',
  `dst` varchar(32) NOT NULL DEFAULT '',
  `dst_type` enum('host','net') NOT NULL DEFAULT 'host',
  `dst_mask` varchar(15) DEFAULT '255.255.255.0',
  `nexthop` varchar(32) NOT NULL DEFAULT '',
  `cost` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`,`src`,`dst`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`,`src`,`dst`),
  KEY `pid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_routes`
--

LOCK TABLES `virt_routes` WRITE;
/*!40000 ALTER TABLE `virt_routes` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_routes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_simnode_attributes`
--

DROP TABLE IF EXISTS `virt_simnode_attributes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_simnode_attributes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `nodeweight` smallint unsigned NOT NULL DEFAULT '1',
  `eventrate` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_simnode_attributes`
--

LOCK TABLES `virt_simnode_attributes` WRITE;
/*!40000 ALTER TABLE `virt_simnode_attributes` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_simnode_attributes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_tiptunnels`
--

DROP TABLE IF EXISTS `virt_tiptunnels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_tiptunnels` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `host` varchar(32) NOT NULL DEFAULT '',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`exptidx`,`host`,`vnode`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`host`,`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_tiptunnels`
--

LOCK TABLES `virt_tiptunnels` WRITE;
/*!40000 ALTER TABLE `virt_tiptunnels` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_tiptunnels` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_trafgens`
--

DROP TABLE IF EXISTS `virt_trafgens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_trafgens` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vnode` varchar(32) NOT NULL DEFAULT '',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `role` tinytext NOT NULL,
  `proto` tinytext NOT NULL,
  `port` int NOT NULL DEFAULT '0',
  `ip` varchar(15) NOT NULL DEFAULT '',
  `target_vnode` varchar(32) NOT NULL DEFAULT '',
  `target_vname` varchar(32) NOT NULL DEFAULT '',
  `target_port` int NOT NULL DEFAULT '0',
  `target_ip` varchar(15) NOT NULL DEFAULT '',
  `generator` tinytext NOT NULL,
  PRIMARY KEY (`exptidx`,`vnode`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vnode`,`vname`),
  KEY `vnode` (`vnode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_trafgens`
--

LOCK TABLES `virt_trafgens` WRITE;
/*!40000 ALTER TABLE `virt_trafgens` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_trafgens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_user_environment`
--

DROP TABLE IF EXISTS `virt_user_environment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_user_environment` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `idx` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `value` text,
  PRIMARY KEY (`exptidx`,`idx`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_user_environment`
--

LOCK TABLES `virt_user_environment` WRITE;
/*!40000 ALTER TABLE `virt_user_environment` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_user_environment` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `virt_vtypes`
--

DROP TABLE IF EXISTS `virt_vtypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `virt_vtypes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `name` varchar(32) NOT NULL DEFAULT '',
  `weight` float(7,5) NOT NULL DEFAULT '0.00000',
  `members` text,
  PRIMARY KEY (`exptidx`,`name`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `virt_vtypes`
--

LOCK TABLES `virt_vtypes` WRITE;
/*!40000 ALTER TABLE `virt_vtypes` DISABLE KEYS */;
/*!40000 ALTER TABLE `virt_vtypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vis_graphs`
--

DROP TABLE IF EXISTS `vis_graphs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vis_graphs` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `zoom` decimal(8,3) NOT NULL DEFAULT '0.000',
  `detail` tinyint NOT NULL DEFAULT '0',
  `image` mediumblob,
  PRIMARY KEY (`exptidx`),
  UNIQUE KEY `pideid` (`pid`,`eid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vis_graphs`
--

LOCK TABLES `vis_graphs` WRITE;
/*!40000 ALTER TABLE `vis_graphs` DISABLE KEYS */;
/*!40000 ALTER TABLE `vis_graphs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vis_nodes`
--

DROP TABLE IF EXISTS `vis_nodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vis_nodes` (
  `pid` varchar(48) NOT NULL DEFAULT '',
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `vname` varchar(32) NOT NULL DEFAULT '',
  `vis_type` varchar(10) NOT NULL DEFAULT '',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`exptidx`,`vname`),
  UNIQUE KEY `pideid` (`pid`,`eid`,`vname`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vis_nodes`
--

LOCK TABLES `vis_nodes` WRITE;
/*!40000 ALTER TABLE `vis_nodes` DISABLE KEYS */;
/*!40000 ALTER TABLE `vis_nodes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vlans`
--

DROP TABLE IF EXISTS `vlans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vlans` (
  `eid` varchar(32) NOT NULL DEFAULT '',
  `exptidx` int NOT NULL DEFAULT '0',
  `pid` varchar(48) NOT NULL DEFAULT '',
  `virtual` varchar(64) DEFAULT NULL,
  `members` text NOT NULL,
  `switchpath` text,
  `id` int NOT NULL AUTO_INCREMENT,
  `tag` smallint NOT NULL DEFAULT '0',
  `stack` varchar(32) DEFAULT NULL,
  `class` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `pid` (`pid`,`eid`,`virtual`),
  KEY `exptidx` (`exptidx`,`virtual`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vlans`
--

LOCK TABLES `vlans` WRITE;
/*!40000 ALTER TABLE `vlans` DISABLE KEYS */;
/*!40000 ALTER TABLE `vlans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `vlantag_history`
--

DROP TABLE IF EXISTS `vlantag_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vlantag_history` (
  `history_id` int unsigned NOT NULL AUTO_INCREMENT,
  `tag` smallint NOT NULL DEFAULT '0',
  `lanid` int NOT NULL DEFAULT '0',
  `lanname` varchar(64) NOT NULL DEFAULT '',
  `exptidx` int unsigned DEFAULT NULL,
  `allocated` int unsigned DEFAULT NULL,
  `released` int unsigned DEFAULT NULL,
  PRIMARY KEY (`history_id`),
  KEY `tag` (`tag`,`history_id`),
  KEY `exptidx` (`exptidx`),
  KEY `lanid` (`lanid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `vlantag_history`
--

LOCK TABLES `vlantag_history` WRITE;
/*!40000 ALTER TABLE `vlantag_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `vlantag_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `web_sessions`
--

DROP TABLE IF EXISTS `web_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `web_sessions` (
  `session_id` varchar(128) NOT NULL DEFAULT '',
  `session_expires` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `session_data` text,
  PRIMARY KEY (`session_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `web_sessions`
--

LOCK TABLES `web_sessions` WRITE;
/*!40000 ALTER TABLE `web_sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `web_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `web_tasks`
--

DROP TABLE IF EXISTS `web_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `web_tasks` (
  `task_id` varchar(128) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `exited` datetime DEFAULT NULL,
  `process_id` int DEFAULT '0',
  `object_uuid` varchar(40) NOT NULL DEFAULT '',
  `exitcode` int DEFAULT '0',
  `task_data` mediumtext,
  PRIMARY KEY (`task_id`),
  KEY `object_uuid` (`object_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `web_tasks`
--

LOCK TABLES `web_tasks` WRITE;
/*!40000 ALTER TABLE `web_tasks` DISABLE KEYS */;
/*!40000 ALTER TABLE `web_tasks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `webcams`
--

DROP TABLE IF EXISTS `webcams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `webcams` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `server` varchar(64) NOT NULL DEFAULT '',
  `last_update` datetime DEFAULT NULL,
  `URL` tinytext,
  `stillimage_URL` tinytext,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `webcams`
--

LOCK TABLES `webcams` WRITE;
/*!40000 ALTER TABLE `webcams` DISABLE KEYS */;
/*!40000 ALTER TABLE `webcams` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `webdb_table_permissions`
--

DROP TABLE IF EXISTS `webdb_table_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `webdb_table_permissions` (
  `table_name` varchar(64) NOT NULL DEFAULT '',
  `allow_read` tinyint(1) DEFAULT '1',
  `allow_row_add_edit` tinyint(1) DEFAULT '0',
  `allow_row_delete` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`table_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `webdb_table_permissions`
--

LOCK TABLES `webdb_table_permissions` WRITE;
/*!40000 ALTER TABLE `webdb_table_permissions` DISABLE KEYS */;
INSERT INTO `webdb_table_permissions` VALUES ('comments',1,1,1),('foreign_keys',1,1,1),('images',1,0,1),('interfaces',1,1,1),('interface_types',1,1,1),('lastlogin',1,1,1),('nodes',1,1,0),('node_types',1,1,0),('tiplines',1,1,1),('os_info',1,1,1),('projects',1,1,0),('osidtoimageid',1,0,1),('table_regex',1,1,1);
/*!40000 ALTER TABLE `webdb_table_permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `webnews`
--

DROP TABLE IF EXISTS `webnews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `webnews` (
  `msgid` int NOT NULL AUTO_INCREMENT,
  `subject` tinytext,
  `date` datetime DEFAULT NULL,
  `author` varchar(32) DEFAULT NULL,
  `author_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `body` text,
  `archived` tinyint(1) NOT NULL DEFAULT '0',
  `archived_date` datetime DEFAULT NULL,
  PRIMARY KEY (`msgid`),
  KEY `date` (`date`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `webnews`
--

LOCK TABLES `webnews` WRITE;
/*!40000 ALTER TABLE `webnews` DISABLE KEYS */;
/*!40000 ALTER TABLE `webnews` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `webnews_protogeni`
--

DROP TABLE IF EXISTS `webnews_protogeni`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `webnews_protogeni` (
  `msgid` int NOT NULL AUTO_INCREMENT,
  `subject` tinytext,
  `date` datetime DEFAULT NULL,
  `author` varchar(32) DEFAULT NULL,
  `author_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `body` text,
  `archived` tinyint(1) NOT NULL DEFAULT '0',
  `archived_date` datetime DEFAULT NULL,
  PRIMARY KEY (`msgid`),
  KEY `date` (`date`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `webnews_protogeni`
--

LOCK TABLES `webnews_protogeni` WRITE;
/*!40000 ALTER TABLE `webnews_protogeni` DISABLE KEYS */;
/*!40000 ALTER TABLE `webnews_protogeni` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `widearea_accounts`
--

DROP TABLE IF EXISTS `widearea_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `widearea_accounts` (
  `uid` varchar(8) NOT NULL DEFAULT '',
  `uid_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `trust` enum('none','user','local_root') DEFAULT NULL,
  `date_applied` date DEFAULT NULL,
  `date_approved` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`,`node_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `widearea_accounts`
--

LOCK TABLES `widearea_accounts` WRITE;
/*!40000 ALTER TABLE `widearea_accounts` DISABLE KEYS */;
/*!40000 ALTER TABLE `widearea_accounts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `widearea_delays`
--

DROP TABLE IF EXISTS `widearea_delays`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `widearea_delays` (
  `time` double DEFAULT NULL,
  `node_id1` varchar(32) NOT NULL DEFAULT '',
  `iface1` varchar(10) NOT NULL DEFAULT '',
  `node_id2` varchar(32) NOT NULL DEFAULT '',
  `iface2` varchar(10) NOT NULL DEFAULT '',
  `bandwidth` double DEFAULT NULL,
  `time_stddev` float NOT NULL DEFAULT '0',
  `lossrate` float NOT NULL DEFAULT '0',
  `start_time` int unsigned DEFAULT NULL,
  `end_time` int unsigned DEFAULT NULL,
  PRIMARY KEY (`node_id1`,`iface1`,`node_id2`,`iface2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `widearea_delays`
--

LOCK TABLES `widearea_delays` WRITE;
/*!40000 ALTER TABLE `widearea_delays` DISABLE KEYS */;
/*!40000 ALTER TABLE `widearea_delays` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `widearea_nodeinfo`
--

DROP TABLE IF EXISTS `widearea_nodeinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `widearea_nodeinfo` (
  `node_id` varchar(32) NOT NULL DEFAULT '',
  `machine_type` varchar(40) DEFAULT NULL,
  `contact_uid` varchar(8) NOT NULL DEFAULT '',
  `contact_idx` mediumint unsigned NOT NULL DEFAULT '0',
  `connect_type` varchar(20) DEFAULT NULL,
  `city` tinytext,
  `state` tinytext,
  `country` tinytext,
  `zip` tinytext,
  `external_node_id` tinytext,
  `hostname` varchar(255) DEFAULT NULL,
  `site` varchar(255) DEFAULT NULL,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  `bwlimit` varchar(32) DEFAULT NULL,
  `privkey` varchar(128) DEFAULT NULL,
  `IP` varchar(15) DEFAULT NULL,
  `gateway` varchar(15) NOT NULL DEFAULT '',
  `dns` tinytext NOT NULL,
  `boot_method` enum('static','dhcp','') NOT NULL DEFAULT '',
  PRIMARY KEY (`node_id`),
  KEY `IP` (`IP`),
  KEY `privkey` (`privkey`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `widearea_nodeinfo`
--

LOCK TABLES `widearea_nodeinfo` WRITE;
/*!40000 ALTER TABLE `widearea_nodeinfo` DISABLE KEYS */;
/*!40000 ALTER TABLE `widearea_nodeinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `widearea_privkeys`
--

DROP TABLE IF EXISTS `widearea_privkeys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `widearea_privkeys` (
  `privkey` varchar(64) NOT NULL DEFAULT '',
  `IP` varchar(15) NOT NULL DEFAULT '1.1.1.1',
  `user_name` tinytext NOT NULL,
  `user_email` tinytext NOT NULL,
  `cdkey` varchar(64) DEFAULT NULL,
  `nextprivkey` varchar(64) DEFAULT NULL,
  `rootkey` varchar(64) DEFAULT NULL,
  `lockkey` varchar(64) DEFAULT NULL,
  `requested` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`privkey`,`IP`),
  KEY `IP` (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `widearea_privkeys`
--

LOCK TABLES `widearea_privkeys` WRITE;
/*!40000 ALTER TABLE `widearea_privkeys` DISABLE KEYS */;
/*!40000 ALTER TABLE `widearea_privkeys` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `widearea_recent`
--

DROP TABLE IF EXISTS `widearea_recent`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `widearea_recent` (
  `time` double DEFAULT NULL,
  `node_id1` varchar(32) NOT NULL DEFAULT '',
  `iface1` varchar(10) NOT NULL DEFAULT '',
  `node_id2` varchar(32) NOT NULL DEFAULT '',
  `iface2` varchar(10) NOT NULL DEFAULT '',
  `bandwidth` double DEFAULT NULL,
  `time_stddev` float NOT NULL DEFAULT '0',
  `lossrate` float NOT NULL DEFAULT '0',
  `start_time` int unsigned DEFAULT NULL,
  `end_time` int unsigned DEFAULT NULL,
  PRIMARY KEY (`node_id1`,`iface1`,`node_id2`,`iface2`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `widearea_recent`
--

LOCK TABLES `widearea_recent` WRITE;
/*!40000 ALTER TABLE `widearea_recent` DISABLE KEYS */;
/*!40000 ALTER TABLE `widearea_recent` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `widearea_switches`
--

DROP TABLE IF EXISTS `widearea_switches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `widearea_switches` (
  `hrn` varchar(255) NOT NULL DEFAULT '',
  `node_id` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`hrn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `widearea_switches`
--

LOCK TABLES `widearea_switches` WRITE;
/*!40000 ALTER TABLE `widearea_switches` DISABLE KEYS */;
/*!40000 ALTER TABLE `widearea_switches` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `widearea_updates`
--

DROP TABLE IF EXISTS `widearea_updates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `widearea_updates` (
  `IP` varchar(15) NOT NULL DEFAULT '1.1.1.1',
  `roottag` tinytext NOT NULL,
  `update_requested` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `update_started` datetime DEFAULT NULL,
  `force` enum('yes','no') NOT NULL DEFAULT 'no',
  PRIMARY KEY (`IP`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `widearea_updates`
--

LOCK TABLES `widearea_updates` WRITE;
/*!40000 ALTER TABLE `widearea_updates` DISABLE KEYS */;
/*!40000 ALTER TABLE `widearea_updates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wireless_stats`
--

DROP TABLE IF EXISTS `wireless_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `wireless_stats` (
  `name` varchar(32) NOT NULL DEFAULT '',
  `floor` varchar(32) NOT NULL DEFAULT '',
  `building` varchar(32) NOT NULL DEFAULT '',
  `data_eid` varchar(32) DEFAULT NULL,
  `data_pid` varchar(48) DEFAULT NULL,
  `type` varchar(32) DEFAULT NULL,
  `altsrc` tinytext,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wireless_stats`
--

LOCK TABLES `wireless_stats` WRITE;
/*!40000 ALTER TABLE `wireless_stats` DISABLE KEYS */;
/*!40000 ALTER TABLE `wireless_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wires`
--

DROP TABLE IF EXISTS `wires`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `wires` (
  `cable` smallint unsigned DEFAULT NULL,
  `len` tinyint unsigned NOT NULL DEFAULT '0',
  `type` enum('Node','Serial','Power','Dnard','Control','Trunk','OuterControl','Unused','Management') NOT NULL DEFAULT 'Node',
  `node_id1` char(32) NOT NULL DEFAULT '',
  `card1` tinyint unsigned NOT NULL DEFAULT '0',
  `port1` smallint unsigned NOT NULL DEFAULT '0',
  `iface1` tinytext,
  `node_id2` char(32) NOT NULL DEFAULT '',
  `card2` tinyint unsigned NOT NULL DEFAULT '0',
  `port2` smallint unsigned NOT NULL DEFAULT '0',
  `iface2` tinytext,
  `logical` tinyint unsigned NOT NULL DEFAULT '0',
  `trunkid` mediumint unsigned NOT NULL DEFAULT '0',
  `external_interface` tinytext,
  `external_wire` tinytext,
  PRIMARY KEY (`node_id1`,`card1`,`port1`),
  KEY `node_id2` (`node_id2`,`card2`),
  KEY `dest` (`node_id2`,`card2`,`port2`),
  KEY `src` (`node_id1`,`card1`,`port1`),
  KEY `node_id1_iface1` (`node_id1`,`iface1`(32)),
  KEY `node_id2_iface2` (`node_id2`,`iface2`(32))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wires`
--

LOCK TABLES `wires` WRITE;
/*!40000 ALTER TABLE `wires` DISABLE KEYS */;
/*!40000 ALTER TABLE `wires` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2021-12-05 14:31:45
