# Usage:
# $ make -f ../an-oral-history-of-unix/main.mk compile

PHONY: help
help:
	$(info $(help))@:

define help =
compile		produce html, epub, pdf
endef

.DELETE_ON_ERROR:
pp-%:
	@echo "$(strip $($*))" | tr ' ' \\n

src := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
out := .

%.txt: %.doc
	antiword $< | recode -f utf8..us > $@

doc.src := $(src)/src-doc
doc := $(wildcard $(doc.src)/*.doc)
txt := $(patsubst $(doc.src)/%.doc, %.txt, $(doc))
vpath %.doc $(doc.src)

.PHONY: txt
txt: $(txt)

node_modules: package.json
	npm install
	touch $@

.PHONY: npm
npm: node_modules

# html

txt.dir := $(src)/txt
txt := $(wildcard $(txt.dir)/*.txt)
vpath %.txt $(txt.dir)

html.dest := $(patsubst $(txt.dir)/%.txt, %.html, $(txt))

$(html.dest): %.html: %.txt
	$(src)/txt2md "MSM" "$(basename $(notdir $<))" < $< | $(src)/md2html > $@

.PHONY: html
html: $(html.dest)

# ebook

PAPER := a4

toc.html: $(html.dest) $(src)/metadata.xml
	$(src)/toc -m $(src)/metadata.xml $(html.dest) > $@

pages.src := $(wildcard $(src)/pages/*.html)
pages.dest := $(notdir $(pages.src))
$(pages.dest): %.html: $(src)/pages/%.html
	cp $< $@

book.zip: $(html.dest) toc.html $(pages.dest)
	-rm $@
	zip -0 -q $@ $^

book.epub: book.zip $(src)/style.epub.css
	ebook-convert $< $@ \
		--level1-toc '//*[@class="title"]' \
		--disable-font-rescaling \
		--epub-inline-toc \
		--no-svg-cover \
		--minimum-line-height 0 \
		--breadth-first \
		--extra-css $(src)/style.epub.css \
		-m $(src)/metadata.xml

book.mobi: book.epub
	ebook-convert $< $@

book.pdf: book.epub
	ebook-convert $< $@ \
		--pdf-add-toc \
		--pdf-footer-template '<div style="margin-top: 2em; text-align:center;"><b>_PAGENUM_</b></div>' \
		--preserve-cover-aspect-ratio \
		--margin-bottom 70 \
		--margin-left 50 \
		--margin-right 50 \
		--margin-top 70 \
		--paper-size $(PAPER)

.PHONY: compile
compile: book.mobi book.pdf

.PHONY: upload
upload: $(html.dest) book.epub book.mobi book.pdf
	rsync -avPL --delete -e ssh $^ gromnitsky@web.sourceforge.net:/home/user-web/gromnitsky/htdocs/lit/an-oral-history-of-unix/
