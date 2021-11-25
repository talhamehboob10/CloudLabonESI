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

package com.flack.geni.tasks.http
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.tasks.http.HttpTask;
	
	/**
	 * Downloads a list of cached advertisements
	 * 
	 * @author mstrum
	 * 
	 */
	public final class PublicListManagersTask extends HttpTask
	{
		public function PublicListManagersTask()
		{
			super(
				"https://www.emulab.net/protogeni/pub/list.txt", // advertisements
				"Download advertisement list",
				"Gets the list of advertisements"
			);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			GeniMain.geniUniverse.managers = new GeniManagerCollection();
			
			var lines:Array = (data as String).split(/[\n\r]+/); // no +?
			for each(var line:String in lines)
			{
				if(line.length == 0)
					continue;
				// Need a way to know the manager type and/or api...
				var newManager:GeniManager = new GeniManager(GeniManager.TYPE_PROTOGENI, ApiDetails.API_PROTOGENI, line);
				newManager.url = url.substring(0, url.lastIndexOf('/')+1) + line;
				newManager.hrn = newManager.id.authority;
				GeniMain.geniUniverse.managers.add(newManager);
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_MANAGER,
					newManager,
					FlackEvent.ACTION_CREATED
				);
				addMessage(
					"Added manager",
					newManager.toString())
				;
			}
			
			addMessage(
				"Added "+GeniMain.geniUniverse.managers.length+" managers",
				"Added "+GeniMain.geniUniverse.managers.length+" managers",
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
			
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGERS,
				null,
				FlackEvent.ACTION_POPULATED
			);
			
			super.afterComplete(addCompletedMessage);
		}
	}
}