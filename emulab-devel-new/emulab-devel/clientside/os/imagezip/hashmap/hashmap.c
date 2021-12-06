/*
 * Copyright (c) 2005-2014 University of Utah and the Flux Group.
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

#include <sys/types.h>
#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <openssl/sha.h>
#include <openssl/md5.h>
#include <assert.h>
#include <sys/uio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>

#include "sliceinfo.h"
#include "global.h"
#include "imagehdr.h"
#include "range.h"
#include "hashmap.h"
#include "imagehash.h"

//#define DEBUG
//#define FOLLOW
#define HASH_FREE

/*
 * globals for fetching the HASHSTATS related information
 */
#ifdef HASHSTATS
struct hashstats {
	uint32_t cur_allocated;	 /* allocated sectors in original */
	uint32_t orig_allocated; /* allocated sectors in current */
	uint32_t cur_only;	 /* sectors allocated only in current */
	uint32_t orig_only;	 /* sectors allocated only in original */
	uint32_t shared;	 /* sectors allocated in both */
	uint32_t unchanged;	 /* shared sectors that have not changed */
	uint32_t nocompare;	 /* sectors assumed different with no compare */
	uint32_t hash_compares;	 /* hash blocks compared */
	uint32_t hash_scompares; /* sectors compared */
	uint32_t hash_identical; /* hash blocks identical */
	uint32_t hash_sidentical;/* sectors identical */
	uint32_t gaps;		 /* hash ranges with free gaps */
	uint32_t gapsects;	 /* free sectors in gaps */
	uint32_t unchangedgaps;	 /* hash ranges with gaps that hash ok */
	uint32_t gapunchanged;	 /* unchanged free sectors in gaps */
	uint32_t gapnocompare;	 /* uncompared sectors in gaps */
	uint32_t fixup;		 /* uncompared due to fixup overlap */
} hashstats;

struct timeval time_orig_read, time_curr_read, time_hash, time_hash_and_cmp;
#endif

/*
 * hash_free determines what we do when we have overlapping free blocks
 * within hash range -- 
 */
#ifdef HASH_FREE
int hash_free = 1;
#else
int hash_free = 0;
#endif

static char *hashfile;
static unsigned char *hashdata;
static unsigned int hashblksize;
static struct hashinfo *nhinfo;
static unsigned int hashlen;
static unsigned char *(*hashfunc)(const unsigned char *, size_t,
				  unsigned char *);
static int imagefd;
static uint32_t poffset = ~0;

/*
 * time the operation, updating the global_v (of type 'struct timeval')
 * with the time diff.
 */
#ifdef HASHSTATS
#define TIMEOP(op, global_v) 	{			\
	struct timeval	st, et, t;			\
	gettimeofday(&st, NULL);			\
	(op);						\
	gettimeofday(&et, NULL);			\
	timersub(&et, &st, &t);				\
	timeradd(&(global_v), &t, &(global_v));		\
}
#else
#define TIMEOP(op, global_v)	(op);
#endif

#ifdef DEBUG
static char *
spewhash(unsigned char *h, int hlen)
{
	static char hbuf[HASH_MAXSIZE*2+1];
	static const char hex[] = "0123456789abcdef";
	int i;

	for (i = 0; i < hlen; i++) {
		hbuf[i*2] = hex[h[i] >> 4];
		hbuf[i*2+1] = hex[h[i] & 0xf];
	}
	hbuf[i*2] = '\0';
	return hbuf;
}

static void
dumphash(struct hashinfo *hinfo)
{
	uint32_t i, total = 0;
	struct hashregion *reg;

	for (i = 0; i < hinfo->nregions; i++) {
		reg = &hinfo->regions[i];
		printf("[%u-%u]: hash %s\n", reg->region.start,
		       reg->region.start + reg->region.size - 1,
		       spewhash(reg->hash, hashlen));
		total += reg->region.size;
	}
	printf("TOTAL = %u\n", total);
}
#endif

/*
 * Read a range of the disk and compute the hash value.
 */
static int
hash_range(uint32_t start, uint32_t size, unsigned char *hash)
{
	unsigned char		*bp;
	size_t			count, byte_size;
	ssize_t			cc;
	off_t			byte_start, retval;

	assert(imagefd >= 0);
	assert(hashfunc != NULL);
	assert(hashlen != 0);

	/*
	 * Read from the disk
	 */
	byte_size = sectobytes(size);
	byte_start = sectobytes(start);
	assert(size <= hashblksize);

	retval = lseek(imagefd, byte_start, SEEK_SET);
	if (retval < 0) {
		perror("hash_range: lseek error");
		return -1;
	}

	count = byte_size;
	bp = hashdata;
	while (count > 0) {
		TIMEOP(cc = read(imagefd, bp, count), time_curr_read);
		if (cc < 0) {
			perror("hash_range: read error");
			return -1;
		}
		if (cc == 0) {
			fprintf(stderr, "hash_range: unexpected EOF\n");
			return -1;
		}
		count -= cc;
		bp += cc;
	}

	/* XXX apply fixups */
	if (hasfixup(start, size)) {
#ifdef FOLLOW
		fprintf(stderr, "  h: [%u-%u] applying fixups\n",
			start, start + size - 1);
#endif
		applyfixups(byte_start, byte_size, hashdata);
	}

	/*
	 * Now caculate the hash, storing in the provided buffer.
	 */
	TIMEOP((void)(*hashfunc)(hashdata, byte_size, hash), time_hash);

	return 0;
}

/*
 * Read from imagefd, hash the contents and compare with the sig file hash.
 * Returns 0 if identical, 1 if not. Also returns computed hash in 'hash'.
 */
static int
hash_and_cmp(struct hashregion *hashreg, unsigned char *hash)
{
	struct region		hreg = hashreg->region;
	int			iretval;

	assert(imagefd >= 0);
	assert(hashfunc != NULL);
	assert(hashlen != 0);

	if (hash_range(hreg.start, hreg.size, hash))
		return -1;

	/*
	 * Compare the hashes
	 */
#if 0
	fprintf(stderr, "disk: %s\n", spewhash(hash, hashlen));
	fprintf(stderr, "sig:  %s\n", spewhash(hashreg->hash, hashlen));
#endif

	iretval = (memcmp(hashreg->hash, hash, hashlen) != 0);

#ifdef HASHSTATS
	hashstats.hash_compares++;
	hashstats.hash_scompares += hreg.size;
	if (!iretval) {
		hashstats.hash_identical++;
		hashstats.hash_sidentical += hreg.size;
	}
#endif

	return iretval;
}

/*
 * add to tail, coalescing the blocks if they can be, else allocate a new node.
 */
static int
add_to_range(struct range **tailp, uint32_t start, uint32_t size)
{
	struct range *tail = *tailp;

	if (tail->start + tail->size == start) {
		/*
		 * coalesce...update the tail's size.
		 */
		tail->size += size;
	} else {
		struct range *tmp = malloc(sizeof(struct range));

		if (tmp == NULL) {
			fprintf(stderr, "add_to_range: malloc failed !\n");
			return -1;
		}

		tmp->start = start;
		tmp->size = size;
		tmp->next = NULL;

		tail->next = tmp;
		*tailp = tmp;
	}
	return 0;
}

/*
 * Read the hash info from a signature file into an array of hashinfo structs
 * We also record the maximum hash range size so we can size a static buffer
 * for IO.
 */
static int
readhashinfo(char *hfile, struct hashinfo **hinfop)
{
	struct hashinfo		hi, *hinfo;
	int			fd, nregbytes, cc, i;

	assert(poffset != ~0);

	fd = open(hfile, O_RDONLY);
	if (fd < 0) {
		perror(hfile);
		return -1;
	}
	cc = read(fd, &hi, sizeof(hi));
	if (cc != sizeof(hi)) {
		if (cc < 0)
			perror(hfile);
		else
			fprintf(stderr, "%s: too short\n", hfile);
		close(fd);
		return -1;
	}
	if (strcmp((char *)hi.magic, HASH_MAGIC) != 0 ||
	    !(hi.version == HASH_VERSION_1 || hi.version == HASH_VERSION_2)) {
		fprintf(stderr, "%s: not a valid signature file\n", hfile);
		return -1;
	}
	nregbytes = hi.nregions * sizeof(struct hashregion);
	hinfo = malloc(sizeof(hi) + nregbytes);
	if (hinfo == 0) {
		fprintf(stderr, "%s: not enough memory for info\n", hfile);
		return -1;
	}
	*hinfo = hi;
	cc = read(fd, hinfo->regions, nregbytes);
	if (cc != nregbytes) {
		free(hinfo);
		return -1;
	}

	hashblksize = (hi.version == HASH_VERSION_1) ?
		bytestosec(HASHBLK_SIZE) : hi.blksize;

	/* Compensate for partition offset */
	for (i = 0; i < hinfo->nregions; i++) {
		struct hashregion *hreg = &hinfo->regions[i];
		assert(hreg->region.size <= hashblksize);

		hreg->region.start += poffset;
#ifdef HASHSTATS
		hashstats.orig_allocated += hreg->region.size;
#endif
	}
	close(fd);

	hashfile = hfile;
	hashdata = malloc(sectobytes(hashblksize));
	if (hashdata == NULL) {
		fprintf(stderr, "%s: not enough memory for data buffer\n",
			hfile);
		return -1;
	}

#ifdef DEBUG
	//dumphash(hinfo);
#endif

	*hinfop = hinfo;
	return 0;
}

int hashmap_blocksize(void)
{
	assert(hashblksize != 0);
	return sectobytes(hashblksize);
}

/*
 * Write out hash (signature) info associated with the named image.
 * Signature file will be given either the explicit 'fname' or will
 * be derived from 'iname' if 'fname' is ''.
 */
int hashmap_write_hashfile(char *fname, char *iname)
{
	int ofd, i, cc, count;
	char *hfile;

	assert(poffset != ~0);

	if (nhinfo == NULL) {
		fprintf(stderr, "No hashinfo to write!?\n");
		return -1;
	}

	/* Compensate for partition offset */
	for (i = 0; i < nhinfo->nregions; i++) {
		struct hashregion *hreg = &nhinfo->regions[i];
		assert(hreg->region.size <= nhinfo->blksize);
		assert(hreg->region.start >= poffset);

		hreg->region.start -= poffset;
	}

	/*
	 * Figure out a derived name if fname == ''.
	 */
	if (fname[0] == '\0') {
		/* Hmm...writing to stdout, call it "/tmp/stdout.sig" */
		if (strcmp(iname, "-") == 0)
			hfile = strdup("/tmp/stdout.sig");
		else {
			hfile = malloc(strlen(iname) + 5);
			if (hfile) {
				strcpy(hfile, iname);
				strcpy(hfile + strlen(hfile), ".sig");
			}
		}
	} else
		hfile = strdup(fname);
	if (hfile == NULL) {
		fprintf(stderr, "%s: out of memory\n", iname);
		return -1;
	}

	ofd = open(hfile, O_RDWR|O_CREAT|O_TRUNC, 0666);
	if (ofd < 0) {
		perror(hfile);
		free(hfile);
		hfile = malloc(strlen("/tmp/000000.sig") + 1);
		if (hfile) {
			sprintf(hfile, "/tmp/%06d.sig", getpid());
			ofd = open(hfile, O_RDWR|O_CREAT|O_TRUNC, 0666);
			if (ofd < 0) {
				perror(hfile);
				free(hfile);
				return -1;
			}
		} else
			return -1;
	}

	count = sizeof(*nhinfo) + nhinfo->nregions*sizeof(struct hashregion);
	cc = write(ofd, nhinfo, count);
	close(ofd);
	if (cc != count) {
		if (cc < 0)
			perror(hfile);
		else
			fprintf(stderr,
				"%s: incomplete write (%d) to sigfile %s\n",
				iname, cc, hfile);
		free(hfile);
		return -1;
	}

	/*
	 * Set the modtime of the hash file to match that of the image.
	 * This is a crude (but fast!) method for matching images with
	 * signatures.
	 */
	if (strcmp(iname, "-") != 0) {
		struct stat sb;
		struct timeval tm[2];

		cc = stat(iname, &sb);
		if (cc >= 0) {
#ifdef linux
			tm[0].tv_sec = sb.st_atime;
			tm[0].tv_usec = 0;
			tm[1].tv_sec = sb.st_mtime;
			tm[1].tv_usec = 0;
#else
			TIMESPEC_TO_TIMEVAL(&tm[0], &sb.st_atimespec);
			TIMESPEC_TO_TIMEVAL(&tm[1], &sb.st_mtimespec);
#endif
			cc = utimes(hfile, tm);
		}
		if (cc < 0)
			fprintf(stderr,
				"%s: WARNING: could not set mtime (%s)\n",
				hfile, strerror(errno));
	}

	fprintf(stderr, "%s: new signature written to %s\n", iname, hfile);
	free(hfile);
	return 0;
}

/*
 * We realloc the region array in big chunks so we don't thrash so much.
 * This is the number of ~32 byte regions per memory chunk
 */
#define REGPERBLK	8192	/* ~256KB -- must be power of 2 */

static int
addhash(struct hashinfo **hinfop, uint32_t start, uint32_t size,
	unsigned char *hash)
{
	struct hashinfo *hinfo = *hinfop;
	int nreg;

	if (hinfo == 0) {
		nreg = 0;
		hinfo = calloc(1, sizeof(*hinfo));
	} else {
		nreg = hinfo->nregions;
	}
	if ((nreg % REGPERBLK) == 0) {
		hinfo = realloc(hinfo, sizeof(*hinfo) +
				(nreg+REGPERBLK) * sizeof(struct hashregion));
		if (hinfo == 0)
			return -1;
		*hinfop = hinfo;
	}

	hinfo->regions[nreg].chunkno = 0;
	hinfo->regions[nreg].region.start = start;
	hinfo->regions[nreg].region.size = size;
	memcpy(hinfo->regions[nreg].hash, hash, HASH_MAXSIZE);
	hinfo->nregions++;
#ifdef FOLLOW
	fprintf(stderr, "    A: [%u-%u] %s\n",
		start, start + size - 1, spewhash(hash, hashlen));
#endif

	return 0;
}

/*
 * Create hash map entries for the indicated range of data.
 * Compute the hash of each range if not given.
 */
static int
add_to_hashmap(struct hashinfo **hinfop, uint32_t rstart, uint32_t rsize,
	       unsigned char *rhash)
{
	uint32_t offset, hsize;
	unsigned char hashbuf[HASH_MAXSIZE], *hash;

	assert(hinfop != NULL);

	/*
	 * Internally, ranges are absolute disk sector sizes.
	 * However, we want to compute hash boundaries relative to
	 * the image (partition) base.
	 */
	assert(poffset != ~0);
	offset = (rstart - poffset) % hashblksize;

	while (rsize > 0) {
		if (offset) {
			hsize = hashblksize - offset;
			if (hsize > rsize)
				hsize = rsize;
			offset = 0;
		} else if (rsize > hashblksize)
			hsize = hashblksize;
		else
			hsize = rsize;

		/*
		 * If no hash was given, we have to compute it
		 */
		if ((hash = rhash) == NULL) {
			if (hash_range(rstart, hsize, hashbuf)) {
				fprintf(stderr, "Error hashing image data\n");
				return -1;
			}
			hash = hashbuf;
		}

		if (addhash(hinfop, rstart, hsize, hash) != 0) {
			fprintf(stderr, "Out of memory for new hash map\n");
			return -1;
		}

		rstart += hsize;
		rsize -= hsize;
	}

	return 0;
}

/* Make sure we don't clobber anything in the original range chain */
#define COPYRANGE(r) ({	   \
	struct range *tmp; \
	if (r) { tmprange = *(r); tmp = &tmprange; } \
	else { tmp = NULL; } \
	tmp; \
})

/*
 * Fill in the chunk number for all hash ranges that start between
 * [ssect - lsect). For any hash range that starts but does not end
 * in the range, mark it special.
 */
void
hashmap_update_chunk(uint32_t ssect, uint32_t lsect, int chunkno)
{
	int i;
	assert(chunkno >= 0);

	if (nhinfo == NULL)
		return;

	lsect--;
	for (i = 0; i < nhinfo->nregions; i++) {
		struct hashregion *hreg = &nhinfo->regions[i];
		uint32_t hrssect = hreg->region.start;
		uint32_t hrlsect = hrssect + hreg->region.size - 1;

		/* hash range all before, skip */
		if (hrlsect < ssect)
			continue;

		/* hash range all after, we are done */
		if (hrssect > lsect)
			break;

		/* overlap at the beginning, we should have marked it */
		if (hrssect < ssect) {
			assert(HASH_CHUNKDOESSPAN(hreg->chunkno));
			continue;
		}

		/* completely contained */
		if (hrlsect <= lsect)
			hreg->chunkno = chunkno;

		/* partially contained, mark it */
		else
			hreg->chunkno = HASH_CHUNKSETSPAN(chunkno);
	}
}

/*
 * Intersect the current allocated disk ranges (curranges) with the
 * hashinfo ranges read from the signature file (hfile).
 * Return the resulting range list.
 */
int
hashmap_compute_delta(struct range *curranges, char *hfile, int infd,
		      uint32_t ssect, char *newhashfile,
		      struct range **nranges)
{
	uint32_t		gapstart, gapsize, lastdrangeend = 0;
	unsigned char 		hash[HASH_MAXSIZE];
	struct range		dummy_head, *range_tail;
	struct hashregion	*hreg, *ereg;
	struct hashinfo		*hinfo;
	struct range		*drange, tmprange;
	int			retval, changed, gapcount;
	
	assert(curranges != NULL);

	imagefd = infd;
	poffset = ssect;

	/*
	 * First we read the hashfile to get hash ranges and values.
	 * If hash file is null, then we concoct a hashinfo struct
	 * for an empty file.
	 */
	if (hfile != NULL) {
		retval = readhashinfo(hfile, &hinfo);
		if (retval < 0) {
			fprintf(stderr, "readhashinfo: failed !\n");
			return -1;
		}
	} else {
		hinfo = calloc(1, sizeof(*nhinfo));
		strcpy((char *)hinfo->magic, HASH_MAGIC);
		hinfo->version = HASH_VERSION_2;
		hinfo->hashtype = HASH_TYPE_SHA1; 		/* XXX */
		hinfo->blksize = bytestosec(HASHBLK_SIZE);	/* XXX */
		hinfo->nregions = 0;

		hashblksize = hinfo->blksize;
		hashdata = malloc(sectobytes(hashblksize));
		if (hashdata == NULL) {
			fprintf(stderr, "%s: not enough memory for data buffer\n",
				hfile);
			return -1;
		}
	}

	/*
	 * Deterimine the hash function
	 */
	switch (hinfo->hashtype) {
	case HASH_TYPE_MD5:
	default:
		hashlen = 16;
		hashfunc = MD5;
		break;
	case HASH_TYPE_SHA1:
		hashlen = 20;
		hashfunc = SHA1;
		break;
	}

	/*
	 * The new range list.  Use a dummy element as the head and
	 * keep track of the tail for easy appending.  The dummy element
	 * is initialized such that add_to_range() will not coalesce
	 * anything with it and it will remain distinct.
	 */
	dummy_head.start = ~0;
	dummy_head.size = 0;
	dummy_head.next = 0;
	range_tail = &dummy_head;

	/*
	 * Copy the fixup list since we are going to have to apply fixups
	 * before computing new hashes and applying fixups is destructive.
	 */
	if (newhashfile) {
#ifdef DEBUG
		extern int numfixups;
#endif
		savefixups();
#ifdef DEBUG
		fprintf(stderr, "Saved %d fixups, first:\n", numfixups);
		dumpfixups(1, 1);
#endif
	}

	/*
	 * Loop through all hash regions, comparing with the currently
	 * allocated disk regions.
	 */
	drange = COPYRANGE(curranges);
	ereg = hinfo->regions + hinfo->nregions;
	for (hreg = hinfo->regions; hreg < ereg; hreg++) {
		assert(drange && drange->size > 0);
#ifdef FOLLOW
		fprintf(stderr, "H: [%u-%u] start\n",
			hreg->region.start,
			hreg->region.start + hreg->region.size - 1);
		fprintf(stderr, "  D: [%u-%u] start\n",
			drange->start,
			drange->start + drange->size - 1);
#endif

		/*
		 * Any allocated ranges on disk that are before the hash
		 * range are newly allocated, and must be put in the image.
		 */
		while (drange &&
		       (drange->start + drange->size) <= hreg->region.start) {
#ifdef FOLLOW
			fprintf(stderr, "    D: [%u-%u] pre-hreg [%u-%u] skip\n",
				drange->start,
				drange->start + drange->size - 1,
				hreg->region.start,
				hreg->region.start + hreg->region.size - 1);
#endif
#ifdef HASHSTATS
			hashstats.cur_allocated += drange->size;
			hashstats.cur_only += drange->size;
#endif
			if (add_to_range(&range_tail,
					 drange->start, drange->size) < 0)
				goto error;

			/* Add hash entries for this range. */
			if (newhashfile &&
			    add_to_hashmap(&nhinfo, drange->start,
					   drange->size, NULL))
				goto error;

			lastdrangeend = drange->start + drange->size;
			drange = COPYRANGE(drange->next);
			assert(drange == NULL || drange->size > 0);
		}
		if (drange == NULL)
			break;
		assert(hreg->region.start < (drange->start + drange->size));

#ifdef FOLLOW
		fprintf(stderr, "  D: [%u-%u] after pre-hreg skip\n",
			drange->start,
			drange->start + drange->size - 1);
#endif

		/*
		 * Any allocated range in the original image that is below our
		 * first allocated range on the current disk can be ignored.
		 * (The blocks must have been deallocated.)
		 */

		if (hreg->region.start + hreg->region.size <= drange->start) {
#ifdef HASHSTATS
			hashstats.orig_only += hreg->region.size;
#endif
			continue;
		}

		/*
		 * Otherwise there is some overlap between the current drange
		 * and hreg.  To simplfy things, we split drange so that we can
		 * treat the portion of drange before the overlap seperately.
		 * thus aligning with hash boundaries
		 */
		assert(hreg->region.start + hreg->region.size > drange->start);
		assert(hreg->region.start < drange->start + drange->size);

		/*
		 * Any part of the drange that falls before the hreg is
		 * new data and needs to be in the image.
		 */
		if (drange->start < hreg->region.start) {
			uint32_t before = hreg->region.start - drange->start;
#ifdef HASHSTATS
			hashstats.cur_allocated += before;
			hashstats.cur_only += before;
#endif
			if (add_to_range(&range_tail,
					 drange->start, before) < 0)
				goto error;

#ifdef FOLLOW
			fprintf(stderr,
				"  D: [%u-%u]/[%u-%u] drange head split\n",
				drange->start,
				drange->start + before - 1,
				drange->start + before,
				drange->start + drange->size - 1);
#endif

			/* Add hash entries for this range. */
			if (newhashfile &&
			    add_to_hashmap(&nhinfo, drange->start, before,
					   NULL))
				goto error;

			/*
			 * Update drange with new start and size to account
			 * for the stuff we've taken off.  We continue
			 * processing with this new range.
			 */
			drange->start += before;
			drange->size -= before;
		}

		/*
		 * We have now isolated one or more dranges that are "covered"
		 * by the current hreg.  Here we might use the hash value
		 * associated with the hreg to determine whether the
		 * corresponding disk contents have changed.  If there is a
		 * single drange that exactly matches the hreg, then we
		 * obviously do this.  But what if there are gaps in the
		 * coverage, i.e., multiple non-adjacent dranges covered by
		 * the hreg?  This implies that not all blocks described by
		 * the original hash are still important in the current image.
		 * In fact there could be as little as a single disk block
		 * still valid for a very large hrange.
		 *
		 * In this case we can either blindly include the dranges
		 * in the merged list (hash_free==0), or we can go ahead and
		 * do the hash over the entire range (hash_free==1) on the
		 * chance that the blocks that are no longer allocated (the
		 * "gaps" between dranges) have not changed content and the
		 * hash will still match and thus we can avoid including the
		 * dranges in the merged list.  The latter is valid, but is
		 * it likely to pay off?  We will have to see.
		 */
		if (hash_free ||
		    (drange->start == hreg->region.start &&
		     drange->size >= hreg->region.size)) {

			/*
			 * If there is a fixup, we have to include the
			 * underlying range in the new image. Even if the
			 * range matched after the fixup was applied, there
			 * would have to be something to apply the fixup to!
			 */
			if (hasfixup(hreg->region.start, hreg->region.size)) {
				changed = 3;
#ifdef FOLLOW
				fprintf(stderr, "  H: [%u-%u] fixup overlap\n",
					hreg->region.start,
					hreg->region.start + hreg->region.size-1);
#endif
			} else {

				TIMEOP(
				       changed = hash_and_cmp(hreg, hash),
				       time_hash_and_cmp);
				if (changed < 0)
					goto error;

#ifdef FOLLOW
				fprintf(stderr, "  H: [%u-%u] hash %s\n",
					hreg->region.start,
					hreg->region.start + hreg->region.size-1,
					changed ? "differs" : "matches");
#endif
				/*
				 * We have a hash value corresponding to
				 * the new contents of the old hrange.
				 * Add that hrange with the new hash.
				 */
				if (newhashfile &&
				    add_to_hashmap(&nhinfo, hreg->region.start,
						   hreg->region.size, hash))
					goto error;
			}
		} else {
			/*
			 * There is a gap in the dranges covered by the hreg.
			 * Just save all dranges covered by this hreg.
			 */
			changed = 2;
#ifdef FOLLOW
			fprintf(stderr, "  H: [%u-%u] no compare\n",
				hreg->region.start,
				hreg->region.start + hreg->region.size - 1);
#endif
		}

#ifdef HASHSTATS
		hashstats.shared += hreg->region.size;
		if (!changed)
			hashstats.unchanged += hreg->region.size;
		else if (changed > 1) {
			hashstats.nocompare += hreg->region.size;
			if (changed == 3)
				hashstats.fixup += hreg->region.size;
		}
		gapstart = hreg->region.start;
		gapsize = gapcount = 0;
#endif
		/*
		 * Loop through all dranges completely covered by the hreg
		 * and add them or skip them depending on changed.
		 */
		assert(drange &&
		       drange->start < hreg->region.start + hreg->region.size);
		while (drange &&
		       drange->start < hreg->region.start + hreg->region.size) {
			uint32_t curstart = drange->start;
			uint32_t curend = curstart + drange->size;
			uint32_t hregstart = hreg->region.start;
			uint32_t hregend = hregstart + hreg->region.size;

			/*
			 * There may be a final drange which crosses over the
			 * hreg end, in which case we split it, treating the
			 * initial part here, and leaving the rest for the next
			 * iteration.
			 */
			if (curend > hregend) {
				uint32_t after = curend - hregend;
#ifdef FOLLOW
				fprintf(stderr, "    D: [%u-%u]/[%u-%u] drange tail split\n",
					curstart,
					hregend - 1,
					hregend,
					curend - 1);
#endif

				drange->start = hregend;
				drange->size = after;

				curend = hregend;
			}

			assert(curstart >= hregstart);
			assert(curend <= hregend);

#ifdef FOLLOW
			fprintf(stderr, "    D: [%u-%u] drange covered, changed=%d\n",
				curstart, curend - 1, changed);
#endif

#ifdef HASHSTATS
			/*
			 * Keep track of the gaps
			 */
			if (gapstart < curstart) {
#ifdef FOLLOW
				fprintf(stderr,
					"    G: [%u-%u]\n",
					gapstart, curstart - 1);
#endif
				gapsize += curstart - gapstart;
				gapcount++;
			}
			gapstart = curend;
			hashstats.cur_allocated += curend - curstart;
#endif
			if (changed) {
				/*
				 * add the overlapping region.
				 */
				if (add_to_range(&range_tail, curstart,
						 curend - curstart) < 0)
					goto error;

				/*
				 * If changed is 0 or 1, we have already
				 * added the entry with the correct hash,
				 * otherwise add hash entries.
				 */
				if (changed > 1 && newhashfile &&
				    add_to_hashmap(&nhinfo, curstart,
						   curend - curstart,
						   NULL))
					goto error;
			}

			/*
			 * Unless we split the current entry, bump
			 * drange to the next entry.
			 */
			if (curstart == drange->start) {
				lastdrangeend = curend;
				drange = COPYRANGE(drange->next);
				assert(drange == NULL || drange->size > 0);
			}
		}

#ifdef HASHSTATS
		/*
		 * Check for an end gap
		 */
		if (gapstart < hreg->region.start + hreg->region.size) {
			uint32_t hregend =
				hreg->region.start + hreg->region.size;
#ifdef FOLLOW
			fprintf(stderr, "    G: [%u-%u]\n",
				gapstart, hregend - 1);
#endif
			gapsize += hregend - gapstart;
			gapcount++;
		}

		/*
		 * Properly account for gaps.
		 * Earlier we counted the gap as part of the shared
		 * space and as either unchanged or uncompared--adjust
		 * those counts now.
		 */
		if (gapcount) {
			hashstats.gaps++;

			/* note adjustment of counts set above */
			hashstats.shared -= gapsize;
			hashstats.gapsects += gapsize;
			if (!changed) {
				hashstats.unchanged -= gapsize;
				hashstats.unchangedgaps++;
				hashstats.gapunchanged += gapsize;
			} else if (changed > 1) {
				hashstats.nocompare -= gapsize;
				if (changed == 3)
					hashstats.fixup -= gapsize;
				hashstats.gapnocompare += gapsize;
			}
#ifdef FOLLOW
			fprintf(stderr, "  H: [%u-%u] %d/%d free\n",
				hreg->region.start,
				hreg->region.start + hreg->region.size - 1,
				gapsize, hreg->region.size);
#endif
		}
#endif
		if (drange == NULL)
			break;
		assert(drange->start >= hreg->region.start + hreg->region.size);
	}
	assert(drange == NULL || hreg == ereg);

	/*
	 * Remaining hash entries are ignored since they are deallocated
	 * space.  We do keep stats about them however.
	 */
#ifdef HASHSTATS
	while (hreg < ereg) {
		uint32_t size;

		/*
		 * If we ran out of dranges in the middle of an hreg,
		 * the rest of the hreg is deallocated.
		 */
		if (lastdrangeend > 0 &&
		    lastdrangeend <= hreg->region.start + hreg->region.size) {
			size = hreg->region.start + hreg->region.size -
				lastdrangeend;
#ifdef FOLLOW
			fprintf(stderr, "H: [%u-%u]/[",
				hreg->region.start,
				lastdrangeend - 1);
			if (size)
				fprintf(stderr, "%u-%u",
					lastdrangeend,
					hreg->region.start +
					hreg->region.size - 1);
			fprintf(stderr, "] split, tail skipped\n");
#endif
		} else {
			size = hreg->region.size;
#ifdef FOLLOW
			fprintf(stderr, "H: [%u-%u] skipped\n",
				hreg->region.start,
				hreg->region.start + hreg->region.size - 1);
#endif
		}
		hashstats.orig_only += size;

		lastdrangeend = 0;
		hreg++;
	}
#endif

	/*
	 * Remaining dranges are added to the changed blocks list.
	 */
	while (drange) {
		assert(hreg == ereg);
#ifdef HASHSTATS
		hashstats.cur_allocated += drange->size;
		hashstats.cur_only += drange->size;
#endif
		if (add_to_range(&range_tail, drange->start, drange->size) < 0)
			goto error;

#ifdef FOLLOW
		fprintf(stderr, "  D: [%u-%u] post-hregs skip\n",
			drange->start,
			drange->start + drange->size - 1);
#endif

		/* Add hash entries for this range. */
		if (newhashfile &&
		    add_to_hashmap(&nhinfo, drange->start, drange->size, NULL))
			goto error;

		drange = COPYRANGE(drange->next);
		assert(drange == NULL || drange->size > 0);
	}
	*nranges = dummy_head.next;

	/*
	 * If creating a new hashfile, copy over header info from
	 * the old one. Even if there are no ranges in the current
	 * image, we create a valid (null) hashfile.
	 */
	if (newhashfile) {
		if (nhinfo == NULL)
			nhinfo = calloc(1, sizeof(*nhinfo));
		assert(nhinfo != NULL);
		strcpy((char *)nhinfo->magic, HASH_MAGIC);
		nhinfo->version = HASH_VERSION_2;
		nhinfo->hashtype = hinfo->hashtype;
		nhinfo->blksize = (hinfo->version == HASH_VERSION_1) ?
			HASHBLK_SIZE : hinfo->blksize;
	}

	if (newhashfile) {
#ifdef DEBUG
		extern int numfixups;
		fprintf(stderr, "%d fixups left-over (should be zero!)\n",
			numfixups);
#endif
		restorefixups(1);
#ifdef DEBUG
		fprintf(stderr, "Restored %d fixups, first:\n", numfixups);
		dumpfixups(1, 1);
#endif
	}
	return 0;

error:
	if (newhashfile) {
#ifdef DEBUG
		extern int numfixups;
		fprintf(stderr, "%d fixups left-over\n", numfixups);
#endif
		restorefixups(0);
#ifdef DEBUG
		fprintf(stderr, "Restored %d fixups, first:\n", numfixups);
		dumpfixups(1, 1);
#endif
	}
	if (nhinfo)
		free(nhinfo);
	freeranges(dummy_head.next);
	return -1;
}

#define NZ(v) ((v)?(v):1)

void
hashmap_dump_stats(int pnum)
{
#ifdef HASHSTATS
	uint32_t b1, b2;
	double t;
	struct stat sb;

	fprintf(stderr,"\nHASH STATS:\n\n");

	fprintf(stderr, "Signature file:         %s ",
		hashfile ? hashfile : "<none>");
	if (hashfile) {
		sb.st_mtime = 0;
		if (lstat(hashfile, &sb) >= 0 && S_ISLNK(sb.st_mode)) {
			char nbuf[128];
			int i;

			i = readlink(hashfile, nbuf, sizeof(nbuf));
			if (i > 0) {
				nbuf[i] = 0;
				fprintf(stderr, "-> %s ", nbuf);
			}
			stat(hashfile, &sb);
		}
		fprintf(stderr, "(%u)\n", (unsigned)sb.st_mtime);
	}
	fprintf(stderr, "Partition:              %d\n", pnum);

	fprintf(stderr, "Max hash block size:    %u sectors\n",
		hashblksize);
	fprintf(stderr, "Hash incomplete ranges: %s\n\n",
		hash_free ? "yes" : "no");

	t = time_curr_read.tv_sec + (double)time_curr_read.tv_usec / 1000000.0;
	fprintf(stderr, "Disk read time:         %7.3f sec\n", t);

	t = time_hash.tv_sec + (double)time_hash.tv_usec / 1000000.0;
	fprintf(stderr, "Hash time:              %7.3f sec\n", t);

	t = time_hash_and_cmp.tv_sec +
		(double)time_hash_and_cmp.tv_usec / 1000000.0;
	fprintf(stderr, "Read+hash time:         %7.3f sec\n\n", t);

	if (hashstats.orig_allocated) {
		b1 = hashstats.hash_compares;
		b2 = hashstats.hash_identical;
		fprintf(stderr, "Hash blocks compared:   %10u\n",
			b1);
		fprintf(stderr, "  Identical:            %10u (%.1f%%)\n",
			b2, ((double)b2 / NZ(b1)) * 100.0);

		b1 = hashstats.hash_scompares;
		b2 = hashstats.hash_sidentical;
		fprintf(stderr, "Total sectors compared: %10u\n",
			b1);
		fprintf(stderr, "  Identical:            %10u (%.1f%%)\n\n",
			b2, ((double)b2 / NZ(b1)) * 100.0);
	}

	b1 = hashstats.orig_allocated;
	fprintf(stderr, "Original sectors:       %10u\n", b1);

	b1 = hashstats.cur_allocated;
	fprintf(stderr, "Current sectors:        %10u\n", b1);

	if (hashstats.orig_allocated) {
		b1 = hashstats.shared;
		fprintf(stderr, "Common sectors:         %10u\n", b1);

		b1 = hashstats.orig_allocated;
		b2 = hashstats.orig_only + hashstats.gapsects;		
		fprintf(stderr, "Deleted from original:  %10u (%.1f%%)\n",
			b2, ((double)b2 / b1) * 100.0);

		b2 = hashstats.cur_only;
		fprintf(stderr, "Added to original:      %10u (%.1f%%)\n",
			b2, ((double)b2 / b1) * 100.0);

		b2 = (hashstats.shared - hashstats.unchanged);
		fprintf(stderr, "Modified from original: %10u (%.1f%%)\n\n",
			b2, ((double)b2 / b1) * 100.0);

		fprintf(stderr, "Hash blocks covering free sectors:   %u\n",
			hashstats.gaps);
		fprintf(stderr, "  Total free sectors covered:        %u\n",
			hashstats.gapsects);
		fprintf(stderr, "  Hash blocks compared identical:    %u\n",
			hashstats.unchangedgaps);
		fprintf(stderr, "  Free sectors compared identical:   %u\n",
			hashstats.gapunchanged);
		fprintf(stderr, "  Allocated sectors assumed changed: %u\n",
			hashstats.nocompare);
		fprintf(stderr, "    Assumed changed due to fixups:   %u\n",
			hashstats.fixup);
	}

	fprintf(stderr,"\nEND HASH STATS\n");
#endif
}
