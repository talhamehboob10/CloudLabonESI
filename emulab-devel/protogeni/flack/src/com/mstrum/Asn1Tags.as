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
	public class Asn1Tags
	{
		// BASE
		public static const EOC:uint = 		0x00;
		public static const BOOLEAN:uint = 	0x01;
		public static const INTEGER:uint = 	0x02;
		public static const BITSTRING:uint = 0x03;
		public static const OCTETSTRING:uint = 0x04;
		public static const NULL:uint = 0x05;
		public static const OID:uint = 0x06;
		public static const OD:uint = 0x07;
		public static const EXTERNAL_INSTANCEOF:uint = 0x08;
		public static const REAL:uint = 0x09;
		public static const ENUMERATED:uint = 0x0A;
		public static const EMBEDDED_PDV:uint = 0x0B;
		public static const UTF8STRING:uint = 0x0C;
		public static const RELATIVE_OID:uint = 0x0D;
		public static const SEQ_SEQOF:uint = 0x10;
		public static const SET_SETOF:uint = 0x11;
		
		// EXTENDED
		public static const NUMERIC_STRING:uint = 0x12;
		public static const PRINTABLESTRING:uint = 0x13;
		public static const T61STRING:uint = 0x14;
		public static const VIDEOTEX_STRING:uint = 0x15;
		public static const XIA5STRING:uint = 0x16;
		public static const UTCTIME:uint = 0x17;
		public static const GENERALIZEDTIME:uint = 0x18;
		public static const GRAPHIC_STRING:uint = 0x19;
		public static const VISIBLE_STRING:uint = 0x1A;
		public static const GENERAL_STRING:uint = 0x1B;
		public static const UNIVERSAL_STRING:uint = 0x1C;
		public static const BMP_STRING:uint = 0x1E;

		// CONTEXT SPECIFIC, primitive (0xAX)
		public static const EXPLICITLYTYPED:uint = 0x00;
		public static const EXTENSIONS:uint = 0x03;
		
		// CONTEXT SPECIFIC, constructed (0x8X)
		// For subject alt name
		// http://www.x500standard.com/index.php?n=X509.X509Extensions
		public static const RFC822NAME:uint = 0x01;
		public static const UNIFORM_RESOURCE_IDENTIFIER:uint = 0x06;
	}
}