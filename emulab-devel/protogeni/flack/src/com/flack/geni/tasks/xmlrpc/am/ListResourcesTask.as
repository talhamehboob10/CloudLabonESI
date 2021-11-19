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
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.tasks.process.ParseAdvertisementTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.CompressUtil;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Lists all of the manager's resources.  Adds a seperate task to the parent to parse the advertisement.
	 * 
	 * @author mstrum
	 * 
	 */
	public class ListResourcesTask extends AmXmlrpcTask
	{
		public var manager:GeniManager;
		
		/**
		 * 
		 * @param newManager Manager to list resources for
		 * 
		 */
		public function ListResourcesTask(newManager:GeniManager)
		{
			super(
				newManager.api.url,
				AmXmlrpcTask.METHOD_LISTRESOURCES,
				newManager.api.version,
				"List resources @ " + newManager.hrn,
				"Listing resources for aggregate manager " + newManager.hrn,
				"List Resources"
			);
			relatedTo.push(newManager);
			manager = newManager;
		}
		
		override protected function createFields():void
		{
			addOrderedField([AmXmlrpcTask.credentialToObject(GeniMain.geniUniverse.user.credential, apiVersion)]);
			
			var options:Object = 
				{
					geni_available: false,
					geni_compressed: true
				};
			var rspecVersion:Object = 
				{
					type:manager.outputRspecVersion.type,
					version:manager.outputRspecVersion.version.toString()
				};
			if(apiVersion < 2)
				options.rspec_version = rspecVersion;
			else
				options.geni_rspec_version = rspecVersion;
			
			addOrderedField(options);	
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			// Sanity check for AM API 2+
			if(apiVersion > 1)
			{
				if(genicode != AmXmlrpcTask.GENICODE_SUCCESS)
				{
					faultOnSuccess();
					return;
				}
			}
			
			try
			{
				var uncompressedRspec:String = data;
				if(uncompressedRspec.indexOf("<") == -1)
				{
					uncompressedRspec = CompressUtil.uncompress(uncompressedRspec);
				}
				
				addMessage(
					"Received advertisement",
					uncompressedRspec,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				manager.advertisement = new Rspec(uncompressedRspec);
				parent.add(new ParseAdvertisementTask(manager));
				
				super.afterComplete(addCompletedMessage);
				
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
			manager.Status = FlackManager.STATUS_FAILED;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				manager
			);
			
			super.afterError(taskError);
		}
		
		override protected function runCancel():void
		{
			manager.Status = FlackManager.STATUS_UNKOWN;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				manager
			);
		}
	}
}