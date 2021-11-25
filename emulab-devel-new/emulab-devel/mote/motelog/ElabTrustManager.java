/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

import javax.net.ssl.*;
import java.io.*;
import java.security.cert.*;
import java.security.*;
import java.util.Arrays;


public class ElabTrustManager implements X509TrustManager {

    private static final String CA_CERT = "/etc/emulab/client.pem";
    private static final String CLIENT_CERT = "/etc/emulab/emulab.pem";

    private byte[] digest;
    
    public ElabTrustManager() 
	throws FileNotFoundException, CertificateException, 
	       NoSuchAlgorithmException, CertificateEncodingException {
	this(new File(CLIENT_CERT));
    }

    public ElabTrustManager(File certFile) 
	throws FileNotFoundException, CertificateException, 
	       NoSuchAlgorithmException, CertificateEncodingException {
	InputStream is = new FileInputStream(certFile);
	CertificateFactory cf = CertificateFactory.getInstance("X.509");
	X509Certificate cert = (X509Certificate)cf.generateCertificate(is);

	MessageDigest md = MessageDigest.getInstance("SHA");
	this.digest = md.digest(cert.getEncoded());
    }

    public ElabTrustManager(String digest) {
	this(hexToBytes(digest));
    }

    public ElabTrustManager(byte[] digest) {
	this.digest = digest;
    }

    /**
     * Radix for hexadecimal numbers.
     */
    private static final int HEX_RADIX = 16;
    
    /* from tim... */
    /**
     * Convert a hexadecimal encoded string into a byte array.
     * 
     * TODO: Move elsewhere...
     * 
     * @param str The hexadecimal encoded string to convert.
     * @return The byte array that was encoded in the given string.
     * @throws NumberFormatException If there was a problem while decoding the
     * string.
     */
    private static byte[] hexToBytes(String str)
	throws NumberFormatException
    {
	byte retval[] = new byte[str.length() / 2];
	int lpc;

	for( lpc = 0; lpc < retval.length; lpc++ )
	{
	    int lo, hi;

	    hi = Character.digit(str.charAt(lpc * 2), HEX_RADIX);
	    lo = Character.digit(str.charAt(lpc * 2 + 1), HEX_RADIX);
	    if( hi == -1 || lo == -1 )
		throw new NumberFormatException(str);
	    retval[lpc] = (byte) ((hi << 4) | lo);
	}
	return retval;
    }
    
    public void checkClientTrusted(X509Certificate chain[], String authType) {
    }
    
    public void checkServerTrusted(X509Certificate chain[], String authType)
	throws CertificateException {
	try {
	    MessageDigest md = MessageDigest.getInstance("SHA");
	    byte certHash[];
	    
	    /** we DO NOT try to auth the server, just check its consistency */

	    certHash = md.digest(chain[0].getEncoded());
	    if( !Arrays.equals(certHash, this.digest) ) {
		System.out.println("bad certificate!");
		throw new CertificateException(
			"Certificate for "
			+ chain[0].getSubjectDN()
			+ " does not match finger print");
	    }
	}
	catch(NoSuchAlgorithmException e) {
	    throw new CertificateException(
		"Unable to verify certificate because: " + e.getMessage());
	}
    }
    
    // don't need this...
    public X509Certificate[] getAcceptedIssuers() {
	return null;
    }
    
    public String toString() {
	return "ElabTrustManager[digest="+this.digest+"]";
    }
}
