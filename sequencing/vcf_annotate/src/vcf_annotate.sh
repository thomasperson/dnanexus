#!/bin/bash
# vcf_annotate 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See https://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.

set -x
#set -o pipefail

function parse_dbnsfp(){
	DBNSFP_IN="$1"
	VCF_IN="$2"
	OUT_FN="$3"
	
	NEWDIR=$(mktemp -d)
	#cd $NEWDIR
	
	ANNO_STR=$(head -1 $DBNSFP_IN | tr '; ' '&_' | \
		awk -F'\t' '{print $4 "|" $29 "|" $32 "|" $35 "|" $38 "|" $41 "|" $44 "|" $47 "|" $50 "|" $53 "|" $59 "|" $11 "|" $22 "|" $23 "|" $116 "|" $117}' | \
		sed -e 's/\.//g'  -e's/_pred//g')

	
	tail -n+2 $DBNSFP_IN | tr '; ' '&_' | \
		awk -F'\t' '{print $1 "\t" $2 "\t" $4 "|" $29 "|" $32 "|" $35 "|" $38 "|" $41 "|" $44 "|" $47 "|" $50 "|" $53 "|" $59 "|" $11 "|" $22 "|" $23 "|" ($116 == "." ? "." : ($116 < 0 ? -$116 : $116)) "|" $117}' | \
		sed -e 's/\.\&*//g' > $NEWDIR/snp_anno
		
	for C in $(tabix -l "$VCF_IN" ); do grep "^$C\W" $NEWDIR/snp_anno | sort -k2,2n; done | bgzip -c > $NEWDIR/snp_anno_sorted.gz

	tabix -s 1 -b 2 $NEWDIR/snp_anno_sorted.gz
	
	zcat $VCF_IN | vcf-annotate -a $NEWDIR/snp_anno_sorted.gz -d key="INFO,ID=dbNSFP,Number=.,Type=String,Description='dbNSFP 2.9 annotations: $ANNO_STR'" -c CHROM,FROM,INFO/dbNSFP | bgzip -c > $OUT_FN
	
	tabix -p vcf $OUT_FN
}

function parse_sift(){
	SIFT_IN="$1"
	VCF_IN="$2"
	OUT_FN="$3"
	
	NEWDIR=$(mktemp -d)
	#cd $NEWDIR
	
	# columns in 2nd cut are:
	# 1 - chrom
	# 2 - pos
	# 3 - ALT
	# 20 - gene
	
	# cut removes the ",1," in the gene ID, tail removes the header,
	# sed turns 1st 3 commas to tabs
	# set removes the REF allele from column 3
	# tr converts ,->& and ' '->_
	# awk prints the annotation, defined to be pipe separated with the following fields:
	#   - ALT allele
	#   - Annotation (D=Damaging, T=Tolerated, N=N/A (i.e., synonymous change)
	#   - Impact Score (default <0.05 == Damaging)
	#   - Gene Name
	#   - Gene ID
	#   - SNP Type (Synon./Nonsynon.)
	#   - Transcript(s) (&-separated, if needed)
	#   - Role (i.e. 3'UTR, EXON, ...)
	cut -d, -f1,2,4- $SIFT_IN | tail -n+2 | sed -E 's/,/\n/g3; s/,/\t/g; s/\n/,/g' | \
		sed 's|\t[^\t/]*/|\t|' | tr ', ' '&_' | \
		awk -F'\t' '{print $1 "\t" $2 "\t" $3 "|" substr($16,1,1) "|" $17 "|" $21 "|" $20 "|" $15 "|" $5 "|" $13}' > $NEWDIR/snp_anno
	
	for C in $(tabix -l "$VCF_IN" ); do grep "^$C\W" $NEWDIR/snp_anno | sort -k2,2n; done | bgzip -c > $NEWDIR/snp_anno_sorted.gz
	tabix -s 1 -b 2 $NEWDIR/snp_anno_sorted.gz
	
	zcat $VCF_IN | vcf-annotate -a $NEWDIR/snp_anno_sorted.gz -d key=INFO,ID=SIFT,Number=.,Type=String,Description='SIFT 5.2.2 annotations: ALT | Annotation (D=Damaging, L=Damaging, low confidence, S=Damaging due to stop, T=Tolerated, N=N/A) | Raw SIFT score | Gene Name | Ensembl Gene ID | SNP Type | Ensembl Transcript ID(s) | SNP placement' -c CHROM,FROM,INFO/SIFT | bgzip -c > $OUT_FN
	
	tabix -p vcf $OUT_FN
}


main() {

    echo "Value of vcf_fn: '$vcf_fn'"
    echo "Value of vcfidx_fn: '$vcfidx_fn'"
    echo "Value of prefix: '$prefix'"
    
    FN=$(dx describe --name "$vcf_fn")
    if test -z "$prefix"; then
    
    	prefix="$(echo "$FN" | sed 's/\.vcf\(\.gz\)*$//').annotated"
    fi

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".
    
   	# get the resources we need in /usr/share/GATK
	sudo mkdir -p /usr/share/GATK/resources
	sudo chmod -R a+rwX /usr/share/GATK
	
	dx download "$DX_RESOURCES_ID:/GATK/jar/GenomeAnalysisTK-3.4-46.jar" -o /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar
	dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.fasta" -o /usr/share/GATK/resources/human_g1k_v37_decoy.fasta
	dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.fasta.fai" -o /usr/share/GATK/resources/human_g1k_v37_decoy.fasta.fai
	dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.dict" -o /usr/share/GATK/resources/human_g1k_v37_decoy.dict
	
	
	WKDIR=$(mktemp -d)
	OUTDIR=$(mktemp -d)
	cd $WKDIR
	
	LOCALFN="input.vcf"
	if test "$(echo "$FN" | grep '\.gz$')"; then
		LOCALFN="$LOCALFN.gz"
	fi
	
	dx download "$vcf_fn" -o $LOCALFN

	if test -z "$(echo "$FN" | grep '\.gz$')"; then
		bgzip "$LOCALFN"
		LOCALFN="$LOCALFN.gz"
	fi

	tabix -p vcf $LOCALFN	
	
    TOT_MEM=$(free -m | grep "Mem" | awk '{print $2}')
    # only ask for 90% of total system memory
    TOT_MEM=$((TOT_MEM * 9 / 10))
    
    if test "$snpeff" = "true"; then

		# Download the necessary files for snpEff
		sudo mkdir -p /usr/share/snpEff/data
		sudo chmod -R a+rwx /usr/share/snpEff
		dx download $(dx find data --name "snpEff-4.1l.jar" --project $DX_RESOURCES_ID --brief) -o /usr/share/snpEff/snpEff-4.1l.jar
		dx download -r "$DX_RESOURCES_ID:/snpEff/datasets/GRCh37.75" -o /usr/share/snpEff/data/
		dx download -r "$DX_RESOURCES_ID:/snpEff/snpEff.config" -o /usr/share/snpEff/snpEff.config


		zcat $LOCALFN | java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/snpEff/snpEff-4.1l.jar \
			-c /usr/share/snpEff/snpEff.config GRCh37.75 - | bgzip -c > snpEff.vcf.gz
		
		tabix -p vcf snpEff.vcf.gz	
	
		cp snpEff.vcf.gz $OUTDIR/$prefix.vcf.gz
	
		LOCALFN=snpEff.vcf.gz
		
		rm -rf /usr/share/snpEff

	fi
	
	# Add SIFT annotations here
	if test "$sift" = "true"; then
	
		# First, download what we need for SIFT
		sudo mkdir /usr/share/blast
		sudo chmod a+rwx /usr/share/blast
		dx download -r "$DX_RESOURCES_ID:/BLAST+/*" -o /usr/share/blast
	
		chmod a+x /usr/share/blast/bin/*
		export PATH="/usr/share/blast/bin:$PATH"
	
	
		sudo mkdir /usr/share/sift
		sudo chmod a+rwx /usr/share/sift
	
		dx download -r "$DX_RESOURCES_ID:/SIFT-5.2.2/*" -o /usr/share/sift
	
		chmod a+x /usr/share/sift/bin/*
	
		sudo mkdir /usr/share/sift_db
		sudo chmod a+rwx /usr/share/sift_db
	
		dx download -r "$DX_RESOURCES_ID:/SIFT_db/*" -o /usr/share/sift_db
	
		# create the file to annotate SNPs
	
		# first, get all the SNPs using GATK SelectVariants
		java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
			-T SelectVariants \
			-nt $(nproc --all) \
			-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
			-V $LOCALFN -selectType SNP -o sift.input.snp.vcf.gz
	
		# Now, convert this into SIFT-enabled input (residue-based, please!)
		zcat sift.input.snp.vcf.gz | grep -v '^#' | cut -f1,2,4,5 | awk -F '\t|,' '{for(i=4;i<=NF;i++){print $1 "," $2 ",1," $3 "/" $i}}' > sift_input
	
		# Looks like SIFT assumes a very specific running location!
		mkdir /usr/share/sift/tmp
		cd /usr/share/sift/tmp
	
		SIFT_DIR=$(mktemp -d)
		/usr/share/sift/bin/SIFT_exome_nssnvs.pl -i $WKDIR/sift_input -d /usr/share/sift_db/hg19_dbsnp135_2014_01_27 -o $SIFT_DIR -A 1 -B 1 > $WKDIR/sift_output
	
		# and back to the working directory with you!
		cd $WKDIR
	
		# Find out where my files are located, please!
		RESULT_FN=$(tail sift_output | grep '^Results in' | sed 's/^Results in //')
	
		# And parse them into a consistent format, prolly using a function
	
		parse_sift $RESULT_FN $LOCALFN $WKDIR/siftSNP.vcf.gz
		cp siftSNP.vcf.gz $OUTDIR/$prefix.vcf.gz
		
		LOCALFN=siftSNP.vcf.gz
	
	
		# Now, let's annotate the INDELs, too! (maybe)
		# first, get all the INDELs using GATK SelectVariants
	#	java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
	#		-T SelectVariants \
	#		-nt $(nproc --all) \
	#		-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
	#		-V $LOCALFN -selType INDEL -o input.INDEL.vcf.gz

		# Now, convert this into SIFT-enabled input (have to use space-based ... bummer)
	#	zcat input.snp.vcf.gz | grep -v '^#' | cut -f1,2,4,5 | awk -F '\t|,' '{for(i=4;i<=NF;i++){print $1 "," $2 - 1, "," length($3) ",1," $3 "/" $i}}' > sift_input

		rm -rf /usr/share/sift
		rm -rf /usr/share/sift_db
		rm -rf /usr/share/blast
	fi
	
	
	# Add polyphen2-HDIV here
	
	# Add polyphen2-HVAR here
	
	# Add LRT here??
	
	# Add dbNSFP here (2.9)
	if test "$dbnsfp" = "true"; then
		sudo mkdir /usr/share/dbNSFP
		sudo chmod a+rwx /usr/share/dbNSFP
	
		dx download "$DX_RESOURCES_ID:/dbNSFP/2.9/dbNSFPv2.9.zip" -o /usr/share/dbNSFP
		dx download "$DX_RESOURCES_ID:/dbNSFP/2.9/dbscSNV.zip" -o /usr/share/dbNSFP
	
		unzip /usr/share/dbNSFP/dbNSFPv2.9.zip -d /usr/share/dbNSFP
		unzip /usr/share/dbNSFP/dbscSNV.zip -d /usr/share/dbNSFP
		
		# first, get all the SNPs using GATK SelectVariants
		java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
			-T SelectVariants \
			-nt $(nproc --all) \
			-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
			-V $LOCALFN -selectType SNP -o dbnsfp.input.snp.vcf.gz
	
		# Convert to dbNSFP-style input
		zcat dbnsfp.input.snp.vcf.gz | grep -v '^#' | cut -f1,2,4,5 | awk -F '\t|,' '{for(i=4;i<=NF;i++){print $1 "\t" $2 "\t" $3 "\t" $i}}' > dbNSFP_input
	
		# query the dbNSFP database
		cd /usr/share/dbNSFP
		java -d64 -Xms512m -Xmx${TOT_MEM}m search_dbNSFP29 -i $WKDIR/dbNSFP_input -o $WKDIR/dbNSFP_output -s $WKDIR/dbNSFP_scsnv
		cd $WKDIR
	
		# Annotate the VCF file with the requested columns
		parse_dbnsfp $WKDIR/dbNSFP_output $LOCALFN $WKDIR/dbNSFP.vcf.gz
		
		# parse scsnv, too (maybe)!
	
		LOCALFN=dbNSFP.vcf.gz
		
		rm -rf /usr/share/dbNSFP
		cp dbNSFP.vcf.gz $OUTDIR/$prefix.vcf.gz	
	fi
	
	# Add CLINVAR here
	if test "$clinvar" = "true"; then
		CLINVARD=$(mktemp -d)
		dx download "$DX_RESOURCES_ID:/CLINVAR/variant_summary_2015-10.txt.gz" -o $CLINVARD/variant_summary.txt.gz
		dx download "$DX_RESOURCES_ID:/CLINVAR/clinvar_20150929.vcf.gz" -o $CLINVARD/clinvar.vcf.gz
		
		gunzip $CLINVARD/variant_summary.txt.gz
		gunzip $CLINVARD/clinvar.vcf.gz
		
		grep 'single nucleotide variant' $CLINVARD/variant_summary.txt  | grep '\WGRCh37\W' | \
			awk -F'\t' '{gsub(/.*expert.*/, "expert", $18); gsub(/.*guideline.*/, "guideline", $18); gsub(/.*conflicting.*/, "conflicting", $18); gsub(/no.*/, "none", $18); gsub(/.*single.*/,"single", $18); gsub(/.*multiple.*/,"multiple", $18);  print $14 ":" $15 "," ($26 == "na" ? "-" : $26) "/" ($27 == "na" ? "-" : $27) "\t" $6 "\t" $18 "\t" $5}' | tr ' ' '_' | sort -t'\0' -u | sort -t$'\t' -k1,1 > $CLINVARD/variant_snp_grch37
			
		grep -v 'single nucleotide variant' $CLINVARD/variant_summary.txt  | grep '\WGRCh37\W' | \
			awk -F'\t' '{gsub(/.*expert.*/, "expert", $18); gsub(/.*guideline.*/, "guideline", $18); gsub(/no.*/, "none", $18); gsub(/.*single.*/,"single", $18); gsub(/.*multiple.*/,"multiple", $18); gsub(/.*conflicting.*/, "conflicting", $18); if($7 != -1){print $7 "\t" $6 "\t" $18 "\t" $5}}' | tr ' ' '_' | sort -t'\0' -u | sort -t$'\t' -k1,1 > $CLINVARD/variant_indel_grch37


		# first, get all the SNPs using GATK SelectVariants
		java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
			-T SelectVariants \
			-nt $(nproc --all) \
			-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
			-V $LOCALFN -selectType SNP -o clinvar.input.snp.vcf.gz
		
		# Also, get all the INDELs (non-SNPs) using GATK selectVariants
		java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
			-T SelectVariants \
			-nt $(nproc --all) \
			-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
			-V $LOCALFN -xlSelectType SNP -o clinvar.input.indel.vcf.gz
			
		# get the INDELs from the CLINVAR VCF
		java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
			-T SelectVariants \
			-nt $(nproc --all) \
			-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
			-V $CLINVARD/clinvar.vcf -xlSelectType SNP -o $CLINVARD/clinvar.indel.vcf.gz

		# Now, create input that looks like "chrom:pos,ref/alt <tab> alt", but only for SNPs!
		zcat clinvar.input.snp.vcf.gz | grep -v '^#' | cut -f1,2,4,5 | awk -F '\t|,' '{for(i=4;i<=NF;i++){print $1 ":" $2 "," $3 "/" $i "\t" $i}}' | sort -t$'\t' -k1,1 | tee clinvar_snp_input | wc -l
		
		# Join the clinvar snp data with the clinvar_snp_input
		join -t$'\t' -j1 clinvar_snp_input $CLINVARD/variant_snp_grch37 | sed 's/^\([^:]*\):\([^,]*\),[^\t]*\t\(.*\)/\1\t\2\t\3/' | sed 's/\t/|/g3' | tr ';/' '&&' | tee clinvar_snp_output | wc -l
		
		# get the INDELs that match in clinvar (actually, we're getting the indels that match in the input)
		java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
			-T SelectVariants \
			-nt $(nproc --all) \
			-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
			-V $CLINVARD/clinvar.indel.vcf.gz -conc clinvar.input.indel.vcf.gz -o clinvar.output.indel.vcf.gz
			
		# And get the RSIDs to match from the indel
		vcf-query clinvar.output.indel.vcf.gz -f "%INFO/RS\t%CHROM\t%POS\t%ALT\n" | tr ',' '&' |  sort -t$'\t' -k1,1 > clinvar_indel_anno
		
		# And join the indels based on RSID
		join -t$'\t' -j1 clinvar_indel_anno $CLINVARD/variant_indel_grch37 | cut -f 2- | sed 's/\t/|/g3' | tr ';/' '&&' | tee clinvar_indel_output | wc -l
		
		cat clinvar_snp_output clinvar_indel_output | tee clinvar_output | wc -l
		
		for C in $(tabix -l $LOCALFN ); do grep "^$C\W" clinvar_output | sort -k2,2n; done | bgzip -c > clinvar_anno_sorted.gz
		tabix -s 1 -b 2 clinvar_anno_sorted.gz
		
		zcat $LOCALFN | vcf-annotate -a clinvar_anno_sorted.gz -d key=INFO,ID=CLINVAR,Number=.,Type=String,Description='CLINVAR (Oct, 2015) annotations: ALT | Significance | Review Status | Gene ID' -c CHROM,FROM,INFO/CLINVAR | bgzip -c > clinvar.vcf.gz
		
		tabix -p vcf clinvar.vcf.gz
		
		LOCALFN=clinvar.vcf.gz
		rm -rf $CLINVARD
		cp clinvar.vcf.gz $OUTDIR/$prefix.vcf.gz
		
	
	fi

	tabix -p vcf $OUTDIR/$prefix.vcf.gz
	
    vcf_out=$(dx upload $OUTDIR/$prefix.vcf.gz --brief)
    vcfidx_out=$(dx upload $OUTDIR/$prefix.vcf.gz.tbi --brief)

    dx-jobutil-add-output vcf_out "$vcf_out" --class=file
    dx-jobutil-add-output vcfidx_out "$vcfidx_out" --class=file
}