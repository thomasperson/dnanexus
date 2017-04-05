#!/bin/bash
# flatten_annotated_vcf 0.0.1
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

export SHELL="/bin/bash"

WKDIR=$(mktemp -d)
DXVCF_LIST=$(mktemp)



function parallel_download_and_process() {
	set -x
  export SHELL="/bin/bash"

	cd $2
	dx download "$1"

  IN_VCF=$(dx describe "$1" --name)

  pythonOptions="--vcf_file $IN_VCF -F $max_maf --gene_list gene_list  --sample_list sample_list"

  if test "$bi_snps_only" = "true"; then
    pythonOptions="$pythonOptions --b_snp"
  fi

    if test "$Ensembl" = "true"; then
      pythonOptions="$pythonOptions --Ensembl"
    else
      pythonOptions="$pythonOptions --RefSeq"
    fi
    if test "$cannonical" = "true"; then
      pythonOptions="$pythonOptions --Cannonical"
    fi
    pythonOptions="$pythonOptions -i $VEP_Level"
    if test "$HGMD_Level"; then
    pythonOptions="$pythonOptions --HGMD $HGMD_Level"
  fi
  if test "$ClinVar_Star"; then
    pythonOptions="$pythonOptions -c $ClinVar_Star"
    if test "$ClinVarSignificance_Level"; then
      pythonOptions="$pythonOptions -p $ClinVarSignificance_Level"
    fi
  fi

  echo $pythonOptions

  python ./flatten_annotated_vcf.py $pythonOptions

  tsv_UP=$(dx upload --brief ${IN_VCF%.vcf.gz}.filtered.tsv.gz)

  dx-jobutil-add-output filtered_tsv "$tsv_UP" --class=array:file

	json_UP=$(dx upload --brief ${IN_VCF%.vcf.gz}.filtered.json.gz)

  dx-jobutil-add-output filtered_json "$json_UP" --class=array:file


  rm ${IN_VCF%.*}*

}
export -f parallel_download_and_process

main() {

    cd $HOME


  	dx download "$gene_list" -o gene_list
		dx download "$sample_list" -o sample_list


    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    cd $HOME

    for i in "${!vcf[@]}"; do
  		echo "${vcf[$i]}" >> $DXVCF_LIST
  	done
    parallel -j $(nproc --all) -u --gnu parallel_download_and_process :::: $DXVCF_LIST ::: $HOME

    #cd $WKDIR

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

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    #dx-jobutil-add-output filtered_vcf "$filtered_vcf" --class=array:file
}