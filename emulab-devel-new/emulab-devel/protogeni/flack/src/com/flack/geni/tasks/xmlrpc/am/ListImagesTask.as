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
	import com.flack.geni.resources.DiskImage;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Sliver;
	import com.flack.geni.resources.virt.VirtualComponent;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.utils.DateUtil;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Lists a user's disk images at a ProtoGENI site.
	 * 
	 * ProtoGENI AM
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ListImagesTask extends AmXmlrpcTask
	{
		public var manager:GeniManager;
		public var creatorUrn:String;
		
		/**
		 * 
		 * @param newSliver Sliver for which to list resources allocated to the sliver's slice
		 * 
		 */
		public function ListImagesTask(newCreatorUrn:String, newManager:GeniManager)
		{
			var creatorName:String = newCreatorUrn;
			if(IdnUrn.isIdnUrn(creatorName))
				creatorName = (new IdnUrn(creatorName)).name;
			
			super(
				newManager.api.url,
				AmXmlrpcTask.METHOD_LISTIMAGES,
				newManager.api.version,
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
			var options:Object = {};
			addOrderedField(creatorUrn);
			addOrderedField([AmXmlrpcTask.credentialToObject(GeniMain.geniUniverse.user.credential, apiVersion)]);
			addOrderedField(options);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if(genicode == AmXmlrpcTask.GENICODE_SUCCESS)
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
	}
}