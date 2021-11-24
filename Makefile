.PHONY: all clean run

all:
	rm -rf working-copy
	./build.sh

clean:
	rm -rf publish
	rm -rf working-copy

run: all
	cd publish && python3 -m http.server
