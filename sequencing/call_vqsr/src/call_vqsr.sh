#!/bin/bash
# call_vqsr 0.0.1
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

echo "deb http://us.archive.ubuntu.com/ubuntu vivid main restricted universe multiverse " >> /etc/apt/sources.list
sudo apt-get update
sudo apt-get install --yes openjdk-8-jre-headless

main() {

    echo "Value of vcf_file: '$vcf_file'"
    echo "Value of vcf_idx_file: '$vcf_idx_file'"
    echo "Value of mode: '$mode'"
    echo "Value of exome: '$exome'"

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    VCF_FN=$(dx describe --name "$vcf_file")
    VCF_IDX_FN=$(dx describe --name "$vcf_idx_file")


    dx download "$vcf_file" -o $VCF_FN
    dx download "$vcf_idx_file" -o $VCF_IDX_FN


    # Fill in your application code here.
    #
    # To report any recognized errors in the correct format in
    # $HOME/job_error.json and exit this script, you can use the
    # dx-jobutil-report-error utility as follows:
    #
    #   dx-jobutil-report-error "My error message"
    #
    # Note however that this entire bash script is executed with -e
    # when running in the cloud, so any line which returns a nonzero
    # exit code will prematurely exit the script; if no error was
    # reported in the job_error.json file, then the failure reason
    # will be AppInternalError with a generic error message.


	# get the resources we need in /usr/share/GATK
	sudo mkdir -p /usr/share/GATK/resources
	sudo chmod -R a+rwX /usr/share/GATK

	# get the supporting files we need for GATK (and GATK itself)

	dx download "$DX_RESOURCES_ID:/GATK/jar/GenomeAnalysisTK-3.6.jar" -o /usr/share/GATK/GenomeAnalysisTK.jar


	if [ "$build_version" == "b37_decoy" ]
	then
		dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.fasta" -o /usr/share/GATK/resources/build.fasta
		dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.fasta.fai" -o /usr/share/GATK/resources/build.fasta.fai
		dx download "$DX_RESOURCES_ID:/GATK/resources/human_g1k_v37_decoy.dict" -o /usr/share/GATK/resources/build.dict

    dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_137.b37.vcf.gz" -o /usr/share/GATK/resources/dbsnp.vcf.gz
		dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_137.b37.vcf.gz.tbi"  -o /usr/share/GATK/resources/dbsnp.vcf.gz.tbi
  elif [ "$build_version" == "rgc_b38" ]
  then

  dx download "$DX_RESOURCES_ID:/GATK/resources/Homo_sapiens_assembly38.fasta" -o /usr/share/GATK/resources/build.fasta
  dx download "$DX_RESOURCES_ID:/GATK/resources/Homo_sapiens_assembly38.fasta.fai" -o /usr/share/GATK/resources/build.fasta.fai
  dx download "$DX_RESOURCES_ID:/GATK/resources/Homo_sapiens_assembly38.dict" -o /usr/share/GATK/resources/build.dict

  dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_144.hg38.chr.vcf.gz" -o /usr/share/GATK/resources/dbsnp.vcf.gz
  dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_144.hg38.chr.vcf.gz.tbi"  -o /usr/share/GATK/resources/dbsnp.vcf.gz.tbi

elif [ "$build_version" == "gatk_b38" ]
then

dx download "$DX_RESOURCES_ID:/GATK/resources/Homo_sapiens_assembly38.fasta" -o /usr/share/GATK/resources/build.fasta
dx download "$DX_RESOURCES_ID:/GATK/resources/Homo_sapiens_assembly38.fasta.fai" -o /usr/share/GATK/resources/build.fasta.fai
dx download "$DX_RESOURCES_ID:/GATK/resources/Homo_sapiens_assembly38.dict" -o /usr/share/GATK/resources/build.dict

dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_144.hg38.chr.vcf.gz" -o /usr/share/GATK/resources/dbsnp.vcf.gz
dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_144.hg38.chr.vcf.gz.tbi"  -o /usr/share/GATK/resources/dbsnp.vcf.gz.tbi

	else

			dx download "$DX_RESOURCES_ID:/GATK/resources/hg38chr.fa" -o /usr/share/GATK/resources/build.fasta
			dx download "$DX_RESOURCES_ID:/GATK/resources/hg38chr.fa.fai" -o /usr/share/GATK/resources/build.fasta.fai
			dx download "$DX_RESOURCES_ID:/GATK/resources/hg38chr.dict" -o /usr/share/GATK/resources/build.dict

      dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_144.hg38.chr.vcf.gz" -o /usr/share/GATK/resources/dbsnp.vcf.gz
			dx download "$DX_RESOURCES_ID:/GATK/resources/dbsnp_144.hg38.chr.vcf.gz.tbi"  -o /usr/share/GATK/resources/dbsnp.vcf.gz.tbi


	fi

    INCL_DP=""
    if test "$exome" = "false"; then
    	INCL_DP="-an DP"
    fi

	RESOURCE_STR=""
	ANNO_STR=""
	# running in SNP mode
	if test "$mode" = "SNP"; then

    if [ "$build_version" == "b37_decoy" ]
  	then
      dx download "$DX_RESOURCES_ID:/GATK/resources/hapmap_3.3.b37.vcf.gz" -o /usr/share/GATK/resources/hapmap_3.3.vcf.gz
  		dx download "$DX_RESOURCES_ID:/GATK/resources/hapmap_3.3.b37.vcf.gz.tbi" -o /usr/share/GATK/resources/hapmap_3.3.vcf.gz.tbi
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_omni2.5.b37.vcf.gz" -o /usr/share/GATK/resources/1000G_omni2.5.vcf.gz
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_omni2.5.b37.vcf.gz.tbi" -o /usr/share/GATK/resources/1000G_omni2.5.vcf.gz.tbi
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_phase1.snps.high_confidence.b37.vcf.gz" -o /usr/share/GATK/resources/1000G_phase1.snps.high_confidence.vcf.gz
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_phase1.snps.high_confidence.b37.vcf.gz.tbi" -o /usr/share/GATK/resources/1000G_phase1.snps.high_confidence.vcf.gz.tbi

  		ANNO_STR="-mode $mode -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum -an InbreedingCoeff $INCL_DP"
  		RESOURCE_STR="$RESOURCE_STR -resource:hapmap,known=false,training=true,truth=true,prior=15.0 /usr/share/GATK/resources/hapmap_3.3.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:omni,known=false,training=true,truth=true,prior=12.0 /usr/share/GATK/resources/1000G_omni2.5.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:1000G,known=false,training=true,truth=false,prior=10.0 /usr/share/GATK/resources/1000G_phase1.snps.high_confidence.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 /usr/share/GATK/resources/dbsnp.vcf.gz"
  	else

      dx download "$DX_RESOURCES_ID:/GATK/resources/hapmap_3.3.hg38.chr.new.vcf.gz" -o /usr/share/GATK/resources/hapmap_3.3.vcf.gz
  		dx download "$DX_RESOURCES_ID:/GATK/resources/hapmap_3.3.hg38.chr.new.vcf.gz.tbi" -o /usr/share/GATK/resources/hapmap_3.3.vcf.gz.tbi
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_omni2.5.hg38.chr.new.vcf.gz" -o /usr/share/GATK/resources/1000G_omni2.5.vcf.gz
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_omni2.5.hg38.chr.new.vcf.gz.tbi" -o /usr/share/GATK/resources/1000G_omni2.5.vcf.gz.tbi
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_phase1.snps.high_confidence.hg38.chr.vcf.gz" -o /usr/share/GATK/resources/1000G_phase1.snps.high_confidence.vcf.gz
  		dx download "$DX_RESOURCES_ID:/GATK/resources/1000G_phase1.snps.high_confidence.hg38.chr.vcf.gz.tbi" -o /usr/share/GATK/resources/1000G_phase1.snps.high_confidence.vcf.gz.tbi

  		ANNO_STR="-mode $mode -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum -an InbreedingCoeff $INCL_DP"
  		RESOURCE_STR="$RESOURCE_STR -resource:hapmap,known=false,training=true,truth=true,prior=15.0 /usr/share/GATK/resources/hapmap_3.3.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:omni,known=false,training=true,truth=true,prior=12.0 /usr/share/GATK/resources/1000G_omni2.5.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:1000G,known=false,training=true,truth=false,prior=10.0 /usr/share/GATK/resources/1000G_phase1.snps.high_confidence.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 /usr/share/GATK/resources/dbsnp.vcf.gz"

  	fi


	else
	# running in INDEL mode

    if [ "$build_version" == "b37_decoy" ]
    then
      dx download "$DX_RESOURCES_ID:/GATK/resources/Mills_and_1000G_gold_standard.indels.b37.vcf.gz" -o /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.vcf.gz
  		dx download "$DX_RESOURCES_ID:/GATK/resources/Mills_and_1000G_gold_standard.indels.b37.vcf.gz.tbi" -o /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.vcf.gz.tbi

  		ANNO_STR="-mode $mode --maxGaussians 4 -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff $INCL_DP"
  		RESOURCE_STR="$RESOURCE_STR -resource:mills,known=false,training=true,truth=true,prior=12.0 /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 /usr/share/GATK/resources/dbsnp.vcf.gz"
    else

      dx download "$DX_RESOURCES_ID:/GATK/resources/Mills_and_1000G_gold_standard.indels.hg38.chr.vcf.gz" -o /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.vcf.gz
      dx download "$DX_RESOURCES_ID:/GATK/resources/Mills_and_1000G_gold_standard.indels.hg38.chr.vcf.gz.tbi" -o /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.vcf.gz.tbi

      #dx download "$DX_RESOURCES_ID:/GATK/resources/Mills_and_1000G_gold_standard.indels.b37.vcf.gz" -o /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.b37.vcf.gz
  		#dx download "$DX_RESOURCES_ID:/GATK/resources/Mills_and_1000G_gold_standard.indels.b37.vcf.gz.tbi" -o /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.b37.vcf.gz.tbi

  		ANNO_STR="-mode $mode --maxGaussians 4 -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff $INCL_DP"
  		RESOURCE_STR="$RESOURCE_STR -resource:mills,known=false,training=true,truth=true,prior=12.0 /usr/share/GATK/resources/Mills_and_1000G_gold_standard.indels.vcf.gz"
  		RESOURCE_STR="$RESOURCE_STR -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 /usr/share/GATK/resources/dbsnp.vcf.gz"
    fi


	fi

	echo "My RESOURCE_STR: $RESOURCE_STR"

    # OK, now, let's run GATK
	TOT_MEM=$(free -m | grep "Mem" | awk '{print $2}')
	# OK, now we can call the GATK genotypeGVCFs
	java -d64 -Xms512m -Xmx${TOT_MEM}m -jar /usr/share/GATK/GenomeAnalysisTK.jar \
	-nt $(nproc --all) \
	-T VariantRecalibrator $ANNO_STR $RESOURCE_STR \
	-R /usr/share/GATK/resources/build.fasta \
	-input "$VCF_FN" -titv $target_titv \
	-tranche 100.0 -tranche 99.9 -tranche 99.5 -tranche 99.0 -tranche 95.0 -tranche 90.0 \
	-recalFile recalibrate_$mode.recal \
	-tranchesFile recalibrate_$mode.tranches \
	#-rscriptFile recalibrate_${mode}.plots.R

	# regenerate the tranches.pdf file in SNP mode to get around GATK bug
	#if test "$mode" = "SNP"; then
		#mv recalibrate_$mode.tranches.pdf recalibrate_$mode.tranches.old.pdf
		#plotTranches.R recalibrate_$mode.tranches $target_titv || true
	#fi

    # The following line(s) use the dx command-line tool to upload your file
    # outputs after you have created them on the local file system.  It assumes
    # that you have used the output field name for the filename for each output,
    # but you can change that behavior to suit your needs.  Run "dx upload -h"
    # to see more options to set metadata.

    recal_file=$(dx upload recalibrate_$mode.recal --brief)
    recal_idx_file=$(dx upload recalibrate_$mode.recal.idx --brief)
    tranches_file=$(dx upload recalibrate_$mode.tranches --brief)
    #rscript_file=$(dx upload recalibrate_${mode}.plots.R --brief)

    #for f in $(ls | grep '\.pdf$'); do
    #	pdf_f=$(dx upload $f --brief)
    #	dx-jobutil-add-output pdf_files --array "$pdf_f" --class=file
    #done

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    dx-jobutil-add-output recal_file "$recal_file" --class=file
    dx-jobutil-add-output recal_idx_file "$recal_idx_file" --class=file
    dx-jobutil-add-output tranches_file "$tranches_file" --class=file
    #dx-jobutil-add-output rscript_file "$rscript_file" --class=file

    sleep 30

}
