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
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.DiskImage;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.StringUtil;
	
	import mx.controls.Alert;
	
	/**
	 * Renews the sliver until the given date
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ListImagesCmTask extends ProtogeniXmlrpcTask
	{
		public var manager:GeniManager;
		public var creatorUrn:String;
		
		/**
		 * 
		 * @param renewSliver Sliver to renew
		 * @param newExpirationDate Desired expiration date
		 * 
		 */
		public function ListImagesCmTask(newCreatorUrn:String, newManager:GeniManager)
		{
			var creatorName:String = newCreatorUrn;
			if(IdnUrn.isIdnUrn(creatorName))
				creatorName = (new IdnUrn(creatorName)).name;
			
			super(
				newManager.url,
				ProtogeniXmlrpcTask.MODULE_CM,
				ProtogeniXmlrpcTask.METHOD_LISTIMAGES,
				"Listing images for user " + creatorName + " at " + newManager.hrn,
				"Listing images for user '" + creatorName + "' @ " + newManager.hrn,
				"List images"
			);
			relatedTo.push(newManager);
			creatorUrn = newCreatorUrn;
			manager = newManager;
			numberTries = 1;
		}
		
		override protected function createFields():void
		{
			addNamedField("creator_urn", creatorUrn);
			addNamedField("credentials", [GeniMain.geniUniverse.user.credential.Raw]);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
			{
				GeniMain.geniUniverse.userDiskImages.removeAll(
					GeniMain.geniUniverse.userDiskImages.getByAuthority(manager.id.authority).getByCreator(creatorUrn));
				for each(var diskImageObj:* in data)
				{
					var diskImage:DiskImage = new DiskImage(diskImageObj.urn);
					diskImage.url = diskImageObj.url;
					diskImage.creator = creatorUrn;
					diskImage.description = diskImage.ShortId + " / " + StringUtil.shortenString(diskImage.url, 30);
					GeniMain.geniUniverse.userDiskImages.add(diskImage);
				}
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_USERDISKIMAGES,
					creatorUrn
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				faultOnSuccess();
			}
		}
		
		override protected function afterError(taskError:TaskError):void
		{
			if((taskError.message as String).indexOf("not XML") != -1)
			{
				Alert.show("It appears that this manager doesn't support listing images.");
			}
			
			super.afterError(taskError);
		}
	}
}