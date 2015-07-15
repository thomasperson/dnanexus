#!/bin/bash
# vcf_batch 0.0.1
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

main() {

    echo "Value of vcf_fn: '$vcf_fn'"
    echo "Value of vcfidx_fn: '$vcfidx_fn'"
    echo "Value of pheno_file: '$pheno_file'"

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

	WKDIR=$(mktemp -d)
	cd $WKDIR
	
	VCF_FN=$(dx describe --name "$vcf_fn")

    if test -n "$input_regions"; then
    	if test -z "$vcfidx_fn"; then
    		dx-jobutil-report-error "ERROR: When providing a region file, a TBI file is mandatory"
    	fi
    
    	dx download "$input_regions" -o input.regions
        VCF_HASH="$(dx describe "$vcf_fn" --json | jq -r .id)"
        TBI_HASH="$(dx describe "$vcfidx_fn" --json | jq -r .id)"

       	PART_ARG="--header --keep-open"
        
        for INTERVAL in $(head -n -1 input.regions) ; do
            python /usr/share/download_part.py \
                --interval "$INTERVAL" \
                --vcf "$VCF_HASH" \
                --index "$TBI_HASH" \
                $PART_ARG \
                --output "$VCF_FN" 
            PART_ARG="--append --keep-open"
        done
        
        INTERVAL="$(tail -n 1 input.regions)"
	    if [[ -f "$VCF_FN" ]]; then
	        PART_ARG="--append"
	    else
	        PART_ARG="--header"
	    fi

	    python /usr/share/download_part.py \
	        --interval "$INTERVAL" \
	        --vcf "$VCF_HASH" \
	        --index "$TBI_HASH" \
	        $PART_ARG \
	        --output "$VCF_FN"

		tabix -p vcf "$VCF_FN"
    	
    else
		dx download "$vcf_fn"
		
		if [ -n "$vcfidx_fn" ]
		then
		    dx download "$vcfidx_fn"
	   	elif test $(echo "$VCF_FN" | grep '\.gz$'); then
	   		tabix -p vcf $VCF_FN
	   	fi
	fi
	
	
   	CAT_CMD=cat
   	if test $(echo "$VCF_FN" | grep '\.gz$'); then
   		CAT_CMD=zcat
   	fi

   	DROP_CMD=""
   	if [ -n "$drop_file" ]
    then
        dx cat "$drop_file" | sed 's/^[ \t]*\([^ \t]*\).*$/\1\t\1/' >  drop_ids
        DROP_CMD="--remove drop_ids"
   	fi
   	
	VCF_IDS=$(mktemp)
	$CAT_CMD $VCF_FN | head -10000 | grep '^#CHROM' | cut -f10- | tr '\t' '\n' | sort > $VCF_IDS
	
	CASE_FILE=$(mktemp)
	if test "$pheno_file"; then
	    dx download "$pheno_file" -f -o $CASE_FILE
	else
		# in this case, select 1/2 of the IDs at random to be cases, please!
		N_IDS=$(cat $VCF_IDS | wc -l)
		N_CASES=$((N_IDS / 2))
		cat $VCF_IDS | shuf | head -n $N_CASES > $CASE_FILE
	fi

   
   	# OK, make sure that everybody in the pheno_file is actually in the VCF
   	
   	PHENO_CASE=$(mktemp)
   	join <(sort $CASE_FILE) $VCF_IDS > $PHENO_CASE
   	  	
   	if test $(cat $PHENO_CASE | wc -l) -ne $(cat $CASE_FILE | sed 's/^[ \t]#.*$//' | grep '.' | wc -l); then
   		echo "WARNING: Sample(s) in case group NOT in VCF! IDs follow:"
		join -v2 <(sort $PHENO_CASE) <(cat $CASE_FILE | sed 's/^[ \t]#.*$//' | grep '.' | sort)
		#dx-jobutil-report-error "ERROR: Samples in case file not present in VCF file, aborting!"
   	fi
   	
   	#OK, now we set cases/controls based on inclusion in the $PHENO_FILE
   	PLINK_PHENO=$(mktemp)
   	sed 's/^[ \t]*\([^ \t]*\).*$/\1\t\1\t2/' $PHENO_CASE > $PLINK_PHENO
   	join -v1 $VCF_IDS $PHENO_CASE | sed 's/^[ \t]*\([^ \t]*\).*$/\1\t\1\t1/' >> $PLINK_PHENO
   	
   	OUT_DIR=$(mktemp -d)	
    
    PLINK_CMD="--assoc"
    PLINK_SUFF="assoc"
    EXTRA_CMD="cat"
    # Now, check for covariates - if so, we'll need to use logistic
    if test "$input_covars"; then
    	PLINK_COVARS=$(mktemp)
    	dx cat "$input_covars" | sed 's/^\([^ \t]*\)\([ \t]\)/\1\2\1\2/' > $PLINK_COVARS
    	COVAR_LIST=$(head -1 $PLINK_COVARS | sed 's/  */\t/g' | cut -f3- | tr '\t' ',')
    	
    	PLINK_CMD="--logistic --covar $PLINK_COVARS"
    	PLINK_SUFF="assoc.logistic"
    	EXTRA_CMD="grep '\WADD\W'"
    fi
    
    
    plink2 --vcf $VCF_FN --double-id --id-delim ' ' $DROP_CMD $PLINK_CMD --out $OUT_DIR/$PREFIX --vcf-filter --pheno $PLINK_PHENO -allow-no-sex --threads $(nproc --all)
    
    sed -i -e 's/^[ \t]*//' -e's/  */\t/g' $OUT_DIR/$PREFIX.$PLINK_SUFF
    if test "$input_covars"; then
		tail -n+2  $OUT_DIR/$PREFIX.$PLINK_SUFF | eval "$EXTRA_CMD" | cut -f9 | grep -v 'NA' | sort -g > $OUT_DIR/$PREFIX.p_vals
	else
		tail -n+2  $OUT_DIR/$PREFIX.$PLINK_SUFF | eval "$EXTRA_CMD" | cut -f9 | grep -v 'NA' | sort -g > $OUT_DIR/$PREFIX.p_vals
	fi
    
    assoc_out=$(dx upload $OUT_DIR/$PREFIX.$PLINK_SUFF --brief)
    pval_list=$(dx upload $OUT_DIR/$PREFIX.p_vals --brief)

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    dx-jobutil-add-output assoc_out "$assoc_out" --class=file
    dx-jobutil-add-output pval_list "$pval_list" --class=file
}
