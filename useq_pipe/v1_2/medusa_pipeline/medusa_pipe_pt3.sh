#!/bin/bash

# part 1 of medusa pipeline - written by Gareth Wilson
# performs final filtering step and some medip specific QC
# requires installation of fastqc (www.bioinformatics.bbsrc.ac.uk/projects/fastqc/), R (www.r-project.org/) and the bioconductor package MEDIPS (http://www.bioconductor.org/packages/2.7/bioc/html/MEDIPS.html)


TREAT=$1
CONTROL=$2
SPECIES=$3
REFNAME=$4
READ_DEPTH=$5
DMR_SIZE=$6
PVALUE=$7
PATH2INPUT=$8
PATH2OUTPUT=$9
PATH2SCRIPTS=${10}

mkdir $PATH2OUTPUT
#run the script in R using Rscript

echo "$PATH2SCRIPTS/R_scripts/medips_dmrs.R $TREAT $CONTROL $SPECIES $REFNAME $READ_DEPTH $DMR_SIZE $PVALUE $PATH2INPUT $PATH2OUTPUT"
$PATH2SCRIPTS/R_scripts/medips_dmrs.R $TREAT $CONTROL $SPECIES $REFNAME $READ_DEPTH $DMR_SIZE $PVALUE $PATH2INPUT $PATH2OUTPUT 


