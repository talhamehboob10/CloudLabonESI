/*
 * Copyright (c) 2000-2020 University of Utah and the Flux Group.
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

/*
 * An image zipper.
 *
 * TODO:
 *	Multithread so that we can be reading ahead on the input device
 *	and overlapping IO with compression.  Maybe a third thread for
 *	doing output.
 */
#ifdef WITH_CRYPTO
#include <openssl/evp.h>
#include <openssl/sha.h>
#include <openssl/rsa.h>
#include <openssl/rand.h>
#ifdef SIGN_CHECKSUM
#include <openssl/err.h>
#endif
#endif
#include <ctype.h>
#include <err.h>
#include <fcntl.h>
#if !defined(__UCLIBC__)
#include <fstab.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <sys/param.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <zlib.h>

#include "imagehdr.h"
#include "sliceinfo.h"
#include "global.h"
#include "checksum.h"
#include "range.h"
#ifdef WITH_HASH
#include "hashmap/hashmap.h"
#ifdef WITH_HASHALIGN
#include "imagehash.h"
#endif
#endif

/*
 * Attempt to split chunks so that hash blocks don't span chunk boundaries.
 *
 * XXX nice thought, but it doesn't do a very good job (saves less than 50%)
 * of the crossings at the expense of wasting about 4% more space). Unless
 * we come up with a less hacky way to fill chunks (e.g. PD fitblk.c) where
 * we can avoid it entirely, don't even try.
 */
#undef WITH_HASH_CHUNKSPLIT

/* XXX this is a hack right now */
#define USE_HACKSORT 0

#define min(a,b) ((a) <= (b) ? (a) : (b))

char	*infilename;
int	infd, outfd, incanseek, outcanseek;
int	secsize	  = 512;	/* XXX bytes. */
int	debug	  = 0;
int	dots	  = 0;
int	info	  = 0;
int	version	  = 0;
int	slicemode = 0;
int	maxmode	  = 0;
int	slice	  = 0;
int	level	  = 4;
long	dev_bsize = 1;
uint32_t compat   = 0;
int	frangesize= 64;	/* 32k */
int	zerofrange= 0;
int	forcereads= 0;
int	badsectors= 0;
int	retrywrites= 1;
int	dorelocs  = 1;
int	forcerelocs = 0;
int	metaoptimize = 0;
int	filemode  = 0;
int	excludenonfs = 0;
int	do_encrypt = 0;
int	cipher = ENC_NONE;
int	do_checksum = 0;
int	csumalg = CSUM_NONE;
off_t	datawritten;
partmap_t ignore, forceraw;
static	int got_imageid;
static unsigned char imageid[UUID_LENGTH];

#ifdef WITH_HASH
char	*hashfile;
char	*newhashfile;
int	deltapct = -1;
#endif

#ifdef WITH_CRYPTO
#ifdef SIGN_CHECKSUM
RSA		*sig_key = NULL;	/* signing key */
static void output_public_key(char *, RSA *);
#endif
unsigned char	*enc_key = NULL;	/* encryption key */
static void output_encrypt_key(char *, unsigned char *, int);
#endif
static void output_uuid(char *, char *);

#define HDRUSED(reg, rel) \
    (sizeof(blockhdr_t) + \
    (reg) * sizeof(struct region) + (rel) * sizeof(struct blockreloc))

/*
 * We want to be able to compress slices by themselves, so we need
 * to know where the slice starts when reading the input file for
 * compression.
 *
 * These numbers are in sectors.
 */
unsigned long inputminsec	= 0;
unsigned long inputmaxsec	= 0;	/* 0 means the entire input image */

struct range	*ranges, *skips, *fixups;
int		numranges, numskips, numfixups;
struct blockreloc	*relocs;
int			numregions, numrelocs;

void	dumpskips(int verbose);
static void	sortrange(struct range **head, int domerge,
		  int (*rangecmp)(struct range *, struct range *));
int	mergeskips(int verbose);
int	mergeranges(struct range *head);
void	makeranges(void);
void	dumpranges(int verbose);
uint32_t sectinranges(struct range *range);
void	addvalid(uint32_t start, uint32_t size);
void	addreloc(off_t offset, off_t size, int reloctype);
void	removereloc(off_t offset, off_t size, int reloctype);
static int cmpfixups(struct range *r1, struct range *r2);

/* Forward decls */
int	read_image(int fd);
int	read_raw(int fd);
int	compress_image(void);
void	usage(void);

static SLICEMAP_PROCESS_PROTO(read_slice);

#define READ_RETRIES	1
#define WRITE_RETRIES	10

ssize_t
slowread(int fd, void *buf, size_t nbytes, off_t startoffset)
{
	int cc, i, count;

	assert(fd != infd || incanseek);

	fprintf(stderr, "read failed: will retry by sector %d more times\n",
		READ_RETRIES);

	count = 0;
	for (i = 0; i < READ_RETRIES; i++) {
		if (lseek(fd, startoffset, SEEK_SET) < 0) {
			perror("devread: seeking to set file ptr");
			exit(1);
		}
		while (nbytes > 0) {
			cc = read(fd, buf, nbytes);
			if (cc == 0) {
				nbytes = 0;
				continue;
			}
			if (cc > 0) {
				nbytes -= cc;
				buf     = (void *)((char *)buf + cc);
				count  += cc;
				continue;
			}

			nbytes += count;
			buf     = (void *)((char *)buf - count);
			count   = 0;
			break;
		}
		if (nbytes == 0)
			break;
	}
	return count;
}

/*
 * Assert the hell out of it...
 */
off_t
devlseek(int fd, off_t off, int whence)
{
	off_t noff;

	assert(fd != infd || incanseek);
	assert((off & (DEV_BSIZE-1)) == 0);
	noff = lseek(fd, off, whence);
	if (!filemode) {
		assert(noff == (off_t)-1 || (noff & (DEV_BSIZE-1)) == 0);
	}
	return noff;
}

/*
 * Wrap up read in a retry mechanism to persist in the face of IO errors,
 * even faking data if requested.
 */
ssize_t
devread(int fd, void *buf, size_t nbytes)
{
	int		cc, count;
	off_t		startoffset;
	size_t		onbytes;

#ifndef linux
	assert((nbytes & (DEV_BSIZE-1)) == 0);
#endif
	cc = read(fd, buf, nbytes);

	/*
	 * If reading from a pipe, try to fill the input buffer
	 * even if it takes multiple reads. Forces deterministic
	 * behavior when compressing the same input stream.
	 */
	if (cc > 0 && cc != nbytes && !incanseek) {
		int ncc;

		count = nbytes - cc;
		while (count > 0) {
			ncc = read(fd, (char *)buf + cc, count);
			if (ncc <= 0)
				break;
			cc += ncc;
			count -= ncc;
		}
		return cc;
	}

	if (!forcereads || cc >= 0)
		return cc;

	assert(fd != infd || incanseek);

	/*
	 * Got an error reading the range.
	 * Retry one sector at a time, replacing any bad sectors with
	 * zeroed data.
	 */
	if ((startoffset = lseek(fd, (off_t) 0, SEEK_CUR)) < 0) {
		perror("devread: seeking to get input file ptr");
		exit(1);
	}
	assert((startoffset & (DEV_BSIZE-1)) == 0);

	onbytes = nbytes;
	while (nbytes > 0) {
		if (nbytes > DEV_BSIZE)
			count = DEV_BSIZE;
		else
			count = nbytes;
		cc = slowread(fd, buf, count, startoffset);
		if (cc != count) {
			fprintf(stderr, "devread: read failed on sector %u, "
				"returning zeros\n",
				bytestosec(startoffset));
			if (cc < 0)
				cc = 0;
			memset(buf, 0, count-cc);
			badsectors++;
			cc = count;
		}
		nbytes -= cc;
		buf = (void *)((char *)buf + cc);
		startoffset += cc;
	}
	return onbytes;
}

/*
 * Wrap up write in a retry mechanism to protect against transient NFS
 * errors causing a fatal error.
 */
ssize_t
devwrite(int fd, const void *buf, size_t nbytes)
{
	int		cc, i, count = 0;
	off_t		startoffset = 0;

	if (retrywrites && outcanseek &&
	    ((startoffset = lseek(fd, (off_t) 0, SEEK_CUR)) < 0)) {
		perror("devwrite: seeking to get output file ptr");
		exit(1);
	}

	for (i = 0; i < WRITE_RETRIES; i++) {
		while (nbytes) {
			cc = write(fd, buf, nbytes);

			if (cc > 0) {
				nbytes -= cc;
				buf     = (void *)((char *)buf + cc);
				count  += cc;
				continue;
			}

			if (!retrywrites)
				return cc;

			if (i == 0)
				perror("write error: will retry");

			sleep(1);
			nbytes += count;
			buf     = (void *)((char *)buf - count);
			count   = 0;
			goto again;
		}
		if (retrywrites && fsync(fd) < 0) {
			perror("fsync error: will retry");
			sleep(1);
			nbytes += count;
			buf     = (void *)((char *)buf - count);
			count   = 0;
			goto again;
		}
		datawritten += count;
		return count;
	again:
		if (lseek(fd, startoffset, SEEK_SET) < 0) {
			perror("devwrite: seeking to set file ptr");
			exit(1);
		}
	}
	perror("write error: busted for too long");
	fflush(stderr);
	exit(1);
}

static int
setpartition(partmap_t map, char *str)
{
	int dospart;
	char bsdpart;

	if (isdigit(str[1])) {
		bsdpart = str[2];
		str[2] = '\0';
	} else {
		bsdpart = str[1];
		str[1] = '\0';
	}
	dospart = atoi(str);
	if (dospart < 1 || dospart > MAXSLICES)
		return EINVAL;

	/* common case: apply to complete DOS partition */
	if (bsdpart == '\0') {
		map[dospart-1] = ~0;
		return 0;
	}

	if (bsdpart < 'a' || bsdpart > 'p')
		return EINVAL;

	map[dospart-1] |= (1 << (bsdpart - 'a'));
	return 0;
}

int
main(int argc, char *argv[])
{
	int	ch, rval;
	char	*outfilename = 0;
	int	rawmode	  = 0;
	int	slicetype = 0;
	struct timeval sstamp;
	extern char build_info[];

	memset(imageid, '\0', UUID_LENGTH);

	gettimeofday(&sstamp, 0);
	while ((ch = getopt(argc, argv, "vlbnNdihrs:c:z:ofI:13F:DR:S:XxH:U:P:Me:k:u:a:ZL")) != -1)
		switch(ch) {
		case 'v':
			version++;
			break;
		case 'i':
			info++;
			debug++;
			break;
		case 'D':
			retrywrites = 0;
			break;
		case 'd':
			debug++;
			break;
		case 'l':
			slicetype = IZTYPE_LINUX;
			break;
		case 'b':
			slicetype = IZTYPE_FBSDNOLABEL;
			break;
		case 'L':
			forcerelocs = 1;
			break;
		case 'N':
			dorelocs = 0;
			break;
		case 'n':
			slicetype = IZTYPE_NTFS;
			break;
		case 'o':
			dots++;
			break;
		case 'r':
			rawmode++;
			break;
		case 'S':
			slicetype = atoi(optarg);
			/* XXX special case for freebsd */
			if (slicetype == IZTYPE_386BSD)
				slicetype = IZTYPE_FBSDNOLABEL;
			break;
		case 's':
			slicemode = 1;
			slice = atoi(optarg);
			break;
		case 'z':
			level = atoi(optarg);
			if (level < 0 || level > 9)
				usage();
			break;
		case 'c':
			maxmode     = 1;
			inputmaxsec = atoi(optarg);
			break;
		case 'I':
			if (setpartition(ignore, optarg))
				usage();
			break;
		case 'R':
			if (setpartition(forceraw, optarg))
				usage();
			break;
		case '1':
			compat = COMPRESSED_V1;
			break;
		case '3':
			compat = COMPRESSED_V3;
			break;
		case 'F':
#ifdef WITH_HASHALIGN
			if (strcmp(optarg, "ha") == 0) {
				frangesize = -1;
				break;
			}
#endif
			frangesize = atoi(optarg);
			if (frangesize < 0)
				usage();
			break;
		case 'Z':
			zerofrange = 1;
			break;
		case 'x':
			excludenonfs++;
			break;
		case 'X':
			forcereads++;
			break;
#ifdef WITH_HASH
		case 'H':
			hashfile = optarg;
			break;
		case 'U':
			newhashfile = optarg;
			break;
		case 'P':
			deltapct = atoi(optarg);
			if (deltapct < 0)
				usage();
			break;
#else
		case 'H':
		case 'U':
		case 'P':
			fprintf(stderr, "'%c' option not supported\n", ch);
			usage();
			break;
#endif
		case 'M':
			metaoptimize++;
			break;
		case 'f':
			filemode++;
			rawmode++;
			break;
		case 'a':
#ifdef WITH_CRYPTO
			/* Authentication (checksum) hash algorithm */
			if (strcmp(optarg, "SHA1") == 0) {
				csumalg = CSUM_SHA1;
			}
			else {
				fprintf(stderr, "Only know \"SHA1\"\n");
				usage();
			}
			do_checksum++;
#ifdef SIGN_CHECKSUM
			csumalg |= CSUM_SIGNED;
#else
			fprintf(stderr, "WARNING: checksum is not signed\n");
#endif
#else
			fprintf(stderr, "'a' option not supported\n");
			usage();
#endif
			break;

		case 'e':
#ifdef WITH_CRYPTO
			/* Encryption cipher */
			if (strcmp(optarg, "bf_cbc") == 0) {
				cipher = ENC_BLOWFISH_CBC;
			}
			else {
				fprintf(stderr,
					"Only know \"bf_cbc\" (blowfish CBC)\n");
				usage();
			}
			do_encrypt++;
#else
			fprintf(stderr, "'e' option not supported\n");
			usage();
#endif
			break;
		case 'k':
#ifdef WITH_CRYPTO
			/* Encryption key file */
			enc_key = calloc(1, ENC_MAX_KEYLEN);
			if (enc_key == NULL ||
			    !encrypt_readkey(optarg, enc_key, ENC_MAX_KEYLEN))
				usage();
			/* XXX can you intuit the cipher from the key? */
			if (cipher == ENC_NONE)
				cipher = ENC_BLOWFISH_CBC;
#else
			fprintf(stderr, "'k' option not supported\n");
			usage();
#endif
			break;
		case 'u':
			/* UUID for image id. */
			if (!hexstr_to_mem(imageid, optarg, UUID_LENGTH))
				usage();
			got_imageid = 1;
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (version || debug) {
		fprintf(stderr, "%s\n", build_info);
		if (version) {
			char *str;

			fprintf(stderr, "Supports:\n");
			fprintf(stderr, "  Partitioning: ");
#ifdef WITH_MBR
			fprintf(stderr, "MBR");
			str = ",";
#endif
#ifdef WITH_GPT
			fprintf(stderr, "%sGPT", str);
#endif
			fprintf(stderr, "\n  Partition types: ");
			printslicemap();
			fprintf(stderr, "\n  Features: ");
			fprintf(stderr, "image UUIDs");
#ifdef WITH_CRYPTO
#ifdef SIGN_CHECKSUM
			fprintf(stderr, ",signed");
#else
			fprintf(stderr, ",unsigned");
#endif
			fprintf(stderr, " SHA1 checksums");
			fprintf(stderr, ",blowfish encryption");
#endif
#ifdef WITH_HASH
			fprintf(stderr, ",delta image creation");
#endif
			fprintf(stderr, "\n");
			exit(0);
		}
	}

	if (argc < 1 || argc > 2)
		usage();

	if (compat &&
	    (
#ifdef WITH_CRYPTO
	     do_encrypt || do_checksum ||
#endif
	     got_imageid)) {
		fprintf(stderr, "Cannot use uuid/encrypt/checksum with -3\n");
		usage();
	}
	if (slicemode && (slice < 1 || slice > MAXSLICES)) {
		fprintf(stderr, "Slice must be a DOS partition (1-4) "
			"or extended DOS partition (5-%d)\n\n", MAXSLICES);
		usage();
	}
	if (maxmode && slicemode) {
		fprintf(stderr, "Count option (-c) cannot be used with "
			"the slice (-s) option\n\n");
		usage();
	}
	if (!info && argc != 2) {
		fprintf(stderr, "Must specify an output filename!\n\n");
		usage();
	}
	else
		outfilename = argv[1];

	if (!slicemode && !filemode && dorelocs)
		dorelocs = 0;

	if (forcerelocs && !dorelocs)
		dorelocs = 1;

	infilename = argv[0];
	if (strcmp(infilename, "-")) {
		if ((infd = open(infilename, O_RDONLY, 0)) < 0) {
			perror(infilename);
			exit(1);
		}
		incanseek = 1;
	}
	else {
		if (!rawmode) {
			fprintf(stderr,
				"Can only use stdin as input with -f or -r\n");
			usage();
		}
		infd = fileno(stdin);
		incanseek = 0;
		forcereads = 0;
	}

#ifdef WITH_CRYPTO
	/*
	 * Let's get random!
	 */
	if (!RAND_load_file("/dev/urandom", 1024))
		fprintf(stderr, "Error getting random seed\n");

#ifdef SIGN_CHECKSUM
	/*
	 * Generate a signing pubkey.
	 * The pubkey is written to <imagename>.skey.
	 */
	if (do_checksum) {
		sig_key = RSA_generate_key(CSUM_MAX_LEN*8, 17, NULL, NULL);
		if (!info)
			output_public_key(outfilename, sig_key);
	}
#endif

	/*
	 * Generate an encryption key if none was given on the command line.
	 * The key is written to <imagename>.ekey.
	 */
	if (do_encrypt && enc_key == NULL) {
		enc_key = calloc(1, ENC_MAX_KEYLEN);
		if (enc_key == NULL || !RAND_bytes(enc_key, ENC_MAX_KEYLEN)) {
			fprintf(stderr, "Unable to generate random key\n");
			exit(1);
		}
		if (!info)
			output_encrypt_key(outfilename, enc_key,
					   ENC_MAX_KEYLEN);
	}
#endif

#ifdef WITH_V3COMPAT
	/*
	 * Deal with pre-crypto backward compatibility.
	 * We don't want to generate V4 images unless we really need it.
	 * Note that this means we do NOT generate a UUID if none was provided.
	 */
	if (!compat &&
#ifdef WITH_CRYPTO
	    !do_encrypt && !do_checksum &&
#endif
	    !got_imageid)
		compat = COMPRESSED_V3;
#endif

	/*
	 * Generate a random UUID if one was not provided and we are
	 * not operating in compatibility mode.
	 */
	if (!info && !compat && !got_imageid) {
		int fd = open("/dev/urandom", O_RDONLY, 0);

		if (fd < 0 ||
		    read(fd, imageid, sizeof(imageid)) != sizeof(imageid)) {
			fprintf(stderr, "WARNING: no UUID generated\n");
			memset(imageid, '\0', UUID_LENGTH);
		} else {
			char uuidstr[UUID_LENGTH*2+1];

			mem_to_hexstr(uuidstr, imageid, UUID_LENGTH);
			output_uuid(outfilename, uuidstr);
			got_imageid = 1;
		}

		if (fd >= 0)
			close(fd);
	}

	/*
	 * Create the skip list by scanning the filesystems on
	 * the disk or indicated partition.
	 */
	if (slicetype != 0) {
		/*
		 * See if we can get a meaningful max size value via seek
		 */
		if (inputmaxsec == 0) {
			off_t maxoff = lseek(infd, (off_t)0, SEEK_END);
			if (maxoff != (off_t)-1 && maxoff != (off_t)0) {
				inputmaxsec = bytestosec(maxoff);
				assert(inputmaxsec == 0 ||
				       inputmaxsec > inputminsec);
				if (debug)
					fprintf(stderr, "Max sector: %lu\n",
						inputmaxsec);
			}
			(void) lseek(infd, (off_t)0, SEEK_SET);
		}

		rval = read_slice(-1, slicetype, 0, inputmaxsec,
				  infilename, infd);
		if (rval == -1)
			fprintf(stderr, ", cannot process\n");
	} else if (rawmode)
		rval = read_raw(infd);
	else
		rval = read_image(infd);
	if (rval) {
		fprintf(stderr, "* * * Aborting * * *\n");
		exit(1);
	}

	/*
	 * Create a valid range list from the skip list
	 */
	(void) mergeskips(debug > 1);
	if (debug)
		dumpskips(debug > 1);
	makeranges();
#ifdef TEST_RANGEMAP
	dumpranges(debug > 1);
#else
	if (debug)
		dumpranges(debug > 1);
#endif
	if (ranges == NULL) {
		/*
		 * No valid ranges, exit with an error.
		 *
		 * XXX it is debatable whether this is really an error.
		 * Perhaps we should just create a valid image file with
		 * one chunk containing no valid ranges, but it seems likely
		 * that they probably made a mistake and we should call it
		 * out immediately.
		 */
		fprintf(stderr,
			"*** No valid data on specified disk/partition!?\n");
		exit(1);
	}
	sortrange(&fixups, 0, cmpfixups);
	if (debug > 1)
		dumpfixups(debug > 2, 0);
	fflush(stderr);

#ifdef WITH_HASH
	/*
	 * If we are creating a "delta" image from a hash signature,
	 * (hashfile != NULL) we read in the signature info and reconcile
	 * that with the known allocated range that we have just computed.
	 * The result is a new list of ranges that are currently allocated
	 * and that have changed from the signature version.
	 *
	 * If we are creating a new signature file (newhashfile != NULL)
	 * then we also collect hashinfo along the way, writing out the
	 * newfile when done.
	 */
	if (hashfile || newhashfile) {
		struct range *nranges = NULL;

		/*
		 * next compare allocated 'ranges' and 'hinfo' to find out the
		 * changed blocks -- computing the hashes for some 'ranges'
		 * in the process
		 */
		if (hashmap_compute_delta(ranges, hashfile, infd, inputminsec,
					  newhashfile, &nranges)) {
			fprintf(stderr, "Errors while computing delta!\n");
			exit(1);
		}

		/*
		 * See if we should just create a full image.
		 */
		if (hashfile && deltapct >= 0) {
			uint32_t oldsect = sectinranges(ranges);
			uint32_t newsect = sectinranges(nranges);
			int dofull =
				(oldsect == 0 ||
				 ((double)newsect / oldsect) * 100 > deltapct);
			fprintf(stderr,
				"Full image size %u sect, "
				"delta image size %u sect\n"
				"Auto image selection creating %s image.\n",
				oldsect, newsect, dofull ? "full" : "delta");
			if (dofull) {
				freeranges(nranges);
				goto done;
			}
		}

		freeranges(ranges);
		ranges = nranges;
		if (debug) {
			fprintf(stderr, "\nAfter delta computation: ");
			dumpranges(debug > 1);
			dumpfixups(debug > 2, 0);
		}
	done:
		hashmap_dump_stats(slice);
	}
#endif

	/*
	 * Now we have all the allocated information, create the image
	 * (unless we just want an info report).
	 */
	if (!info) {
		if (strcmp(outfilename, "-")) {
			if ((outfd = open(outfilename, O_RDWR|O_CREAT|O_TRUNC,
					  0666)) < 0) {
				perror("opening output file");
				exit(1);
			}
			outcanseek = 1;
			/*
			 * XXX retrywrites is a hack to avoid transient NFS
			 * write errors: we use fsync after every write to
			 * check that it worked, re-trying if not. However,
			 * some devices (e.g., /dev/null) do not support
			 * fsync, so check for that here and disable the
			 * retry if necessary.
			 */
			if (retrywrites &&
			    fsync(outfd) < 0 && errno == EINVAL) {
				fprintf(stderr,
					"WARNING: '%s' does not support fsync,"
					" write errors may not be detected "
					"or corrected.\n", outfilename);
				retrywrites = 0;
			}
		}
		else {
			outfd = fileno(stdout);
			outcanseek = 0;
			retrywrites = 0;
		}
		compress_image();
		assert(fixups == NULL);

		if (outcanseek)
			close(outfd);

#ifdef WITH_HASH
		/*
		 * Write out new signature file.
		 */
		if (newhashfile &&
		    hashmap_write_hashfile(newhashfile, outfilename))
			fprintf(stderr, "Could not write new hashfile!\n");
#endif
	}
	close(infd);

	{
		struct timeval stamp;
		unsigned int ms;

		gettimeofday(&stamp, 0);
		if (stamp.tv_usec < sstamp.tv_usec) {
			stamp.tv_usec += 1000000;
			stamp.tv_sec--;
		}
		ms = (stamp.tv_sec - sstamp.tv_sec) * 1000 +
			(stamp.tv_usec - sstamp.tv_usec) / 1000;
		fprintf(stderr,
			"Finished in %u.%03u seconds\n",
			ms / 1000, ms % 1000);
	}
	fflush(stderr);

#ifdef WITH_CRYPTO
#ifdef SIGN_CHECKSUM
	if (do_checksum)
		RSA_free(sig_key);
#endif
#endif

	exit(0);
}

static int
read_slice(int snum, iz_type stype, iz_lba start, iz_size size,
	   char *sname, int sfd)
{
	struct sliceinfo *smap = getslicemap(stype);

	if (smap && smap->process)
		return (*smap->process)(snum, stype, start, size, sname, sfd);

	fprintf(stderr, "Slice %d is an unknown type %#x (%s)",
		snum+1, stype, smap ? smap->desc : "??");
	return -1;
}

/*
 * Parse the MBR/GPT and dispatch to the individual readers.
 */
int
read_image(int fd)
{
	int		i, rval = 0;
	struct iz_disk	disk;
	struct iz_slice	*parttab;
	int		gotbb = 0;
	char *		bbstr;
	iz_lba		dstart;
	iz_size		dsize;
	int		dowarn = debug ? 2 : 0;

#ifdef WITH_GPT
	if (!gotbb && parse_gpt(fd, &disk, dowarn) == 0) {
		gotbb = 1;
		bbstr = "GPT";
	}
#endif
#ifdef WITH_MBR
	if (!gotbb && parse_mbr(fd, &disk, dowarn) == 0) {
		gotbb = 2;
		bbstr = "MBR";
	}
	/*
	 * If we are forcing interpretation as a BSD slice, there should
	 * not be an MBR, however there is sometimes this thing called the
	 * "historical bogus partition table" (by the geom code) which
	 * is an MBR with P4 having 50000 sectors. We need to avoid this
	 * so we force looking for just a disklabel instead.
	 */
	if (gotbb == 2) {
		parttab = disk.slices;
		if (parttab[3].type == IZTYPE_386BSD &&
		    parttab[3].size == 50000 && parttab[3].offset == 0 &&
		    parttab[2].size == 0 && parttab[2].offset == 0 &&
		    parttab[1].size == 0 && parttab[1].offset == 0 &&
		    parttab[0].size == 0 && parttab[0].offset == 0) {
			fprintf(stderr,
				"WARNING: ignoring historical bogus MBR\n");
			gotbb = 0;
		}
	}
#endif

	if (!gotbb) {
		/* try to parse as one of the FS types */
		warnx("No GPT or MBR partition table found!");
		return 1;
	}

	parttab = disk.slices;
	dstart = 0;
	dsize = disk.dsize;

	if (debug) {
		int i;

		fprintf(stderr, "Disk:            start %12d, size %12d\n",
			0, dsize);
		fprintf(stderr, "Usable:          start %12d, size %12d\n",
			disk.lodata, disk.hidata - disk.lodata + 1);
		fprintf(stderr, "Partition range: start %12d, size %12d\n",
			disk.losect, disk.hisect - disk.losect + 1);
		fprintf(stderr, "%s Partitions:\n", bbstr);
		for (i = 0; i < MAXSLICES; i++) {
			struct sliceinfo *sinfo;

			if (parttab[i].type == IZTYPE_INVALID)
				continue;

			fprintf(stderr, "  P%d: ", i+1);
			sinfo = getslicemap(parttab[i].type);
			if (sinfo == 0)
				fprintf(stderr, "0x%x", parttab[i].type);
			else
				fprintf(stderr, "%-12s", sinfo->desc);

			fprintf(stderr, "  start %12d, size %12d",
				parttab[i].offset, parttab[i].size);
			if (parttab[i].flags) {
				fprintf(stderr, " (");
				if (parttab[i].flags & IZFLAG_NOTSUP)
					fprintf(stderr, "Not supported,");
				if (parttab[i].flags & IZFLAG_IGNORE)
					fprintf(stderr, "IGNORED,");
				if (parttab[i].flags & IZFLAG_RAW)
					fprintf(stderr, "compress RAW");
				fprintf(stderr, ")\n");
			} else {
				fprintf(stderr, "\n");
			}
		}
		fprintf(stderr, "\n");
	}

	/*
	 * Quick, brute-force check for overlap of partitions.
	 * XXX right now, any overlap is bad and we bail.  In the future,
	 * we could determine all areas of intersection and be conservative
	 * with those areas; i.e., always save unless overlap is strictly
	 * between unused/ignored partitions.
	 */
	for (i = 0; i < MAXSLICES; i++) {
		iz_lba start1, start2;
		iz_size size1, size2;
		int ii;

		if (parttab[i].type == IZTYPE_INVALID)
			continue;

		if ((size1 = parttab[i].size) == 0)
			continue;

		start1 = parttab[i].offset;
		for (ii = i + 1; ii < MAXSLICES; ii++) {
			if (parttab[ii].type == IZTYPE_INVALID)
				continue;
			if ((size2 = parttab[ii].size) == 0)
				continue;
			start2 = parttab[ii].offset;
			if (start2+size2 > start1 &&
			    start1+size1 > start2) {
				warnx("P%d and P%d overlap!", i+1, ii+1);
				rval++;
			}
		}
	}
	if (rval)
		return 1;

	/*
	 * If not in slice mode, skip sectors outside of any partition.
	 *
	 * XXX we could skip space between partitions too since we don't
	 * allow overlapping partitions. But partitions don't have to be
	 * in lowest to highest order on the disk, so it is harder.
	 */
	if (!slicemode) {
		iz_lba dlow = disk.lodata;
		iz_lba dhigh = maxmode ? (inputmaxsec-1) : disk.hidata;
		iz_lba losect = disk.losect;
		iz_lba hisect = disk.hisect;

		if (losect > dlow) {
			addskip(dlow, losect-dlow);
			if (dowarn > 1)
				warnx("%s: skipping %u sectors at %u",
				      bbstr, losect - dlow, dlow);
		}
		if (hisect < dhigh) {
			addskip(hisect+1, dhigh-hisect);
			if (dowarn > 1)
				warnx("%s: skipping %lu sectors at %u",
				      bbstr, (unsigned long)(dhigh - hisect),
				      hisect + 1);
		}
	}

	/*
	 * Now operate on individual slices.
	 */
	for (i = 0; i < MAXSLICES; i++) {
		iz_type	type  = parttab[i].type;
		iz_lba start  = parttab[i].offset;
		iz_size size  = parttab[i].size;
		iz_flags flags= parttab[i].flags;

		/*
		 * No such slice
		 */
		if (type == IZTYPE_INVALID)
			continue;

		/*
		 * This is not the slice you are looking for...
		 */
		if (slicemode && i + 1 != slice)
			continue;

		/*
		 * Explicit request by the user to ignore the partition
		 */
		if (ignore[i] && (!ISBSD(type) || ignore[i] == ~0)) {
			fprintf(stderr,
				"P%d: forcing skip, NOT SAVING.\n", i+1);
			if (size > 0)
				addskip(start, size);
			flags |= IZFLAG_IGNORE;
		}
		/*
		 * Explicit request by the user to compress raw
		 */
		else if (forceraw[i] && (!ISBSD(type) || forceraw[i] == ~0)) {
			fprintf(stderr,
				"P%d: forcing raw compression.\n", i+1);
			flags |= IZFLAG_RAW;
		}
		/*
		 * Partition type is unsupported. We could either compress
		 * it raw or ignore it. Right now we always compress them
		 * raw. We could add an option to ignore them.
		 */
		else if ((flags & IZFLAG_NOTSUP) != 0) {
			fprintf(stderr,
				"P%d: Type 0x%x not supported, ", i+1, type);

			fprintf(stderr, "forcing raw compression.\n");
			flags |= IZFLAG_RAW;
		}
		/*
		 * Partition is being ignored either because it is unused
		 * or otherwise contains no useful info (e.g., extended DOS
		 * partitions).
		 */
		else if ((flags & IZFLAG_IGNORE) != 0) {
			fprintf(stderr,
				"P%d: %s, NOT SAVING.\n", i+1,
				type == IZTYPE_UNUSED ? "unused" : "ignored");
			if (size > 0)
				addskip(start, size);
		}
		/*
		 * Finally! We have a partition that we can apply some
		 * smarts to. If that fails, we try raw compression.
		 */
		else {
			rval = read_slice(i, type, start, size,
					  infilename, fd);
			if (rval == -1) {
				fprintf(stderr, ", forcing raw compression\n");
				rval = 0;
			}
		}

		/*
		 * In slicemode, we need to set the bounds of compression.
		 * If not in slicemode, we cannot set the bounds according
		 * to the partition info since its possible that someone
		 * will create a disk with empty space before the first
		 * partition (typical, to start partition 1 at the second
		 * cylinder) or after the last partition (Mike!). However,
		 * do not set the inputminsec since we usually want the
		 * stuff before the first partition, which is the boot stuff.
		 */
		if (slicemode) {
			inputminsec = start;
			inputmaxsec = start + size;
		} else if (!maxmode && (start + size) > inputmaxsec) {
			inputmaxsec = start + size;
		}
	}

	/*
	 * Ultimately, we are going to believe the partitioner about
	 * min/max values, but lets see how they compare.
	 */
	if (!slicemode) {
		if (dstart != inputminsec) {
			fprintf(stderr,
				"partitioner low value (%lu) different than "
				"computed value (%lu); using the former\n",
				(unsigned long)dstart, inputminsec);
			inputminsec = dstart;
		}
		if (!maxmode && dstart+dsize != inputmaxsec) {
			fprintf(stderr,
				"partitioner high value (%lu) different than "
				"computed value (%lu); using the former\n",
				(unsigned long)(dstart+dsize), inputmaxsec);
			inputmaxsec = dstart + dsize;
		}
	}
	return rval;
}

int
read_rawslice(int slice, iz_type bsdtype, iz_lba start, iz_size size,
	      char *sname, int infd)
{
	if (debug)
		fprintf(stderr, "  P%d (RAW Slice)\n", slice + 1);

	/* nothing else to do! */
	return 0;
}

/*
 * For a raw image (something we know nothing about), we report the size
 * and compress the entire thing (that is, there are no skip ranges).
 */
int
read_raw(int fd)
{
	off_t	size = 0;

	if (incanseek && (size = devlseek(fd, (off_t) 0, SEEK_END)) < 0) {
		warn("lseeking to end of raw image");
		return 1;
	}

	/*
	 * Round up the size to a sector boundary
	 */
	if (filemode)
		size = sectobytes(bytestosec(size + secsize-1));

	if (debug) {
		fprintf(stderr, "  Raw Image\n");
		fprintf(stderr, "        start %12d, size %12lld\n",
			0, (long long)size);
	}
	return 0;
}

char *usagestr =
 "usage: imagezip [-vihor] [-s #] <image | device> [outputfilename]\n"
 " -v             Print version info and exit\n"
 " -i             Info mode only.  Do not write an output file\n"
 " -h             Print this help message\n"
 " -o             Print progress indicating dots\n"
 " -r             Generate a `raw' image.  No FS compression is attempted\n"
 " -f             Generate an image from a regular file (implies -r)\n"
 " -s slice       Compress a particular slice (DOS numbering 1-4)\n"
 " image | device The input image or a device special file (ie: /dev/ad0)\n"
 " outputfilename The output file ('-' for stdout)\n"
 "\n"
 " Authentication and integrity options\n"
 " -a hashalg     Create per-chunk signatures using the hash algorithm given\n"
 " -u uuid        Assign the given value as the image UUID\n"
 "\n"
 " Encryption options\n"
 " -e cipher      Encrypt the image with the given cipher\n"
 " -k keyfile     File containing a key to use for encrypting\n"
 "\n"
 " Advanced options\n"
 " -z level       Set the compression level.  Range 0-9 (0==none, default==4)\n"
 " -I slice       Ignore (skip) the indicated slice (not with slice mode)\n"
 " -R slice       Force raw compression of the indicated slice (not with slice mode)\n"
 " -c count       Compress <count> number of sectors (not with slice mode)\n"
 " -D             Do `dangerous' writes (don't check for async errors)\n"
 " -1             Output a version one image file\n"
 " -H hashfile    Use the specified imagehash-generated signature to produce a delta image\n"
 " -U sigfile     Update or create the signature to reflect the new image.\n"
 "                Image is written to named sigfile or <outfile>.sig if ''.\n"
 " -P pct         With -H, if the resulting delta would be <pct> percent or\n"
 "                greater of the (uncompressed) size of a full image, create\n"
 "                a full image instead\n"
 "\n"
 " Debugging options (not to be used by mere mortals!)\n"
 " -d             Turn on debugging.  Multiple -d options increase output\n"
 " -b             FreeBSD slice only.  Input must be a FreeBSD FFS slice\n"
 " -l             Linux slice only.  Input must be a Linux EXT2FS slice\n"
 " -n             NTFS slice only.  Input must be an NTFS slice\n"
 " -S DOS-ptype   Treat the input device as containing a slice of the given type\n";

void
usage()
{
	fprintf(stderr, "%s", usagestr);
	exit(1);
}

#ifdef TEST_RANGEMAP
#include <libndz/rangemap.h>
struct ndz_rangemap *rangemap;

static void
initmap(void)
{
	ndz_addr_t maplo, maphi;
	int rv;

	maplo = inputminsec;
	maphi = inputmaxsec ? (inputmaxsec-1) : NDZ_HIADDR;
	fprintf(stderr, "Initializing range map [%lu-%lu]\n", maplo, maphi);

	rangemap = ndz_rangemap_init(maplo, maphi);
	assert(rangemap != NULL);

	/* consider everything allocated to start */
	rv = ndz_rangemap_alloc(rangemap, maplo, maphi-maplo+1, NULL);
	assert(rv == 0);
}

static void
freerange(ndz_addr_t start, ndz_size_t size)
{
	int rv;

	if (rangemap == NULL)
		initmap();

	rv = ndz_rangemap_dealloc(rangemap, start, size);
	assert(rv == 0);
}

static void
allocrange(ndz_addr_t start, ndz_size_t size)
{
	int rv;

	if (rangemap == NULL)
		initmap();
	rv = ndz_rangemap_alloc(rangemap, start, size, NULL);
	assert(rv == 0);
}

static int
verifyfunc(struct ndz_rangemap *imap, struct ndz_range *range, void *arg)
{
	struct range **izrangep = arg;
	struct range *izrange = *izrangep;
	ndz_addr_t addr, eaddr, izaddr, izeaddr;

	addr = range->start;
	eaddr = range->end;

	if (izrange == NULL) {
		fprintf(stderr, "*** [%lu-%lu]: ran out of iz ranges!\n",
			addr, eaddr);
		return 1;
	}
	izaddr = izrange->start;
	izeaddr = izaddr + izrange->size - 1;
	if (addr != izaddr || eaddr != izeaddr) {
		fprintf(stderr,
			"*** [%lu-%lu]: does not match iz range [%lu-%lu]!\n",
			addr, eaddr, izaddr, izeaddr);
		return 1;
	}

	*izrangep = izrange->next;
	return 0;
}

static void
comparemap(int verbose)
{
	/* XXX adjust max */
	if (inputmaxsec != 0)
		ndz_rangemap_dealloc(rangemap, inputmaxsec,
				     NDZ_HIADDR - inputmaxsec + 1);

	ndz_rangemap_dump(rangemap, verbose ? 0 : 1, NULL);

	if (frangesize == 0) {
		struct range *currange = ranges;

		/* ranges should be 1-to-1 with map ranges */
		if (ndz_rangemap_iterate(rangemap, verifyfunc, &currange))
			fprintf(stderr, "*** Maps differ!\n");
		if (currange != NULL)
			fprintf(stderr, "*** More iz ranges starting at %u!\n",
				currange->start);
	}
}
#endif

/*
 * Add a range of free space to skip
 */
void
addskip(uint32_t start, uint32_t size)
{
	struct range	   *skip;

	if ((skip = (struct range *) malloc(sizeof(*skip))) == NULL) {
		fprintf(stderr, "No memory for skip range, "
			"try again with '-F <numsect>'\n"
			"where <numsect> is greater than the current %d\n",
			frangesize);
		exit(1);
	}

	skip->start = start;
	skip->size  = size;
	skip->next  = skips;
	skips       = skip;
	numskips++;

#ifdef TEST_RANGEMAP
	freerange((ndz_addr_t)start, (ndz_size_t)size);
#endif
}

/*
 * Add an explicit valid block range.
 * We always add entries to the end of the list since we are commonly
 * called with alredy sorted entries.
 */
void
addvalid(uint32_t start, uint32_t size)
{
	static struct range **lastvalid = &ranges;
	struct range *valid;

	if ((valid = (struct range *) malloc(sizeof(*valid))) == NULL) {
		fprintf(stderr, "No memory for valid range\n");
		exit(1);
	}

	valid->start = start;
	valid->size  = size;
	valid->next  = 0;
	*lastvalid   = valid;
	lastvalid    = &valid->next;
	numranges++;
}

void
dumpskips(int verbose)
{
	struct range	*pskip;
	uint32_t	offset = 0, total = 0;
	int		nranges = 0;

	if (!skips)
		return;

	if (verbose) {
		fprintf(stderr, "\nMin sector %lu, Max sector %lu\n",
			inputminsec, inputmaxsec);
		fprintf(stderr, "Skip ranges (start/size) in sectors:\n");
	}

	pskip = skips;
	while (pskip) {
		if (verbose)
			fprintf(stderr,
				"  %12d    %9d\n", pskip->start, pskip->size);
		assert(pskip->start >= offset);
		offset = pskip->start + pskip->size;
		total += pskip->size;
		nranges++;
		pskip  = pskip->next;
	}

	fprintf(stderr,
		"Total Number of Free Sectors: %u (bytes %lld) in %d ranges\n",
		(unsigned)total, (long long)sectobytes(total), nranges);
}

#undef DOHISTO

/*
 * Zero the data associated with a free range that is being included
 * in the image because its size is less than frangesize.
 */
static void
zerofixup(void *bstart, off_t bsize, void *fdata)
{
	if (debug > 1)
		fprintf(stderr, "zerofixup: zeroing %llu@%p\n",
			(unsigned long long)bsize, bstart);

	memset(bstart, 0, bsize);
}

/*
 * Sort and merge the list of skip blocks.
 * This code also winnows out the free ranges smaller than frangesize.
 * Returns the number of entries freed, useful so that it can be called
 * on-the-fly if we run out of memory to see if we managed to free anything.
 */
int
mergeskips(int verbose)
{
	struct range *prange, **prevp;
	int freed = 0, culled = 0;
	uint32_t total = 0;
#ifdef DOHISTO
	uint32_t histo[64];
	memset(histo, 0, sizeof(histo));
#endif

	sortrange(&skips, 0, 0);
	freed += mergeranges(skips);

	/*
	 * After merging, make another pass to cull out the too-small ranges.
	 */
	if (frangesize) {
		prevp = &skips;
		while (*prevp) {
			prange = *prevp;
#ifdef WITH_HASHALIGN
			/*
			 * Free ranges should line up with hash ranges
			 */
			if (frangesize < 0) {
				unsigned int hbsize, toff, tsize;
				int didit = 0;

				hbsize = bytestosec(HASHBLK_SIZE); /* XXX */
				toff = prange->start % hbsize;
				if (prange->size < hbsize ||
				    (toff &&
				     prange->size < (hbsize - toff) + hbsize))
					goto dropall;

				if (toff) {
					tsize = hbsize - toff;
					toff = prange->start;
					
					if (zerofrange)
						addfixupfunc(zerofixup,
							     sectobytes(toff),
							     0,
							     sectobytes(tsize),
							     NULL, 0,
							     RELOC_NONE);

					prange->start += tsize;
					prange->size -= tsize;
					total += tsize;
					didit++;
				}
				tsize = prange->size % hbsize;
				if (tsize) {
					toff = prange->start + prange->size
						- tsize;
					if (zerofrange)
						addfixupfunc(zerofixup,
							     sectobytes(toff),
							     0,
							     sectobytes(tsize),
							     NULL, 0,
							     RELOC_NONE);

					prange->size -= tsize;
					total += tsize;
					didit++;
				}
				if (didit)
					culled++;
				assert(prange->size >= hbsize);
				assert((prange->start % hbsize) == 0);
				assert((prange->size % hbsize) == 0);
				prevp = &prange->next;
			} else
#endif
			if (prange->size < (uint32_t)frangesize) {
#ifdef WITH_HASHALIGN
			dropall:
#endif
				if (debug > 2)
					fprintf(stderr,
						"dropping range [%u-%u]\n",
						prange->start,
						prange->start+prange->size-1);
				if (zerofrange)
					addfixupfunc(zerofixup,
						     sectobytes(prange->start),
						     0,
						     sectobytes(prange->size),
						     NULL, 0, RELOC_NONE);
				total += prange->size;
#ifdef DOHISTO
				if (prange->size < 64)
					histo[prange->size]++;
#endif
				*prevp = prange->next;
				free(prange);
				culled++;
			} else
				prevp = &prange->next;
		}
		if (verbose && culled) {
			fprintf(stderr,
				"\nFree Sectors Ignored: %d (%lld bytes) in %d ranges\n",
				total, (long long)sectobytes(total), culled);
#ifdef DOHISTO
			{
				int i;
				double r, s;
				double cumr = 0.0, cums = 0.0;
				for (i = 0; i < 64; i++) {
					if (histo[i] == 0)
						continue;
					r = (double)histo[i]/culled*100.0;
					cumr += r;
					s = (double)(histo[i]*i)/total*100.0;
					cums += s;
					fprintf(stderr,
						"%d: %u, %4.1f%% (%4.1f%%) of ranges "
						"%4.1f%% (%4.1f%%) of sectors)\n",
						i, histo[i], r, cumr, s, cums);
				}
			}
#endif
		}
	}

	return (freed + culled);
}

#if USE_HACKSORT > 0
/*
 * A "better" sort.  Put pointers to all the linked list elements in an
 * array so that we can use qsort and then rebuild the linked list afterward.
 * The best sort technology available with less than 5 minutes work!
 */
int
#ifdef linux
sfunc(const void *e1, const void *e2, void *rfunc)
#else
sfunc(void *rfunc, const void *e1, const void *e2)
#endif
{
	int ((*rangecmp)(struct range *, struct range *)) = rfunc;
	struct range *r1 = *(struct range **)e1;
	struct range *r2 = *(struct range **)e2;

	if (r1->start > r2->start ||
	    (rfunc && (*rangecmp)(r1, r2)))
		return 1;
	return -1;
}

struct range *
bettersort(struct range *head, size_t count,
	       int (*rangecmp)(struct range *, struct range *))
{
	struct range **tarray, *nlist, **listp, *prange;
	int i;

	tarray = calloc(count, sizeof(struct range *));
	if (tarray == NULL)
		return NULL;

	i = 0;
	for (prange = head; prange; prange = prange->next) {
		assert(i < count);
		tarray[i] = prange;
		i++;
	}
	assert(i == count);
#ifdef linux
	qsort_r(tarray, count, sizeof(struct range *), sfunc, rangecmp);
#else
	qsort_r(tarray, count, sizeof(struct range *), rangecmp, sfunc);
#endif
	listp = &nlist;
	for (i = 0; i < count; i++) {
		assert(tarray[i+1] == NULL ||
		       tarray[i]->start <= tarray[i+1]->start);
		prange = tarray[i];
		*listp = prange;
		listp = &prange->next;
	}
	*listp = NULL;
	free(tarray);
	return nlist;
}
#endif

/*
 * A very dumb bubblesort!
 */
void
sortrange(struct range **headp, int domerge,
	  int (*rangecmp)(struct range *, struct range *))
{
	struct range	*prange, tmp, *head = *headp;
	int		changed = 1;

	if (head == NULL)
		return;

#if USE_HACKSORT > 0
	{
		size_t count = 0;
		for (prange = head; prange; prange = prange->next)
			count++;
		fprintf(stderr, "sorting %u records\n", count);
		if (count > 10000) {
			head = bettersort(head, count, rangecmp);
			if (head != NULL) {
				for (prange = head; prange; prange = prange->next) {
					if (prange->next)
						assert(prange->start+prange->size <= prange->next->start);
				}
				*headp = head;
				return;
			}
		}
	}
#endif

	while (changed) {
		changed = 0;

		prange = head;
		while (prange) {
			if (prange->next &&
			    (prange->start > prange->next->start ||
			     (rangecmp && (*rangecmp)(prange, prange->next)))) {
				tmp.start = prange->start;
				tmp.size  = prange->size;
				tmp.data  = prange->data;

				prange->start = prange->next->start;
				prange->size  = prange->next->size;
				prange->data  = prange->next->data;
				prange->next->start = tmp.start;
				prange->next->size  = tmp.size;
				prange->next->data  = tmp.data;

				changed = 1;
			}
			prange  = prange->next;
		}
	}

	if (domerge)
		(void)mergeranges(head);

	return;
}

/*
 * Look for contiguous free regions and combine them.
 * Returns the number of entries freed up as a result of merging.
 */
int
mergeranges(struct range *head)
{
	struct range *prange, *ptmp;
	int freed = 0;

	prange = head;
	while (prange) {
		if (prange->next == 0)
			break;

		if (prange->start + prange->size == prange->next->start) {
			if (debug > 2)
				fprintf(stderr,
					"merging ranges [%u-%u] and [%u-%u]\n",
					prange->start,
					prange->start+prange->size-1,
					prange->next->start,
					prange->next->start+prange->next->size-1);
			prange->size += prange->next->size;

			ptmp = prange->next;
			prange->next = ptmp->next;
			free(ptmp);
			freed++;
		} else
			prange = prange->next;
	}

	return (freed);
}

/*
 * Life is easier if I think in terms of the valid ranges instead of
 * the free ranges. So, convert them.  Note that if there were no skips,
 * we create a single range covering the entire partition.
 */
void
makeranges(void)
{
	struct range	*pskip, *ptmp;
	uint32_t	offset;

	offset = inputminsec;

	pskip = skips;
	while (pskip) {
		if ((pskip->start - offset) > 0)
			addvalid(offset, pskip->start - offset);
		offset = pskip->start + pskip->size;

		ptmp  = pskip;
		pskip = pskip->next;
		free(ptmp);
	}
	/*
	 * Last piece, but only if there is something to compress.
	 */
	if (inputmaxsec == 0 || (inputmaxsec - offset) != 0) {
		assert(inputmaxsec == 0 || inputmaxsec > offset);

		/*
		 * A bug in FreeBSD causes lseek on a device special file to
		 * return 0 all the time! Well we want to be able to read
		 * directly out of a raw disk (/dev/ad0), so we need to
		 * use the compressor to figure out the actual size when it
		 * isn't known beforehand.
		 *
		 * Mark the last range with 0 so compression goes to end
		 * if we don't know where it is.
		 */
		addvalid(offset, inputmaxsec ? (inputmaxsec - offset) : 0);
	}
}

void
freeranges(struct range *head)
{
	struct range *next;

	while (head != NULL) {
		next = head->next;
		free(head);
		head = next;
	}
}

uint32_t
sectinranges(struct range *range)
{
	unsigned int total = 0;

	while (range) {
		total += range->size;
		range = range->next;
	}

	return total;
}

void
dumpranges(int verbose)
{
	struct range *range;
	uint32_t total = 0;
	int nranges = 0;

	if (verbose)
		fprintf(stderr, "\nAllocated ranges (start/size) in sectors:\n");
	range = ranges;
	while (range) {
		if (verbose)
			fprintf(stderr, "  %12d    %9d\n",
				range->start, range->size);
		total += range->size;
		nranges++;
		range = range->next;
	}
	fprintf(stderr,
		"Total Number of Valid Sectors: %u (bytes %llu) in %d ranges\n",
		(unsigned)total, (unsigned long long)sectobytes(total), nranges);
#ifdef TEST_RANGEMAP
	comparemap(verbose);
#endif
}

/*
 * Fixup descriptor handling.
 *
 * Fixups are modifications that need to be made to file data prior
 * to compressing.
 */
struct fixup {
	off_t offset;	/* disk offset */
	off_t poffset;	/* partition offset */
	off_t size;
	int reloctype;
	void *data;	/* current value of data ptr */
	off_t dsize;
	void (*func)(void *, off_t, void *);
};

static void
addfixupentry(off_t offset, off_t poffset, off_t size, void *data, off_t dsize,
	      int reloctype, void (*func)(void *, off_t, void *))
{
	struct mydata {
		struct fixup _fixup;
		char _fdata[0];
	} *buf;
	struct range *entry;
	struct fixup *fixup;
	void *fdata;

	if (compat == COMPRESSED_V1) {
		static int warned;

		if (!warned) {
			fprintf(stderr, "WARNING: no fixups in V1 images\n");
			warned = 1;
		}
		return;
	}

	/*
	 * Malloc the range separate from the fixup data since
	 * sortranges will swap contents of the former.
	 */
	if ((entry = malloc(sizeof(*entry))) == NULL ||
	    (buf = malloc(sizeof(*buf) + (size_t)dsize)) == NULL) {
		fprintf(stderr, "Out of memory!\n");
		exit(1);
	}
	assert((void *)buf == (void *)&buf->_fixup);

	fixup = &buf->_fixup;
	fdata = dsize ? buf->_fdata : NULL;

	entry->start = bytestosec(offset);
	entry->size  = bytestosec(size + secsize - 1);
	entry->data  = fixup;

	fixup->offset    = offset;
	fixup->poffset   = poffset;
	fixup->size      = size;
	fixup->reloctype = reloctype;
	fixup->data	 = fdata;
	if (fdata)
		memcpy(fixup->data, data, (size_t)dsize);
	fixup->dsize	 = dsize;
	fixup->func	 = func;

	entry->next  = fixups;
	fixups       = entry;
	numfixups++;
}

/*
 * Create a fixup to apply to the disk data prior to compressing.
 * The given fixup will be applied to the appropriate data and a relocation
 * genearated if desired.  The region over which the fixup should be
 * applied is given by 'offset' and 'size'.  That range is replaced by
 * the data in 'data'.  If 'reloctype' is not 0, a relocation entry of
 * the appropraite type is generated.  'poffset' is the partition
 * offset which is used when generating relocations to ensure that
 * they are partition-relative.
 */
void
addfixup(off_t offset, off_t poffset, off_t size, void *data, int reloctype)
{
	addfixupentry(offset, poffset, size, data, size, reloctype, NULL);
}

/*
 * Similar to the above but calls a function with the fixup entry and the
 * range of data to apply the fixup to.  The data arg is passed to the
 * function along with the data range.
 */
void
addfixupfunc(void (*func)(void *, off_t, void *), off_t offset,
	     off_t poffset, off_t size, void *data, int dsize, int reloctype)
{
	addfixupentry(offset, poffset, size, data, dsize, reloctype, func);
}

/*
 * Return 1 if r1 > r2
 */
static int
cmpfixups(struct range *r1, struct range *r2)
{
	if (r1->start > r2->start ||
	    (r1->start == r2->start &&
	     ((struct fixup *)r1->data)->offset >
	     ((struct fixup *)r2->data)->offset))
		return 1;
	return 0;
}

/*
 * See if there is a fixup associated with any part of the given addr range.
 * Returns 1 if so, 0 otherwise.
 */
int
hasfixup(uint32_t soffset, uint32_t ssize)
{
	struct range *rp;
	struct fixup *fp;
	off_t offset, eoffset;

	offset = sectobytes(soffset);
	eoffset = offset + sectobytes(ssize);
	for (rp = fixups; rp != NULL; rp = rp->next) {
		fp = rp->data;

		/* range completely before fixup, all done */
		if (eoffset <= fp->offset)
			break;

		/* range completely after fixup, keep looking */
		if (offset >= fp->offset + fp->size)
			continue;

		/* otherwise, there is overlap */
#ifdef FOLLOW
		fprintf(stderr, "R: [%u-%u] overlaps with F: [%u/%u-%u/%u]\n",
			soffset, soffset+ssize-1,
			bytestosec(fp->offset),
			(uint32_t)fp->offset % SECSIZE,
			bytestosec(fp->offset+fp->size-1),
			(uint32_t)(fp->offset+fp->size-1) % SECSIZE);
#endif
		return 1;
	}

	return 0;
}

/*
 * Copy the fixup list. Keeps around the original for later restoration.
 *
 * Since applying fixups is destructive (to the fixup list) and we
 * need to apply fixups when hashing an image, we need a mechanism
 * for allowing fixups to be applied twice.
 *
 * XXX we always set reloctype to RELOC_NONE, as we don't want to add
 * relocs multiple times. Hope this is the only non-idempotent behavior...
 */
static struct range *Ofixups;
static int Onumfixups;

void
savefixups(void)
{
	struct range *range;
	struct fixup *fp;

	Ofixups = fixups;
	Onumfixups = numfixups;
	fixups = NULL;
	numfixups = 0;

	range = Ofixups;
	while (range) {
		assert(range->data != NULL);
		fp = range->data;

		addfixupentry(fp->offset, fp->poffset, fp->size,
			      fp->data, fp->dsize, RELOC_NONE, fp->func);
		range = range->next;
	}
	assert(numfixups == Onumfixups);

	/* sort--addfixupentry adds to the end, so the list is reversed */
	sortrange(&fixups, 0, cmpfixups);
}

void
restorefixups(int isempty)
{
	if (isempty) {
		assert(fixups == NULL);
		assert(numfixups == 0);
	} else {
		struct range *next;
		while (fixups) {
			next = fixups->next;
			free(fixups->data);
			free(fixups);
			numfixups--;
			fixups = next;
		}
		assert(numfixups == 0);
	}
	fixups = Ofixups;
	numfixups = Onumfixups;
}

/*
 * Look for fixups which overlap the range [offset - offset+size-1].
 * If an overlap is found, we overwrite the data for that range with
 * that given in the fixup or call the associated function.
 */
void
applyfixups(off_t offset, off_t size, void *data)
{
	struct range **prev, *entry;
	struct fixup *fp;
	uint32_t coff, clen;

#ifdef FOLLOW
	fprintf(stderr, "D: [%u-%u], %d fixups\n",
		bytestosec(offset), bytestosec(offset+size)-1, numfixups);
#endif
	prev = &fixups;
	while ((entry = *prev) != NULL) {
		assert(entry->data != NULL);
		fp = entry->data;
#ifdef FOLLOW
		fprintf(stderr, "  F%p: [%u/%u-%u/%u]: ",
			fp,
			bytestosec(fp->offset),
			(uint32_t)fp->offset % SECSIZE,
			bytestosec(fp->offset+fp->size-1),
			(uint32_t)(fp->offset+fp->size-1) % SECSIZE);
#endif

		/*
		 * Since we sort both the ranges we are processing and
		 * the fixup ranges, and we remove fixups as we apply them,
		 * we should never encounter any fixups that fall even
		 * partially before the data range we are operating on.
		 */
		assert(fp->offset >= offset);

		/*
		 * Again, since the lists are sorted, if the current fixup
		 * starts beyond the end of the data we are processing,
		 * we are done.
		 */
		if (offset+size <= fp->offset) {
#ifdef FOLLOW
			fprintf(stderr, "falls after, done\n");
#endif
			break;
		}

		/*
		 * If the frange extends beyond the current data buffer,
		 * apply as much as we can and save the rest.  We only do
		 * this for RELOC_NONE for the moment.
		 */
		if (fp->offset+fp->size > offset+size) {
			assert(fp->reloctype == RELOC_NONE);
			coff = (u_int32_t)(fp->offset - offset);
			clen = (offset + size) - fp->offset;
		} else {
			coff = (u_int32_t)(fp->offset - offset);
			clen = (u_int32_t)fp->size;
		}
		assert(offset+coff == fp->offset);
		assert(offset+coff+clen <= fp->offset+fp->size);

		if (debug > 2)
			fprintf(stderr,
				"Applying %sfixup [%llu-%llu] to [%llu-%llu]\n",
				(clen == (u_int32_t)fp->size) ?
				"full " : "partial ",
				(unsigned long long)fp->offset,
				(unsigned long long)fp->offset+fp->size,
				(unsigned long long)offset,
				(unsigned long long)offset+size);

		/* don't mess with data arg for functions */
		if (fp->func != NULL)
			(*fp->func)(data+coff, (off_t)clen, fp->data);
		else {
			memcpy(data+coff, fp->data, clen);
			fp->data += clen;
		}

		/* create a reloc if necessary */
		if (fp->reloctype != RELOC_NONE)
			addreloc(fp->offset - fp->poffset,
				 fp->size, fp->reloctype);

		/*
		 * See if there is anything left over in the fixup.
		 * If so, adjust it and move to the next entry.
		 * If not, free the entry.
		 */
		fp->size -= clen;
		if (fp->size > 0) {
			fp->offset += clen;
#ifdef FOLLOW
			fprintf(stderr, "used, reduced to [%u/%u-%u/%u]\n",
				bytestosec(fp->offset),
				(uint32_t)fp->offset % SECSIZE,
				bytestosec(fp->offset+fp->size-1),
				(uint32_t)(fp->offset+fp->size-1) % SECSIZE);
#endif
			prev = &entry->next;
		} else {
#ifdef FOLLOW
			fprintf(stderr, "used, freed E%p\n", entry);
#endif
			*prev = entry->next;
			free(entry->data);
			free(entry);
			numfixups--;
			if (debug > 2)
				fprintf(stderr, " %d fixups left\n",
					numfixups);
		}
	}
}

void
dumpfixups(int verbose, int count)
{
	struct range *range;
	struct fixup *fp;
	int nfixups = 0;

	if (verbose)
		fprintf(stderr,
			"\nFixups start/size in sectors (bytes):\n");
	range = fixups;
	while (range) {
		assert(range->data != NULL);
		fp = range->data;

		if (verbose) {
			fprintf(stderr, "  %12d/%9d (%12llu/%9llu)\n",
				range->start, range->size,
				(unsigned long long)fp->offset,
				(unsigned long long)fp->size);
		}
		nfixups++;
		if (count && count == nfixups)
			break;
		range = range->next;
	}
	fprintf(stderr, "Total Number of Fixups: %d\n", nfixups);
}

void
addreloc(off_t offset, off_t size, int reloctype)
{
	struct blockreloc *reloc;

	assert(compat != COMPRESSED_V1);

	numrelocs++;
	if (HDRUSED(numregions, numrelocs) > DEFAULTREGIONSIZE) {
		fprintf(stderr, "Over filled region/reloc table (%d/%d)\n",
			numregions, numrelocs);
		exit(1);
	}

	relocs = realloc(relocs, numrelocs * sizeof(struct blockreloc));
	if (relocs == NULL) {
		fprintf(stderr, "Out of memory!\n");
		exit(1);
	}

	reloc = &relocs[numrelocs-1];
	reloc->type = reloctype;
	reloc->sector = bytestosec(offset);
	reloc->sectoff = offset - sectobytes(reloc->sector);
	reloc->size = size;
}

void
freerelocs(void)
{
	numrelocs = 0;
	free(relocs);
	relocs = NULL;
}

/*
 * Compress the image.
 */
static uint8_t	output_buffer[CHUNKSIZE];
static int	buffer_offset;
static off_t	inputoffset;
static struct timeval cstamp;
static long long bytescompressed;

static off_t	compress_chunk(off_t, off_t, int *, uint32_t *);
static int	compress_finish(uint32_t *subblksize);
static void	compress_status(int sig);
#ifdef WITH_CRYPTO
static void	checksum_start(blockhdr_t *hdr, int alg);
static void	checksum_chunk(uint8_t *buf, off_t size);
static void	checksum_finish(blockhdr_t *hdr);
static void	encrypt_start(blockhdr_t *hdr);
static void	encrypt_chunk(uint8_t *buf, off_t size, off_t maxsize);
static void	encrypt_finish(blockhdr_t *hdr,
			       uint8_t *outbuf, uint32_t *out_size);
#endif

/*
 * Loop through the image, compressing the allocated ranges.
 */
int
compress_image(void)
{
	int		cc, full, i, count, chunkno;
	off_t		size = 0, outputoffset;
	off_t		tmpoffset, rangesize;
	struct range	*prange;
	blockhdr_t	*blkhdr;
	struct region	*curregion, *regions;
	struct timeval	estamp;
	uint8_t		*buf;
	uint32_t	cursect = 0;
	struct region	*lreg;

	gettimeofday(&cstamp, 0);
	inputoffset = 0;
#ifdef SIGINFO
	signal(SIGINFO, compress_status);
#endif

	buf = output_buffer;
	memset(buf, 0, DEFAULTREGIONSIZE);
	blkhdr = (blockhdr_t *) buf;
	switch (compat) {
	case COMPRESSED_V1:
		regions = (struct region *)((struct blockhdr_V1 *)blkhdr + 1);
		break;
	case COMPRESSED_V2:
	case COMPRESSED_V3:
		regions = (struct region *)((struct blockhdr_V2 *)blkhdr + 1);
		break;
	default:
		assert(compat == 0);
		regions = (struct region *)(blkhdr + 1);
		break;
	}
	curregion = regions;
	numregions = 0;
	chunkno = 0;

	/*
	 * Reserve room for the subblock hdr and the region pairs.
	 * We go back and fill it it later after the subblock is
	 * done and we know much input data was compressed into
	 * the block.
	 */
	buffer_offset = DEFAULTREGIONSIZE;

	prange = ranges;
	while (prange) {
		inputoffset = sectobytes(prange->start);

		/*
		 * Seek to the beginning of the data range to compress.
		 */
		if (incanseek)
			devlseek(infd, (off_t) inputoffset, SEEK_SET);

		/*
		 * The amount to compress is the size of the range, which
		 * might be zero if it is the last one (size unknown).
		 */
		rangesize = sectobytes(prange->size);

		/*
		 * Compress the chunk.
		 */
		if (debug > 1 && debug < 3) {
			fprintf(stderr,
				"Compressing range: %14llu --> ",
				(unsigned long long)inputoffset);
			fflush(stderr);
		}

		size = compress_chunk(inputoffset, rangesize,
				      &full, &blkhdr->size);

		if (debug > 2) {
			fprintf(stderr, "%14llu -> %12llu %10ld %10u %10d %d\n",
				(unsigned long long)inputoffset,
				(unsigned long long)inputoffset + size,
				prange->start - inputminsec,
				bytestosec(size),
				blkhdr->size, full);
		}
		else if (debug > 1) {
			gettimeofday(&estamp, 0);
			estamp.tv_sec -= cstamp.tv_sec;
			fprintf(stderr, "%12llu in %ld seconds.\n",
				(unsigned long long)inputoffset + size,
				(long)estamp.tv_sec);
		}
		else if (dots && full) {
			static int pos;

			putc('.', stderr);
			if (pos++ >= 60) {
				gettimeofday(&estamp, 0);
				estamp.tv_sec -= cstamp.tv_sec;
				fprintf(stderr, " %12llu %4ld\n",
					(unsigned long long)inputoffset+size,
					(long)estamp.tv_sec);
				pos = 0;
			}
			fflush(stderr);
		}

		if (size == 0)
			goto done;

		/*
		 * This should never happen!
		 */
		if (size & (secsize - 1)) {
			fprintf(stderr, "  Not on a sector boundry at %llu\n",
				(unsigned long long)inputoffset);
			return 1;
		}

		/*
		 * We have completed a region.  We have either:
		 *
		 * 1. compressed the entire current input range
		 * 2. run out of room in the 1MB chunk
		 * 3. hit the end of the input file
		 *
		 * For #1 we want to continue filling the current chunk.
		 * For 2 and 3 we are done with the current chunk.
		 */
		curregion->start = prange->start - inputminsec;
		curregion->size  = bytestosec(size);
		curregion++;
		numregions++;

		/*
		 * Check to see if the region/reloc table is full.
		 * If this is the last region that will fit in the available
		 * space (i.e., one more would not), finish off any
		 * compression we are in the middle of and declare the
		 * region full.
		 */
		if (HDRUSED(numregions+1, numrelocs) > DEFAULTREGIONSIZE) {
			assert(HDRUSED(numregions, numrelocs) <=
			       DEFAULTREGIONSIZE);
			if (!full) {
				compress_finish(&blkhdr->size);
				full = 1;
			}
		}

		/*
		 * 1. We managed to compress the entire range,
		 *    go to the next range continuing to fill the
		 *    current chunk.
		 */
		if (!full) {
			assert(rangesize == 0 || size == rangesize);

			prange = prange->next;
			continue;
		}

		/*
		 * A partial range. Well, maybe a partial range.
		 *
		 * Go back and stick in the block header and the region
		 * information.
		 */
		blkhdr->magic = compat ? compat : COMPRESSED_MAGIC_CURRENT;
		blkhdr->blockindex  = chunkno;
		blkhdr->regionsize  = DEFAULTREGIONSIZE;
		blkhdr->regioncount = (curregion - regions);
		if (compat != COMPRESSED_V1) {
			blkhdr->firstsect = cursect;
			if (size == rangesize) {
				/*
				 * Finished subblock at the end of a range.
				 * Find the beginning of the next range so that
				 * we include any free space between the ranges
				 * here.  If this was the last range, we use
				 * inputmaxsec.  If inputmaxsec is zero, we know
				 * that we did not end with a skip range.
				 */
				if (prange->next)
					blkhdr->lastsect = prange->next->start -
						inputminsec;
				else if (inputmaxsec > 0)
					blkhdr->lastsect = inputmaxsec -
						inputminsec;
				else {
					lreg = curregion - 1;
					blkhdr->lastsect =
						lreg->start + lreg->size;
				}
			} else {
				lreg = curregion - 1;
				blkhdr->lastsect = lreg->start + lreg->size;
			}
			cursect = blkhdr->lastsect;

			blkhdr->reloccount = numrelocs;
		}

		/*
		 * Dump relocation info
		 */
		if (numrelocs) {
			assert(compat != COMPRESSED_V1);
			assert(relocs != NULL);
			memcpy(curregion, relocs,
			       numrelocs * sizeof(struct blockreloc));
			freerelocs();
		}

		if (!compat)
			memcpy(blkhdr->imageid, imageid, UUID_LENGTH);

#ifdef WITH_CRYPTO
		/*
		 * Encrypt the chunk if needed.
		 * Otherwise enc_cipher will be ENC_NONE.
		 *
		 * XXX this has been broken into start/encrypt/finish
		 * so that someday it could be done in the loop along
		 * with the compression.
		 */
		if (do_encrypt) {
			assert(!compat);
			encrypt_start(blkhdr);
			encrypt_chunk(output_buffer + blkhdr->regionsize,
				      blkhdr->size, CHUNKMAX);
			encrypt_finish(blkhdr,
				       output_buffer + blkhdr->regionsize,
				       &(blkhdr->size));
		}

		/*
		 * Checksum header+chunk if needed.
		 * If no signature, csum_type will be CSUM_NONE.
		 *
		 * XXX this has been broken into start/encrypt/finish
		 * so that someday it could be done in the loop along
		 * with the compression.
		 */
		if (do_checksum) {
			assert(!compat);
			checksum_start(blkhdr, csumalg);
			checksum_chunk(output_buffer,
				       blkhdr->size + blkhdr->regionsize);
			checksum_finish(blkhdr);
		}
#endif

#ifdef WITH_HASH
		/*
		 * Update chunk numbers in new signature file.
		 */
		if (newhashfile) {
			assert(compat != COMPRESSED_V1);
			hashmap_update_chunk(blkhdr->firstsect + inputminsec,
					     blkhdr->lastsect + inputminsec,
					     blkhdr->blockindex);
		}
#endif

		/*
		 * Write out the finished chunk to disk.
		 */
		cc = devwrite(outfd, output_buffer, sizeof(output_buffer));
		if (cc != sizeof(output_buffer)) {
			if (cc < 0)
				perror("chunk write");
			else
				fprintf(stderr,
					"chunk write: short write (%d bytes)\n",
					cc);
			exit(1);
		}

		/*
		 * Moving to the next block. Reserve the header area.
		 */
		memset(buf, 0, DEFAULTREGIONSIZE);
		buffer_offset = DEFAULTREGIONSIZE;
		curregion     = regions;
		numregions    = 0;
		chunkno++;

		/*
		 * Okay, so its possible that we ended the region at the
		 * end of the subblock. I guess "partial" is a bad name.
		 * Anyway, most of the time we ended a subblock in the
		 * middle of a range, and we have to keeping going on it.
		 *
		 * Ah, the last range is a possible special case. It might
		 * have a 0 size if we were reading from a device special
		 * file that does not return the size from lseek (Freebsd).
		 * Zero indicated that we just read until EOF cause we have
		 * no idea how big it really is.
		 */
		if (size == rangesize)
			prange = prange->next;
		else {
			uint32_t sectors = bytestosec(size);

			prange->start += sectors;
			if (prange->size)
				prange->size -= sectors;
		}
	}

 done:
	/*
	 * Have to finish up by writing out the last batch of region info.
	 */
	if (curregion != regions) {
		compress_finish(&blkhdr->size);

		blkhdr->magic = compat ? compat : COMPRESSED_MAGIC_CURRENT;
		blkhdr->blockindex  = chunkno;
		blkhdr->regionsize  = DEFAULTREGIONSIZE;
		blkhdr->regioncount = (curregion - regions);
		if (compat != COMPRESSED_V1) {
			blkhdr->firstsect = cursect;
			if (inputmaxsec > 0)
				blkhdr->lastsect = inputmaxsec - inputminsec;
			else {
				lreg = curregion - 1;
				blkhdr->lastsect = lreg->start + lreg->size;
			}
			blkhdr->reloccount = numrelocs;
		}

		/*
		 * Check to see if the region/reloc table is full.
		 * XXX handle this gracefully sometime.
		 */
		if (HDRUSED(numregions, numrelocs) > DEFAULTREGIONSIZE) {
			fprintf(stderr, "Over filled region table (%d/%d)\n",
				numregions, numrelocs);
			exit(1);
		}

		/*
		 * Dump relocation info
		 */
		if (numrelocs) {
			assert(compat != COMPRESSED_V1);
			assert(relocs != NULL);
			memcpy(curregion, relocs,
			       numrelocs * sizeof(struct blockreloc));
			freerelocs();
		}

		if (!compat)
			memcpy(blkhdr->imageid, imageid, UUID_LENGTH);

#ifdef WITH_CRYPTO
		/*
		 * Encrypt the chunk if needed.
		 * Otherwise enc_cipher will be ENC_NONE.
		 *
		 * XXX this has been broken into start/encrypt/finish
		 * so that someday it could be done in the loop along
		 * with the compression.
		 */
		if (do_encrypt) {
			assert(!compat);
			encrypt_start(blkhdr);
			encrypt_chunk(output_buffer + blkhdr->regionsize,
				      blkhdr->size, CHUNKMAX);
			encrypt_finish(blkhdr,
				       output_buffer + blkhdr->regionsize,
				       &(blkhdr->size));
		}

		/*
		 * Checksum header+chunk if needed.
		 * If no signature, csum_type will be CSUM_NONE.
		 *
		 * XXX this has been broken into start/encrypt/finish
		 * so that someday it could be done in the loop along
		 * with the compression.
		 */
		if (do_checksum) {
			assert(!compat);
			checksum_start(blkhdr, csumalg);
			checksum_chunk(output_buffer,
				       blkhdr->size + blkhdr->regionsize);
			checksum_finish(blkhdr);
		}
#endif

#ifdef WITH_HASH
		/*
		 * Update chunk numbers in new signature file.
		 */
		if (newhashfile) {
			assert(compat != COMPRESSED_V1);
			hashmap_update_chunk(blkhdr->firstsect + inputminsec,
					     blkhdr->lastsect + inputminsec,
					     blkhdr->blockindex);
		}
#endif

		/*
		 * Write out the finished chunk to disk, and
		 * start over from the beginning of the buffer.
		 */
		cc = devwrite(outfd, output_buffer, sizeof(output_buffer));
		if (cc != sizeof(output_buffer)) {
			if (cc < 0)
				perror("chunk write");
			else
				fprintf(stderr,
					"chunk write: short write (%d bytes)\n",
					cc);
			exit(1);
		}
		buffer_offset = 0;
	}

	inputoffset += size;
	if (debug > 1 || dots)
		fprintf(stderr, "\n");
	compress_status(0);
	fflush(stderr);

	/*
	 * For version 2 and beyond we don't bother to go back and fill in
	 * the blockcount.  Imageunzip and frisbee don't use it.  We still
	 * do it if creating V1 images and we can seek on the output.
	 */
	if (compat != COMPRESSED_V1 || !outcanseek)
		return 0;

	/*
	 * Get the total filesize, and then number the subblocks.
	 * Useful, for netdisk.
	 */
	if ((tmpoffset = lseek(outfd, (off_t) 0, SEEK_END)) < 0) {
		perror("seeking to get output file size");
		exit(1);
	}
	count = tmpoffset / CHUNKSIZE;

	for (i = 0, outputoffset = 0; i < count;
	     i++, outputoffset += CHUNKSIZE) {

		if (lseek(outfd, (off_t) outputoffset, SEEK_SET) < 0) {
			perror("seeking to read block header");
			exit(1);
		}
		if ((cc = read(outfd, buf, sizeof(struct blockhdr_V1))) < 0) {
			perror("reading subblock header");
			exit(1);
		}
		assert(cc == sizeof(struct blockhdr_V1));
		if (lseek(outfd, (off_t) outputoffset, SEEK_SET) < 0) {
			perror("seeking to write new block header");
			exit(1);
		}
		blkhdr = (blockhdr_t *) buf;
		assert(blkhdr->blockindex == i);
		blkhdr->blocktotal = count;

		if ((cc = devwrite(outfd, buf, sizeof(struct blockhdr_V1))) < 0) {
			perror("writing new subblock header");
			exit(1);
		}
		assert(cc == sizeof(struct blockhdr_V1));
	}
	return 0;
}

static void
compress_status(int sig)
{
	struct timeval stamp;
	int oerrno = errno;
	unsigned int ms, bps;

	gettimeofday(&stamp, 0);
	if (stamp.tv_usec < cstamp.tv_usec) {
		stamp.tv_usec += 1000000;
		stamp.tv_sec--;
	}
	ms = (stamp.tv_sec - cstamp.tv_sec) * 1000 +
		(stamp.tv_usec - cstamp.tv_usec) / 1000;
	fprintf(stderr,
		"%llu input (%llu compressed) bytes in %u.%03u seconds\n",
		(unsigned long long)inputoffset,
		bytescompressed, ms / 1000, ms % 1000);
	if (badsectors)
		fprintf(stderr, "%d bad input sectors skipped\n", badsectors);
	if (sig == 0) {
		fprintf(stderr, "Image size: %llu bytes\n",
			(unsigned long long)datawritten);
		bps = ms ? (bytescompressed * 1000) / ms : 0;
		fprintf(stderr, "%.3fMB/second compressed\n",
			(double)bps / (1024*1024));
	}
	errno = oerrno;
}

/*
 * Compress a chunk. The next bit of input stream is read in and compressed
 * into the output file.
 */
#define INBSIZE		(128 * 1024)	/* size of device input buffer */
#define SBTHRESHOLD	(8 * 1024)	/* remaining space threshold */

static char		inbuf[INBSIZE];
static int		subblockleft = CHUNKMAX;
static int		subblockthresh = -1;
static z_stream		d_stream;	/* Compression stream */
#ifdef WITH_HASH_CHUNKSPLIT
static int		hashblksize;
#endif

#define CHECK_ZLIB_ERR(err, msg) { \
    if (err != Z_OK) { \
	fprintf(stderr, "%s error: %d\n", msg, err); \
	exit(1); \
    } \
}

static off_t
compress_chunk(off_t off, off_t size, int *full, uint32_t *subblksize)
{
	int		cc, count, err, tileof, finish, outsize;
	off_t		total = 0;

	/*
	 * One-time calculation
	 */
	if (subblockthresh < 0) {
		subblockthresh = SBTHRESHOLD;
#ifdef WITH_HASH_CHUNKSPLIT
		/*
		 * It is desirable to keep blocks of hashed data all
		 * within a single chunk, but it is not essential.
		 * In particular, we are not going to waste a significant
		 * fraction of each chunk just to preserve this property.
		 * Note also, that this is a heuristic anyway based on
		 * how much space we will need for the compressed
		 * version of any particular hash block.
		 *
		 * So I somewhat arbitrarily picked "no more than 5%
		 * wasted space" which translates to about 51K per 1MB
		 * chunk--call it 50K. This should work most of the time
		 * assuming about a 1.28x compression ratio with 64K hash
		 * blocks. How is that for arbitrary?
		 */
		if (newhashfile) {
			subblockthresh = (50 * 1024);
			hashblksize = hashmap_blocksize();
			if (subblockthresh > hashblksize)
				subblockthresh = hashblksize;
		}
#endif
	}

	/*
	 * Whenever subblockleft equals CHUNKMAX, it means that a new
	 * compression subblock needs to be started.
	 */
	if (subblockleft == CHUNKMAX) {
		d_stream.zalloc = (alloc_func)0;
		d_stream.zfree  = (free_func)0;
		d_stream.opaque = (voidpf)0;

		err = deflateInit(&d_stream, level);
		CHECK_ZLIB_ERR(err, "deflateInit");
	}
	*full  = 0;
	finish = 0;

	/*
	 * If no size, then we want to compress until the end of file
	 * (and report back how much).
	 */
	if (!size) {
		tileof  = 1;
		size	= INBSIZE + 1;
	} else
		tileof  = 0;

	while (size > 0) {
		if (size > INBSIZE)
			count = INBSIZE;
		else
			count = (int) size;
		/*
		 * As we get near the end of the subblock, reduce the amount
		 * of input to make sure we can fit without producing a
		 * partial output block. Easier. See explanation below.
		 * Also, subtract out a little bit as we get near the end since
		 * as the blocks get smaller, it gets more likely that the
		 * data won't be compressable (maybe its already compressed),
		 * and the output size will be *bigger* than the input size.
		 */
		if (count > (subblockleft - 1024)) {
			count = subblockleft - 1024;

			/*
			 * But of course, we always want to be sector aligned.
			 */
			count = count & ~(secsize - 1);
		}

#ifdef WITH_HASH_CHUNKSPLIT
		/*
		 * When we are computing a new signature file, try to align
		 * our read/compress blocks on hash-block size boundaries.
		 * This will hopefully minimize the odds of us needing to
		 * split a hash block across chunks.
		 */
		if (newhashfile) {
			off_t curoff, endoff;

			curoff = off+total - sectobytes(inputminsec);
			assert(curoff >= 0);
			endoff = (curoff + count) & ~(hashblksize - 1);
			if (endoff > curoff)
				count = endoff - curoff;
		}
#endif

		cc = devread(infd, inbuf, count);
		if (cc < 0) {
			perror("reading input file");
			exit(1);
		}

		if (cc == 0) {
			/*
			 * If hit the end of the file, then finish off
			 * the compression.
			 */
			finish = 1;
			break;
		}

		/*
		 * In filemode, a file may not be a multiple of the sector
		 * size.  Pad it so it is.
		 */
		if (filemode && (cc & (secsize - 1)) != 0) {
			int zoff = cc & (secsize - 1);
			int zsize = secsize - zoff;

			/* XXX minor abuse of reloc: signal short sector */
			addreloc(off+total+(cc-zoff), zoff, RELOC_SHORTSECTOR);

			memset(&inbuf[cc], 0, zsize);
			cc += zsize;
		}

		if (cc != count && !tileof) {
			fprintf(stderr, "Bad count in read, %d != %d at %llu\n",
				cc, count,
				(unsigned long long)off+total);
			exit(1);
		}

		/*
		 * Apply fixups.  This may produce a relocation record.
		 */
		if (fixups != NULL)
			applyfixups(off+total, count, inbuf);

		if (!tileof)
			size -= cc;
		total += cc;

		outsize = CHUNKSIZE - buffer_offset;

		/* XXX match behavior of original compressor */
		if (compat == COMPRESSED_V1 && outsize > 0x20000)
			outsize = 0x20000;

		d_stream.next_in   = (Bytef *)inbuf;
		d_stream.avail_in  = cc;
		d_stream.next_out  = &output_buffer[buffer_offset];
		d_stream.avail_out = outsize;
		assert(d_stream.avail_out > 0);

		err = deflate(&d_stream, Z_SYNC_FLUSH);
		CHECK_ZLIB_ERR(err, "deflate");

		if (d_stream.avail_in != 0 ||
		    (compat != COMPRESSED_V1 && d_stream.avail_out == 0)) {
			fprintf(stderr, "Something went wrong, ");
			if (d_stream.avail_in)
				fprintf(stderr, "not all input deflated!\n");
			else
				fprintf(stderr, "too much data for chunk!\n");
			exit(1);
		}
		count = outsize - d_stream.avail_out;
		buffer_offset += count;
		assert(buffer_offset <= CHUNKSIZE);
		bytescompressed += cc - d_stream.avail_in;

		/*
		 * If we have reached the subblock maximum, then need
		 * to start a new compression block. In order to make
		 * this simpler, I do not allow a partial output
		 * buffer to be written to the file. No carryover to the
		 * next block, and thats nice. I also avoid anything
		 * being left in the input buffer.
		 *
		 * The downside of course is wasted space, since I have to
		 * quit early to avoid not having enough output space to
		 * compress all the input. How much wasted space is kinda
		 * arbitrary since I can just make the input size smaller and
		 * smaller as you get near the end, but there are diminishing
		 * returns as your write calls get smaller and smaller.
		 * See above where I compare count to subblockleft.
		 */
		subblockleft -= count;
		assert(subblockleft >= 0);

		if (subblockleft < subblockthresh) {
			finish = 1;
			*full  = 1;
			break;
		}
	}
	if (finish) {
		compress_finish(subblksize);
		return total;
	}
	*subblksize = CHUNKMAX - subblockleft;
	return total;
}

/*
 * Need a hook to finish off the last part and write the pending data.
 */
static int
compress_finish(uint32_t *subblksize)
{
	int		err, count;

	if (subblockleft == CHUNKMAX)
		return 0;

	d_stream.next_in   = 0;
	d_stream.avail_in  = 0;
	d_stream.next_out  = &output_buffer[buffer_offset];
	d_stream.avail_out = CHUNKSIZE - buffer_offset;

	err = deflate(&d_stream, Z_FINISH);
	if (err != Z_STREAM_END)
		CHECK_ZLIB_ERR(err, "deflate");

	assert(d_stream.avail_out > 0);

	/*
	 * There can be some left even though we use Z_SYNC_FLUSH!
	 */
	count = (CHUNKSIZE - buffer_offset) - d_stream.avail_out;
	if (count) {
		buffer_offset += count;
		assert(buffer_offset <= CHUNKSIZE);
		subblockleft -= count;
		assert(subblockleft >= 0);
	}

	err = deflateEnd(&d_stream);
	CHECK_ZLIB_ERR(err, "deflateEnd");

	/*
	 * The caller needs to know how big the actual data is.
	 */
	*subblksize  = CHUNKMAX - subblockleft;

	/*
	 * Pad the subblock out.
	 */
	assert(buffer_offset + subblockleft <= CHUNKSIZE);
	memset(&output_buffer[buffer_offset], 0, subblockleft);
	buffer_offset += subblockleft;
	subblockleft = CHUNKMAX;
	return 1;
}

#ifdef WITH_CRYPTO
/*
 * Checksum functions
 */
SHA_CTX sha_ctx;
void
checksum_start(blockhdr_t *hdr, int alg)
{
	/*
	 * Start with the checksum zeroed out - this way, we can put the
	 * checksum in the header, but don't have to worry about skipping over
	 * it.
	 */
	memset(hdr->checksum, 0, sizeof(hdr->checksum));

	/* type is part of the checksum */
	hdr->csum_type = alg;

	SHA1_Init(&sha_ctx);
}

static void
output_encrypt_key(char *imagename, unsigned char *keybuf, int buflen)
{
	char akeybuf[ENC_MAX_KEYLEN*2+1];
	FILE *file;
	char *fname;
	int omask;

	if (strcmp(imagename, "-")) {
		fname = malloc(strlen(imagename) + 8);
		if (fname == NULL) {
			fprintf(stderr, "No memory\n");
			exit(1);
		}
		strcpy(fname, imagename);
		strcat(fname, ".ekey");
	} else {
		fname = strdup("stdout.ekey");
	}

	/* XXX */
	if (buflen > ENC_MAX_KEYLEN)
		buflen = ENC_MAX_KEYLEN;
	mem_to_hexstr(akeybuf, keybuf, buflen);

	unlink(fname);
	omask = umask(077);
	if ((file = fopen(fname, "w")) == NULL) {
		umask(omask);
		fprintf(stderr, "Cannot create keyfile %s\n", fname);
		exit(1);
	}
	umask(omask);
	fputs(akeybuf, file);
	fputc('\n', file);
	fclose(file);

	fprintf(stderr, "Encryption key written to %s\n", fname);
	free(fname);
}

#ifdef SIGN_CHECKSUM
static void
output_public_key(char *imagename, RSA *key)
{
	FILE *file;
	char *fname;

	if (strcmp(imagename, "-")) {
		fname = malloc(strlen(imagename) + 8);
		if (fname == NULL) {
			fprintf(stderr, "No memory\n");
			exit(1);
		}
		strcpy(fname, imagename);
		strcat(fname, ".skey");
	} else {
		fname = strdup("stdout.skey");
	}

	file = fopen(fname, "w");
	if (file == NULL) {
		fprintf(stderr, "Cannot create keyfile %s\n", fname);
		exit(1);
	}
#if (OPENSSL_VERSION_NUMBER >= 0x10100000L)
	const BIGNUM *n = NULL, *e = NULL;
	const BIGNUM *dmp1 = NULL, *dmq1 = NULL, *iqmp = NULL;
	RSA_get0_key(key,&n,&e,NULL);
	BN_print_fp(file, n);
	fprintf(file, "\n");
	BN_print_fp(file, e);
	fprintf(file, "\n");
	BN_print_fp(file, dmp1);
	fprintf(file, "\n");
	BN_print_fp(file, dmq1);
	fprintf(file, "\n");
	BN_print_fp(file, iqmp);
	fprintf(file, "\n");
#else
	BN_print_fp(file, key->n);
	fprintf(file, "\n");
	BN_print_fp(file, key->e);
	fprintf(file, "\n");
	BN_print_fp(file, key->dmp1);
	fprintf(file, "\n");
	BN_print_fp(file, key->dmq1);
	fprintf(file, "\n");
	BN_print_fp(file, key->iqmp);
	fprintf(file, "\n");
#endif
	fclose(file);

	fprintf(stderr, "Signing pubkey written to %s\n", fname);
	free(fname);
}
#endif

static void
output_uuid(char *imagename, char *uuidstr)
{
	FILE *file;
	char *fname;

	if (strcmp(imagename, "-")) {
		fname = malloc(strlen(imagename) + 8);
		if (fname == NULL) {
			fprintf(stderr, "No memory\n");
			exit(1);
		}
		strcpy(fname, imagename);
		strcat(fname, ".uuid");
	} else {
		fname = strdup("stdout.uuid");
	}

	file = fopen(fname, "w");
	if (file == NULL) {
		fprintf(stderr, "Cannot create keyfile %s\n", fname);
		exit(1);
	}

	fprintf(file, "%s\n", uuidstr);
	fclose(file);

	fprintf(stderr, "UUID written to %s\n", fname);
	free(fname);
}

void
checksum_chunk(uint8_t *buf, off_t size)
{
	/*
	 * Easy, just call the update function
	 */
	SHA1_Update(&sha_ctx,buf,size);
}

void
checksum_finish(blockhdr_t *hdr)
{
	/*
	 * Important! The digest field in the header MUST be big enough to hold
	 * the digest output by the finalizing function!
	 */
#ifdef SIGN_CHECKSUM
	unsigned char checksum[CSUM_MAX_LEN - 11];
	int result = 0;

	SHA1_Final(checksum, &sha_ctx);

	result = RSA_private_encrypt(sizeof(checksum), checksum,
				     hdr->checksum, sig_key,
				     RSA_PKCS1_PADDING);
	if (result == -1) {
		char errstr[128];
		int errornum = ERR_get_error();

		ERR_load_crypto_strings();
		ERR_error_string_n(errornum, errstr, sizeof(errstr));
		fprintf(stderr, "Failed signing checksum: %s\n", errstr);
		exit(1);
	}
#else
	SHA1_Final(hdr->checksum, &sha_ctx);
#endif
}

/*
 * Encryption functions
 */
#if (OPENSSL_VERSION_NUMBER >= 0x10100000L)
static EVP_CIPHER_CTX *cipher_ctxp;
#else
static EVP_CIPHER_CTX cipher_ctx;
static EVP_CIPHER_CTX *cipher_ctxp = &cipher_ctx;
#endif
static const EVP_CIPHER *ecipher;
/* XXX: the size of the IV may have to change with different ciphers */
static uint8_t iv[ENC_MAX_KEYLEN];

/*
 * For the time being, at least, we have to encrypt into a seperate buffer
 */
static uint8_t  encryption_buffer[CHUNKSIZE];
static uint8_t  *ebuffer_current;
static uint32_t encrypted_bytes;

void
encrypt_start(blockhdr_t *hdr)
{
	static int first_chunk = 1;

	/*
	 * Pick our cipher - currently, only Blowfish in CBC mode is supported
	 */
#if (OPENSSL_VERSION_NUMBER >= 0x10100000L)
	cipher_ctxp = EVP_CIPHER_CTX_new();
#else
	EVP_CIPHER_CTX_init(cipher_ctxp);
#endif
	ecipher = EVP_bf_cbc();

	/*
	 * If this is the first chunk, generate a new IV. Otherwise, we use
	 * the CBC residue from the last chunk as the IV for this chunk.
	 * This way, the decryptor can tell that both chunks are from the
	 * same file.
	 */
	if (first_chunk) {
		first_chunk = 0;
#if 1
		if (!RAND_bytes(iv, sizeof(iv))) {
			fprintf(stderr,"Unable to generate random IV\n");
			exit(1);
		}
#else
		/*
		 * Zero IV for debugging
		 */
		memset(iv, 0, sizeof(iv));
#endif
	} else {
#if 1	
		/*
		 * TODO: Figure out how to get CBC residue!
		 */
		if (!RAND_bytes(iv, sizeof(iv))) {
			fprintf(stderr,"Unable to generate random IV\n");
			exit(1);
		}
#else
		/*
		 * Zero IV for debugging
		 */
		memset(iv, 0, sizeof(iv));
#endif
	}

	/*
	 * Set the cipher and IV
	 */
	EVP_EncryptInit(cipher_ctxp, ecipher, NULL, iv);

	/*
	 * Bump up the key length and set the key
	 */
	EVP_CIPHER_CTX_set_key_length(cipher_ctxp, ENC_MAX_KEYLEN);
	EVP_EncryptInit(cipher_ctxp, NULL, enc_key, NULL);

	/*
	 * Copy the IV into the header
	 */
	memcpy(hdr->enc_iv, iv, sizeof(hdr->enc_iv));

	/*
	 * Prepare the buffer! (Preparing the buffer!)
	 */
	ebuffer_current = encryption_buffer;
	encrypted_bytes = 0;
}

void
encrypt_chunk(uint8_t *buf, off_t size, off_t maxsize)
{
	int encrypted_this_round = 0;

	/* man page says encrypted output could be this large */
	assert(size + EVP_CIPHER_CTX_block_size(cipher_ctxp) - 1 <= maxsize);

	EVP_EncryptUpdate(cipher_ctxp, ebuffer_current, &encrypted_this_round,
			  buf, size);
	encrypted_bytes += encrypted_this_round;
	ebuffer_current = encryption_buffer + encrypted_bytes;
}

void
encrypt_finish(blockhdr_t *hdr, uint8_t *outbuf, uint32_t *out_size)
{
	int encrypted_this_round = 0;

	EVP_EncryptFinal(cipher_ctxp, ebuffer_current, &encrypted_this_round);
	encrypted_bytes += encrypted_this_round;

	/*
	 * Copy the encrypted buffer back to the chunk buffer
	 */
	assert(encrypted_bytes <= CHUNKMAX);
	memcpy(outbuf, encryption_buffer, encrypted_bytes);

	hdr->enc_cipher = cipher;

	*out_size = encrypted_bytes;
}
#endif
