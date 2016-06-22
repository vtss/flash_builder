.PHONY: all symlinks build clean clobber

all: symlinks build

build:
	perl -w ./buildflash.pl --verbose templates/*.txt
	./mksummary.rb --output status/20-flash_images.json templates/*.txt

symlinks:
	mkdir -p artifacts status
	(cd artifacts; find ../inputs -type f | xargs -I '{}' ln -sf '{}')

clean:
	rm -fr artifacts images status

clobber: clean
	rm -fr inputs
