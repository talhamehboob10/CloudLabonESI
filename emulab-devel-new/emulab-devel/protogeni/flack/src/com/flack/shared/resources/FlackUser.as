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

package com.flack.shared.resources
{
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.utils.StringUtil;
	import com.mattism.http.xmlrpc.JSLoader;

	/**
	 * GENI user
	 * 
	 * @author mstrum
	 * 
	 */
	public class FlackUser extends IdentifiableObject
	{
		[Bindable]
		public var uid:String = "";
		
		[Bindable]
		public var hrn:String = "";
		[Bindable]
		public var email:String = "";
		[Bindable]
		public var name:String = "";
		
		public var hasSetupSecurity:Boolean = false;
		
		public var password:String = "";
		[Bindable]
		public var sslCert:String = "";
		public function get PrivateKey():String
		{
			var startIdx:int = sslCert.indexOf("-----BEGIN RSA PRIVATE KEY-----");
			var endIdx:int = sslCert.lastIndexOf("-----END RSA PRIVATE KEY-----") + 30;
			if(startIdx != -1 && endIdx != -1)
				return sslCert.substring(startIdx, endIdx);
			else
				return "";
		}
		
		public function get PrivateKeyEncrypted():Boolean
		{
			return PrivateKey.indexOf("DEK-Info:") > -1;
		}
		
		public function get SslCertReady():Boolean
		{
			if(sslCert.length > 0) {
				var isPrivateKeyEncrypted:Boolean = PrivateKeyEncrypted;
				return !isPrivateKeyEncrypted || (isPrivateKeyEncrypted && password.length > 0);
			}
			return false;
		}
		
		public function FlackUser()
		{
			super();
		}
		
		public function get CertificateSetUp():Boolean
		{
			return hasSetupSecurity;// && (authority != null || credential != null);
		}
		
		/**
		 * 
		 * @param newPassword Password for the user's private key
		 * @param newCertificate SSL certificate to use
		 * @return TRUE if failed, FALSE if successful
		 * 
		 */
		public function setSecurity(newCertificate:String, newPassword:String=""):Boolean
		{
			if(newCertificate.length > 0)
			{
				try
				{
					JSLoader.setClientInfo(newPassword, newCertificate);
					password = newPassword;
					sslCert = newCertificate;
					hasSetupSecurity = true;
					return false;
				}
				catch (e:Error)
				{
					SharedMain.logger.add(
						new LogMessage(
							[this],
							"",
							"User Security",
							"Problem setting user credentials in Forge: " + StringUtil.errorToString(e),
							"",
							LogMessage.LEVEL_FAIL
						)
					);
				}
			}
			return true;
		}
	}
}