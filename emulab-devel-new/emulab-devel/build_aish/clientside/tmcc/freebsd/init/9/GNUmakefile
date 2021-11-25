#
# Insert Copyright Here.
#
SRCDIR		= ../../../../../../clientside/tmcc/freebsd/init/9
TESTBED_SRCDIR	= ../../../../../..
OBJDIR		= ../../../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

include $(OBJDIR)/Makeconf

all:	
client: init

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS	+= -DDEBUGSHELL -DSECURE -DLOGIN_CAP -DCOMPAT_SYSV_INIT -DTESTBED

init: init.c pathnames.h
	$(CC) $(CFLAGS) -static -o init $< -lutil -lcrypt

install:

client-install: client
	install -s -o root -g wheel -m 555 -b -B.bak -fschg -S init $(DESTDIR)/sbin/init

clean:	
	rm -f *.o core init
