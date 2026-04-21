from pathlib import Path
import psutil
import json
from os import cpu_count

root = Path(__file__).parent
raw  = root.joinpath("data")

def get_samples(path2config):
	SIDS = list()
	DATA = dict()
	with open(path2config) as f:
		for line in f:
			line = line.strip()
			if not line or line.startswith("#"): continue
			data  = line.split("\t")
			reads = data[1].split(";")
			md5s  = data[2].split(";")
			SIDS.append(data[0])
			DATA[data[0]] = {"R1":reads[0], "R2":reads[1],
					 "MD5R1":md5s[0], "MD5R2":md5s[1]}	 
			Path(f"data/{data[0]}").mkdir(parents=True, exist_ok=True)
	return SIDS, DATA

def get_genome(path2config):
	LINKS = list()
	NAMES = list()
	MD5GENOME = list()
	with open(path2config) as f:
		for line in f:
			line = line.strip()
			if not line or line.startswith("#"): continue
			data  = line.split(",")
			LINKS.append(data[0])
			NAMES.append(data[0].split("/")[-1])
			MD5GENOME.append(data[1])
	return LINKS, NAMES, MD5GENOME

def get_links(path2config):
	DATA = list()
	with open(path2config) as f:
		for line in f:
			line = line.strip()
			if not line or line.startswith("#"): continue
			DATA.append(line.split("/")[-1])
	return DATA

VARINATSET = get_links("config/truthset.s3")
GIABSET    = get_links("config/giab.ftp")

GENOME, GNAMES, MD5GENOME = get_genome("config/genome.ftp")
GENOME_PREFIX = GNAMES[0].removesuffix(".fasta.gz").removesuffix(".fa.gz")
			
SIDS, DATA = get_samples("data/samples.tsv")

rule all:
	input:
		expand("data/{sample}/{sample}_R1.fastq.gz", sample=SIDS),
		expand("data/{sample}/{sample}_R2.fastq.gz", sample=SIDS),
		expand("genome/giab/{giabset}", giabset=GIABSET),
		expand("genome/{ref}", ref=GNAMES),
		"genome/.genome.prepared",
		"config/config.json",
		expand("genome/truthset/{variantset}", variantset=VARINATSET)
		
rule get_fq:
	params:
		".tree.built",
		R1 = lambda wc: DATA[wc.sample]["R1"],
		R2 = lambda wc: DATA[wc.sample]["R2"],
		MD5R1 = lambda wc: DATA[wc.sample]["MD5R1"],
		MD5R2 = lambda wc: DATA[wc.sample]["MD5R2"]
	output:
		temp("data/{sample}/{sample}_R1.fastq.tmp.gz"),
		temp("data/{sample}/{sample}_R2.fastq.tmp.gz"),
		temp("data/{sample}/.{sample}.R1.md5check"),
		temp("data/{sample}/.{sample}.R2.md5check")
	run:
		shell('mkdir -p workspace/{wildcards.sample}/trimming/log/')
		shell('mkdir -p workspace/{wildcards.sample}/alignment/log/')
		shell('mkdir -p workspace/{wildcards.sample}/calling/log/')
		
		# download data
		shell('wget {params[R1]} --output-document data/{wildcards.sample}/{wildcards.sample}_R1.fastq.tmp.gz')
		shell('wget {params[R2]} --output-document data/{wildcards.sample}/{wildcards.sample}_R2.fastq.tmp.gz')
		
        	# check md5sum
		shell('if [[ $(md5sum data/{wildcards.sample}/{wildcards.sample}_R1.fastq.tmp.gz | cut -d " " -f 1) != {params[MD5R1]} ]]; ' +\
        	'then echo "[MD5 ERROR] {wildcards.sample} R1"; exit 1; else touch "data/{wildcards.sample}/.{wildcards.sample}.R1.md5check"; fi')
		shell('if [[ $(md5sum data/{wildcards.sample}/{wildcards.sample}_R2.fastq.tmp.gz | cut -d " " -f 1) != {params[MD5R2]} ]]; ' +\
        	'then echo "[MD5 ERROR] {wildcards.sample} R2"; exit 1; else touch "data/{wildcards.sample}/.{wildcards.sample}.R2.md5check"; fi')
        	
rule fix_header:
	input:
		"data/{sample}/{sample}_R1.fastq.tmp.gz",
		"data/{sample}/{sample}_R2.fastq.tmp.gz",
		"data/{sample}/.{sample}.R1.md5check",
		"data/{sample}/.{sample}.R2.md5check",
		".tree.built"
	output:
		"data/{sample}/{sample}_R1.fastq.gz",
		"data/{sample}/{sample}_R2.fastq.gz"
	threads: 16
	shell:
		r"""
		set -euo pipefail
		c=1
		for file in "data/{wildcards.sample}/{wildcards.sample}_R1.fastq.tmp.gz" "data/{wildcards.sample}/{wildcards.sample}_R2.fastq.tmp.gz"; do
			zcat "$file" | \
			awk '
			NR%4==1{{
				split($0,a," ")
				illum=a[2]

				if (illum ~ /\/1$/) R=1
				else if (illum ~ /\/2$/) R=2
				else {{
				print "ERROR: cannot determine read number:", $0 > "/dev/stderr"
				exit 1
				}}

			sub(/^@/,"",illum)
			sub(/\/[12]$/,"",illum)

			print "@"illum" "R":N:0:NA"
			next
			}}
			{{print}}
			' | pigz -p {threads} > "data/{wildcards.sample}/{wildcards.sample}_R$c.fastq.gz"
			((c++))
		done
		"""
		
rule get_variantsets:
	input:
		"config/truthset.s3",
		".tree.built"
	priority: 10
	output:
		expand("genome/truthset/{variantset}", variantset=VARINATSET)
	shell:	
		"""
		for link in $(cat {input}); do
			aws s3 cp $link genome/truthset/ --no-sign-request
		done
		"""
		
rule get_giab_truthsets:
	input:
		"config/giab.ftp",
		".tree.built"
	priority: 10
	output:
		expand("genome/giab/{giabset}", giabset=GIABSET)
	shell:	
		"""
		for link in $(cat {input}); do
			wget $link -P genome/giab/
		done
		"""

rule make_indexes4genome:
	input: 
		ref = f"genome/{GNAMES[0]}"
	priority: 5
	threads: 16
	output: temp("genome/.genome.prepared")
	shell:
		"""
		gunzip -k {input.ref}
		samtools faidx -@ {threads} genome/{GENOME_PREFIX}.fasta
		
		bowtie2-build --threads {threads} {input.ref} genome/{GENOME_PREFIX}
		bwa-mem2 index {input.ref}
		
		touch {output}
		"""

rule get_reference_genome:
	input: ".tree.built"
	params: 
		GENOME    = GENOME,
		MD5GENOME = MD5GENOME,
	priority: 10
	output:
		expand("genome/{ref}", ref=GNAMES)
	run:
		for file, md5sum in zip(params.GENOME, params.MD5GENOME):
			name = file.split("/")[-1]
			shell("wget {file} -P genome/")
			shell('if [[ $(md5sum genome/{name} | cut -d " " -f 1) != {md5sum} ]]; then echo "[MD5 ERROR] {name}"; exit 1; fi')

rule make_config:
	priority: 20
	params: SIDS = SIDS,
		GNAMES = GNAMES
	output: "config/config.json"
	run:    
		config = dict()
		root = Path().cwd()
		config["root"] = str(root)
		config["raw"] = str(root.joinpath("data"))

		for sample in params.SIDS:
			config[sample] = str(root.joinpath("workspace", sample))
	    	
		config["hg38"] = f"genome/{params.GNAMES[0]}"
		config["threads"] = max(1, cpu_count() - 2)
		config["ram"] = int((psutil.virtual_memory().total / (1024**3)) * 0.8)
	    	
		#create config file
		with open(root.joinpath('config', 'config.json'), 'w') as f:
			json.dump(config, f, indent=4)
			
rule create_directory_tree:
	priority: 20
	output: temp(".tree.built")
	shell:
		"""
		mkdir -p workspace/
		mkdir -p genome/giab/
		mkdir -p genome/truthset/
		touch {output}
		"""



