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
	// Example for looking up an OID: http://www.alvestrand.no/objectid/2.5.4.html
	public class Oids
	{
		// See: https://nmparsers.svn.codeplex.com/svn/Verified_Build_Branch/NPL/common/asnber.npl
		public static function getNameFor(oid:String):String {
			switch(oid) {
				case "0.0.20.124.0.1": return "Generic Conference Contro";
				case "1.3.6.1.4.1.311.2.1.14": return "X509Extensions";
				case "1.3.6.1.4.1.311.13.2.2": return "EnrollmentCspProvider";
				case "1.3.6.1.4.1.311.47.1.1": return "SoHCertificateExtension";
				case "1.3.6.1.4.1.311.13.2.3": return "OsVersion";
				case "1.3.6.1.4.1.311.13.1": return "RenewalCertificate";
				case "1.3.6.1.4.1.311.20.2": return "Certificate Template";
				case "1.3.6.1.4.1.311.21.20": return "RequestClientInfo";
				case "1.3.6.1.4.1.311.21.13": return "ArchivedKeyAttr";
				case "1.3.6.1.4.1.311.21.21": return "EncryptedKeyHash";
				case "1.3.6.1.4.1.311.13.2.1": return "EnrollmentNameValuePair";
				case "2.5.4.41": return "IdAtName";
				case "2.5.4.3": return "IdAtCommonName";
				case "2.5.4.7": return "IdAtLocalityName";
				case "2.5.4.8": return "IdAtStateOrProvinceName";
				case "2.5.4.10": return "IdAtOrganizationName";
				case "2.5.4.11": return "IdAtOrganizationalUnitName";
				case "2.5.4.12": return "IdAtTitle";
				case "2.5.4.46": return "IdAtDnQualifier";
				case "2.5.4.6": return "IdAtCountryName";
				case "2.5.4.5": return "IdAtSerialNumber";
				case "2.5.4.65": return "IdAtPseudonym";
				case "0.9.2342.19200300.100.1.25": return "IdDomainComponent";
				case "1.2.840.113549.1.9.1": return "IdEmailAddress";
				case "2.5.29.35": return "IdCeAuthorityKeyIdentifier";
				case "2.5.29.14": return "IdCeSubjectKeyIdentifier";
				case "2.5.29.15": return "IdCeKeyUsage";
				case "2.5.29.16": return "IdCePrivateKeyUsagePeriod";
				case "2.5.29.32": return "IdCeCertificatePolicies";
				case "2.5.29.33": return "IdCePolicyMappings";
				case "2.5.29.17": return "IdCeSubjectAltName";
				case "2.5.29.18": return "IdCeIssuerAltName";
				case "2.5.29.19": return "IdCeBasicConstraints";
				case "2.5.29.30": return "IdCeNameConstraints";
				case "2.5.29.36": return "idCdPolicyConstraints";
				case "2.5.29.37": return "IdCeExtKeyUsage";
				case "2.5.29.31": return "IdCeCRLDistributionPoints";
				case "2.5.29.54": return "IdCeInhibitAnyPolicy";
				case "1.3.6.1.5.5.7.1.1": return "IdPeAuthorityInfoAccess";
				case "1.3.6.1.5.5.7.1.11": return "IdPeSubjectInfoAccess";
				case "2.5.29.20": return "IdCeCRLNumber";
				case "2.5.29.27": return "IdCeDeltaCRLIndicator";
				case "2.5.29.28": return "IdCeIssuingDistributionPoint";
				case "2.5.29.46": return "IdCeFreshestCRL";
				case "2.5.29.21": return "IdCeCRLReason";
				case "2.5.29.23": return "IdCeHoldInstructionCode";
				case "2.5.29.24": return "IdCeInvalidityDate";
				case "2.5.29.29": return "IdCeCertificateIssuer";
				case "1.3.6.1.5.5.7.0.12": return "IdModAttributeCert";
				case "1.3.6.1.5.5.7.1.4": return "IdPeAcAuditIdentity";
				case "2.5.29.55": return "IdCeTargetInformation";
				case "2.5.29.56": return "IdCeNoRevAvail";
				case "1.3.6.1.5.5.7.10.1": return "IdAcaAuthenticationInfo";
				case "1.3.6.1.5.5.7.10.2": return "IdAcaAccessIdentity";
				case "1.3.6.1.5.5.7.10.3": return "IdAcaChargingIdentity";
				case "1.3.6.1.5.5.7.10.4": return "IdAcaGroup";
				case "2.5.4.72": return "IdAtRole";
				case "2.5.1.5.55": return "IdAtClearance";
				case "1.3.6.1.5.5.7.10.6": return "IdAcaEncAttrs";
				case "1.3.6.1.5.5.7.1.10": return "IdPeAcProxying";
				case "1.3.6.1.5.5.7.1.6": return "IdPeAaControls";
				case "1.2.840.113549.1.9.16.1.6": return "IdCtContentInfo";
				case "1.2.840.113549.1.7.1": return "IdDataAuthpack";
				case "1.2.840.113549.1.7.2": return "IdSignedData";
				case "1.2.840.113549.1.7.3": return "IdEnvelopedData";
				case "1.2.840.113549.1.7.5": return "IdDigestedData";
				case "1.2.840.113549.1.7.6": return "IdEncryptedData";
				case "1.2.840.113549.1.9.16.1.2": return "IdCtAuthData";
				case "1.2.840.113549.1.9.3": return "IdContentType";
				case "1.2.840.113549.1.9.4": return "IdMessageDigest";
				case "1.2.840.113549.1.9.5": return "IdSigningTime";
				case "1.2.840.113549.1.9.6": return "IdCounterSignature";
				case "1.2.840.113549.1.1.1": return "RsaEncryption";
				case "1.2.840.113549.1.1.7": return "IdRsaesOaep";
				case "1.2.840.113549.1.1.9": return "IdPSpecified";
				case "1.2.840.113549.1.1.10": return "IdRsassaPss";
				case "1.2.840.113549.1.1.2": return "Md2WithRSAEncryption";
				case "1.2.840.113549.1.1.4": return "Md5WithRSAEncryption";
				case "1.2.840.113549.1.1.5": return "Sha1WithRSAEncryption";
				case "1.2.840.113549.1.1.11": return "Sha256WithRSAEncryption";
				case "1.2.840.113549.1.1.12": return "Sha384WithRSAEncryption";
				case "1.2.840.113549.1.1.13": return "Sha512WithRSAEncryption";
				case "1.2.840.113549.2.2": return "IdMd2";
				case "1.2.840.113549.2.5": return "IdMd5";
				case "1.3.14.3.2.26": return "IdSha1";
				case "2.16.840.1.101.3.4.2.1": return "IdSha256";
				case "2.16.840.1.101.3.4.2.2": return "IdSha384";
				case "2.16.840.1.101.3.4.2.3": return "IdSha512";
				case "1.2.840.113549.1.1.8": return "IdMgf1";
				case "1.2.840.10040.4.3": return "IdDsaWithSha1";
				case "1.2.840.10045.4.1": return "EcdsaWithSHA1";
				case "1.2.840.10040.4.1": return "IdDsa";
				case "1.2.840.10046.2.1": return "DhPublicNumber";
				case "2.16.840.1.101.2.1.1.22": return "IdKeyExchangeAlgorithm";
				case "1.2.840.10045.2.1": return "IdEcPublicKey";
				case "1.2.840.10045.1.1": return "PrimeField";
				case "1.2.840.10045.1.2": return "CharacteristicTwoField";
				case "1.2.840.10045.1.2.1.1": return "GnBasis";
				case "1.2.840.10045.1.2.1.2": return "TpBasis";
				case "1.2.840.10045.1.2.1.3": return "PpBasis";
				case "1.2.840.113549.1.9.16.3.5": return "IdAlgEsdh";
				case "1.2.840.113549.1.9.16.3.10": return "IdAlgSsdh";
				case "1.2.840.113549.1.9.16.3.6": return "IdAlgCms3DesWrap";
				case "1.2.840.113549.1.9.16.3.7": return "IdAlgCmsRc2Wrap";
				case "1.2.840.113549.1.5.12": return "IdPbkDf2";
				case "1.2.840.113549.3.7": return "DesEde3Cbc";
				case "1.2.840.113549.3.2": return "Rc2Cbc";
				case "1.3.6.1.5.5.8.1.2": return "HmacSha1";
				case "2.16.840.1.101.3.4.1.2": return "IdAes128Cbc";
				case "2.16.840.1.101.3.4.1.22": return "IdAes192Cbc";
				case "2.16.840.1.101.3.4.1.42": return "IdAes256Cbc";
				case "2.16.840.1.101.3.4.1.5": return "IdAes128Wrap";
				case "2.16.840.1.101.3.4.1.25": return "IdAes192Wrap";
				case "2.16.840.1.101.3.4.1.45": return "IdAes256Wrap";
				case "1.3.6.1.5.5.7.7.2": return "IdCmcIdentification";
				case "1.3.6.1.5.5.7.7.3": return "IdCmcIdentityProof";
				case "1.3.6.1.5.5.7.7.4": return "IdCmcDataReturn";
				case "1.3.6.1.5.5.7.7.5": return "IdCmcTransactionId";
				case "1.3.6.1.5.5.7.7.6": return "IdCmcSenderNonce";
				case "1.3.6.1.5.5.7.7.7": return "IdCmcRecipientNonce";
				case "1.3.6.1.5.5.7.7.18": return "IdCmcRegInfo";
				case "1.3.6.1.5.5.7.7.19": return "IdCmcResponseInfo";
				case "1.3.6.1.5.5.7.7.21": return "IdCmcQueryPending";
				case "1.3.6.1.5.5.7.7.22": return "IdCmcPopLinkRandom";
				case "1.3.6.1.5.5.7.7.23": return "IdCmcPopLinkWitness";
				case "1.3.6.1.5.5.7.12.2": return "IdCctPKIData";
				case "1.3.6.1.5.5.7.12.3": return "IdCctPKIResponse";
				case "1.3.6.1.5.5.7.7.1": return "IdCmccMCStatusInfo";
				case "1.3.6.1.5.5.7.7.8": return "IdCmcAddExtensions";
				case "1.3.6.1.5.5.7.7.9": return "IdCmcEncryptedPop";
				case "1.3.6.1.5.5.7.7.10": return "IdCmcDecryptedPop";
				case "1.3.6.1.5.5.7.7.11": return "IdCmcLraPopWitness";
				case "1.3.6.1.5.5.7.7.15": return "IdCmcGetCert";
				case "1.3.6.1.5.5.7.7.16": return "IdCmcGetCRL";
				case "1.3.6.1.5.5.7.7.17": return "IdCmcRevokeRequest";
				case "1.3.6.1.5.5.7.7.24": return "IdCmcConfirmCertAcceptance";
				case "1.2.840.113549.1.9.14": return "IdExtensionReq";
				case "1.3.6.1.5.5.7.6.2": return "IdAlgNoSignature";
				case "1.2.840.113533.7.66.13": return "PasswordBasedMac";
				case "1.3.6.1.5.5.7.5.1.1": return "IdRegCtrlRegToken";
				case "1.3.6.1.5.5.7.5.1.2": return "IdRegCtrlAuthenticator";
				case "1.3.6.1.5.5.7.5.1.3": return "IdRegCtrlPkiPublicationInfo";
				case "1.3.6.1.5.5.7.5.1.4": return "IdRegCtrlPkiArchiveOptions";
				case "1.3.6.1.5.5.7.5.1.5": return "IdRegCtrlOldCertID";
				case "1.3.6.1.5.5.7.5.1.6": return "IdRegCtrlProtocolEncrKey";
				case "1.3.6.1.5.5.7.5.2.1": return "IdRegInfoUtf8Pairs";
				case "1.3.6.1.5.5.7.5.2.2": return "IdRegInfoCertReq";
				case "1.3.6.1.5.5.2": return "SpnegoToken";
				case "1.3.6.1.5.5.2.4.2": return "SpnegoNegTok";
				case "1.2.840.113554.1.2.1.1": return "GSS_KRB5_NT_USER_NAME";
				case "1.2.840.113554.1.2.1.2": return "GSS_KRB5_NT_MACHINE_UID_NAME";
				case "1.2.840.113554.1.2.1.3": return "GSS_KRB5_NT_STRING_UID_NAME";
				case "1.2.840.113554.1.2.1.4": return "GSS_C_NT_HOSTBASED_SERVICE";
				case "1.2.840.113554.1.2.2": return "KerberosToken";
				case "1.3.6.1.4.1.311.2.2.30" : return "Negoex";
				case "1.2.840.113554.1.2.2.1": return "GSS_KRB5_NT_PRINCIPAL_NAME";
				case "1.2.840.113554.1.2.2.2": return "GSS_KRB5_NT_PRINCIPAL";
				case "1.2.840.113554.1.2.2.3": return "UserToUserMechanism";
				case "1.2.840.48018.1.2.2": return "MsKerberosToken";
				case "1.3.6.1.4.1.311.2.2.10": return "NLMP";
				case "1.3.6.1.5.5.7.48.1.1": return "IdPkixOcspBasic";
				case "1.3.6.1.5.5.7.48.1.2": return "IdPkixOcspNonce";
				case "1.3.6.1.5.5.7.48.1.3": return "IdPkixOcspCrl";
				case "1.3.6.1.5.5.7.48.1.4": return "IdPkixOcspResponse";
				case "1.3.6.1.5.5.7.48.1.5": return "IdPkixOcspNocheck";
				case "1.3.6.1.5.5.7.48.1.6": return "IdPkixOcspArchiveCutoff";
				case "1.3.6.1.5.5.7.48.1.7": return "IdPkixOcspServiceLocator";
				case "1.3.6.1.4.1.311.20.2.2": return "IdMsKpScLogon";
				case "1.3.6.1.5.2.2": return "IdPkinitSan";
				case "1.3.6.1.5.2.3.1": return "IdPkinitAuthData";
				case "1.3.6.1.5.2.3.2": return "IdPkinitDHKeyData";
				case "1.3.6.1.5.2.3.3": return "IdPkinitRkeyData";
				case "1.3.6.1.5.2.3.4": return "IdPkinitKPClientAuth";
				case "1.3.6.1.5.2.3.5": return "IdPkinitKPKdc";
				case "1.3.14.3.2.29": return "SHA1 with RSA signature";
				case "2.5.29.1": return "AUTHORITY_KEY_IDENTIFIER";
				case "2.5.29.2": return "KEY_ATTRIBUTES";
				case "2.5.29.3": return "CERT_POLICIES_95";
				case "2.5.29.4": return "KEY_USAGE_RESTRICTION";
				case "2.5.29.7": return "SUBJECT_ALT_NAME";
				case "2.5.29.8": return "ISSUER_ALT_NAME";
				case "2.5.29.9": return "Subject_Directory_Attributes";
				case "2.5.29.10": return "BASIC_CONSTRAINTS";
				case "2.5.29.32.0": return "ANY_CERT_POLICY";
				case "2.5.29.5": return "LEGACY_POLICY_MAPPINGS";
				case "1.3.6.1.4.1.311.20.2.1": return "ENROLLMENT_AGENT";
				case "1.3.6.1.5.5.7": return "PKIX";
				case "1.3.6.1.5.5.7.1": return "PKIX_PE";
				case "1.3.6.1.4.1.311.10.2": return "NEXT_UPDATE_LOCATION";
				case "1.3.6.1.4.1.311.10.8.1": return "REMOVE_CERTIFICATE";
				case "1.3.6.1.4.1.311.10.9.1": return "CROSS_CERT_DIST_POINTS";
				case "1.3.6.1.4.1.311.10.1": return "CTL";
				case "1.3.6.1.4.1.311.10.1.1": return "SORTED_CTL";
				case "1.3.6.1.4.1.311.10.3.3.1": return "SERIALIZED";
				case "1.3.6.1.4.1.311.20.2.3": return "NT_PRINCIPAL_NAME";
				case "1.3.6.1.4.1.311.31.1": return "PRODUCT_UPDATE";
				case "1.3.6.1.4.1.311.10.12.1": return "ANY_APPLICATION_POLICY";
				case "1.3.6.1.4.1.311.20.1": return "AUTO_ENROLL_CTL_USAGE";
				case "1.3.6.1.4.1.311.20.3": return "CERT_MANIFOLD";
				case "1.3.6.1.4.1.311.21.1": return "CERTSRV_CA_VERSION";
				case "1.3.6.1.4.1.311.21.2": return "CERTSRV_PREVIOUS_CERT_HASH";
				case "1.3.6.1.4.1.311.21.3": return "CRL_VIRTUAL_BASE";
				case "1.3.6.1.4.1.311.21.4": return "CRL_NEXT_PUBLISH";
				case "1.3.6.1.4.1.311.21.5": return "KP_CA_EXCHANGE";
				case "1.3.6.1.4.1.311.21.6": return "KP_KEY_RECOVERY_AGENT";
				case "1.3.6.1.4.1.311.21.7": return "CERTIFICATE_TEMPLATE";
				case "1.3.6.1.4.1.311.21.8": return "ENTERPRISE_OID_ROOT";
				case "1.3.6.1.4.1.311.21.9": return "RDN_DUMMY_SIGNER";
				case "1.3.6.1.4.1.311.21.10": return "APPLICATION_CERT_POLICIES";
				case "1.3.6.1.4.1.311.21.11": return "APPLICATION_POLICY_MAPPINGS";
				case "1.3.6.1.4.1.311.21.12": return "APPLICATION_POLICY_CONSTRAINTS";
				case "1.3.6.1.4.1.311.21.14": return "CRL_SELF_CDP";
				case "1.3.6.1.4.1.311.21.15": return "REQUIRE_CERT_CHAIN_POLICY";
				case "1.3.6.1.4.1.311.21.16": return "ARCHIVED_KEY_CERT_HASH";
				case "1.3.6.1.4.1.311.21.17": return "ISSUED_CERT_HASH";
				case "1.3.6.1.4.1.311.21.19": return "DS_EMAIL_REPLICATION";
				case "1.3.6.1.4.1.311.21.22": return "CERTSRV_CROSSCA_VERSION";
				case "1.3.6.1.4.1.311.25.1": return "NTDS_REPLICATION";
				case "1.3.6.1.5.5.7.3": return "PKIX_KP";
				case "1.3.6.1.5.5.7.3.1": return "PKIX_KP_SERVER_AUTH";
				case "1.3.6.1.5.5.7.3.2": return "PKIX_KP_CLIENT_AUTH";
				case "1.3.6.1.5.5.7.3.3": return "PKIX_KP_CODE_SIGNING";
				case "1.3.6.1.5.5.7.3.4": return "PKIX_KP_EMAIL_PROTECTION";
				case "1.3.6.1.5.5.7.3.5": return "PKIX_KP_IPSEC_END_SYSTEM";
				case "1.3.6.1.5.5.7.3.6": return "PKIX_KP_IPSEC_TUNNEL";
				case "1.3.6.1.5.5.7.3.7": return "PKIX_KP_IPSEC_USER";
				case "1.3.6.1.5.5.7.3.8": return "PKIX_KP_TIMESTAMP_SIGNING";
				case "1.3.6.1.5.5.8.2.2": return "IPSEC_KP_IKE_INTERMEDIATE";
				case "1.3.6.1.4.1.311.10.3.1": return "KP_CTL_USAGE_SIGNING";
				case "1.3.6.1.4.1.311.10.3.2": return "KP_TIME_STAMP_SIGNING";
				case "1.3.6.1.4.1.311.10.3.3": return "SERVER_GATED_CRYPTO";
				case "2.16.840.1.113730.4.1": return "SGC_NETSCAPE";
				case "1.3.6.1.4.1.311.10.3.4": return "KP_EFS";
				case "1.3.6.1.4.1.311.10.3.4.1": return "EFS_RECOVERY";
				case "1.3.6.1.4.1.311.10.3.5": return "WHQL_CRYPTO";
				case "1.3.6.1.4.1.311.10.3.6": return "NT5_CRYPTO";
				case "1.3.6.1.4.1.311.10.3.7": return "OEM_WHQL_CRYPTO";
				case "1.3.6.1.4.1.311.10.3.8": return "EMBEDDED_NT_CRYPTO";
				case "1.3.6.1.4.1.311.10.3.9": return "ROOT_LIST_SIGNER";
				case "1.3.6.1.4.1.311.10.3.10": return "KP_QUALIFIED_SUBORDINATION";
				case "1.3.6.1.4.1.311.10.3.11": return "KP_KEY_RECOVERY";
				case "1.3.6.1.4.1.311.10.3.12": return "KP_DOCUMENT_SIGNING";
				case "1.3.6.1.4.1.311.10.3.13": return "KP_LIFETIME_SIGNING";
				case "1.3.6.1.4.1.311.10.3.14": return "KP_MOBILE_DEVICE_SOFTWARE";
				case "1.3.6.1.4.1.311.10.5.1": return "DRM";
				case "1.3.6.1.4.1.311.10.5.2": return "DRM_INDIVIDUALIZATION";
				case "1.3.6.1.4.1.311.10.6.1": return "LICENSES";
				case "1.3.6.1.4.1.311.10.6.2": return "LICENSE_SERVER";
				case "1.3.6.1.4.1.311.10.4.1": return "YESNO_TRUST_ATTR";
				case "1.3.6.1.5.5.7.2.1": return "PKIX_POLICY_QUALIFIER_CPS";
				case "1.3.6.1.5.5.7.2.2": return "PKIX_POLICY_QUALIFIER_USERNOTICE";
				case "2.16.840.1.113733.1.7.1.1": return "CERT_POLICIES_95_QUALIFIER1";
				case "1.2.840.113549": return "RSA";
				case "1.2.840.113549.1": return "PKCS";
				case "1.2.840.113549.2": return "RSA_HASH";
				case "1.2.840.113549.3": return "RSA_ENCRYPT";
				case "1.2.840.113549.1.1": return "PKCS_1";
				case "1.2.840.113549.1.2": return "PKCS_2";
				case "1.2.840.113549.1.3": return "PKCS_3";
				case "1.2.840.113549.1.4": return "PKCS_4";
				case "1.2.840.113549.1.5": return "PKCS_5";
				case "1.2.840.113549.1.6": return "PKCS_6";
				case "1.2.840.113549.1.7": return "PKCS_7";
				case "1.2.840.113549.1.8": return "PKCS_8";
				case "1.2.840.113549.1.9": return "PKCS_9";
				case "1.2.840.113549.1.10": return "PKCS_10";
				case "1.2.840.113549.1.12": return "PKCS_12";
				case "1.2.840.113549.1.1.3": return "RSA_MD4RSA";
				case "1.2.840.113549.1.1.6": return "RSA_SETOAEP_RSA";
				case "1.2.840.113549.1.3.1": return "RSA_DH";
				case "1.2.840.113549.1.7.4": return "RSA_signEnvData";
				case "1.2.840.113549.1.9.2": return "RSA_unstructName";
				case "1.2.840.113549.1.9.7": return "RSA_challengePwd";
				case "1.2.840.113549.1.9.8": return "RSA_unstructAddr";
				case "1.2.840.113549.1.9.9": return "RSA_extCertAttrs";
				case "1.2.840.113549.1.9.15": return "RSA_SMIMECapabilities";
				case "1.2.840.113549.1.9.15.1": return "RSA_preferSignedData";
				case "1.2.840.113549.1.9.16.3": return "RSA_SMIMEalg";
				case "1.2.840.113549.2.4": return "RSA_MD4";
				case "1.2.840.113549.3.4": return "RSA_RC4";
				case "1.2.840.113549.3.9": return "RSA_RC5_CBCPad";
				case "1.2.840.10046": return "ANSI_X942";
				case "1.2.840.10040": return "X957";
				case "2.5": return "DS";
				case "2.5.8": return "DSALG";
				case "2.5.8.1": return "DSALG_CRPT";
				case "2.5.8.2": return "DSALG_HASH";
				case "2.5.8.3": return "DSALG_SIGN";
				case "2.5.8.1.1": return "DSALG_RSA";
				case "1.3.14": return "OIW";
				case "1.3.14.3.2": return "OIWSEC";
				case "1.3.14.3.2.2": return "OIWSEC_md4RSA";
				case "1.3.14.3.2.3": return "OIWSEC_md5RSA";
				case "1.3.14.3.2.4": return "OIWSEC_md4RSA2";
				case "1.3.14.3.2.6": return "OIWSEC_desECB";
				case "1.3.14.3.2.7": return "OIWSEC_desCBC";
				case "1.3.14.3.2.8": return "OIWSEC_desOFB";
				case "1.3.14.3.2.9": return "OIWSEC_desCFB";
				case "1.3.14.3.2.10": return "OIWSEC_desMAC";
				case "1.3.14.3.2.11": return "OIWSEC_rsaSign";
				case "1.3.14.3.2.12": return "OIWSEC_dsa";
				case "1.3.14.3.2.13": return "OIWSEC_shaDSA";
				case "1.3.14.3.2.14": return "OIWSEC_mdc2RSA";
				case "1.3.14.3.2.15": return "OIWSEC_shaRSA";
				case "1.3.14.3.2.16": return "OIWSEC_dhCommMod";
				case "1.3.14.3.2.17": return "OIWSEC_desEDE";
				case "1.3.14.3.2.18": return "OIWSEC_sha";
				case "1.3.14.3.2.19": return "OIWSEC_mdc2";
				case "1.3.14.3.2.20": return "OIWSEC_dsaComm";
				case "1.3.14.3.2.21": return "OIWSEC_dsaCommSHA";
				case "1.3.14.3.2.22": return "OIWSEC_rsaXchg";
				case "1.3.14.3.2.23": return "OIWSEC_keyHashSeal";
				case "1.3.14.3.2.24": return "OIWSEC_md2RSASign";
				case "1.3.14.3.2.25": return "OIWSEC_md5RSASign";
				case "1.3.14.3.2.27": return "OIWSEC_dsaSHA1";
				case "1.3.14.3.2.28": return "OIWSEC_dsaCommSHA1";
				case "1.3.14.7.2": return "OIWDIR";
				case "1.3.14.7.2.1": return "OIWDIR_CRPT";
				case "1.3.14.7.2.2": return "OIWDIR_HASH";
				case "1.3.14.7.2.3": return "OIWDIR_SIGN";
				case "1.3.14.7.2.2.1": return "OIWDIR_md2";
				case "1.3.14.7.2.3.1": return "OIWDIR_md2RSA";
				case "2.16.840.1.101.2.1": return "INFOSEC";
				case "2.16.840.1.101.2.1.1.1": return "INFOSEC_sdnsSignature";
				case "2.16.840.1.101.2.1.1.2": return "INFOSEC_mosaicSignature";
				case "2.16.840.1.101.2.1.1.3": return "INFOSEC_sdnsConfidentiality";
				case "2.16.840.1.101.2.1.1.4": return "INFOSEC_mosaicConfidentiality";
				case "2.16.840.1.101.2.1.1.5": return "INFOSEC_sdnsIntegrity";
				case "2.16.840.1.101.2.1.1.6": return "INFOSEC_mosaicIntegrity";
				case "2.16.840.1.101.2.1.1.7": return "INFOSEC_sdnsTokenProtection";
				case "2.16.840.1.101.2.1.1.8": return "INFOSEC_mosaicTokenProtection";
				case "2.16.840.1.101.2.1.1.9": return "INFOSEC_sdnsKeyManagement";
				case "2.16.840.1.101.2.1.1.10": return "INFOSEC_mosaicKeyManagement";
				case "2.16.840.1.101.2.1.1.11": return "INFOSEC_sdnsKMandSig";
				case "2.16.840.1.101.2.1.1.12": return "INFOSEC_mosaicKMandSig";
				case "2.16.840.1.101.2.1.1.13": return "INFOSEC_SuiteASignature";
				case "2.16.840.1.101.2.1.1.14": return "INFOSEC_SuiteAConfidentiality";
				case "2.16.840.1.101.2.1.1.15": return "INFOSEC_SuiteAIntegrity";
				case "2.16.840.1.101.2.1.1.16": return "INFOSEC_SuiteATokenProtection";
				case "2.16.840.1.101.2.1.1.17": return "INFOSEC_SuiteAKeyManagement";
				case "2.16.840.1.101.2.1.1.18": return "INFOSEC_SuiteAKMandSig";
				case "2.16.840.1.101.2.1.1.19": return "INFOSEC_mosaicUpdatedSig";
				case "2.16.840.1.101.2.1.1.20": return "INFOSEC_mosaicKMandUpdSig";
				case "2.16.840.1.101.2.1.1.21": return "INFOSEC_mosaicUpdatedInteg";
				case "2.5.4.4": return "SUR_NAME";
				case "2.5.4.9": return "STREET_ADDRESS";
				case "2.5.4.13": return "DESCRIPTION";
				case "2.5.4.14": return "SEARCH_GUIDE";
				case "2.5.4.15": return "BUSINESS_CATEGORY";
				case "2.5.4.16": return "POSTAL_ADDRESS";
				case "2.5.4.17": return "POSTAL_CODE";
				case "2.5.4.18": return "POST_OFFICE_BOX";
				case "2.5.4.19": return "PHYSICAL_DELIVERY_OFFICE_NAME";
				case "2.5.4.20": return "TELEPHONE_NUMBER";
				case "2.5.4.21": return "TELEX_NUMBER";
				case "2.5.4.22": return "TELETEXT_TERMINAL_IDENTIFIER";
				case "2.5.4.23": return "FACSIMILE_TELEPHONE_NUMBER";
				case "2.5.4.24": return "X21_ADDRESS";
				case "2.5.4.25": return "INTERNATIONAL_ISDN_NUMBER";
				case "2.5.4.26": return "REGISTERED_ADDRESS";
				case "2.5.4.27": return "DESTINATION_INDICATOR";
				case "2.5.4.28": return "PREFERRED_DELIVERY_METHOD";
				case "2.5.4.29": return "PRESENTATION_ADDRESS";
				case "2.5.4.30": return "SUPPORTED_APPLICATION_CONTEXT";
				case "2.5.4.31": return "MEMBER";
				case "2.5.4.32": return "OWNER";
				case "2.5.4.33": return "ROLE_OCCUPANT";
				case "2.5.4.34": return "SEE_ALSO";
				case "2.5.4.35": return "USER_PASSWORD";
				case "2.5.4.36": return "USER_CERTIFICATE";
				case "2.5.4.37": return "CA_CERTIFICATE";
				case "2.5.4.38": return "AUTHORITY_REVOCATION_LIST";
				case "2.5.4.39": return "CERTIFICATE_REVOCATION_LIST";
				case "2.5.4.40": return "CROSS_CERTIFICATE_PAIR";
				case "2.5.4.42": return "GIVEN_NAME";
				case "2.5.4.43": return "INITIALS";
				case "1.2.840.113549.1.9.20": return "PKCS_12_FRIENDLY_NAME_ATTR";
				case "1.2.840.113549.1.9.21": return "PKCS_12_LOCAL_KEY_ID";
				case "1.3.6.1.4.1.311.17.1": return "PKCS_12_KEY_PROVIDER_NAME_ATTR";
				case "1.3.6.1.4.1.311.17.2": return "LOCAL_MACHINE_KEYSET";
				case "1.3.6.1.4.1.311.10.7.1": return "KEYID_RDN";
				case "1.3.6.1.5.5.7.48": return "PKIX_ACC_DESCR";
				case "1.3.6.1.5.5.7.48.1": return "PKIX_OCSP";
				case "1.3.6.1.5.5.7.48.2": return "PKIX_CA_ISSUERS";
				case "2.16.840.1.113733.1.6.9": return "VERISIGN_PRIVATE_6_9";
				case "2.16.840.1.113733.1.6.11": return "VERISIGN_ONSITE_JURISDICTION_HASH";
				case "2.16.840.1.113733.1.6.13": return "VERISIGN_BITSTRING_6_13";
				case "2.16.840.1.113733.1.8.1": return "VERISIGN_ISS_STRONG_CRYPTO";
				case "2.16.840.1.113730": return "NETSCAPE";
				case "2.16.840.1.113730.1": return "NETSCAPE_CERT_EXTENSION";
				case "2.16.840.1.113730.1.1": return "NETSCAPE_CERT_TYPE";
				case "2.16.840.1.113730.1.2": return "NETSCAPE_BASE_URL";
				case "2.16.840.1.113730.1.3": return "NETSCAPE_REVOCATION_URL";
				case "2.16.840.1.113730.1.4": return "NETSCAPE_CA_REVOCATION_URL";
				case "2.16.840.1.113730.1.7": return "NETSCAPE_CERT_RENEWAL_URL";
				case "2.16.840.1.113730.1.8": return "NETSCAPE_CA_POLICY_URL";
				case "2.16.840.1.113730.1.12": return "NETSCAPE_SSL_SERVER_NAME";
				case "2.16.840.1.113730.1.13": return "NETSCAPE_COMMENT";
				case "2.16.840.1.113730.2": return "NETSCAPE_DATA_TYPE";
				case "2.16.840.1.113730.2.5": return "NETSCAPE_CERT_SEQUENCE";
				case "1.3.6.1.5.5.7.7": return "CMC";
				case "1.3.6.1.4.1.311.10.10.1": return "CMC_ADD_ATTRIBUTES";
				//case "1.2.840.113549.1.7.4": return "PKCS_7_SIGNEDANDENVELOPED";
				case "1.3.6.1.4.1.311.10.11.": return "CERT_PROP_ID_PREFIX";
				case "1.3.6.1.4.1.311.10.11.20": return "CERT_KEY_IDENTIFIER_PROP_ID";
				case "1.3.6.1.4.1.311.10.11.28": return "CERT_ISSUER_SERIAL_NUMBER_MD5_HASH_PROP_ID";
				case "1.3.6.1.4.1.311.10.11.29": return "CERT_SUBJECT_NAME_MD5_HASH_PROP_ID";						
					
				default: return "UnknownOidExtension";
			}
		}
		
		// Need to find
		public static const COMMON_NAME:String = "IdAtCommonName";
		public static const SUBJECT_ALT_NAME:String = "IdCeSubjectAltName";
		public static const ACA_GROUP:String = "IdAcaGroup";
		public static const ORG_NAME:String = "IdAtOrganizationName";
		public static const EMAIL_ADDRESS:String = "IdEmailAddress";
		
	}
}