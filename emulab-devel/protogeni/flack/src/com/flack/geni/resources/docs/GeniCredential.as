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

package com.flack.geni.resources.docs
{
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.utils.DateUtil;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Credential for a GENI object
	 * 
	 * @author mstrum
	 * 
	 */
	public class GeniCredential
	{
		// Types
		public static const TYPE_USER:int = 0;
		public static const TYPE_SLICE:int = 1;
		public static const TYPE_SLIVER:int = 2;
		public static const TYPE_UNKNOWN:int = 4;
		
		private var _xml:XML = null;
		private var _raw:String = "";
		[Bindable]
		public function get Raw():String
		{
			return _raw;
		}
		public function set Raw(value:String):void
		{
			if(value == null || value.length == 0)
			{
				_raw = "";
				_xml = null;
				return;
			}
			_raw = value;
			if(_raw.length == 0)
				_xml = null;
			try
			{
				_xml = new XML(_raw);
				if(_xml.toXMLString().length == 0)
					_xml = null;
			}
			catch(e:Error)
			{
				_xml = null;
			}
		}
		public function get Xml():XML
		{
			return _xml;
		}
		
		private function get OwnerId():IdnUrn
		{
			try
			{
				return new IdnUrn(_xml.credential.owner_urn)
			}
			catch(e:Error)
			{
			}
			
			return null;
		}
		
		private function get TargetId():IdnUrn
		{
			try
			{
				return new IdnUrn(_xml.credential.target_urn)
			}
			catch(e:Error)
			{
			}
			return null;
		}
		
		public function getIdWithType(specifiedType:String):IdnUrn
		{
			var ownerId:IdnUrn = OwnerId;
			if(ownerId != null && ownerId.type == specifiedType)
				return ownerId;
			var targetId:IdnUrn = TargetId;
			if(targetId != null && targetId.type == specifiedType)
				return targetId;
			return null;
		}
		
		public function get Expires():Date
		{
			try
			{
				// Fix UTC times which don't have a Z
				var expiresStr:String = _xml.credential.expires;
				var timeStr:String = expiresStr.substring(expiresStr.indexOf("T")+1, expiresStr.length);
				if (timeStr.indexOf("Z") == -1
					&& timeStr.indexOf("+") == -1
					&& timeStr.indexOf("-") == -1)
				{
					expiresStr = StringUtil.makeSureEndsWith(expiresStr, "Z");
				}
				return DateUtil.parseRFC3339(expiresStr);
			}
			catch(e:Error)
			{
			}
			return null;
		}
		
		/**
		 * What type of object is this a credential for?
		 */
		public var type:int;
		
		public var version:GeniCredentialVersion;
		
		/**
		 * 
		 * @return Detected type if understandable by Flack.
		 * 
		 */
		public function get GuessedType():int
		{
			var ownerId:IdnUrn = OwnerId;
			var targetId:IdnUrn = TargetId;
			if(targetId != null) {
				if(targetId.type == IdnUrn.TYPE_SLIVER || ownerId.type == IdnUrn.TYPE_SLIVER)
					return TYPE_SLIVER;
				if(targetId.type == IdnUrn.TYPE_SLICE || ownerId.type == IdnUrn.TYPE_SLICE)
					return TYPE_SLICE;
				if(targetId.type == IdnUrn.TYPE_USER || ownerId.type == IdnUrn.TYPE_USER)
					return TYPE_USER;
			}
			return TYPE_UNKNOWN;
		}
		
		/**
		 * What gave us this credential?
		 */
		public var source:IdentifiableObject;
		
		/**
		 * 
		 * @param stringRepresentation Credential in string form
		 * @param newType What is this a credential for?
		 * @param newSource Where did this credential come from?
		 * 
		 */
		public function GeniCredential(stringRepresentation:String = "",
									   newType:int = TYPE_UNKNOWN,
									   newSource:IdentifiableObject = null,
									   newVersion:GeniCredentialVersion = null)
		{
			Raw = stringRepresentation;
			source = newSource;
			version = newVersion;
			if(version == null)
				version = GeniCredentialVersion.Default;
			
			// Set the type if we understand this credential.
			type = newType;
			if(stringRepresentation.length > 0 && type == TYPE_UNKNOWN)
				type = GuessedType;
		}
	}
}