/*
 * Automatically generated by jrpcgen 1.0.5 on 1/8/05 2:03 PM
 * jrpcgen is part of the "Remote Tea" ONC/RPC package for Java
 * See http://acplt.org/ks/remotetea.html for details
 */
package net.emulab;
import org.acplt.oncrpc.*;
import java.io.IOException;

public class mtp_packet implements XdrAble {
    public short vers;
    public short role;
    public mtp_payload data;

    public mtp_packet() {
    }

    public mtp_packet(XdrDecodingStream xdr)
           throws OncRpcException, IOException {
        xdrDecode(xdr);
    }

    public void xdrEncode(XdrEncodingStream xdr)
           throws OncRpcException, IOException {
        xdr.xdrEncodeShort(vers);
        xdr.xdrEncodeShort(role);
        data.xdrEncode(xdr);
    }

    public void xdrDecode(XdrDecodingStream xdr)
           throws OncRpcException, IOException {
        vers = xdr.xdrDecodeShort();
        role = xdr.xdrDecodeShort();
        data = new mtp_payload(xdr);
    }

}
// End of mtp_packet.java
