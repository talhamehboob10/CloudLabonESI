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

package com.flack.shared.utils
{
	import flash.external.ExternalInterface;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	import flash.net.navigateToURL;
	import flash.system.Security;
	import flash.utils.Dictionary;
	
	import mx.core.FlexGlobals;
	import mx.utils.StringUtil;
	
	/**
	 * Common functions used for web stuff
	 * 
	 * @author mstrum
	 * 
	 */
	public final class NetUtil
	{
		public static const flashSocketSecurityPolicyUrl:String = "http://www.protogeni.net/trac/protogeni/wiki/FlackManual#AddingaFlashSocketSecurityPolicyServer";
		public static function openWebsite(url:String):void
		{
			navigateToURL(new URLRequest(url), "_blank");
		}
		
		public static function openMail(receiverEmail:String, subject:String, body:String):void
		{
			var mailRequest:URLRequest = new URLRequest("mailto:" + receiverEmail);
			var mailVariables:URLVariables = new URLVariables();
			mailVariables.subject = subject;
			mailVariables.body = body;
			mailRequest.data = mailVariables;
			navigateToURL(mailRequest, "_blank");
		}
		
		public static function runningFromWebsite():Boolean
		{
			return FlexGlobals.topLevelApplication.url.toLowerCase().indexOf("http") == 0;
		}
		
		public static function tryGetBaseUrl(url:String):String
		{
			var hostPattern:RegExp = /^(http(s?):\/\/([^\/]+))(\/.*)?$/;
			var match : Object = hostPattern.exec(url);
			if (match != null)
			{
				if((match[1] as String).split(":").length > 2)
					return (match[1] as String).substr(0, (match[1] as String).lastIndexOf(":"));
				else
					return match[1] as String;
			}
			else
				return url;
		}
		
		public static function getBrowserName():String
		{
			var browser:String;
			var browserAgent:String = ExternalInterface.call("function getBrowser(){return navigator.userAgent;}");
			
			if(browserAgent == null)
				return "Undefined";
			else if(browserAgent.indexOf("Firefox") >= 0)
				browser = "Firefox";
			else if(browserAgent.indexOf("Safari") >= 0)
				browser = "Safari";
			else if(browserAgent.indexOf("MSIE") >= 0)
				browser = "IE";
			else if(browserAgent.indexOf("Opera") >= 0)
				browser = "Opera";
			else
				browser = "Undefined";
			
			return (browser);
		}
		
		// Takes the given bandwidth and creates a human readable string
		public static function kbsToString(bandwidth:Number):String
		{
			if(bandwidth < 1000)
				return bandwidth + " Kb/s";
			else if(bandwidth < 1000000)
				return bandwidth / 1000 + " Mb/s";
			else
				return bandwidth / 1000000 + " Gb/s";
		}
		
		private static var visitedSites:Dictionary = new Dictionary();
		public static function checkLoadCrossDomain(url:String):void
		{
			var hostPattern:RegExp = /^(http(s?):\/\/([^\/]+))(\/.*)?$/;
			var match : Object = hostPattern.exec(url);
			
			var baseUrl:String = tryGetBaseUrl(url);
			if (visitedSites[baseUrl] == null)
			{
				visitedSites[baseUrl] = true;
				Security.loadPolicyFile(baseUrl + "/protogeni/crossdomain.xml");
				Security.loadPolicyFile(baseUrl + "/crossdomain.xml");
				//Security.loadPolicyFile("http://" + (match[3] as String).split(':')[0] + ":843");
			}
			
			// Try loading all crossdomain files in the path
			var directories:Array = (match[4] as String).split('/');
			var currentPath:String = baseUrl;
			for (var i:int = 1; i < directories.length-1; i++) {
				currentPath += "/" + directories[i];
				Security.loadPolicyFile(currentPath + "/crossdomain.xml");
			}
		}
	}
}