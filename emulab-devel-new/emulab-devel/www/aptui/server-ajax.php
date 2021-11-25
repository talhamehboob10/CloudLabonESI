<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
chdir("..");
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
include_once("../session.php");

#
# We need all errors to come back to us so that we can report the error
# to the user.
# 
function handle_error($message, $death)
{
    SPITAJAX_ERROR(-1, $message);
    # Always exit; ignore $death.
    exit(1);
}
$session_errorhandler = 'handle_error';
$session_interactive  = 0;

#
# Poor man routing description.
#
$routing = array("geni-login" =>
			array("file"    => "geni-login.ajax",
			      "guest"   => true,
			      "methods" => array("GetSignerInfo" =>
						      "Do_GetSignerInfo",
						 "CreateSecret" =>
						      "Do_CreateSecret",
						 "VerifySpeaksfor" =>
						      "Do_VerifySpeaksfor")),
		 "dashboard" =>
			array("file"    => "dashboard.ajax",
			      "guest"   => false,
			      "methods" => array("GetStats" =>
						      "Do_GetStats")),
		 "rspec2genilib" =>
			array("file"    => "rspec2genilib.ajax",
			      "guest"   => false,
			      "methods" => array("Convert" =>
						      "Do_Convert")),
		 "cluster-status" =>
			array("file"    => "cluster-status.ajax",
			      "guest"   => false,
			      "methods" => array("GetStatus" =>
                                                    "Do_GetStatus",
                                                 "GetPreReservations" =>
						      "Do_GetPreReservations")),
		 "sumstats" =>
			array("file"    => "sumstats.ajax",
			      "guest"   => false,
			      "methods" => array("GetDurationInfo" =>
						      "Do_GetDurationInfo")),
		 "instantiate" =>
			array("file"    => "instantiate.ajax",
			      "guest"   => false,
			      "methods" => array("GetProfile" =>
						     "Do_GetProfile",
						 "CheckForm" =>
						     "Do_CheckForm",
						 "RunScript" =>
						     "Do_RunScript",
						 "VerifyEmail" =>
						     "Do_VerifyEmail",
						 "Submit" =>
						     "Do_Submit",
						 "Instantiate" =>
						     "Do_Instantiate",
						 "MaxDuration" =>
						     "Do_MaxDuration",
						 "GetParameters" =>
                                                     "Do_GetParameters",
						 "GetPreviousBindings" =>
                                                     "Do_GetPreviousBindings",
                                                 "GetImageList" =>
						     "Do_GetImageList",
						 "GetImageInfo" =>
						     "Do_GetImageInfo",
						 "MarkFavorite" =>
						     "Do_MarkFavorite",
						 "ClearFavorite" =>
						     "Do_ClearFavorite",
						 "RequestLicenses" =>
						     "Do_RequestLicenses")),
		 "manage_profile" =>
			array("file"    => "manage_profile.ajax",
			      "guest"   => false,
			      "methods" => array("Create" =>
						     "Do_Create",
                                                 "CloneStatus" =>
						     "Do_CloneStatus",
						 "DeleteProfile" =>
						     "Do_DeleteProfile",
						 "PublishProfile" =>
						     "Do_PublishProfile",
						 "CheckScript" =>
						     "Do_CheckScript",
						 "BindParameters" =>
						     "Do_BindParameters",
						 "ConvertClassic" =>
                                                     "Do_ConvertClassic",
						 "ConvertRspec" =>
                                                     "Do_ConvertRspec",
						 "RTECheck" =>
                                                     "Do_RTECheck",
						 "UpdateRepository" =>
                                                     "Do_UpdateRepository",
						 "GetRepository" =>
                                                     "Do_GetRepository",
						 "GetRepoHash" =>
                                                     "Do_GetRepoHash",
						 "SearchProfiles" =>
                                                     "Do_SearchProfiles",
						 "GetProfile" =>
                                                     "Do_GetProfile",
						 "Duplicate" =>
                                                     "Do_Duplicate",
                              )
                        ),
		 "gitrepo" =>
			array("file"    => "gitrepo.ajax",
			      "guest"   => true,
			      "methods" => array("GetRepository" =>
                                                     "Do_GetRepository",
						 "GetRepoSource" =>
                                                     "Do_GetRepoSource",
						 "GetBranchList" =>
                                                     "Do_GetBranchList",
						 "GetCommitInfo" =>
                                                     "Do_GetCommitInfo",
                              )
                        ),
		 "show-profile" =>
			array("file"    => "show-profile.ajax",
			      "guest"   => true,
			      "methods" => array("CheckScript" =>
						     "Do_CheckScript",
						 "GetProfile" =>
                                                     "Do_GetProfile",
						 "GetParamsets" =>
                                                     "Do_GetParamsets",
                              )
                        ),
		 "status" =>
			array("file"    => "status.ajax",
			      "guest"   => false,
			      "methods" => array("GetInstanceStatus" =>
						   "Do_GetInstanceStatus",
						 "ExpInfo" =>
						    "Do_ExpInfo",
						 "IdleData" =>
						    "Do_IdleData",
						 "Utilization" =>
						    "Do_Utilization",
						 "TerminateInstance" =>
						    "Do_TerminateInstance",
						 "GetInstanceManifest" =>
						    "Do_GetInstanceManifest",
						 "GetSSHAuthObject" =>
						    "Do_GetSSHAuthObject",
						 "ConsoleURL" =>
						     "Do_ConsoleURL",
						 "DeleteNodes" =>
						     "Do_DeleteNodes",
						 "DeleteSite" =>
						     "Do_DeleteSite",
						 "RequestExtension" =>
						     "Do_RequestExtension",
						 "DenyExtension" =>
						     "Do_DenyExtension",
						 "MoreInfo" =>
						     "Do_MoreInfo",
						 "SchedTerminate" =>
						     "Do_SchedTerminate",
						 "SnapShot" =>
						     "Do_Snapshot",
						 "SnapshotStatus" =>
                                                     "Do_SnapshotStatus",
						 "PowerCycle" =>
                                                     "Do_PowerCycle",
						 "Reboot" =>
                                                     "Do_Reboot",
						 "Reload" =>
                                                     "Do_Reload",
						 "Recovery" =>
                                                     "Do_Recovery",
						 "Flash" =>
                                                     "Do_Flash",
						 "Refresh" =>
						     "Do_Refresh",
						 "ReloadTopology" =>
						     "Do_ReloadTopology",
						 "DecryptBlocks" =>
						     "Do_DecryptBlocks",
						 "Lockout" =>
                                                     "Do_Lockout",
						 "Lockdown" =>
                                                     "Do_Lockdown",
						 "Warn" =>
                                                     "Do_WarnExperiment",
						 "Quarantine" =>
						     "Do_Quarantine",
						 "SaveAdminNotes" =>
						     "Do_SaveAdminNotes",
						 "LinktestControl" =>
						     "Do_Linktest",
						 "OpenstackStats" =>
						     "Do_OpenstackStats",
						 "MaxExtension" =>
						     "Do_MaxExtension",
						 "GetRspec" =>
						     "Do_GetRspec",
						 "IgnoreFailure" =>
						     "Do_IgnoreFailure",
						 "Top" =>
						     "Do_Top",
						 "dismissExtensionDenied" =>
                                                 "Do_DismissExtensionDenied")),
		 "approveuser" =>
			array("file"    => "approveuser.ajax",
			      "guest"   => false,
			      "methods" => array("approve" =>
						     "Do_Approve",
						 "deny" =>
						      "Do_Deny")),
		 "dataset" =>
			array("file"    => "dataset.ajax",
			      "guest"   => false,
			      "methods" => array("create" =>
						      "Do_CreateDataset",
						 "modify" =>
						      "Do_ModifyDataset",
						 "delete" =>
						      "Do_DeleteDataset",
						 "refresh" =>
						      "Do_RefreshDataset",
						 "approve" =>
						     "Do_ApproveDataset",
						 "extend" =>
                                                      "Do_ExtendDataset",
						 "getinfo" =>
						      "Do_GetInfo")),
		 "ssh-keys" =>
			array("file"    => "ssh-keys.ajax",
			      "guest"   => false,
			      "methods" => array("addkey" =>
						      "Do_AddKey",
						 "deletekey" =>
                                                      "Do_DeleteKey")),
		 "myaccount" =>
			array("file"    => "myaccount.ajax",
			      "guest"   => false,
                              "unapproved" => true,
			      "methods" => array("update" =>
                                                     "Do_Update")),
		 "changepswd" =>
			array("file"    => "changepswd.ajax",
			      "guest"   => false,
                              "unapproved" => true,
                              "notloggedinokay" => true,
			      "methods" => array("changepswd" =>
                                                     "Do_ChangePassword")),
		 "lists" =>
			array("file"    => "lists.ajax",
			      "guest"   => false,
			      "methods" => array("SearchUsers" =>
                                                     "Do_SearchUsers",
                                                 "SearchProjects" =>
                                                     "Do_SearchProjects")),
		 "user-dashboard" =>
			array("file"    => "user-dashboard.ajax",
			      "guest"   => false,
			      "methods" => array("ExperimentList" =>
						      "Do_ExperimentList",
                                                 "ClassicExperimentList" =>
						      "Do_ClassicExperimentList",
                                                 "ClassicProfileList" =>
						      "Do_ClassicProfileList",
                                                 "DatasetList" =>
						      "Do_DatasetList",
                                                 "ClassicDatasetList" =>
						      "Do_ClassicDatasetList",
                                                 "ProjectList" =>
                                                      "Do_ProjectList",
                                                 "UsageSummary" =>
                                                      "Do_UsageSummary",
                                                 "ProfileList" =>
                                                      "Do_ProfileList",
                                                 "ProjectProfileList" =>
                                                      "Do_ProjectProfileList",
                                                 "ResgroupList" =>
                                                      "Do_ResgroupList",
                                                 "Toggle" =>
                                                     "Do_Toggle",
                                                 "FreezeOrThaw" =>
                                                     "Do_FreezeOrThaw",
                                                 "SendTestMessage" =>
                                                     "Do_SendTestMessage",
                                                 "SendPasswordReset" =>
                                                     "Do_SendPasswordReset",
                                                 "NagPI" =>
                                                     "Do_NagPI",
                                                 "AccountDetails" =>
                                                     "Do_AccountDetails",
                                                 "ListParameterSets" =>
                                                     "Do_ListParameterSets",
                                                 "AcceptAUP" =>
                                                     "Do_AcceptAUP",
                                                 "VerifyScopusInfo" =>
                                                     "Do_VerifyScopusInfo",
                                                 "DeleteUser" =>
                                                     "Do_DeleteUser"
                              )
                        ),
		 "nag" =>
			array("file"    => "user-dashboard.ajax",
                              "unapproved" => true,
			      "guest"   => false,
			      "methods" => array("NagPI" =>
                                                     "Do_NagPI",)),
		 "show-project" =>
			array("file"    => "show-project.ajax",
			      "guest"   => false,
			      "methods" => array("ExperimentList" =>
						      "Do_ExperimentList",
                                                 "ClassicExperimentList" =>
						      "Do_ClassicExperimentList",
                                                 "ClassicProfileList" =>
						      "Do_ClassicProfileList",
                                                 "DatasetList" =>
						      "Do_DatasetList",
                                                 "ClassicDatasetList" =>
						      "Do_ClassicDatasetList",
                                                 "ProfileList" =>
                                                      "Do_ProfileList",
                                                 "MemberList" =>
                                                      "Do_MemberList",
                                                 "GroupList" =>
                                                      "Do_GroupList",
                                                 "ResgroupList" =>
                                                      "Do_ResgroupList",
                                                 "UsageSummary" =>
                                                      "Do_UsageSummary",
                                                 "Toggle" =>
                                                     "Do_Toggle",
                                                 "ProjectProfile" =>
                                                     "Do_ProjectProfile",
                                                 "DeleteProject" =>
                                                     "Do_DeleteProject",
                                                 "NSF" =>
                                                     "Do_NSF"
                              )
                        ),
		 "groups" =>
			array("file"    => "groups.ajax",
			      "guest"   => false,
			      "methods" => array("ExperimentList" =>
						      "Do_ExperimentList",
                                                 "ClassicExperimentList" =>
						     "Do_ClassicExperimentList",
                                                 "MemberList" =>
                                                      "Do_MemberList",
                                                 "EditMembership" =>
                                                      "Do_EditMembership",
                                                 "EditPrivs" =>
                                                      "Do_EditPrivs",
                                                 "Create" =>
                                                      "Do_CreateGroup",
                                                 "Delete" =>
                                                      "Do_DeleteGroup",
                                                 "GroupProfile" =>
                                                      "Do_GroupProfile")),
		 "ranking" =>
			array("file"    => "ranking.ajax",
			      "guest"   => false,
			      "methods" => array("RankList" =>
                                                     "Do_RankList")),
                 "announcement" =>
                        array("file"    => "announcement.ajax",
                              "guest"   => false,
                              "methods" => array("Dismiss" =>
                                                     "Do_Dismiss",
                                                 "Click" =>
                                                     "Do_Click",
                                                 "Announcements" =>
                                                     "Do_Announcements")),
		 "reserve" =>
			array("file"    => "reserve.ajax",
			      "guest"   => false,
			      "methods" => array("Reserve" =>
                                                     "Do_Reserve",
                                                 "Validate" =>
                                                     "Do_Validate",
                                                 "ListReservations" =>
                                                     "Do_ListReservations",
                                                 "GetReservation" =>
                                                     "Do_GetReservation",
                                                 "Approve" =>
                                                     "Do_Approve",
                                                 "WarnUser" =>
                                                     "Do_WarnUser",
                                                 "Delete" =>
                                                     "Do_Delete",
                                                 "Cancel" =>
                                                     "Do_Cancel",
                                                 "RequestInfo" =>
                                                     "Do_RequestInfo",
                                                 "ReservationInfo" =>
                                                     "Do_ReservationInfo",
                                                 "ReservationHistory" =>
                                                     "Do_ReservationHistory")),
		 "resgroup" =>
			array("file"    => "resgroup.ajax",
			      "guest"   => false,
			      "methods" => array("Reserve" =>
                                                     "Do_Reserve",
                                                 "Validate" =>
                                                     "Do_Validate",
                                                 "ListReservationGroups" =>
                                                     "Do_ListReservationGroups",
                                                 "GetReservationGroup" =>
                                                     "Do_GetReservationGroup",
                                                 "Approve" =>
                                                     "Do_Approve",
                                                 "WarnUser" =>
                                                     "Do_WarnUser",
                                                 "Delete" =>
                                                     "Do_Delete",
                                                 "Refresh" =>
                                                     "Do_Refresh",
                                                 "Cancel" =>
                                                     "Do_Cancel",
                                                 "IdleDetection" =>
                                                     "Do_IdleDetection",
                                                 "RequestInfo" =>
                                                     "Do_RequestInfo",
                                                 "RangeReservations" =>
                                                     "Do_RangeReservations",
                                                 "RouteReservations" =>
                                                     "Do_RouteReservations",
                                                 "ReservationHistory" =>
                                                     "Do_ReservationHistory")),
		 "rfresgroup" =>
			array("file"    => "rfresgroup.ajax",
			      "guest"   => false,
			      "methods" => array("Reserve" =>
                                                     "Do_Reserve",
                                                 "Validate" =>
                                                     "Do_Validate",
                                                 "ListReservations" =>
                                                     "Do_ListReservations",
                                                 "GetReservation" =>
                                                     "Do_GetReservation",
                                                 "Approve" =>
                                                     "Do_Approve",
                                                 "WarnUser" =>
                                                     "Do_WarnUser",
                                                 "Delete" =>
                                                     "Do_Delete",
                                                 "Cancel" =>
                                                     "Do_Cancel",
                                                 "RequestInfo" =>
                                                     "Do_RequestInfo",
                                                 "ReservationInfo" =>
                                                     "Do_ReservationInfo",
                                                 "ReservationHistory" =>
                                                     "Do_ReservationHistory")),
		 "images" =>
			array("file"    => "images.ajax",
			      "guest"   => false,
			      "methods" => array("ListImages" =>
                                                     "Do_ListImages",
                                                 "DeleteImage" =>
                                                     "Do_DeleteImage",
                                                 "ClassicImages" =>
                                                     "Do_ClassicImageList")),
		 "image" =>
			array("file"    => "image.ajax",
			      "guest"   => false,
			      "methods" => array("GetInfo" =>
                                                     "Do_GetInfo",
                                                 "SaveAdminNotes" =>
                                                     "Do_SaveAdminNotes",
                                                 "Delete" =>
                                                     "Do_Delete",
                                                 "SetSharing" =>
                                                     "Do_SetSharing",
                                                 "SetTypes" =>
                                                     "Do_SetTypes",
                                                 "Clone" =>
                                                     "Do_Clone",
                                                 "Snapshot" =>
                                                     "Do_Snapshot",
                                                 "SnapshotStatus" =>
                                                     "Do_SnapshotStatus",
                                                 "Modify" =>
                                                     "Do_Modify")),
		 "node" =>
			array("file"    => "node.ajax",
			      "guest"   => true,
			      "methods" => array("GetInfo" =>
                                                     "Do_GetInfo",
                                                 "GetHardwareInfo" =>
                                                     "Do_GetHardwareInfo",
                                                 "Modify" =>
                                                     "Do_Modify",
                                                 "Reboot" =>
                                                     "Do_Reboot",
                                                 "GetLog" =>
                                                     "Do_GetLog",
                                                 "SaveLogEntry" =>
                                                     "Do_SaveLogEntry",
                                                 "DeleteLogEntry" =>
                                                     "Do_DeleteLogEntry",
                                                 "GetHistory" =>
                                                     "Do_GetHistory",
                                                 "GetRFViolations" =>
                                                     "Do_GetRFViolations")),
		 "nodetype" =>
			array("file"    => "nodetype.ajax",
                              # We wllow guest users to see type info.
			      "guest"   => true,
			      "methods" => array("GetInfo" =>
                                                     "Do_GetInfo",
                                                 "GetHardwareInfo" =>
                                                     "Do_GetHardwareInfo",
                                                 "SaveFlag" =>
                                                     "Do_SaveFlag",
                                                 "SaveFeature" =>
                                                     "Do_SaveFeature",
                                                 "SaveAttribute" =>
                                                     "Do_SaveAttribute",
                                                 "SaveOSImage" =>
                                                     "Do_SaveOSImage",
                                                 "DeleteFeature" =>
                                                     "Do_DeleteFeature",
                                                 "DeleteAttribute" =>
                                                     "Do_DeleteAttribute",
                                                 "DeleteOSImage" =>
                                                     "Do_DeleteOSImage")),
		 "vlan" =>
			array("file"    => "vlan.ajax",
			      "guest"   => false,
			      "methods" => array("GetInfo" =>
                                                     "Do_GetInfo",
                                                 "List" =>
                                                     "Do_List",
                                                 "History" =>
                                                     "Do_History",
                              )),
		 "wires" =>
			array("file"    => "wires.ajax",
			      "guest"   => false,
			      "methods" => array("List" =>
                                                     "Do_List")),
		 "news" =>
			array("file"    => "news.ajax",
			      "guest"   => false,
			      "methods" => array("create" =>
						      "Do_CreateNews",
						 "modify" =>
						      "Do_ModifyNews",
						 "delete" =>
						      "Do_DeleteNews",
						 "getnews" =>
                                                      "Do_GetNews",
						 "gotnews" =>
                                                      "Do_GotNews",
                              )),
		 "experiments" =>
			array("file"    => "experiments.ajax",
			      "guest"   => false,
			      "methods" => array("ExperimentList" =>
                                                     "Do_ExperimentList",
                                                 "ClassicExperimentList" =>
                                                     "Do_ClassicExperimentList",
                                                 "SearchIP" =>
                                                     "Do_SearchIP",
                                                 "ExperimentErrors" =>
                                                     "Do_ExperimentErrors")),
		 "activity" =>
			array("file"    => "activity.ajax",
			      "guest"   => false,
			      "methods" => array("Search" =>
                                                     "Do_Search")),
		 "approve-projects" =>
			array("file"    => "approve-projects.ajax",
			      "guest"   => false,
			      "methods" => array("ProjectList" =>
                                                     "Do_ProjectList",
                                                 "SaveDescription" =>
                                                     "Do_SaveDescription",
                                                 "MoreInfo" =>
                                                     "Do_MoreInfo",
                                                 "Deny" =>
                                                     "Do_Deny",
                                                 "Approve" =>
                                                     "Do_Approve")),
		 "frontpage" =>
			array("file"    => "frontpage.ajax",
			      "guest"   => true,
			      "methods" => array("GetHealthStatus" =>
						    "Do_GetHealthStatus",
						 "GetHealthStatusExtended" =>
                                                   "Do_GetHealthStatusExtended",
						 "GetWirelessStatus" =>
						    "Do_GetWirelessStatus")),
		 "memlane" =>
			array("file"    => "memlane.ajax",
			      "guest"   => false,
			      "methods" => array("HistoryRecord" =>
						    "Do_HistoryRecord")),
		 "aggregate-status" =>
			array("file"    => "aggregate-status.ajax",
			      "guest"   => false,
			      "methods" => array("AggregateStatus" =>
						    "Do_AggregateStatus")),
		 "sitevars" =>
			array("file"    => "sitevars.ajax",
			      "guest"   => false,
			      "methods" => array("GetSitevars" =>
						    "Do_GetSitevars",
                                                 "SetSitevar" =>
						    "Do_SetSitevar",
                                                 "ResetSitevar" =>
						    "Do_ResetSitevar")),
		 "licenses" =>
			array("file"    => "licenses.ajax",
			      "guest"   => false,
			      "methods" => array("List" =>
						    "Do_List",
                                                 "Accept" =>
                                                     "Do_Accept",
                                                 "Reject" =>
                                                     "Do_Reject",
                                                 "Request" =>
                                                     "Do_Request")),
		 "paramsets" =>
			array("file"    => "paramsets.ajax",
			      "guest"   => false,
			      "methods" => array("Create" =>
                                                     "Do_Create",
                                                 "Delete" =>
                                                     "Do_Delete")),
                 "powder-shutdown" =>
			array("file"    => "powder-shutdown.ajax",
			      "guest"   => false,
			      "methods" => array("Shutdown" =>
                                                     "Do_StartShutdown",
                                                 "Status" =>
                                                     "Do_ShutdownStatus")),
                 "map-support" =>
			array("file"    => "map-support.ajax",
			      "guest"   => true,
			      "methods" => array("GetFixedEndpoints" =>
                                                     "Do_GetFixedEndpoints",
                                                 "GetBaseStations" =>
                                                     "Do_GetBaseStations",
                                                 "GetMobileEndpoints" =>
                                                     "Do_GetMobileEndpoints",
                              )
                        ),
		 "scopus" =>
			array("file"    => "scopus.ajax",
			      "guest"   => false,
			      "methods" => array("MarkUses" =>
						     "Do_MarkUses",
                              )
                        ),
		 "frequency-graph" =>
			array("file"    => "frequency-graph.ajax",
			      "guest"   => true,
			      "methods" => array("GetFrequencyData" =>
						     "Do_GetFrequencyData",
                                                 "GetListing" =>
						     "Do_GetListing",
                              )
                        ),
		 "rfrange" =>
			array("file"    => "rfrange.ajax",
			      "guest"   => false,
			      "methods" => array("ProjectRanges" =>
                                                     "Do_ProjectRanges",
                                                 "GlobalRanges" =>
                                                     "Do_GlobalRanges",
                                                 "AllProjectRanges" =>
                                                     "Do_AllProjectRanges",
                                                 "ProjectInuseRanges" =>
                                                     "Do_ProjectInuseRanges",
                                                 "AllInuseRanges" =>
                                                     "Do_AllInuseRanges"
                              )
                        ),
);

#
# Redefine this so we return XML instead of html for all errors.
#
$PAGEERROR_HANDLER = function($msg, $status_code = 0) {
    if ($status_code == 0) {
	$status_code = 1;
    }
    SPITAJAX_ERROR(1, $msg);
    return;
};

#
# Included file determines if guest user okay.
#
$this_user = CheckLogin($check_status);

#
# Check user login, called by included code. Basically just a
# way to let guest users pass through when allowed, without
# duplicating the code in each file.
#
function CheckLoginForAjax($route)
{
    global $this_user, $check_status;
    global $ISAPT;
    $guestokay = false;
    $unapprovedokay = false;
    $notloggedinokay = false;
    
    if (array_key_exists("guest", $route)) {
        $guestokay = $route["guest"];
    }
    if (array_key_exists("unapproved", $route)) {
        $unapprovedokay = $route["unapproved"];
    }
    if (array_key_exists("notloggedinokay", $route)) {
        $notloggedinokay = $route["notloggedinokay"];
    }
    if (NOLOGINS()) {
        if (!isset($this_user) || !ISADMIN()) {
            SPITAJAX_ERROR(222, "Logins are disabled");
            exit(1);
        }
    }
    # Known user, but timed out.
    if ($check_status & CHECKLOGIN_TIMEDOUT) {
	SPITAJAX_ERROR(222, "Your login has timed out");
	exit(1);
    }
    # Logged in user always okay.
    if (isset($this_user)) {
	if ($check_status & CHECKLOGIN_MAYBEVALID) {
	    SPITAJAX_ERROR(222, "Your login cannot be verified. ".
                           "Cookie problem?");
	    exit(1);
	}
        # Known user, but not frozen.
        if ($check_status & CHECKLOGIN_FROZEN) {
            SPITAJAX_ERROR(222, "Your account has been frozen");
            exit(1);
        }
        if (! $unapprovedokay) {
            # Known user, but not approved.
            if ($check_status & CHECKLOGIN_UNAPPROVED) {
	        SPITAJAX_ERROR(222, "Your account has not been approved yet");
                exit(1);
            }
            # Known user, but not active.
            if (! ($check_status & CHECKLOGIN_ACTIVE)) {
                SPITAJAX_ERROR(222, "Your account is no longer active");
                exit(1);
            }
            # Known user, but inactive.
            if ($check_status & CHECKLOGIN_INACTIVE) {
                SPITAJAX_ERROR(222, "Your account has gone inactive cause ".
                               "your last login was so long ago: " .
                               $this_user->weblogin_last());
                exit(1);
            }
        }
        # Kludge, still thinking about it. If a geni user has no project
        # permissions at their SA, then we mark the acount as WEBONLY, and
        # deny access to anything that is not marked as guest okay. 
	if ($check_status & CHECKLOGIN_WEBONLY && !$guestokay) {
	    SPITAJAX_ERROR(222, "Your account is not allowed to do this");
	    exit(1);
        }
	return;
    }
    if (!($guestokay || $notloggedinokay)) {
	SPITAJAX_ERROR(222, "You are not logged in");	
	exit(1);
    }
}

#
# So we can capture stderr. Sheesh.
# 
function myexec($cmd)
{
    ignore_user_abort(1);

    $myexec_output_array = array();
    $myexec_output       = "";
    $myexec_retval       = 0;
    
    exec("$cmd 2>&1", $myexec_output_array, $myexec_retval);
    if ($myexec_retval) {
	for ($i = 0; $i < count($myexec_output_array); $i++) {
	    $myexec_output .= "$myexec_output_array[$i]\n";
	}
	$foo  = "Shell Program Error. Exit status: $myexec_retval\n";
	$foo .= "  '$cmd'\n";
	$foo .= "\n";
	$foo .= $myexec_output;
	TBERROR($foo, 0);
	return 1;
    }
    return 0;
}

#
# Verify page arguments.
#
$optargs = RequiredPageArguments("ajax_route",    PAGEARG_STRING,
				 "ajax_method",   PAGEARG_STRING,
				 "ajax_args",     PAGEARG_ARRAY);

#
# Verify page and method.
#
if (! array_key_exists($ajax_route, $routing)) {
    SPITAJAX_ERROR(1, "Invalid route: $ajax_route");
    exit(1);
}
if (! array_key_exists($ajax_method, $routing[$ajax_route]["methods"])) {
    SPITAJAX_ERROR(1, "Invalid method: $ajax_route,$ajax_method");
    exit(1);
}
CheckLoginForAjax($routing[$ajax_route]);
include($routing[$ajax_route]["file"]);
call_user_func($routing[$ajax_route]["methods"][$ajax_method]);

?>
