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
	import com.flack.geni.GeniCache;
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.resources.sites.GeniAuthorityCollection;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.sites.authorities.ProtogeniSliceAuthority;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.http.HttpTask;
	
	/**
	 * Downloads a public list of ProtoGENI slice authorities
	 * 
	 * @author mstrum
	 * 
	 */
	public class PublicListAuthoritiesTask extends HttpTask
	{
		public function PublicListAuthoritiesTask()
		{
			super(
				"https://www.emulab.net/protogeni/authorities/salist.txt",
				"Download authority list",
				"Gets list of slice authorities"
			);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			//GeniMain.geniUniverse.authorities = new GeniAuthorityCollection();
			
			var sliceAuthorityLines:Array = data.split(/[\n\r]+/);
			for each(var sliceAuthorityLine:String in sliceAuthorityLines)
			{
				if(sliceAuthorityLine.length == 0)
					continue;
				var sliceAuthorityLineParts:Array = sliceAuthorityLine.split(" ");
				var sliceAuthority:ProtogeniSliceAuthority =
					new ProtogeniSliceAuthority(
						sliceAuthorityLineParts[0],
						sliceAuthorityLineParts[1],
						true
					);
				if(GeniMain.geniUniverse.authorities.getByUrl(sliceAuthority.url) == null)
					GeniMain.geniUniverse.authorities.add(sliceAuthority);
				addMessage(
					"Added authority: " + sliceAuthority.name,
					sliceAuthority.toString()
				);
			}
			
			var manuallyAddedAuthorities:GeniAuthorityCollection = GeniCache.getManualAuthorities();
			for each(var cachedAuthority:GeniAuthority in manuallyAddedAuthorities.collection)
			{
				if(GeniMain.geniUniverse.authorities.getByUrl(cachedAuthority.url) == null)
				{
					GeniMain.geniUniverse.authorities.add(cachedAuthority);
					addMessage(
						"Added cached authority: " + sliceAuthority.name,
						sliceAuthority.toString()
					);
				}
			}
			
			addMessage(
				GeniMain.geniUniverse.authorities.length+" authorities loaded",
				GeniMain.geniUniverse.authorities.length+" authorities loaded",
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
			
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_AUTHORITIES,
				null,
				FlackEvent.ACTION_POPULATED
			);
			
			super.afterComplete(addCompletedMessage);
		}
	}
}