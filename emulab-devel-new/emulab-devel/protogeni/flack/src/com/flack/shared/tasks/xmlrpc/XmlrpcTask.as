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

package com.flack.shared.tasks.xmlrpc
{
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.TaskGroup;
	import com.flack.shared.utils.MathUtil;
	import com.flack.shared.utils.NetUtil;
	import com.flack.shared.utils.StringUtil;
	import com.mattism.http.xmlrpc.ConnectionImpl;
	import com.mattism.http.xmlrpc.MethodFault;
	
	import flash.display.Sprite;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	
	/**
	 * Everything needed to run a XML-RPC call
	 * 
	 * @author mstrum
	 * 
	 */
	public class XmlrpcTask extends Task
	{
		protected var server:ConnectionImpl;
		
		// Object which will be used as the argument to the XML-RPC call
		private var param:Object;
		
		// URL of the XML-RPC server
		public var url:String;
		
		// Method for this call
		public var method:String;
		
		// Options for retries
		public var maxTries:int = 10;
		public var promptAfterMaxTries:Boolean = true;
		
		public var errorLogUrn:String = "";
		public var errorLogUrl:String = "";
		public function get ErrorLog():String {
			var errorLog:String = "";
			if(errorLogUrl.length > 0)
				errorLog += "For more information, please visit: " + errorLogUrl;
			if(errorLogUrn.length > 0)
			{
				if(errorLog.length > 0)
					errorLog += "\n";
				errorLog += "For reference, the ProtoGENI error URN is: " + errorLogUrn;
			}
			return errorLog;
		}
		public function get ErrorLogHtml():String {
			var errorLog:String = "";
			if(errorLogUrl.length > 0)
				errorLog += "For more information, please visit: <a href=\"" + errorLogUrl + "\">" + errorLogUrl + "</a>";
			if(errorLogUrn.length > 0)
			{
				if(errorLog.length > 0)
					errorLog += "<br>";
				errorLog += "For reference, the error id is: <a href=\"" + errorLogUrn + "\">" + errorLogUrn + "</a>";
			}
			return errorLog;
		}
		
		/**
		 * 
		 * @param taskUrl URL to make the XML-RPC call at
		 * @param taskMethod XML-RPC method name
		 * @param taskName
		 * @param taskDescription
		 * @param taskShortName
		 * @param taskParent
		 * @param taskRetryWhenPossible
		 * 
		 */
		public function XmlrpcTask(taskUrl:String,
								   taskMethod:String,
								   taskName:String = "XML-RPC Task",
								   taskDescription:String = "Calls a XML-RPC service",
								   taskShortName:String = "",
								   taskParent:TaskGroup = null,
								   taskRetryWhenPossible:Boolean = true)
		{
			super(
				taskName,
				taskDescription,
				taskShortName,
				taskParent,
				300,
				0,
				taskRetryWhenPossible
			);
			url = taskUrl;
			method = taskMethod;
		}
		
		/**
		 * Makes the arguments an ordered list
		 * 
		 */
		public function setOrdered():void
		{
			param = [];
		}
		/**
		 * Adds the given argument to the end of the arguments to be included
		 * 
		 * @param value Argument to include
		 * 
		 */
		public function addOrderedField(value:Object):void
		{
			if(param == null || !(param is Array))
				setOrdered();
			(param as Array).push(value);
		}
		
		/**
		 * Makes the arguments an unordered list with named fields
		 * 
		 */
		public function setNamed():void
		{
			param = {};
		}
		/**
		 * Adds the given value to the arguments with the given key
		 * @param key Name of the argument
		 * @param value Argument
		 * 
		 */
		public function addNamedField(key:String, value:Object):void
		{
			if(param == null || param is Array)
				setNamed();
			param[key] = value;
		}
		
		/**
		 * Clears the arguments which have been added
		 * 
		 * Called every runStart() before createFields()
		 * 
		 */
		public function clearFields():void
		{
			param = null;
		}
		
		/**
		 * IMPLEMENT and if needed add named OR ordered arguments
		 * 
		 * Called in runStart()
		 * 
		 */
		protected function createFields():void
		{
			/* IMPLEMENT */
		}
		
		override protected function runStart():void
		{
			try
			{
				clearFields();
				createFields();
				server = new ConnectionImpl(url);
				server.addEventListener(Event.COMPLETE, callSuccess);
				server.addEventListener(ErrorEvent.ERROR, callErrorFailure);
				server.addEventListener(IOErrorEvent.IO_ERROR, callErrorFailure);
				server.addEventListener(IOErrorEvent.NETWORK_ERROR, callErrorFailure);
				server.addEventListener(SecurityErrorEvent.SECURITY_ERROR, callErrorFailure);
				if(param is Array)
				{
					for each(var o:* in param)
						server.addParam(o, null);
				}	
				else if(param != null)
					server.addParam(param, "struct");
				server.call(method);
				
				autoUpdate = new Timer(1000);
				autoUpdate.addEventListener(TimerEvent.TIMER, onAutoUpdate);
				autoUpdate.start();
				
				addMessage(
					"Sent request",
					"URL: " + url + "\nRequest:\n" +
						String(server._request.data),
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
			}
			catch (e:Error)
			{
				afterError(
					new TaskError(
						StringUtil.errorToString(e),
						TaskError.FAULT
					)
				);
			}
		}
		private function onAutoUpdate(evt:TimerEvent):void
		{
			Message = "Waited "+autoUpdate.currentCount+" seconds for response...";
		}
		
		/**
		 * Callback on a successfull XML-RPC call.
		 * 
		 * EXTEND afterComplete() if working with the result (*.data)
		 * 
		 * @param event
		 * 
		 */
		public function callSuccess(event:Event):void
		{
			cancelTimers();
			
			data = server.getResponse();
			
			addMessage(
				"Received response",
				server._response.data
			);
			
			afterComplete(false);
		}
		
		/**
		 * Callback on a general-error failed XML-RPC call
		 * 
		 * EXTEND afterError() if you need to deal with this in detail
		 * 
		 * @param event
		 * 
		 */
		public function callErrorFailure(event:ErrorEvent):void
		{
			var fault:MethodFault = server.getFault();
			if(fault != null)
			{
				switch(fault.getFaultCode())
				{
					// Happens when too many users are calling the server in ProtoGENI
					// Restart
					case XmlrpcUtil.FAULTCODE_CURRENTLYNOTAVAILABLE:
						addMessage(
							"Server currently not available",
							"XML-RPC server reported currently not available.",
							LogMessage.LEVEL_WARNING
						);
						runTryRetry();
						return;
					case XmlrpcUtil.FAULTCODE_RESOURCEISBUSY:
						addMessage(
							"Resources is busy",
							"XML-RPC server reported resource is busy.",
							LogMessage.LEVEL_WARNING
						);
						runTryRetry();
						return;
					default:
						afterError(
							new TaskError(
								fault.toString(),
								TaskError.FAULT,
								fault
							)
						);
				}
			}
			else
			{
				if(event != null &&
					event.text != null)
				{
					if(event.text.indexOf("2048") != -1)
					{
						afterError(
							new TaskError(
								"Can't connect to socket. Either server can't be reached or the flash socket security policy has not been installed. To check for the security policy, follow the directions at "+NetUtil.flashSocketSecurityPolicyUrl+". Error text was: " + event.text,
								TaskError.FAULT,
								event
							)
						);
						return;
					}
					else if(event.text.indexOf("Certificate revoked") != -1)
					{
						Alert.show("Certificate no longer valid, please make sure your are using your newest certificate!", "Certificate Revoked");
						afterError(
							new TaskError(
								"Certificate no longer valid, please make sure your are using your newest certificate! Error text was: " + event.text,
								TaskError.FAULT,
								event
							)
						);
						return;
					}
					else if(event.text.indexOf("Certificate expir") != -1)
					{
						Alert.show("Certificate expired, please generate a new certificate at your authority!", "Certificate Expired");
						afterError(
							new TaskError(
								"Certificate expired, please generate a new certificate at your authority! Error text was: " + event.text,
								TaskError.FAULT,
								event
							)
						);
						return;
					}
				}
				afterError(
					new TaskError(
						event.text,
						TaskError.FAULT,
						event
					)
				);
			}
		}
		
		public function runTryRetry():void
		{
			if(numberTries >= maxTries)
			{
				if(promptAfterMaxTries)
				{
					Alert.show(Name + " has tried " + numberTries + " times without succeeding, continue trying until it succeeds?", "Continue trying?", Alert.YES|Alert.NO, FlexGlobals.topLevelApplication as Sprite,
						function chooseWhetherToContinue(e:CloseEvent):void
						{
							if(e.detail == Alert.YES)
							{
								maxTries = int.MAX_VALUE
								runRetry();
							}
							else
							{
								afterError(
									new TaskError(
										"User stopped retrying",
										TaskError.FAULT
									)
								);
							}
						}
					);
				}
				else
				{
					afterError(
						new TaskError(
							"Exceeded number of tries.",
							TaskError.FAULT
						)
					);
				}
			}
			else
				runRetry();
		}
		
		protected function runRetry(newDelay:int=-1):void
		{
			if(newDelay == -1)
				delay =  MathUtil.randomNumberBetween(20, 60);
			else
				delay = newDelay;
			delay =  MathUtil.randomNumberBetween(20, 60);
			addMessage(
				"Scheduling retry",
				"Delaying call for " + delay + " seconds.",
				LogMessage.LEVEL_WARNING
			);
			runCleanup();
			start();
		}
		
		override protected function runTimeout():Boolean
		{
			// No more tries
			if(numberTries >= maxTries)
				return true;
			// XXX include runTryRetry
			// XXX BACKOFF
			// Clean up state if we will retry
			if(retryWhenPossible)
				runCleanup();
			return super.runTimeout();
		}
		
		/**
		 * Cancels the XML-RPC call
		 * 
		 */
		override protected function runCancel():void
		{
			if(server != null)
				server.cancel();
		}
		
		override protected function runCleanup():void
		{
			if (server != null)
			{
				clearFields();
				server.cleanup();
				server.removeEventListener(Event.COMPLETE, callSuccess);
				server.removeEventListener(ErrorEvent.ERROR, callErrorFailure);
				server.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, callErrorFailure);
				server.removeEventListener(IOErrorEvent.IO_ERROR, callErrorFailure);
				server.removeEventListener(IOErrorEvent.NETWORK_ERROR, callErrorFailure);
				server = null;
			}
		}
	}
}