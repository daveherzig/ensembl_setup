#!/bin/bash -f

# Parameters
MYSQL_HOST=$1
MYSQL_USER=$2
MYSQL_PASS=$3
ENSEMBL_DIR=$4
MINIPIG_DIR=$5

### SCHEMA

# create database
createDBCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} < sql/createMinipigDB.sql"
echo $createDBCMD
eval $createDBCMD

# load core table
loadCoreSchemaCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -D sus_scrofa_domesticus_core_85_2012 < ${ENSEMBL_DIR}/ensembl/sql/table.sql"
echo $loadCoreSchemaCMD
eval $loadCoreSchemaCMD

# load pipeline table
loadPipelineSchemaCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -D sus_scrofa_domesticus_core_85_2012 < ${ENSEMBL_DIR}/ensembl-pipeline/sql/table.sql"
echo $loadPipelineSchemaCMD
eval $loadPipelineSchemaCMD

# populate production table
populateCMD="perl ${ENSEMBL_DIR}/ensembl-production/scripts/production_database/populate_production_db_tables.pl -h ${MYSQL_HOST} -u ${MYSQL_USER} --pass=${MYSQL_PASS} -d sus_scrofa_domesticus_core_85_2012 -mh ${MYSQL_HOST} -mu ${MYSQL_USER} --mpass=${MYSQL_PASS} -md sus_scrofa_core_85_102"
echo $populateCMD
eval $populateCMD


### ASSEMBLY

# step 0: convert files
eval "convertFastaFiles.sh ${MINIPIG_DIR}"

# step 1: create AGP files
eval "rm -r ~/agp"
eval "mkdir ~/agp"
chromosomes=("genome")
#chromosomes=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "X" "Y")
for i in "${chromosomes[@]}"; do
  #echo "rm -r ~/agp/chr$i"
  #eval "rm -r ~/agp/chr$i"

  # step 1: create AGP files
  echo "mkdir ~/agp/$i"
  eval "mkdir ~/agp/$i" 
  agpCMD="perl /home/ensembl/genome-information-spot/ensembl/loader/fasta2agp.pl -name $i -i ${MINIPIG_DIR}/converted/$i.fa -o ~/agp/$i"
  echo $agpCMD
  eval $agpCMD

  # step 2: create scaffolds
  scaffoldsCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/load_seq_region.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname sus_scrofa_domesticus_core_85_2012 -coord_system_name chromosome -rank 1 -default_version -agp_file ~/agp/$i/$i.agp"
  echo $scaffoldsCMD
  eval $scaffoldsCMD

  # step 3: create contigs
  contigsCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/load_seq_region.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname sus_scrofa_domesticus_core_85_2012 -coord_system_name contig -default_version -rank 3 -sequence_level -coord_system_version Minipig2012 -fasta_file ~/agp/$i/$i.contigs.fa"
  echo $contigsCMD
  eval $contigsCMD

  # step 4: create link between scaffold and contig
  #updateCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -e \"update coord_system set version=NULL where name='contig';\" sus_scrofa_domesticus_core_85_2012"
  #echo $updateCMD
  #eval $updateCMD
  linkCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/load_agp.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname sus_scrofa_domesticus_core_85_2012 -assembled_name chromosome -component_name contig -agp_file ~/agp/$i/$i.agp"
  echo $linkCMD
  eval $linkCMD
done

toplevelCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/set_toplevel.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname sus_scrofa_domesticus_core_85_2012"
echo $toplevelCMD
eval $toplevelCMD


