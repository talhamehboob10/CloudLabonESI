/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * 
 * {{{GENIPUBLIC-LICENSE
 * 
 * GENI Public License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and/or hardware specification (the "Work") to
 * deal in the Work without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Work, and to permit persons to whom the Work
 * is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Work.
 * 
 * THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
 * IN THE WORK.
 * 
 * }}}
 */

package com.flack.geni.tasks.xmlrpc.am
{
	import com.flack.geni.resources.docs.GeniCredentialVersion;
	import com.flack.geni.resources.docs.GeniCredentialVersionCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.resources.docs.RspecVersionCollection;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Gets version info from manager then adds task to get resources
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetVersionTask extends AmXmlrpcTask
	{
		public var manager:GeniManager;
		
		/**
		 * 
		 * @param newManager Manager to get the version info for
		 * 
		 */
		public function GetVersionTask(newManager:GeniManager)
		{
			super(
				newManager.api.url,
				AmXmlrpcTask.METHOD_GETVERSION,
				NaN,
				"Get version @ " + newManager.hrn,
				"Getting the version information of the aggregate manager for " + newManager.hrn,
				"Get Version"
			);
			maxTries = 2;
			timeout = 30;
			promptAfterMaxTries = false;
			newManager.Status = FlackManager.STATUS_INPROGRESS;
			relatedTo.push(newManager);
			manager = newManager;
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			// Sanity check for AM API 2+
			if(apiVersion > 1)
			{
				if(genicode != AmXmlrpcTask.GENICODE_SUCCESS)
				{
					if(numberTries < maxTries) {
						runRetry(5);
						return;
					}
					faultOnSuccess();
					return;
				}
			}
			
			try
			{
				if (data.urn != null) {
					manager.id.full = data.urn;
				}
				
				var apiDetail:ApiDetails = new ApiDetails(manager.api.type, Number(data.geni_api), manager.api.url, manager.api.level);
				manager.api = apiDetail;
				manager.apis.removeAll(manager.apis.getType(ApiDetails.API_GENIAM));
				if(manager.type == GeniManager.TYPE_PROTOGENI && manager.apis.getType(ApiDetails.API_PROTOGENI).length == 0) {
					manager.apis.add(new ApiDetails(ApiDetails.API_PROTOGENI, NaN, manager.url));
				}
				manager.apis.add(apiDetail);
				if(data.geni_api_versions != null)
				{
					//URL
					var highestSuppportedVersion:ApiDetails = manager.api;
					for(var supportedApiVersion:String in data.geni_api_versions)
					{
						var supportedApiUrl:String = data.geni_api_versions[supportedApiVersion];
						var supportedApi:ApiDetails = 
							new ApiDetails(
								manager.api.type,
								Number(supportedApiVersion),
								supportedApiUrl
							);
						if (manager.api.equals(supportedApi))
							continue;
						if(supportedApi.version <= 2
						   && supportedApi.version > highestSuppportedVersion.version)
							highestSuppportedVersion = supportedApi;
						manager.apis.add(supportedApi);
					}
					var oldApi:ApiDetails = manager.api;
					manager.setApi(highestSuppportedVersion);
					if(oldApi.version < manager.api.version)
					{
						parent.add(new GetVersionTask(manager));
						
						super.afterComplete(addCompletedMessage);
						
						return;
					}
				}

				//V3
				if(data.geni_am_type != null)
				{
					manager.types = new Vector.<String>();
					for(var amType:String in data.geni_am_type)
					{
						manager.types.push(amType);
					}
					if (manager.types.length == 1) {
						manager.type = manager.types[0];
					}
				}
				
				if(data.geni_am_code_version != null)
				{
					manager.codeVersion = String(data.geni_am_code_version);
				}
				if(data.code_tag != null)
				{
					manager.codeVersion = String(data.code_tag);
				}
				
				manager.inputRspecVersions = new RspecVersionCollection();
				manager.outputRspecVersions = new RspecVersionCollection();
				
				// Request RSPEC versions
				var requestRspecVersions:Array = null;
				switch(manager.api.version)
				{
					case 1:
						requestRspecVersions = data.request_rspec_versions;
						break;
					case 2:
					default:
						requestRspecVersions = data.geni_request_rspec_versions;
				}
				if(requestRspecVersions != null)
				{
					for each(var requestRspecVersion:Object in requestRspecVersions)
					{
						var requestVersion:RspecVersion = 
							new RspecVersion(
								String(requestRspecVersion.type).toLowerCase(),
								Number(requestRspecVersion.version)
							);
						//V3: schema, namespace, extensions
						manager.inputRspecVersions.add(requestVersion);
					}
				}
				
				// Advertisement RSPEC versions
				var adRspecVersions:Array = null;
				switch(manager.api.version)
				{
					case 1:
						adRspecVersions = data.ad_rspec_versions;
						break;
					case 2:
					default:
						adRspecVersions = data.geni_ad_rspec_versions;
				}
				if(adRspecVersions != null)
				{
					for each(var adRspecVersion:Object in adRspecVersions)
					{
						var adVersion:RspecVersion =
							new RspecVersion(
								String(adRspecVersion.type).toLowerCase(),
								Number(adRspecVersion.version)
							);
						//V3: schema, namespace, extensions
						manager.outputRspecVersions.add(adVersion);
					}
				}
				
				if(data.geni_credential_types != null)
				{
					manager.credentialTypes = new GeniCredentialVersionCollection();
					for each(var geniCredentialType:Object in data.geni_credential_types)
					{
						manager.credentialTypes.add(
							new GeniCredentialVersion(
								geniCredentialType.geni_type,
								Number(geniCredentialType.geni_version)));
					}
				}

				if(data.geni_single_allocation != null)
					manager.singleAllocation = data.geni_single_allocation == "1" || data.geni_single_allocation == "true";
				if(data.geni_allocate != null)
					manager.allocate = data.geni_allocate;
				//V3: geni_best_effort?
				
				// Make sure aggregate uses compatible rspec
				if(manager.inputRspecVersions.UsableRspecVersions.length > 0 && manager.outputRspecVersions.UsableRspecVersions.length > 0)
				{
					manager.outputRspecVersion = manager.outputRspecVersions.UsableRspecVersions.MaxVersion;
					manager.inputRspecVersion = manager.inputRspecVersions.UsableRspecVersions.MaxVersion;
					
					addMessage(
						"Compatible",
						"Input: "+manager.inputRspecVersion.toString()+"\nOutput:" + manager.outputRspecVersion.toString(),
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
					
					SharedMain.sharedDispatcher.dispatchChanged(
						FlackEvent.CHANGED_MANAGER,
						manager
					);
					
					parent.add(new ListResourcesTask(manager));
					
					super.afterComplete(addCompletedMessage);
				}
				else
				{
					manager.errorType = FlackManager.FAIL_NOTSUPPORTED;
					afterError(
						new TaskError(
							"ProtoGENI RSPEC not supported",
							TaskError.CODE_PROBLEM
						)
					);
				}
			}
			catch(e:Error)
			{
				afterError(
					new TaskError(
						StringUtil.errorToString(e),
						TaskError.CODE_UNEXPECTED,
						e
					)
				);
			}
		}
		
		override protected function afterError(taskError:TaskError):void
		{
			if(numberTries < maxTries) {
				runRetry(5);
				return;
			}
			manager.Status = FlackManager.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				manager,
				FlackEvent.ACTION_STATUS
			);
			
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			manager.Status = FlackManager.STATUS_UNKOWN;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				manager,
				FlackEvent.ACTION_STATUS
			);
		}
	}
}