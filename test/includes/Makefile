POST = $(shell find pre -name '*.h' | sed 's/^pre/post/')

all: $(POST)

$(POST): post/%: pre/%
	@echo GEN $*
	@mkdir -p $(@D)
	@cc -std=c99 -E -P $< -o $@

clean:
	rm -rf post
