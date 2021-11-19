#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

SRCDIR		= ../../ssl
TESTBED_SRCDIR	= ../..
EVENTSYS	= 1
OBJDIR		= ..
SUBDIR		= ssl
RANDFILE        = ./.rnd

# Installed certs and keys.
APACHE_ETCDIR	    = /usr/local/etc/apache
APACHE_CERTFILE     = $(APACHE_ETCDIR)/ssl.crt/www.$(OURDOMAIN).crt
APACHE_KEYFILE      = $(APACHE_ETCDIR)/ssl.key/www.$(OURDOMAIN).key
APACHE_CERTFILE_OPS = $(APACHE_ETCDIR)/ssl.crt/$(USERNODE).crt
APACHE_KEYFILE_OPS  = $(APACHE_ETCDIR)/ssl.key/$(USERNODE).key

include $(OBJDIR)/Makeconf

all:	emulab.pem server.pem localnode.pem ctrlnode.pem \
	capture.pem capture.fingerprint capture.sha1fingerprint \
	keys mksig updatecert

remote-site:	emulab.pem capture.pem capture.fingerprint server.pem \
	localnode.pem capture.sha1fingerprint apache.pem apache-ops.pem \
	ctrlnode.pem updatecert

clearinghouse:	emulab.pem apache.pem

include $(TESTBED_SRCDIR)/GNUmakerules

#
# You do not want to run these targets unless you are sure you
# know what you are doing! You really do not want to install these
# unless you are very sure you know what you are doing. You could
# mess up all the clients when the CA changes out from under them.
#
pems:	emulab.pem server.pem client.pem

prebuild: dirsmade emulab.cnf emulab-geni.cnf

emulab.pem:	dirsmade emulab.cnf emulab-geni.cnf emulab.key emulab.pub
	#
	# Create the Certificate Authority.
	# The certificate is installed on both boss and remote nodes.
	#
ifeq (1,1)
	openssl req -new -x509 -days 2000 -config emulab-geni.cnf \
		    -text -key emulab.key -out emulab.pem
else
	openssl req -new -x509 -days 2000 -config emulab.cnf \
		    -text -key emulab.key -out emulab.pem
endif

server.pem:	dirsmade mkserial server.cnf ca.cnf server.key server.req
	# Create the serial file.
	perl ./mkserial
	#
	# Sign the server cert request, creating a server certificate.
	#
	openssl ca -batch -policy policy_match -config ca.cnf \
		-out server.pem -cert emulab.pem -keyfile emulab.key \
		-infiles server.req
	#
	# Combine the key and the certificate into one file which is installed
	# on boss and used by tmcd.
	#
	cat server.key >> server.pem

#
# This is for the main web server on boss.
# 
apache.pem:	dirsmade mkserial apache.cnf ca.cnf apache.key apache.req
	# Create the serial file.
	perl ./mkserial
	#
	# Sign the apache cert request, creating an apache certificate.
	#
	openssl ca -batch -policy policy_sslxmlrpc -config ca.cnf \
		-out apache.pem -cert emulab.pem -keyfile emulab.key \
		-infiles apache.req

#
# This is for the secondary web server on users.
# 
apache-ops.pem:	dirsmade mkserial apache-ops.cnf ca.cnf apache-ops.key apache-ops.req
	# Create the serial file.
	perl ./mkserial
	#
	# Sign the apache cert request, creating an apache certificate.
	#
	openssl ca -batch -policy policy_sslxmlrpc -config ca.cnf \
		-out apache-ops.pem -cert emulab.pem -keyfile emulab.key \
		-infiles apache-ops.req

capture.pem:	dirsmade mkserial capture.cnf ca.cnf capture.key capture.req
	# Create the serial file.
	perl ./mkserial
	#
	# Sign the capture cert request, creating a capture certificate.
	#
	openssl ca -batch -policy policy_match -config ca.cnf \
		-out capture.pem -cert emulab.pem -keyfile emulab.key \
		-infiles capture.req
	#
	# Combine the key and the certificate into one file which is installed
	# on boss and used by capture.
	#
	cat capture.key >> capture.pem

#
# Generate the fingerprint of the capture certificate
# NOTE: I'd rather use SHA1 than SHA, but we've widely distributed the
# tiptunnel binary, and it needs SHA
# NOTE: We have no choice anymore, openssl no longer supports SHA.
#
capture.fingerprint:	capture.pem
	openssl x509 -sha1 -noout -fingerprint -in capture.pem \
	    > capture.fingerprint

capture.sha1fingerprint:	capture.pem
	openssl x509 -sha1 -noout -fingerprint -in capture.pem \
	    > capture.sha1fingerprint

localnode.pem:	dirsmade mkserial localnode.cnf ca.cnf localnode.key localnode.req
	cat localnode.key >> localnode.req
	# Create the serial file.
	perl ./mkserial
	$(SRCDIR)/mkclient.sh localnode

ctrlnode.pem:	dirsmade mkserial ctrlnode.cnf ca.cnf ctrlnode.key ctrlnode.req
	cat ctrlnode.key >> ctrlnode.req
	# Create the serial file.
	perl ./mkserial
	$(SRCDIR)/mkclient.sh ctrlnode

keys:		emulab_privkey.pem emulab_pubkey.pem

emulab_privkey.pem: | $(RANDFILE)
	#
	# Generate a priv key for signing stuff. This one gets a
	# passphrase.
	# 
	(RANDFILE=$(RANDFILE) \
	 openssl genrsa -out emulab_privkey.pem -rand $(RANDFILE) -des3 2048)

emulab_pubkey.pem:	emulab_privkey.pem
	#
	# Extract a pubkey from the privkey
	# 
	openssl rsa -in emulab_privkey.pem -pubout -out emulab_pubkey.pem

#
# Rule to generate an rsa key with no encryption
# If this fails, check to make sure that ~/.rnd is owned
# by you and writable. 
#
%.key:	| $(RANDFILE)
	(RANDFILE=$(RANDFILE) openssl genrsa -out $@ -rand $(RANDFILE) 2048)

#
# Rule to extract public key from private key,
#
%.pub:
	openssl rsa -in $*.key -pubout -out $@

$(RANDFILE):
	dd if=/dev/urandom of=$(RANDFILE) bs=256 count=4

# The point of the this is to recover the keys from where they were
# originally installed. We do this cause people often lose their
# original build tree, but if want to rebuild the certs, we usually
# want the original keys. 
recover-keys:
	-cp $(INSTALL_DIR)/etc/emulab.key emulab.key
	-cp $(INSTALL_DIR)/etc/emulab_privkey.pem emulab_privkey.pem
	-cp $(APACHE_KEYFILE) apache.key
	-openssl rsa -in $(INSTALL_DIR)/etc/server.pem -out server.key
	-openssl rsa -in $(INSTALL_DIR)/etc/capture.pem -out capture.key
	-openssl rsa -in $(INSTALL_DIR)/etc/ctrlnode.pem -out ctrlnode.key
	-openssl rsa -in $(INSTALL_DIR)/etc/client.pem -out localnode.key
	-scp ${USERNODE}:${APACHE_KEYFILE_OPS} apache-ops.key
	touch recover-keys

#
# Rule to generate a certificate request using the existing key.
#
%.req:
	# No good place to put this. 
	@chmod +x mkserial
	openssl req -new -config $*.cnf -key $*.key -text -out $@
	#
	# Combine key and cert request.
	#
	cat $*.key >> $@

dirsmade: 
	-mkdir -p certs
	-mkdir -p newcerts
	-mkdir -p crl
	# The initial system certificates start here.
	echo "0001" > serial
	touch index.txt
	touch dirsmade

install-dirs:
	-mkdir -p $(INSTALL_DIR)/ssl
	chmod 770 $(INSTALL_DIR)/ssl
	-mkdir -p $(INSTALL_DIR)/ssl/certs
	-mkdir -p $(INSTALL_DIR)/ssl/newcerts
	chmod 775 $(INSTALL_DIR)/ssl/newcerts
	-mkdir -p $(INSTALL_DIR)/ssl/crl
	-mkdir -p $(INSTALL_DIR)/ssl/keys
	-mkdir -p $(INSTALL_LIBDIR)/ssl
	-mkdir -p $(APACHE_ETCDIR)/ssl.crt
	-mkdir -p $(APACHE_ETCDIR)/ssl.key
	chmod 700 $(APACHE_ETCDIR)/ssl.crt
	chmod 700 $(APACHE_ETCDIR)/ssl.key

$(INSTALL_DIR)/ssl/serial:
	# It does not matter what we put in here; we use the DB to
	# create unique serial numbers after initial install
	echo "01" > $(INSTALL_DIR)/ssl/serial

$(INSTALL_DIR)/ssl/index.txt:
	touch $(INSTALL_DIR)/ssl/index.txt

#
# You do not want to run these targets unless you are sure you
# know what you are doing!
#
install:	install-dirs $(INSTALL_SBINDIR)/mksig
	@echo "BE VERY CAREFUL! INSTALLING NEW CERTS CAN CAUSE DISASTER!"

boss-installX:	install-dirs \
		$(INSTALL_DIR)/ssl/serial $(INSTALL_DIR)/ssl/index.txt \
		$(INSTALL_ETCDIR)/emulab.pem \
		$(INSTALL_ETCDIR)/emulab.key \
		$(INSTALL_ETCDIR)/emulab.pub \
		$(INSTALL_ETCDIR)/server.pem \
		$(INSTALL_ETCDIR)/ctrlnode.pem \
		$(INSTALL_ETCDIR)/capture.pem \
		$(INSTALL_ETCDIR)/capture.fingerprint \
		$(INSTALL_ETCDIR)/capture.sha1fingerprint \
		$(INSTALL_ETCDIR)/emulab_privkey.pem \
		$(INSTALL_ETCDIR)/emulab_pubkey.pem \
		$(INSTALL_SBINDIR)/updatecert \
		install-conf
	$(INSTALL_DATA) localnode.pem $(INSTALL_ETCDIR)/client.pem
	chmod 644 $(INSTALL_ETCDIR)/emulab.pem
	chmod 644 $(INSTALL_ETCDIR)/emulab.key
	chmod 644 $(INSTALL_ETCDIR)/emulab.pub
	chmod 640 $(INSTALL_ETCDIR)/server.pem
	chmod 640 $(INSTALL_ETCDIR)/client.pem
	chmod 640 $(INSTALL_ETCDIR)/ctrlnode.pem
	chmod 640 $(INSTALL_ETCDIR)/emulab_privkey.pem
	chmod 640 $(INSTALL_ETCDIR)/capture.pem
	chmod 644 $(INSTALL_ETCDIR)/capture.fingerprint
	chmod 644 $(INSTALL_ETCDIR)/capture.sha1fingerprint

install-conf:	usercert.cnf syscert.cnf ca.cnf
	$(INSTALL_DATA) usercert.cnf $(INSTALL_LIBDIR)/ssl/usercert.cnf
	$(INSTALL_DATA) syscert.cnf $(INSTALL_LIBDIR)/ssl/syscert.cnf
	$(INSTALL_DATA) ca.cnf $(INSTALL_LIBDIR)/ssl/ca.cnf

remote-site-boss-install:	install-dirs \
		$(INSTALL_DIR)/ssl/serial $(INSTALL_DIR)/ssl/index.txt \
		$(INSTALL_ETCDIR)/emulab.pem \
		$(INSTALL_ETCDIR)/emulab.key \
		$(INSTALL_ETCDIR)/emulab.pub \
		$(INSTALL_ETCDIR)/capture.pem \
		$(INSTALL_ETCDIR)/capture.fingerprint \
		$(INSTALL_ETCDIR)/capture.sha1fingerprint \
		$(INSTALL_ETCDIR)/ctrlnode.pem \
		$(INSTALL_ETCDIR)/server.pem \
		$(INSTALL_SBINDIR)/updatecert \
		install-conf
	$(INSTALL_DATA) localnode.pem $(INSTALL_ETCDIR)/client.pem
	chmod 644 $(INSTALL_ETCDIR)/emulab.pem
	chmod 644 $(INSTALL_ETCDIR)/emulab.key
	chmod 644 $(INSTALL_ETCDIR)/emulab.pub
	chmod 640 $(INSTALL_ETCDIR)/capture.pem
	chmod 644 $(INSTALL_ETCDIR)/capture.fingerprint
	chmod 644 $(INSTALL_ETCDIR)/capture.sha1fingerprint
	chmod 640 $(INSTALL_ETCDIR)/server.pem
	chmod 640 $(INSTALL_ETCDIR)/client.pem
	chmod 640 $(INSTALL_ETCDIR)/ctrlnode.pem

# Do not run this if you have a "real" web certificate.
apache-install:
	$(INSTALL_DATA) apache.pem $(DESTDIR)$(APACHE_CERTFILE)
	$(INSTALL_DATA) apache.key $(DESTDIR)$(APACHE_KEYFILE)
	chmod 640 $(DESTDIR)$(APACHE_CERTFILE)
	chmod 640 $(DESTDIR)$(APACHE_KEYFILE)

client-install:
	$(INSTALL_DATA) localnode.pem $(DESTDIR)$(CLIENT_ETCDIR)/client.pem
	$(INSTALL_DATA) emulab.pem $(DESTDIR)$(CLIENT_ETCDIR)/emulab.pem
	$(INSTALL_DATA) emulab_pubkey.pem \
			$(DESTDIR)$(CLIENT_ETCDIR)/emulab_pubkey.pem

control-install:	$(INSTALL_ETCDIR)/capture.pem \
			$(INSTALL_ETCDIR)/emulab.pem
	$(INSTALL_DATA) ctrlnode.pem $(INSTALL_ETCDIR)/client.pem
	chmod 640 $(INSTALL_ETCDIR)/capture.pem
	chmod 640 $(INSTALL_ETCDIR)/client.pem
	chmod 640 $(INSTALL_ETCDIR)/emulab.pem

clearinghouse-install:	install-dirs \
		$(INSTALL_ETCDIR)/emulab.pem \
		$(INSTALL_ETCDIR)/emulab.key \
		install-conf
	chmod 640 $(INSTALL_ETCDIR)/emulab.pem
	chmod 600 $(INSTALL_ETCDIR)/emulab.key

tipserv-install:	$(INSTALL_ETCDIR)/capture.pem
	chmod 640 $(INSTALL_ETCDIR)/capture.pem

usercert-install:	install-dirs
	-mkdir -p $(INSTALL_LIBDIR)/ssl
	$(INSTALL_DATA) ca.cnf $(INSTALL_LIBDIR)/ssl/ca.cnf
	$(INSTALL_DATA) usercert.cnf $(INSTALL_LIBDIR)/ssl/usercert.cnf

clean:
	@echo "BE VERY CAREFUL! CLEANING THE SSL DIR CAN CAUSE DISASTER!"

cleanX: clean-certs clean-keys
	rm -f serial index.txt *.old dirsmade *.cnf .rnd
	rm -f mkserial updatecert mksig
	rm -rf newcerts certs crl

#
# Leave the private keys behind so that new certs use same keys;
# existing certs still have valid sigs.
#
clean-certs:
	rm -f *.pem *.req *.old *.cnf
	rm -f *fingerprint

clean-keys:
	rm -f *.key
