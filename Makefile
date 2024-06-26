# Copyright 2024 The Khronos Group Inc.
# SPDX-License-Identifier: Apache-2.0

# Khronos Sample Specification Makefile

# NOTE: this Makefile is massively overbuilt in terms of just generating
# the Sample Specification itself.
# It is intended to show useful methods and targets for more complex
# specifications.
# Other repositories are expected to modify the Makefile extensively as
# appropriate for their needs, including adding additional targets for
# intermediate generated files and other artifacts, etc.
# Other build tools such as cmake or meson can be used instead.

# If a recipe fails, delete its target file. Without this cleanup, the leftover
# file from the failed recipe can falsely satisfy dependencies on subsequent
# runs of `make`.
.DELETE_ON_ERROR:

# APITITLE can be set to extra text to append to the document title,
# normally used when building with extensions included.
APITITLE =

# IMAGEOPTS is normally set to generate inline SVG images, but can be
# overridden to an empty string, since the inline option doesn't work
# well with our HTML diffs.
IMAGEOPTS = inline

# The default 'all' target builds the following sub-targets:
#  html - HTML5 single-page API specification
#  pdf - PDF single-page API specification

all: html pdf

QUIET	 ?= @
PYTHON	 ?= python3
ASCIIDOC ?= asciidoctor
RUBY	 = ruby
NODEJS	 = node
PATCH	 = patch
RM	 = rm -f
RMRF	 = rm -rf
MKDIR	 = mkdir -p
CP	 = cp
ECHO	 = echo

# Where the repo root is
ROOTDIR        = $(CURDIR)
# Where the spec files are
SPECDIR        = $(CURDIR)

# Path to scripts used in generation
SCRIPTS  = $(ROOTDIR)/scripts
# Path to configs and asciidoc extensions used in generation
CONFIGS  = $(ROOTDIR)/config

# Target directories for output files
# HTMLDIR - 'html' target
# PDFDIR - 'pdf' target
OUTDIR	  = $(GENERATED)/out
HTMLDIR   = $(OUTDIR)/html
PDFDIR	  = $(OUTDIR)/pdf

# PDF Equations are written to SVGs, this dictates the location to store those files (temporary)
PDFMATHDIR = $(OUTDIR)/equations_temp

# Set VERBOSE to -v to see what asciidoc is doing.
VERBOSE =

# asciidoc attributes to set (defaults are usually OK)
# NOTEOPTS sets options controlling which NOTEs are generated
# PATCHVERSION is the minor document release version
# ATTRIBOPTS sets the API revision and enables KaTeX generation
# EXTRAATTRIBS sets additional attributes, if passed to make
# ADOCMISCOPTS miscellaneous options controlling error behavior, etc.
# ADOCEXTS asciidoctor extensions to load
# ADOCOPTS options for asciidoc->HTML5 output

NOTEOPTS     = -a editing-notes -a implementation-guide
PATCHVERSION = 1
SPECREVISION = 1.0.$(PATCHVERSION)

# Spell out ISO 8601 format as not all date commands support --rfc-3339
SPECDATE     = $(shell echo `date -u "+%Y-%m-%d %TZ"`)

# Generate Asciidoc attributes for spec remark
# Could use `git log -1 --format="%cd"` to get branch commit date
# The dependency on HEAD is per the suggestion in
# http://neugierig.org/software/blog/2014/11/binary-revisions.html
SPECREMARK = from git branch: $(shell echo `git symbolic-ref --short HEAD 2> /dev/null || echo Git branch not available`) \
	     commit: $(shell echo `git log -1 --format="%H" 2> /dev/null || echo Git commit not available`)

# Some of the attributes used in building all spec documents:
#   chapters - absolute path to chapter sources
#   appendices - absolute path to appendix sources
#   images - absolute path to images
ATTRIBOPTS   = -a revnumber="$(SPECREVISION)" \
	       -a revdate="$(SPECDATE)" \
	       -a revremark="$(SPECREMARK)" \
	       -a apititle="$(APITITLE)" \
	       -a stem=latexmath \
	       -a imageopts="$(IMAGEOPTS)" \
	       -a config=$(ROOTDIR)/config \
	       -a appendices=$(SPECDIR)/appendices \
	       -a chapters=$(SPECDIR)/chapters \
	       -a images=$(IMAGEPATH) \
	       $(EXTRAATTRIBS)
ADOCMISCOPTS = --failure-level ERROR
# Non target-specific Asciidoctor extensions and options
ADOCEXTS     = -r $(CONFIGS)/open_listing_block.rb
ADOCOPTS     = -d book $(ADOCMISCOPTS) $(ATTRIBOPTS) $(NOTEOPTS) $(VERBOSE) $(ADOCEXTS)

# HTML target-specific Asciidoctor extensions and options
#@TODO ADOCHTMLEXTS = -r $(CONFIGS)/katex_replace.rb \
#@TODO		      -r $(CONFIGS)/loadable_html.rb

# ADOCHTMLOPTS relies on the relative runtime path from the output HTML
# file to the katex scripts being set with KATEXDIR. This is overridden
# by some targets.
# KaTeX source is copied from KATEXSRCDIR in the repository to
# KATEXINSTDIR in the output directory.
# KATEXDIR is the relative path from a target to KATEXINSTDIR, since
# that is coded into CSS, and set separately for each HTML target.
# ADOCHTMLOPTS also relies on the absolute build-time path to the
# 'stylesdir' containing our custom CSS.
KATEXSRCDIR  = $(ROOTDIR)/katex
KATEXINSTDIR = $(OUTDIR)/katex
ADOCHTMLOPTS = $(ADOCHTMLEXTS) -a katexpath=$(KATEXDIR) \
	       -a stylesheet=khronos.css \
	       -a stylesdir=$(ROOTDIR)/config \
	       -a sectanchors

# PDF target-specific Asciidoctor extensions and options
ADOCPDFEXTS  = -r asciidoctor-pdf \
	       -r asciidoctor-mathematical \
	       -r $(CONFIGS)/asciidoctor-mathematical-ext.rb
ADOCPDFOPTS  = $(ADOCPDFEXTS) -a mathematical-format=svg \
	       -a imagesoutdir=$(PDFMATHDIR) \
	       -a pdf-stylesdir=$(CONFIGS)/themes -a pdf-style=pdf

.PHONY: directories

# Images used by the specification.
# These are included in generated HTML now.
IMAGEPATH = $(SPECDIR)/images
SVGFILES  = $(wildcard $(IMAGEPATH)/*.svg)

# Top-level spec source file
SPECSRC   = $(SPECDIR)/sample.adoc
# Static files making up sections of the specification.
SPECFILES = $(wildcard chapters/[A-Za-z]*.adoc appendices/[A-Za-z]*.adoc)
# Shorthand for where different types generated files go.
# All can be relocated by overriding GENERATED in the make invocation.
GENERATED      = $(CURDIR)/gen
# All non-format-specific dependencies
COMMONDOCS     = $(SPECFILES)

# Script to translate math at build time
#@TODO TRANSLATEMATH = $(NODEJS) $(SCRIPTS)/translate_math.js $(KATEXSRCDIR)/katex.min.js
TRANSLATEMATH = true

# Install katex in KATEXINSTDIR ($(OUTDIR)/katex) to be shared by all
# HTML targets.
# We currently only need the css and fonts, but copy all of KATEXSRCDIR anyway.
$(KATEXINSTDIR): $(KATEXSRCDIR)
	$(QUIET)$(MKDIR) $(KATEXINSTDIR)
	$(QUIET)$(RMRF)  $(KATEXINSTDIR)
	$(QUIET)$(CP) -rf $(KATEXSRCDIR) $(KATEXINSTDIR)

# Spec targets
# There is some complexity to try and avoid short virtual targets like 'html'
# causing specs to *always* be regenerated.

html: $(HTMLDIR)/sample.html $(SPECSRC) $(COMMONDOCS)

#@TODO $(HTMLDIR)/sample.html: KATEXDIR = ../katex
#@TODO $(HTMLDIR)/sample.html: $(SPECSRC) $(COMMONDOCS) $(KATEXINSTDIR)
$(HTMLDIR)/sample.html: $(SPECSRC) $(COMMONDOCS)
	$(QUIET)$(ASCIIDOC) -b html5 $(ADOCOPTS) $(ADOCHTMLOPTS) -o $@ $(SPECSRC)
	$(QUIET)$(TRANSLATEMATH) $@

# PDF optimizer - usage $(OPTIMIZEPDF) in.pdf out.pdf
# OPTIMIZEPDFOPTS=--compress-pages is slightly better, but much slower
OPTIMIZEPDF = hexapdf optimize $(OPTIMIZEPDFOPTS)

pdf: $(PDFDIR)/sample.pdf $(SPECSRC) $(COMMONDOCS)

$(PDFDIR)/sample.pdf: $(SPECSRC) $(COMMONDOCS)
	$(QUIET)$(MKDIR) $(PDFDIR)
	$(QUIET)$(MKDIR) $(PDFMATHDIR)
	$(QUIET)$(ASCIIDOC) -b pdf $(ADOCOPTS) $(ADOCPDFOPTS) -o $@ $(SPECSRC)
	$(QUIET)$(OPTIMIZEPDF) $@ $@.out.pdf && mv $@.out.pdf $@
	$(QUIET)rm -rf $(PDFMATHDIR)

# Clean generated and output files

clean: clean_html clean_pdf clean_generated

clean_html:
	$(QUIET)$(RMRF) $(HTMLDIR) $(OUTDIR)/katex
	$(QUIET)$(RM) $(OUTDIR)/sample.html

clean_pdf:
	$(QUIET)$(RMRF) $(PDFDIR) $(OUTDIR)/sample.pdf

# Generated directories and files to remove
CLEAN_GEN_PATHS = \
    $(PDFMATHDIR)

clean_generated:
	$(QUIET)$(RMRF) $(CLEAN_GEN_PATHS)
