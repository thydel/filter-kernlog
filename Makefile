#!/usr/bin/make -f

MAKEFLAGS += -Rr
MAKEFLAGS += --warn-undefined-variables
SHELL := $(shell which bash)
.SHELLFLAGS := -euo pipefail -c

.ONESHELL:
.DELETE_ON_ERROR:
.PHONY: phony

.RECIPEPREFIX :=
.RECIPEPREFIX +=

.DEFAULT_GOAL := main

MIN_VERSION := 4.1
VERSION_ERROR :=  make $(MAKE_VERSION) < $(MIN_VERSION)
$(and $(or $(filter $(MIN_VERSION),$(firstword $(sort $(MAKE_VERSION) $(MIN_VERSION)))),$(error $(VERSION_ERROR))),)

self    := $(lastword $(MAKEFILE_LIST))
$(self) := $(basename $(self))
$(self):;

top: phony; @date

################

sync := sync
tmp := tmp
dirs := $(sync) $(tmp)
stones := $(dirs:%=%/.stone)
stones: phony $(stones)

gzlogs.wildcard := kern.log.*.gz

sync: pat := $(gzlogs.wildcard)
sync: $(sync)/.stone phony; rsync -av $(firewall):/var/log/$(pat) $(<D)

all-log := $(tmp)/all.log
all-log: phony $(all-log)
$(all-log): cdr = $(filter-out $(firstword $1), $1)
$(all-log): $(tmp)/.stone $(wildcard $(sync)/$(gzlogs.wildcard)); zcat $(sort $(call cdr, $^)) > $@

all-txt := $(tmp)/all.txt
all-txt : phony $(all-txt)
$(all-txt): awk.common := $$1, $$2, $$3, $$10, $$11,
$(all-txt): awk := $$17 == "DF" { print $(awk.common) $$18, $$20 }
$(all-txt): awk += $$17 != "DF" { print $(awk.common) $$17, $$19 }
$(all-txt): sed := s/:/ /g\n
$(all-txt): sed += s/^Apr/04/\n
$(all-txt): sed += s/^May/05/\n
$(all-txt): sed += s/[A-Z]+=//g
$(all-txt): grep := ^([0-9]{1,2} ){5}(([0-9]{1,3}[.]){3}[0-9]{1,3} ){2}[A-Z]{3,} [0-9]+$$
$(all-txt): $(all-txt)  =   grep :DROP: $< | awk '$(awk)'
$(all-txt): $(all-txt) += | sed -re $$'$(sed)' | sort -n | tee $@.1
$(all-txt): $(all-txt) += | grep -Ee '$(grep)' > $@
$(all-txt): $(all-log); @$($@)

fields := src dst
src := 6
dst := 7
extracted := all cnt
$(foreach f,$(fields),$(foreach e,$(extracted),$(eval $f-$e := $(tmp)/$f-$e.txt)))
$(foreach e,$(extracted),$(eval ip-$e := $(fields:%=$(tmp)/%-$e.txt)))

by-ip: phony $(extracted:%=ip-%)

ip-all: phony $(ip-all)
$(ip-all): $(tmp)/%-all.txt : $(all-txt); < $< awk '{print $$$($*)}' | sort -t. -k1,4 -n > $@

ip-cnt: phony $(ip-cnt)
$(ip-cnt): $(tmp)/%-cnt.txt : $(tmp)/%-all.txt; < $< uniq -c | sort -nr > $@

time := day hour
by-time: phony $(time:%=$(tmp)/by-%.txt)
$(tmp)/by-day.txt: $(all-txt); < $< awk '{print $$1,$$2}' | sort | uniq -c | sort -n -k 2 -k 3 > $@
$(tmp)/by-hour.txt: $(all-txt); < $< awk '{print $$1,$$2,$$3}' | sort | uniq -c | sort -n -k 2 -k 3 -k 4 > $@

top-most-src-cnt := 10 40
$(foreach n,$(top-most-src-cnt),$(eval $(n)k-src.txt := $(n)000))
top-most-src := $(top-most-src-cnt:%=$(tmp)/%k-src.txt)
$(top-most-src): $(src-cnt); < $< head -$($(@F)) | awk '{print $$2}' > $@
top-most-src: phony $(top-most-src)

ipinfo.cache := ipinfo.io

# My ipinfo.io free account allows 50k requests a month, so we cache requests
ipinfo: token  := $(shell pass ipinfo.io/tokens/thydel@github.com)
ipinfo: curl   := curl -u $(token): -s http://ipinfo.io/{}/geo -o $(ipinfo.cache)/{}.json --create-dirs
ipinfo: sorted  = < $< sort
ipinfo: cached := ls $(ipinfo.cache) | xargs basename -a -s .json | sort
ipinfo: search  = comm -23 <($(sorted)) <($(cached))
ipinfo: $(tmp)/40k-src.txt phony; $(search) | xargs -P 100 -i $(curl)

ipinfo-txt := $(tmp)/ipinfo.txt
$(ipinfo-txt): jq := [.ip, .country]|join(" ")
$(ipinfo-txt):; find $(ipinfo.cache) -name '*.json' | xargs cat | jq -r '$(jq)' | sort -t. -k1,4 -n > $@
ipinfo-txt: phony $(ipinfo-txt)

ip-by-country := $(tmp)/ip-by-country.txt
$(ip-by-country): $(ipinfo-txt); < $< awk '{print $$2}' | sort | uniq -c | sort -nr > $@
ip-by-country: phony $(ip-by-country)

drop-by-country := $(tmp)/drop-by-country.txt
$(drop-by-country): cmd = join --nocheck-order $^ | awk '{print $$2}' | sort | uniq -c | sort -nr > $@
$(drop-by-country): $(src-all) $(ipinfo-txt); $(cmd)
drop-by-country: phony $(drop-by-country)

dirs += $(ipinfo.cache)
gitignore: phony $(dirs:%=gitignore/%)
gitignore/%: phony; grep -q $(@F) .$(@D) || echo $(@F)/ | tee -a .$(@D)

main: phony by-ip by-time ip-by-country drop-by-country

################

%/.stone:; mkdir -p $(@D); touch $@

# Local Variables:
# indent-tabs-mode: nil
# End:
