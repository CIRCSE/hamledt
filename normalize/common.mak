SHELL=/bin/bash

# To be included from the language-specific makefiles like this:
# include ../common.mak
# The language-specific makefile should define two environment variables:
# LANGCODE=cs # Czech
# TREEBANK=cs-pdt30 # either same as language code, or with hyphen and lowercase treebank code; will be used in paths
# HARMONIZE=HarmonizeSpecial # only needed if not called Harmonize; will be sought for in the $(LANGCODE) folder.

# Set paths. The main path to the working copy of the data, HAMLEDT_DATA, must be pre-set in your environment.
# You may want to put something like this in your .bash_profile:
# export HAMLEDT_DATA=/net/projects/tectomt_shared/data/resources/hamledt
DATADIR   = $(HAMLEDT_DATA)/$(TREEBANK)
SUBDIRIN  = source
SUBDIR0   = treex/00
SUBDIR1   = treex/01
SUBDIR2   = treex/02
SUBDIRCU  = conllu
SUBDIRPTQ = pmltq
IN        = $(DATADIR)/$(SUBDIRIN)
DIR0      = $(DATADIR)/$(SUBDIR0)
DIR1      = $(DATADIR)/$(SUBDIR1)
DIR2      = $(DATADIR)/$(SUBDIR2)
CONLLUDIR = $(DATADIR)/$(SUBDIRCU)

# Processing shortcuts.
# Ordinary users can set --priority from -1023 to 0 (0 being the highest priority). Treex default is -100.
# I am temporarily setting it rather high in order to sneak before Shadi's jobs.
TREEX      = treex -L$(LANGCODE)
QTREEX     = treex -p --jobs 100 --priority=0 -L$(LANGCODE)
IMPORTX    = Read::CoNLLX lines_per_doc=100
IMPORTU    = Read::CoNLLU lines_per_doc=100
WRITE0     = Write::Treex file_stem='' compress=1
WRITE      = Write::Treex compress=1
# Treebank-specific Makefiles must override the value of HARMONIZE if their harmonization block is not called Harmonize.
# They must do so before they include common.mak.
HARMONIZE ?= Harmonize
TRAIN      = $(IN)/train.conll
DEV        = $(IN)/dev.conll
TEST       = $(IN)/test.conll

# If a treebank requires postprocessing after conversion to UD, the treebank-specific Makefile must override the value of POST_UD_BLOCKS.
# Example: POST_UD_BLOCKS=HamleDT::CS::SplitFusedWords
POST_UD_BLOCKS ?=

check-source:
	[ -d $(IN) ] || (echo new $(LANGCODE) && make source)

dirs:
	@echo The root data directory for $(TREEBANK): $(DATADIR)
	mkdir -p $(DATADIR)
	if [ ! -e data ]; then ln -s $(DATADIR) data; fi
	mkdir -p data/$(SUBDIRIN)
	mkdir -p data/{$(SUBDIR0),$(SUBDIR1),$(SUBDIR2)}/{train,dev,test}
	chmod -R g+w data/. data/*

# Run a conversion of the original data into the treex format
# and store the results in 00. This default assumes CoNLL-X,
# our most-widely used source format. If a different conversion
# is needed, override in the language-specific Makefile.
# Otherwise, define the treebank-specific "treex" goal as dependent
# on "conll_to_treex".
conll_to_treex:
	$(TREEX) $(IMPORTX) from=$(IN)/train.conll $(WRITE0) path=$(DIR0)/train/
	$(TREEX) $(IMPORTX) from=$(IN)/dev.conll   $(WRITE0) path=$(DIR0)/dev/
	$(TREEX) $(IMPORTX) from=$(IN)/test.conll  $(WRITE0) path=$(DIR0)/test/

# If the source data is already in Universal Dependencies, do not convert it to the Prague style and then back to UD.
# Read UD directly instead. Note that there will be just one tree per sentence, not three.
# (There are three trees per sentence for treebanks that are converted via Prague.)
# Also note that we save the result directly in $(DIR2), not $(DIR0).
# For UD treebanks the treebank-specific Makefile should redefine the "ud" goal as dependent on "conllu_to_treex".
# (See also "prague_to_ud" below.)
conllu_to_treex:
	$(TREEX) $(IMPORTU) from=$(IN)/train.conllu $(WRITE0) path=$(DIR2)/train/
	$(TREEX) $(IMPORTU) from=$(IN)/dev.conllu   $(WRITE0) path=$(DIR2)/dev/
	$(TREEX) $(IMPORTU) from=$(IN)/test.conllu  $(WRITE0) path=$(DIR2)/test/

# Convert the trees to the HamleDT/Prague style and store the result in 01.
UCLANG = $(shell perl -e 'print uc("$(LANGCODE)");')
SCEN1 = A2A::CopyAtree source_selector='' selector='orig' HamleDT::$(UCLANG)::$(HARMONIZE)
prague:
	$(QTREEX) $(SCEN1) Write::Treex substitute={00}{01} -- '!$(DIR0)/{train,dev,test}/*.treex.gz'

# Convert the trees to Universal Dependencies and store the result in 02.
# If the UD version of the treebank is created using HamleDT transformation via the Prague style,
# define the treebank-specific goal "ud" as dependent on "prague_to_ud".
# Otherwise, if reading directly data published in Universal Dependencies, make "ud" dependent on "conllu_to_treex".
SCEN2 = A2A::CopyAtree source_selector='' selector='prague' HamleDT::Udep $(POST_UD_BLOCKS)
prague_to_ud:
	$(QTREEX) $(SCEN2) Write::Treex substitute={01}{02} -- '!$(DIR1)/{train,dev,test}/*.treex.gz'

# This goal exports the harmonized trees in the CoNLL-U format, which is more useful for ordinary users.
export_conllu:
	$(QTREEX) Read::Treex from='!$(DIR2)/{train,dev,test}/*.treex.gz' Write::CoNLLU substitute={$(DIR2)}{$(CONLLUDIR)} compress=1

# Export for PML-TQ: Treex files but smaller (50 trees per file) and all in one folder.
# Further processing occurs in /net/work/projects/pmltq/data/hamledt.
# We do not use parallel treex here because it cannot work with undefined total number of documents. And the reader does not know in advance how many documents it will read.
pmltq:
	$(TREEX) Read::Treex from='!$(DIR2)/{train,dev,test}/*.treex.gz' bundles_per_doc=50 Write::Treex substitute='{$(SUBDIR2)/(train|dev|test)/(.+)(\d\d\d)}{$(SUBDIRPTQ)/\1-\2-\3}' compress=1



# Basic statistics: number of sentences and tokens in train and test data.
stats:
	$(QTREEX) Read::Treex from='!$(DIR0)/train/*.treex.gz' Util::Eval atree='print("XXX ROOT XXX\n");' anode='print("XXX NODE XXX\n");' > train-wcl.txt
	$(QTREEX) Read::Treex from='!$(DIR0)/dev/*.treex.gz'  Util::Eval atree='print("XXX ROOT XXX\n");' anode='print("XXX NODE XXX\n");' > dev-wcl.txt
	$(QTREEX) Read::Treex from='!$(DIR0)/test/*.treex.gz'  Util::Eval atree='print("XXX ROOT XXX\n");' anode='print("XXX NODE XXX\n");' > test-wcl.txt
	grep 'XXX ROOT XXX' train-wcl.txt | wc -l
	grep 'XXX NODE XXX' train-wcl.txt | wc -l
	grep 'XXX ROOT XXX' dev-wcl.txt | wc -l
	grep 'XXX NODE XXX' dev-wcl.txt | wc -l
	grep 'XXX ROOT XXX' test-wcl.txt | wc -l
	grep 'XXX NODE XXX' test-wcl.txt | wc -l

morphostats:
	$(QTREEX) Read::Treex from='!$(DIR2)/{train,dev,test}/*.treex.gz' Util::Eval anode='print($$.form, "\t", $$.lemma, "\n");' |\
		grep -v -P '\d' |\
		perl -e 'while(<>) { s/\r?\n$$//; if(m/^(.+\t(.+))$$/) { $$f{lc($$1)}++; $$l{lc($$2)}++; } } $$nf=scalar(keys(%f)); $$nl=scalar(keys(%l)); $$r=($$nl==0)?0:($$nf/$$nl); print("$$nf forms, $$nl lemmas, mr=$$r\n");' |\
		tee morphostats.txt

featurestats:
	$(QTREEX) Read::Treex from='!$(DIR2)/{train,dev,test}/*.treex.gz' Util::Eval anode='my $$f = join("|", $$.iset()->get_ufeatures()); print($$f, "\n") if(defined($$f));' |\
		perl -e 'while(<>) { s/\r?\n$$//; @f=split(/\|/, $$_); foreach $$fv (@f) { $$h{$$fv}++ }} @k=sort(keys(%h)); foreach my $$k (@k) { print("$$k\t$$h{$$k}\n"); }' |\
		tee featurestats.txt

deprelstats:
	$(TREEX) Read::Treex from='!$(DIR0)/{train,dev,test}/*.treex.gz' Print::DeprelStats > deprelstats.txt


clean_cluster:
	rm -rf *-cluster-run-*

clean: clean_cluster
	rm -rf $(DATADIR)/treex $(DATADIR)/conllu
