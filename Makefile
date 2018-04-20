# Copyright (c) 2006-2017 Microsemi Corporation "Microsemi". All Rights Reserved.
#
# Unpublished rights reserved under the copyright laws of the United States of
# America, other countries and international treaties. Permission to use, copy,
# store and modify, the software and its source code is granted but only in
# connection with products utilizing the Microsemi switch and PHY products.
# Permission is also granted for you to integrate into other products, disclose,
# transmit and distribute the software only in an absolute machine readable
# format (e.g. HEX file) and only in or with products utilizing the Microsemi
# switch and PHY products.  The source code of the software may not be
# disclosed, transmitted or distributed without the prior written permission of
# Microsemi.
#
# This copyright notice must appear in any copy, modification, disclosure,
# transmission or distribution of the software.  Microsemi retains all
# ownership, copyright, trade secret and proprietary rights in the software and
# its source code, including all modifications thereto.
#
# THIS SOFTWARE HAS BEEN PROVIDED "AS IS". MICROSEMI HEREBY DISCLAIMS ALL
# WARRANTIES OF ANY KIND WITH RESPECT TO THE SOFTWARE, WHETHER SUCH WARRANTIES
# ARE EXPRESS, IMPLIED, STATUTORY OR OTHERWISE INCLUDING, WITHOUT LIMITATION,
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR USE OR PURPOSE AND
# NON-INFRINGEMENT.

.PHONY: all build clean clobber

all: build

build:
	rm -rf artifacts images status
	mkdir -p artifacts status
	(cd artifacts; find ../../../../obj/ -type f -regex '.*\.\(img\|mfi\|gz\)' | xargs -I '{}' ln -sf '{}')
	perl -w ./buildflash.pl --verbose templates/*.txt
	./mksummary.rb --output status/20-flash_images.json templates/*.txt

clean:
	rm -fr artifacts images status

clobber: clean
	rm -fr inputs
