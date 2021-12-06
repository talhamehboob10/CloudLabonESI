#!/bin/sh

set -x

rm /usr/sbin/policy-rc.d
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl 
locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
/usr/sbin/update-rc.d -f ondemand remove
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
	/etc/init/module*.conf ; do
    dpkg-divert --local --rename --add "$f"
done
echo '# /lib/init/fstab: cleared out for bare-bones Docker' >/lib/init/fstab
sed -ri 's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd

exit 0
