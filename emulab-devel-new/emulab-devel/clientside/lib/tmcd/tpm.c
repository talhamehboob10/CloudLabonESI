/*
 * Copyright (c) 2009-2015 University of Utah and the Flux Group.
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

#ifndef STANDALONE
#include "log.h"
#include "config.h"
#else
#define error		printf
#endif /* STANDALONE */

#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <strings.h>
#include <string.h>
#include <netinet/in.h>

static unsigned int nonce_counter = 0;

/*
 * XXX: Teach me how to do this properly . . .  This is so boss can build ssl.o
 * 	properly without installing trousers headers
 */
#ifdef TPMOVERRIDE
#undef TPM
#endif /* TPMOVERRIDE */

#ifdef TPM
#include <tss/tss_defines.h>
#endif	/* TPM */

#include "tpm.h"

#ifdef WITHSSL
#include "ssl.h"
#endif

EVP_PKEY *tpmk;

#ifdef TPM
static ENGINE *tpme;
/*
 * hash is the SHA1 hash of our TPM storage root passsword (not the owner
 * password!)
 */
static char *tpmhash = "\x71\x10\xed\xa4\xd0\x9e\x06\x2a\xa5\xe4\xa3\x90\xb0"
			"\xa5\x72\xac\x0d\x2c\x02\x20";
#endif
static void tpm_dump_pcr(char *msg, unsigned char *pcrbuf);

int
tmcd_tpm_loadengine(void)
{
#ifdef	TPM
	ENGINE_load_builtin_engines();
	tpme = ENGINE_by_id("tpm");
	if (!tpme){
		error("ENGINE_by_id\n");
		return 1;
	}

	if (!ENGINE_init(tpme)){
		error("ENGINE_init\n");
		//ENGINE_free(tpme);	/* this segfaults?? */
		return 1;
	}
	if (!ENGINE_set_default_RSA(tpme) || !ENGINE_set_default_RAND(tpme)){
		error("ENGINE_set_default\n");
		ENGINE_free(tpme);
		ENGINE_finish(tpme);
		return 1;
	}

	/* Don't need this anymore */
	ENGINE_free(tpme);

	/* Set auth */
        if (!ENGINE_ctrl_cmd(tpme, "SECRET_MODE",
	    (long)TSS_SECRET_MODE_SHA1, NULL, NULL, 0)){
		error("set SECRET_MODE hash\n");
		ENGINE_finish(tpme);
		return 1;
	}
        if (!ENGINE_ctrl_cmd(tpme, "PIN", 0, tpmhash, NULL, 0)){
		error("set SECRET_MODE hash\n");
		ENGINE_finish(tpme);
		return 1;
	}

	return 0;
#else
	error("Oops!  Want TPM but we're compiled without TPM support\n");
	return 1;
#endif /* TPM */
}

int
tmcd_tpm_getkey(char *kf)
{
#ifdef	TPM
	if (!tpme){
		error("invalid tpm engine reference\n");
		return 1;
	}
	if (!kf){
		error("invalid keyfile pointer\n");
		return 1;
	}
	/*
	 * XXX: This call to ENGINE_load_private_key apparently can segfault if
	 * you pass in a keyfile that it doesn't like. . .  need to do
	 * something about that . . .
	 */
	if ((tpmk = ENGINE_load_private_key(tpme, kf, NULL, NULL)) == NULL){
		error("error loading keyfile: %s\n", kf);
		return 1;
	}

	return 0;
#else
	error("Oops!  Want TPM but we're compiled without TPM support\n");
	return 1;
#endif /* TPM */
}

int
tmcd_tpm_free(void)
{
#ifdef TPM
	ENGINE_finish(tpme);
	tpme = NULL;
	return 0;
#else
	error("Oops!  Want TPM but we're compiled without TPM support\n");
	return 1;
#endif /* TPM */
}

int
tmcd_tpm_generate_nonce(unsigned char *nonce)
{
    /*
     * Nonce must be 160 bits (20 bytes) long, and we must be quite sure that
     * we will never use the same one twice.  We put three things into the
     * nonce to make it unique:
     * 1) Timestamp to the best accuracy we can get (8 bytes)
     * 2) The PID of the current process, to avoid someone asking two 
     *    different tmcds for nonces at the same time (2 bytes)
     * 3) A local counter, in case someone can ask for nonces faster than our
     *    clock resolution (4 bytes)
     *
     * We use this union since "struct timeval" has a different size between
     * 32- and 64-bit FreeBSD (8 bytes vs. 16).
     */
    union _nonce {
	    struct {
		    uint32_t timesec;
		    uint32_t timeusec;
		    uint16_t pid;
		    uint32_t counter;
	    } members;
	    uint8_t bytes[TPM_NONCE_BYTES];
    } *noncep;
    struct timeval time;

    if (sizeof(*noncep) > TPM_NONCE_BYTES)
	    error("Oops!  Nonce too big!\n");

    noncep = (union _nonce *)nonce;
    memset(noncep, 0, TPM_NONCE_BYTES);
    
    // timestamp
    if (gettimeofday(&time,NULL)) {
        return -1;
    }
    noncep->members.timesec = time.tv_sec;
    noncep->members.timeusec = time.tv_usec;

    // pid
    noncep->members.pid = getpid();

    // counter
    noncep->members.counter = nonce_counter;
    nonce_counter++;

    // TODO: Maybe hash to avoid giving away info on state on boss?

    return 0;

}

/*
 * Verify that a quote is what we expect it to be.  We need SHA1 hashing to do
 * this so we require SSL.
 *
 * Returns 1 if the quote is valid, 0 otherwise.
 */
int tmcd_tpm_verify_quote(unsigned char *quote, ssize_t quotelen,
			  unsigned char *pcomp, ssize_t pcomplen,
			  ETPM_NONCE nonce, unsigned short wantpcrs,
			  TPM_PCR *pcrs, unsigned char *idkey)
{
#ifdef	WITHSSL
	struct signed_pcomp sp;

	unsigned short pcrmlen;
	/* XXX: The pcr mask is supposedly variable length but really 2 bytes
	 * in practice */
	unsigned short pcrm;
	uint32_t pcrlen;
	int i, c, pcrtot = 0;
	unsigned char hash[20];

	if (!quote) {
		error("NULL quote to %s\n", __FUNCTION__);
		return 0;
	}
	if (!pcomp) {
		error("NULL pcomp to %s\n", __FUNCTION__);
		return 0;
	}
	if (!nonce) {
		error("NULL nonce to %s\n", __FUNCTION__);
		return 0;
	}
	if (!pcrs) {
		error("NULL pcrs to %s\n", __FUNCTION__);
		return 0;
	}
	if (!idkey) {
		error("NULL idkey to %s\n", __FUNCTION__);
		return 0;
	}

	pcrmlen = ntohs(*((unsigned short *)&pcomp[PCOMP_PCRMASK_LEN]));
	pcrlen = ntohl(*((uint32_t *)&pcomp[PCOMP_PCRBLOB_LEN]));
	/* Some sanity - 28 bytes is the smallest quote size possible on our
	 * TPMs.
	 * XXX: We do not deal with variable length pcr masks yet (it is
	 * probably useless unless you want to quote the dynamic pcrs). */
	i = pcrmlen + pcrlen + sizeof(short) + sizeof(uint32_t);
	if (pcrmlen != 2 || i != pcomplen || pcomplen < 28) {
		error("Corrupt quote blob; unexpected quote size\n");
		error("pcr mask len: %d, pcomplen: %d, pcrlen: %d,"
		    " calculated len: %d\n", pcrmlen, pcomplen, pcrlen, i);
		return 0;
	}
	pcrm = *((unsigned short *)&pcomp[PCOMP_PCRMASK]);
	for (i = 0; i < PCOMP_PCRMASK_BITS; i++)
		if (pcrm & (1 << i))
			pcrtot++;

	if (pcrlen != pcrtot * PCOMP_PCR_LEN) {
		error("Corrupt quote blob; pcrlen %d, should be: %d\n", pcrlen,
		    pcrtot * PCOMP_PCR_LEN);
		return 0;
	}

	/* Check that it includes the PCRs we want */
	if ((pcrm & wantpcrs) != wantpcrs) {
		error("Missing required PCRs; wantpcr: %x pcrmask: %x\n",
		    wantpcrs, pcrm);
		return 0;
	}

	/* Make sure that the PCRs are what we expect them to be.  Dig up
	 * required PCRs.  This assumes our pcrs argument contains the required
	 * PCR values in ascending order. */
	for (i = 0, c = 0; i < PCOMP_PCRMASK_BITS; i++) {
		if (pcrm & (1 << i)) {
			if (memcmp(&pcomp[PCOMP_PCRBLOB + PCOMP_PCR_LEN * c],
			    pcrs[c], PCOMP_PCR_LEN)) {
				error("PCR %d doesn't match\n", i);
				tpm_dump_pcr("  should be:  ",
					     (unsigned char *)pcrs[c]);
				tpm_dump_pcr("  quote says: ", 
					     &pcomp[PCOMP_PCRBLOB+PCOMP_PCR_LEN * c]);
				return 0;
                        }
                        c++;
		}
	}

	/* SHA1 pcomp and stuff it into struct _signed_comp */
	sp.fixed[0] = 1; sp.fixed[1] = 1;
	sp.fixed[2] = 0; sp.fixed[3] = 0;
	sp.fixed[4] = 'Q'; sp.fixed[5] = 'U';
	sp.fixed[6] = 'O'; sp.fixed[7] = 'T';

	if (tmcd_quote_hash(pcomp, pcomplen, &sp.comphash)) {
		error("Error hashing pcr composite\n");
		return 0;
	}

	memcpy(&sp.nonce, nonce, TPM_NONCE_BYTES);

	/* SHA1 _signed_comp */
	if (tmcd_quote_hash(&sp, sizeof(sp), hash)) {
		error("Error hashing signed pcomp\n");
		return 0;
	}

	/* Verify that quote is indeed a signature of the SHA1 of
	 * _signed_comp */
	if (!tmcd_quote_verifysig(hash, quote, quotelen, idkey)) {
		error("Signature check failed\n");
		return 0;
	}

	/* They survived the gauntlet! */
	return 1;

#else
	error("Can't verify quotes without SSL\n");
	return 0;
#endif
}

/*
 * Key extracting functions
 *
 * I use these to verify quotes.  We must extract the identity key from the key
 * blob.  I took these from libtpm.
 *
 * XXX: I'll minimize these functions later.
 */
#define LOAD32(buffer,offset)         ( ntohl(*(uint32_t *)&buffer[offset]) )
#define LOAD16(buffer,offset)         ( ntohs(*(uint16_t *)&buffer[offset]) )
#define TPM_U16_SIZE                   2
#define TPM_U32_SIZE                   4

static int tpm_extract_pubkey(unsigned char *keybuff, struct pubkeydata *k,
    int pcrpresent)
{
	uint32_t parmsize;
	uint32_t pcrisize;

	int offset;

	offset = 0;
	k->algorithm = LOAD32(keybuff, offset);
	offset += TPM_U32_SIZE;
	k->encscheme = LOAD16(keybuff, offset);
	offset += TPM_U16_SIZE;
	k->sigscheme = LOAD16(keybuff, offset);
	offset += TPM_U16_SIZE;
	parmsize = LOAD32(keybuff, offset);
	offset += TPM_U32_SIZE;
	if (k->algorithm == 0x00000001 && parmsize > 0) {	/* RSA */
		k->keybitlen = LOAD32(keybuff, offset);
		offset += TPM_U32_SIZE;
		k->numprimes = LOAD32(keybuff, offset);
		offset += TPM_U32_SIZE;
		k->expsize = LOAD32(keybuff, offset);
		offset += TPM_U32_SIZE;
	} else {
		offset += parmsize;
	}
	if (k->expsize == 3) {
		k->exponent[0] = *(keybuff + offset + 0);
		k->exponent[1] = *(keybuff + offset + 1);
		k->exponent[2] = *(keybuff + offset + 2);
		offset += k->expsize;
	} else if (k->expsize != 0)
		offset += k->expsize;
	else {
		k->exponent[0] = 0x01;
		k->exponent[1] = 0x00;
		k->exponent[2] = 0x01;
		k->expsize = 3;
	}
	if (pcrpresent) {
		pcrisize = LOAD32(keybuff, offset);
		offset += TPM_U32_SIZE;
		if (pcrisize > 0 && pcrisize <= 256)
			memcpy(k->pcrinfo, keybuff + offset, pcrisize);
		offset += pcrisize;
		k->pcrinfolen = pcrisize;
	}
	k->keylength = LOAD32(keybuff, offset);
	offset += TPM_U32_SIZE;
	if (k->keylength > 0 && k->keylength <= 256)
		memcpy(k->modulus, keybuff + offset, k->keylength);
	offset += k->keylength;
	return offset;
}

int tpm_extract_key(unsigned char *keybuff, struct keydata * k)
{
	int offset;
	int pubkeylen;

	/* fill in  keydata structure */
	offset = 0;
	memcpy(k->version, keybuff + offset, sizeof(k->version));
	offset += 4;
	k->keyusage = LOAD16(keybuff, offset);
	offset += TPM_U16_SIZE;
	k->keyflags = LOAD32(keybuff, offset);
	offset += TPM_U32_SIZE;
	k->authdatausage = keybuff[offset];
	offset += 1;
	pubkeylen = tpm_extract_pubkey(keybuff + offset, &(k->pub), 1);
	offset += pubkeylen;
	k->privkeylen = LOAD32(keybuff, offset);
	offset += TPM_U32_SIZE;
	if (k->privkeylen > 0 && k->privkeylen <= 1024)
		memcpy(k->encprivkey, keybuff + offset, k->privkeylen);
	offset += k->privkeylen;
	return offset;
}

static void
tpm_dump_pcr(char *msg, unsigned char *pcrbuf)
{
	int i;
	char strbuf[PCOMP_PCR_LEN*2+1], *bp;

	bp = strbuf;
	for (i = 0; i < PCOMP_PCR_LEN; i++)
		bp += sprintf(bp, "%02x", pcrbuf[i]);
	error("%s%s\n", msg, strbuf);
}
