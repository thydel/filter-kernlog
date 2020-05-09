SHELL := bash

top:; @date

all.log: $(wildcard kern.log kern.log.*); cat $^ > $@

all.txt: awk := $$17 == "DF" { print $$1, $$2, $$3, $$10, $$11, $$18, $$20 }
all.txt: awk += $$17 != "DF" { print $$1, $$2, $$3, $$10, $$11, $$17, $$19 }
all.txt: sed := s/:/ /g\n
all.txt: sed += s/^Apr/04/\n
all.txt: sed += s/^May/05/\n
all.txt: sed += s/[A-Z]+=//g
all.txt: grep := ^([0-9]{1,2} ){5}(([0-9]{1,3}[.]){3}[0-9]{1,3} ){2}[A-Z]{3,} [0-9]+$$
all.txt: all.log; grep :DROP: $< | awk '$(awk)' | sed -re $$'$(sed)' | grep -Ere '$(grep)' | sort -n > $@

all-dst.txt: all.txt; < $< awk '{print $$7}' | sort -t. -k1,4 -n > $@
all-dst-cnt.txt: all-dst.txt; < $< uniq -c | sort -nr > $@

all-src.txt: all.txt; < $< awk '{print $$6}' | sort -t. -k1,4 -n > $@
all-src-cnt.txt: all-src.txt; < $< uniq -c | sort -nr > $@

by-day.txt: all.txt; < $< awk '{print $$1,$$2}' | sort | uniq -c | sort -n -k 2 -k 3 > $@
by-hour.txt: all.txt; < $< awk '{print $$1,$$2,$$3}' | sort | uniq -c | sort -n -k 2 -k 3 -k 4 > $@

10k-src.txt := 10000
40k-src.txt := 40000
10k-src.txt 40k-src.txt: all-src.txt; < $< head -$($@) | awk '{print $$2}' > $@

ipinfo.cache := ipinfo.io

# My ipinfo.io free account allows 50k requests a day, so we cache requests
ipinfo: token  := $(shell pass ipinfo.io/tokens/thydel@github.com)
ipinfo: curl   := curl -u $(token): -s http://ipinfo.io/{}/geo -o $(ipinfo.cache)/{}.json --create-dirs
ipinfo: sorted  = < $< sort
ipinfo: cached := ls $(ipinfo.cache) | xargs basename -a -s .json | sort
ipinfo: search  = comm -23 <($(sorted)) <($(cached))
ipinfo: 40k-src.txt; $(search) | xargs -P 100 -i $(curl)

ipinfo.txt: jq := [.ip, .country]|join(" ")
ipinfo.txt:; find $(ipinfo.cache) -name '*.json' | xargs cat | jq -r '$(jq)' | sort -t. -k1,4 -n > $@

ip-by-country.txt: ipinfo.txt; < $< awk '{print $$2}' | sort | uniq -c | sort -nr > $@

drop-by-country.txt: cmd = join --nocheck-order $^ | awk '{print $$2}' | sort | uniq -c | sort -nr > $@
drop-by-country.txt: all-src.txt ipinfo.txt; $(cmd)
