all:
	rm -f obs.txt
	morloc make foo.loc
	./nexus.pl foo [1,2,3] [2,3,4] >> obs.txt

clean:
	rm -f nexus* pool*
