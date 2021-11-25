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

package com.mstrum
{
	import flash.utils.ByteArray;

	public class Asn1Field
	{
		public var identifierClass:uint;
		public var identifierTag:uint;
		public var identifierConstructed:Boolean; // false = primitive
		
		public var length:uint;
		
		public var rawContents:ByteArray;
		public var contents:*;
		
		public var parent:Asn1Field;
		
		public function Asn1Field(newParent:Asn1Field = null)
		{
			rawContents = new ByteArray();
			parent = newParent;
		}
		
		public function getValue():* {
			if(contents is Array) {
				var valueIdx:int = 0;
				if(contents[0] is Asn1Field && contents[0].identifierClass == Asn1Classes.UNIVERSAL && contents[0].identifierTag == Asn1Tags.OID)
					valueIdx = contents.length-1;
				if(contents[valueIdx] is Asn1Field)
					return contents[valueIdx].getValue();
				else
					return contents[valueIdx];
			} else if(contents is Asn1Field)
				return contents.getValue();
			else
				return contents;
		}
		
		public function getHoldersFor(oid:String):Vector.<Asn1Field> {
			var holders:Vector.<Asn1Field> = new Vector.<Asn1Field>();
			if(identifierTag == Asn1Tags.OID) {
				if(contents == oid)
				{
					holders.push(parent);
					return holders;
				}
			} else if(contents is Asn1Field) {
				return contents.getHoldersFor(oid);
			} else if(contents is Array) {
				for each(var child:Asn1Field in contents) {
					var resultField:Vector.<Asn1Field> = child.getHoldersFor(oid);
					for each(var f:Asn1Field in resultField)
						holders.push(f);
				}
			}
			return holders;
		}
		
		public function getHolderFor(oid:String):Asn1Field {
			if(identifierTag == Asn1Tags.OID) {
				if(contents == oid)
					return parent;
				else
					return null;
			} else if(contents is Asn1Field) {
				return contents.getHolderFor(oid);
			} else if(contents is Array) {
				for each(var child:Asn1Field in contents) {
					var resultField:Asn1Field = child.getHolderFor(oid);
					if(resultField != null)
						return resultField;
				}
			}
			return null;
		}
	}
}