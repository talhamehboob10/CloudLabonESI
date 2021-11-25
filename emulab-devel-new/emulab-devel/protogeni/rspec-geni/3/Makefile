#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2011 University of Utah and the Flux Group.
# All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and/or hardware specification (the "Work") to
# deal in the Work without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Work, and to permit persons to whom the Work
# is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Work.
#
# THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
# IN THE WORK.
#

ifdef TRANG
  TRANGCMD = java -jar ${TRANG}
else
  TRANGCMD = java -jar /usr/local/share/java/classes/trang.jar
endif

SCHEMAS = ad.xsd request.xsd manifest.xsd

all: $(SCHEMAS)

clean:
	rm $(SCHEMAS)

%.xsd: %.rnc common.rnc
	mkdir -p tmp
	$(TRANGCMD) $< tmp/$@
	sed "s/any-extension.xsd/any-extension-schema.xsd/" tmp/common.xsd > $(@:.xsd=)-common.xsd
	rm tmp/common.xsd
	sed "s/common.xsd/$(@:.xsd=)-common.xsd/" tmp/$@ > $@
	rm tmp/$@
	sed "s/any-extension.xsd/any-extension-schema.xsd/" $@ > tmp/$@
	mv tmp/$@ $@
	if [ $< = manifest.rnc ]; then \
		sed "s/common.xsd/manifest-common.xsd/" tmp/request.xsd > manifest-request.xsd; \
		rm tmp/request.xsd; \
		sed "s/request.xsd/manifest-request.xsd/" manifest.xsd > manifest.tmp; \
		mv manifest.tmp manifest.xsd; \
	fi
	rm tmp/any-extension.xsd
	rmdir tmp

.PHONY: clean
