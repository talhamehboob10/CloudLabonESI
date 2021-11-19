##
## Much of this is taken from
## https://github.com/tianon/dockerfiles/blob/master/sbin-init/ubuntu/upstart/14.1#0/Dockerfile
## .  Reworked to use fewer RUN statements!  Also removed a bit of ssh
## configuration that we handle by default in Emulabization, and removed
## the static root passwd.
##

# Generate some fake events and trigger runlevel 3.
ADD init-fake.conf /etc/init/fake-container-events.conf

# let Upstart know it's in a container
ENV container docker

# undo some leet hax of the base image
# generate a nice UTF-8 locale for our use
# remove some pointless services
# small fix for SSH in 13.10 (that's harmless everywhere else)
RUN rm /usr/sbin/policy-rc.d; \
	rm /sbin/initctl; dpkg-divert --rename --remove /sbin/initctl ; \
    locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 ; \
    /usr/sbin/update-rc.d -f ondemand remove; \
	for f in \
		/etc/init/u*.conf \
		/etc/init/mounted-dev.conf \
		/etc/init/mounted-proc.conf \
		/etc/init/mounted-run.conf \
		/etc/init/mounted-tmp.conf \
		/etc/init/mounted-var.conf \
		/etc/init/hostname.conf \
		/etc/init/networking.conf \
		/etc/init/tty*.conf \
		/etc/init/plymouth*.conf \
		/etc/init/hwclock*.conf \
		/etc/init/module*.conf\
	; do \
		dpkg-divert --local --rename --add "$f"; \
	done; \
	echo '# /lib/init/fstab: cleared out for bare-bones Docker' >/lib/init/fstab ; \
    sed -ri 's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd

# prepare for takeoff
CMD ["/sbin/init"]
