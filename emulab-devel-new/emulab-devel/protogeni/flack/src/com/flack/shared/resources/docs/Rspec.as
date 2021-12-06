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

package com.flack.shared.resources.docs
{
	/**
	 * Holds a resource-description document as well as some meta info
	 * 
	 * @author mstrum
	 * 
	 */
	public class Rspec
	{
		// Types
		static public const TYPE_ADVERTISEMENT:String = "advertisement";
		static public const TYPE_REQUEST:String = "request";
		static public const TYPE_MANIFEST:String = "manifest";
		
		/**
		 * Full RSPEC as a string
		 */
		public var document:String = "";
		
		/**
		 * Version information
		 */
		public var info:RspecVersion;
		/**
		 * When the document was generated
		 */
		public var generated:Date;
		/**
		 * When the document will expire
		 */
		public var expires:Date;
		/**
		 * What type is the document
		 */
		public var type:String;
		
		/**
		 * 
		 * @param newDocument String representation
		 * @param newVersion Version information
		 * @param newGenerated When was this generated?
		 * @param newExpires When does it expire?
		 * @param newType What type of RSPEC is this?
		 * 
		 */
		public function Rspec(newDocument:String = "",
							  newVersion:RspecVersion = null,
							  newGenerated:Date = null,
							  newExpires:Date = null,
							  newType:String = "")
		{
			if(newDocument != null)
				document = newDocument;
			info = newVersion;
			generated = newGenerated;
			expires = newExpires;
			type = newType;
		}
	}
}