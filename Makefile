PANDOC  = pandoc
PANDOC_OPT  =                  \
	--latex-engine=lualatex      \
	-V documentclass=bxjsbook \
	-V papersize=b5              \
	-V fontsize=8pt              \
	-V classoption=pandoc        \
	-V classoption=jafont=ipaex  \
	--number-sections            \
	--toc                        \
	--toc-depth=2                \
	--top-level-division=chapter \
	--listings                   \
	-H tools/header.tex          \

MD =                    \
	MakeNowJust/README.md \
	at-grandpa/README.md  \
	tobias/README.md      \
	msky026/README.md     \
	pacuum/README.md      \
	arcage/README.md      \
	5t111111/README.md    \
	postscript.md         \

.PHONY: all
all: build/techbookfest.pdf

build/techbookfest.pdf: $(MD) tools/header.tex build/
	$(PANDOC) -f markdown $(MD) -o $@ $(PANDOC_OPT)

build/:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf build/
