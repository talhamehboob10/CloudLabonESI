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

--
-- Table structure for table `image_permissions`
--

DROP TABLE IF EXISTS `image_aliases`;
CREATE TABLE `image_aliases` (
  `urn` varchar(128) default NULL,
  `uuid` varchar(40) NOT NULL default '',
  `target_urn` varchar(128) NOT NULL default '',
  PRIMARY KEY  (`urn`,`target_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_permissions`
--

DROP TABLE IF EXISTS `image_permissions`;
CREATE TABLE `image_permissions` (
  `urn` varchar(128) default NULL,
  `imagename` varchar(30) NOT NULL default '',
  `image_uuid` varchar(40) NOT NULL default '',
  `permission_type` enum('user','project') NOT NULL default 'user',
  `permission_urn` varchar(128) NOT NULL default '',
  PRIMARY KEY  (`urn`,`permission_urn`),
  UNIQUE KEY `uuidurn` (`image_uuid`,`permission_urn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `image_versions`
--

DROP TABLE IF EXISTS `image_versions`;
CREATE TABLE `image_versions` (
  `urn` varchar(128) default NULL,
  `imagename` varchar(30) NOT NULL default '',
  `version` int(8) unsigned NOT NULL default '0',
  `version_uuid` varchar(40) NOT NULL default '',
  `image_uuid` varchar(40) NOT NULL default '',
  `creator_urn` varchar(128) default NULL,
  `created` datetime default NULL,
  `description` text NOT NULL,
  `filesize` bigint(20) unsigned NOT NULL default '0',
  `hash` varchar(64) default NULL,
  `lba_low` bigint(20) unsigned NOT NULL default '0',
  `lba_high` bigint(20) unsigned NOT NULL default '0',
  `lba_size` int(10) unsigned NOT NULL default '512',
  `mbr_version` varchar(50) NOT NULL default '1',
  `arch` enum ('i386','x86_64','aarch64','ppc64le') NOT NULL default 'x86_64',
  `visibility` enum ('project','public') NOT NULL default 'public',
  `virtualizaton` enum ('raw-pc','emulab-xen','emulab-docker') NOT NULL default 'raw-pc',
  `osfeatures` text default NULL,
  `metadata_url` tinytext,
  `types_known_working` text default NULL,
  `types_known_notworking` text default NULL,
  `types_unknown` text default NULL,
  `deprecated` datetime default NULL,
  `deprecated_iserror` tinyint(1) NOT NULL default '0',
  `deprecated_message` mediumtext,
  PRIMARY KEY (`urn`,`version`),
  UNIQUE KEY `version_uuid` (`version_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `images`
--

DROP TABLE IF EXISTS `images`;
CREATE TABLE `images` (
  `urn` varchar(128) default NULL,
  `imagename` varchar(30) NOT NULL default '',
  `aggregate_urn` varchar(128) default NULL,
  `project_urn` varchar(128) default NULL,
  `image_uuid` varchar(40) NOT NULL default '',
  `isdataset` tinyint(1) NOT NULL default '0',
  `issystem` tinyint(1) NOT NULL default '0',
  `listed` tinyint(1) NOT NULL default '1',
  `isversioned` tinyint(1) NOT NULL default '0',
  `locked` datetime default NULL,
  `locker_pid` int(11) default '0',
  PRIMARY KEY (`urn`),
  UNIQUE KEY `image_uuid` (`image_uuid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
