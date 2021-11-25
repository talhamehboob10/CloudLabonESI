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

package com.flack.emulab.tasks.http
{
	import com.flack.emulab.EmulabMain;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.http.HttpTask;
	import com.hurlant.util.der.PEM;
	import com.mstrum.Asn1Field;
	import com.mstrum.DER;
	import com.mstrum.Oids;
	
	import flash.utils.ByteArray;
	
	import mx.controls.Alert;
	
	public class GetUserCertTask extends HttpTask
	{
		public function GetUserCertTask()
		{
			super(
				"https://www.emulab.net/getsslcert.php3",
				"Get user cert",
				"Gets the user certificate"
			);
			relatedTo.push(SharedMain.user);
			forceSerial = true;
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			var pem:String = data as String;
			if(pem.indexOf("-----BEGIN RSA PRIVATE KEY-----") > -1 && pem.indexOf("-----BEGIN CERTIFICATE-----") > -1)
			{
				// Get what we need from the cert
				//try
				//{
					var certArray:ByteArray = PEM.readCertIntoArray(pem);
					var cert:Asn1Field = DER.Parse(certArray);
					var comNames:Vector.<Asn1Field> = cert.getHoldersFor(Oids.COMMON_NAME);
					var urlString:String = comNames[0].getValue();
					EmulabMain.manager.api.url = "https://" + urlString + ":3069/usr/testbed";
					var orgNames:Vector.<Asn1Field> = cert.getHoldersFor(Oids.ORG_NAME);
					EmulabMain.manager.hrn = orgNames[0].getValue();
					var emails:Vector.<Asn1Field> = cert.getHoldersFor(Oids.EMAIL_ADDRESS);
					EmulabMain.user.email = emails[1].getValue();
					EmulabMain.user.name = EmulabMain.user.email.substring(0, EmulabMain.user.email.indexOf('@'));
					
					EmulabMain.user.sslCert = pem;
					
					SharedMain.sharedDispatcher.dispatchChanged(
						FlackEvent.CHANGED_MANAGER,
						EmulabMain.manager,
						FlackEvent.ACTION_CREATED
					);
					SharedMain.sharedDispatcher.dispatchChanged(
						FlackEvent.CHANGED_USER,
						SharedMain.user
					);
					SharedMain.sharedDispatcher.dispatchChanged(
						FlackEvent.CHANGED_MANAGERS,
						EmulabMain.manager,
						FlackEvent.ACTION_POPULATED
					);
				/*}
				catch(e:Error)
				{
					Alert.show("bad");
					return;
				}*/
				
				if(SharedMain.user.setSecurity(pem))
				{
					Alert.show("It appears that the password is incorrect, try again", "Incorrect password");
					return;
				}
				
				super.afterComplete(addCompletedMessage);
			}
			else
			{
				Alert.show("bad");
				afterError(new TaskError());
			}
		}
	}
}