.PHONY: all clean run watch

all:
	rm -rf .working-copy
	./build.sh

clean:
	rm -rf .publish
	rm -rf .working-copy

run: all
	cd .publish && python3 -m http.server

watch:
	./watch.sh
