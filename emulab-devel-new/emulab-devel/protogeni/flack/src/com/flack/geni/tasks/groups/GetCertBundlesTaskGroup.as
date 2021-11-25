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

package com.flack.geni.tasks.groups
{
	import com.flack.geni.GeniMain;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.ParallelTaskGroup;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.http.HttpTask;
	import com.flack.shared.tasks.http.JsHttpTask;
	
	/**
	 * Downloads and applies any certificate bundles needed
	 * 
	 * @author mstrum
	 * 
	 */
	public class GetCertBundlesTaskGroup extends ParallelTaskGroup
	{
		/**
		 * 
		 * @param extraBundleUrls List of bundle urls to include
		 * 
		 */
		public function GetCertBundlesTaskGroup(extraBundleUrls:Vector.<String> = null)
		{
			super(
				"Download cert bundles",
				"Downloads server certificate bundles"
			);
			
			add(
				new HttpTask(
                                        "https://www.emulab.net/rootca.bundle",
					"Download root bundle",
					"Downloads the root cert bundle"
				)
			);
			
			add(
				new HttpTask(
                                        "https://www.emulab.net/genica.bundle",
					"Download GENI bundle",
					"Downloads the GENI cert bundle"
				)
			);
			
			if(extraBundleUrls != null && extraBundleUrls.length > 0) {
				for each(var certUrl:String in extraBundleUrls) {
					add(
						new JsHttpTask(
							certUrl,
							"Download extra bundle",
							"Downloads an extra bundle"
						)
					);
				}
			}
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			combineAndApplyBundles();
			
			if(GeniMain.skipStartup &&
				!GeniMain.geniUniverse.user.CertificateSetUp &&
				GeniMain.geniUniverse.user.SslCertReady) {
				GeniMain.geniUniverse.user.setSecurity(GeniMain.geniUniverse.user.sslCert, GeniMain.geniUniverse.user.password);
				GeniMain.geniUniverse.loadAuthenticated();
			}
			
			super.afterComplete(addCompletedMessage);
		}
		
		/**
		 * Combine all of the server cert bundles we recieved and use them
		 * 
		 */
		private function combineAndApplyBundles():void {
			var combinedBundle:String = "";
			for each(var bundleTask:Task in tasks.collection)
			{
				if(bundleTask.data != null)
					combinedBundle += bundleTask.data + "\n";
			}
			
			SharedMain.Bundle = combinedBundle;
			
			addMessage(
				"Bundles applied",
				combinedBundle,
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
		}
	}
}