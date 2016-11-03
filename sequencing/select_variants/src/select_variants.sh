#!/bin/bash
# vcf_qc 0.0.1
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

main() {
	set -x

	SUBJOB_ARGS="-ief:boolean=$ef -ienv:boolean=$env"
	if test "$region_file"; then
		SUBJOB_ARGS="$SUBJOB_ARGS -iregion_file:file=$(dx describe --json "$region_file" | jq -r .id)"
	fi
		
	if test "$samp_incl"; then
		SUBJOB_ARGS="$SUBJOB_ARGS -isamp_incl:file=$(dx describe --json "$samp_incl" | jq -r .id)"
	fi
	
	if test "$samp_excl"; then
		SUBJOB_ARGS="$SUBJOB_ARGS -isamp_excl:file=$(dx describe --json "$samp_excl" | jq -r .id)"
	fi
	
	if test "$concord_vcf"; then
		SUBJOB_ARGS="$SUBJOB_ARGS -iconcord_vcf:file=$(dx describe --json "$concord_vcf" | jq -r .id)"
	fi
	
	
	if test "$EXTRA_CMD"; then
		SUBJOB_ARGS="$SUBJOB_ARGS -iEXTRA_CMD:string='$EXTRA_CMD'"
	fi

	if test "$out_suffix"; then
		SUBJOB_ARGS="$SUBJOB_ARGS -iout_suffix:string='$out_suffix'"
	fi

	SUBJOB_ARGS="$SUBJOB_ARGS -iheader:boolean=$headers"

	WKDIR=$(mktemp -d)
	cd $WKDIR

	VCFIDX_LIST=$(mktemp)
	for i in "${!vcfidx_fn[@]}"; do	
		dx describe --json "${vcfidx_fn[$i]}" | jq -r '"\(.id)\t\(.name)"' >> $VCFIDX_LIST
	done
	
	
	for i in "${!vcf_fn[@]}"; do
	
		PREFIX="$(dx describe --name "${vcf_fn[$i]}" | sed 's/\.vcf.\(gz\)*$//').subset"
	
		VCF_NAME=$(dx describe --name "${vcf_fn[$i]}");
		VCF_IDX_LINE=$(grep "\W$VCF_NAME.tbi$" $VCFIDX_LIST | cut -f1)
		# download the tabix index
		dx download "$VCF_IDX_LINE" -o raw.vcf.gz.tbi
	
		# get a list of chromosomes and run SelectVariants on the chromosomes independently
		if test "$out_suffix"; then
			CONCAT_PREFIX="${PREFIX}.${out_suffix}"
		else
			CONCAT_PREFIX="$PREFIX"
		fi
		CONCAT_ARGS="-iprefix=$CONCAT_PREFIX"
		CONCAT_HDR_ARGS="-iprefix=header.$CONCAT_PREFIX"
		
		N_CHR=$(tabix -l raw.vcf.gz | wc -l)
		
		for CHR in $(tabix -l raw.vcf.gz); do
			NEWPREFIX="$PREFIX"
			if test $N_CHR -gt 1; then
				NEWPREFIX="$NEWPREFIX.$CHR"
			fi
		
			SUBJOBID=$(eval dx-jobutil-new-job run_sv -ivcf_fn:file=$(dx describe --json "${vcf_fn[$i]}" | jq -r .id) -ivcfidx_fn:file=$VCF_IDX_LINE -iCHR:string="$CHR" -iPREFIX:string="$NEWPREFIX" "$SUBJOB_ARGS") 
			
			if test $N_CHR -gt 1 -a "$merge" = "false"; then
				dx-jobutil-add-output vcf_out --array "$SUBJOBID:vcf_out" --class=jobref
				dx-jobutil-add-output vcfidx_out --array "$SUBJOBID:vcfidx_out" --class=jobref
				if test "$headers" = "true"; then
					dx-jobutil-add-output vcf_hdr_out --array "$SUBJOBID:vcf_hdr_out" --class=jobref
					dx-jobutil-add-output vcfidx_hdr_out --array "$SUBJOBID:vcfidx_hdr_out" --class=jobref
				fi
			fi
			
			CONCAT_ARGS="$CONCAT_ARGS -ivcfs=$SUBJOBID:vcf_out -ivcfidxs=$SUBJOBID:vcfidx_out"
			CONCAT_HDR_ARGS="$CONCAT_HDR_ARGS -ivcfs=$SUBJOBID:vcf_hdr_out -ivcfidxs=$SUBJOBID:vcfidx_hdr_out"
		done
	
		if test $N_CHR -gt 1; then
			if test "$merge" = "true"; then
				# Concatenate the results
				CONCAT_JOB=$(dx run cat_variants $CONCAT_ARGS --brief)
				dx-jobutil-add-output vcf_out --array "$CONCAT_JOB:vcf_out" --class=jobref
				dx-jobutil-add-output vcfidx_out --array "$CONCAT_JOB:vcfidx_out" --class=jobref
				if test "$headers" = "true"; then
					CONCAT_HDR_JOB=$(dx run cat_variants $CONCAT_HDR_ARGS --brief)
					dx-jobutil-add-output vcf_hdr_out --array "$CONCAT_HDR_JOB:vcf_out" --class=jobref
					dx-jobutil-add-output vcfidx_hdr_out --array "$CONCAT_HDR_JOB:vcfidx_out" --class=jobref
				fi
			fi
			# empty else is taken care of in the "for CHR ..." loop
		else
			dx-jobutil-add-output vcf_out --array "$SUBJOBID:vcf_out" --class=jobref
			dx-jobutil-add-output vcfidx_out --array "$SUBJOBID:vcfidx_out" --class=jobref
			if test "$headers" = "true"; then
				dx-jobutil-add-output vcf_hdr_out --array "$SUBJOBID:vcf_hdr_out" --class=jobref
				dx-jobutil-add-output vcfidx_hdr_out --array "$SUBJOBID:vcfidx_hdr_out" --class=jobref
			fi			
		fi

    	rm raw.vcf.gz.tbi
    done

}


run_sv() {

	set -x

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

	WKDIR=$(mktemp -d)
	cd $WKDIR
	
	SV_ARGS=""
	if test "$region_file"; then
		REGION_FN=$(dx describe --name "$region_file");
		REGION_EXT=$(echo "$REGION_FN" | sed 's|.*\.||')
		REGION_BASE=$(echo "$REGION_FN" | sed 's|\.[^.]*$||')
		
		declare -A ext_list
		ext_list["list"]=1
		ext_list["interval_list"]=1
		ext_list["bed"]=1
		
		if [[ ${ext_list[$REGION_EXT]} ]]; then
			REGION_FN="$REGION_BASE.$REGION_EXT"
		else
			REGION_FN="$REGION_BASE.list"
		fi
		
		dx download "$region_file" -o "$REGION_FN"
		SV_ARGS="$SV_ARGS -L $PWD/$REGION_FN"
	fi
	
	if test "$ef" = "true"; then
		SV_ARGS="$SV_ARGS -ef"
	fi
	
	if test "$env" = "true"; then 
		SV_ARGS="$SV_ARGS -env"
	fi
	
	if test "$samp_incl"; then
		dx download "$samp_incl" -o samp_incl
		SV_ARGS="$SV_ARGS -sf samp_incl"
	fi
	
	if test "$samp_excl"; then
		dx download "$samp_excl" -o samp_excl
		SV_ARGS="$SV_ARGS -xl_sf samp_excl"
	fi
	
	if test "$EXTRA_CMD"; then
		SV_ARGS="$SV_ARGS $EXTRA_CMD"
	fi
	
	if test -z "$SV_ARGS" -a -z "$concord_vcf"; then
		dx-jobutil-report-error "ERROR: Nothing to do!"
	fi

	
	# get the resources we need in /usr/share/GATK
	sudo mkdir -p /usr/share/GATK/resources
	sudo chmod -R a+rwX /usr/share/GATK
	
		
	dx download "$DX_RESOURCES_ID:/GATK/jar/GenomeAnalysisTK-3.4-46.jar" -o /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar
	dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.fasta" -o /usr/share/GATK/resources/human_g1k_v37_decoy.fasta
	dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.fasta.fai" -o /usr/share/GATK/resources/human_g1k_v37_decoy.fasta.fai
	dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.dict" -o /usr/share/GATK/resources/human_g1k_v37_decoy.dict



    TOT_MEM=$(free -m | grep "Mem" | awk '{print $2}')
    # only ask for 90% of total system memory
    TOT_MEM=$((TOT_MEM * 9 / 10))

	if test "$concord_vcf"; then
	
		# NOTE: This is only here because some of the VCFs may be unsorted... grumble...
		# This REALLY should just be a check for compression, then tabix if necessary
		CAT_CMD="cat"
		if test $(dx describe --name "$concord_vcf" | grep '\.gz$' | wc -l) -ne 0; then
			CAT_CMD="zcat"
		fi
		
		dx cat "$concord_vcf" | $CAT_CMD | vcf-sort | bgzip -c > concord_all.vcf.gz
		tabix -p vcf concord_all.vcf.gz
		
		# Restrict the concord_all.$EXT to the chromosome of interest only!
		java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
		-T SelectVariants \
		-nt $(nproc --all) \
		-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
		-V concord_all.vcf.gz -L $CHR -o concord_chr.vcf.gz
		
		SV_ARGS="$SV_ARGS -conc concord_chr.vcf.gz"
	fi	

	download_part.py -f $(dx describe --json "$vcf_fn" | jq -r .id) -i $(dx describe --json "$vcfidx_fn" | jq -r .id) -L $CHR -H -o raw.vcf.gz
	tabix -p vcf raw.vcf.gz
	
 #   dx download "$vcf_fn" -o raw.vcf.gz
 #   dx download "$vcfidx_fn" -o raw.vcf.gz.tbi
    

	OUT_DIR=$(mktemp -d)
	if test -z "$PREFIX"; then
		PREFIX="$(dx describe --name "$vcf_fn" | sed 's/\.vcf.\(gz\)*$//').subset"
	fi

	if test "$out_suffix"; then
		SUFFIX="${out_suffix}."
	fi

	eval java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK-3.4-46.jar \
		-T SelectVariants \
		-nt $(nproc --all) \
		-R /usr/share/GATK/resources/human_g1k_v37_decoy.fasta \
		-V raw.vcf.gz "$SV_ARGS" \
		-o $OUT_DIR/$PREFIX."$SUFFIX"vcf.gz
	
	vcf_out=$(dx upload $OUT_DIR/$PREFIX.${SUFFIX}vcf.gz --brief)
	vcfidx_out=$(dx upload $OUT_DIR/$PREFIX.${SUFFIX}vcf.gz.tbi --brief)

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    dx-jobutil-add-output vcf_out "$vcf_out" --class=file
    dx-jobutil-add-output vcfidx_out "$vcfidx_out" --class=file
    
    if test "$header" = "true"; then
       	# get only the 1st 8 (summary) columns - will be helpful when running VQSR or other variant-level information
		pigz -dc "$OUT_DIR/$PREFIX.${SUFFIX}vcf.gz" | cut -f1-8 | bgzip -c > "$OUT_DIR/header.$PREFIX.${SUFFIX}vcf.gz"
		tabix -p vcf "$OUT_DIR/header.$PREFIX.${SUFFIX}vcf.gz"
		
    
		vcf_hdr_fn=$(dx upload "$OUT_DIR/header.$PREFIX.${SUFFIX}vcf.gz" --brief)
		vcf_idx_hdr_fn=$(dx upload "$OUT_DIR/header.$PREFIX.${SUFFIX}vcf.gz.tbi" --brief)

		dx-jobutil-add-output vcf_hdr_out "$vcf_hdr_fn" --class=file
		dx-jobutil-add-output vcfidx_hdr_out "$vcf_idx_hdr_fn" --class=file
    fi
}
