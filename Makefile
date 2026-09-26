.PHONY: all clean run watch test

all:
	./build.sh

run: all
	cd .publish && python3 -m http.server

clean:
	rm -rf .working-copy/
	rm -rf .publish/

watch:
	./watch.sh
