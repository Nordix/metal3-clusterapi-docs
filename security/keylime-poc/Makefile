# simple makefile to make life easy

.PHONY: e2e run docker kind verify clean realclean

e2e: run verify
	"e2e done!"

run: docker kind
	echo "Done!"

docker:
	cd scripts; ./run_docker.sh

kind:
	cd scripts; ./run_kind.sh

verify:
	#cd scripts; ./verify.sh

clean:
	cd scripts; ./clean.sh

realclean:
	cd scripts; ./clean.sh realclean
