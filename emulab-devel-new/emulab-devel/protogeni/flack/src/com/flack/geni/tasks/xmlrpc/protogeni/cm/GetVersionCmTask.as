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

package com.flack.geni.tasks.xmlrpc.protogeni.cm
{
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.resources.docs.RspecVersionCollection;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.TaskError;
	
	/**
	 * Gets version information from the manager.
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetVersionCmTask extends ProtogeniXmlrpcTask
	{
		public var manager:GeniManager;
		
		/**
		 * 
		 * @param newManager Manager to get version info for
		 * 
		 */
		public function GetVersionCmTask(newManager:GeniManager)
		{
			super(
				newManager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_GETVERSION,
				"Get version @ " + newManager.hrn,
				"Gets the version information of the component manager named " + newManager.hrn,
				"Get Version"
			);
			maxTries = 1;
			timeout = 60;
			promptAfterMaxTries = false;
			newManager.Status = FlackManager.STATUS_INPROGRESS;
			relatedTo.push(newManager);
			manager = newManager;
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				var apiDetail:ApiDetails = new ApiDetails(manager.api.type, Number(data.api), manager.api.url, int(data.level));
				manager.setApi(apiDetail);
				manager.apis.removeAll(manager.apis.getType(ApiDetails.API_PROTOGENI));
				if(manager.apis.getType(ApiDetails.API_GENIAM).length == 0) {
					manager.apis.add(new ApiDetails(ApiDetails.API_GENIAM, NaN, manager.api.url += "/am"));
				}
				manager.apis.add(apiDetail);
				
				manager.inputRspecVersions = new RspecVersionCollection();
				manager.outputRspecVersions = new RspecVersionCollection();
				
				// request RSPEC versions
				manager.inputRspecVersions = new RspecVersionCollection();
				for each(var inputVersion:Number in data.input_rspec)
				{
					if(inputVersion)
					{
						var newInputVersion:RspecVersion =
							new RspecVersion(
								inputVersion < 3 ? RspecVersion.TYPE_PROTOGENI : RspecVersion.TYPE_GENI,
								inputVersion
							);
						manager.inputRspecVersions.add(newInputVersion);
					}
				}
				
				// ad RSPEC versions
				var outputRspecDefaultVersionNumber:Number = Number(data.output_rspec);
				manager.outputRspecVersions = new RspecVersionCollection();
				if(data.ad_rspec != null)
				{
					for each(var outputVersion:Number in data.ad_rspec)
					{
						if(outputVersion)
						{
							var newOutputVersion:RspecVersion =
								new RspecVersion(
									outputVersion < 3 ? RspecVersion.TYPE_PROTOGENI : RspecVersion.TYPE_GENI,
									outputVersion
								);
							if(outputRspecDefaultVersionNumber == outputVersion)
								manager.outputRspecVersion = newOutputVersion;
							manager.outputRspecVersions.add(newOutputVersion);
						}
					}
				}
				else
				{
					manager.outputRspecVersions.add(
						new RspecVersion(
							outputRspecDefaultVersionNumber < 3 ? RspecVersion.TYPE_PROTOGENI : RspecVersion.TYPE_GENI,
							outputRspecDefaultVersionNumber
						)
					);
					manager.outputRspecVersion = manager.outputRspecVersions.collection[0];
				}
				
				
				// Set defaults
				if(manager.outputRspecVersion == null)
					manager.outputRspecVersion = manager.outputRspecVersions.MaxVersion;
				manager.inputRspecVersion = manager.inputRspecVersions.MaxVersion;
				
				addMessage(
					"Version found",
					"Input: "+manager.inputRspecVersion.toString()+"\nOutput:" + manager.outputRspecVersion.toString(),
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_MANAGER,
					manager
				);
				
				parent.add(new DiscoverResourcesCmTask(manager));
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				if(numberTries < maxTries) {
					runRetry(5);
					return;
				}
				faultOnSuccess();
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
			manager.Status = FlackManager.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				manager,
				FlackEvent.ACTION_STATUS
			);
		}
	}
}