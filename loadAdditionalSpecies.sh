#!/bin/bash -f

# Parameters

# MySQL Server
MYSQL_HOST=$1

# MySQL User
MYSQL_USER=$2

# MySQL Password
MYSQL_PASS=$3

# MySQL Database Name
MYSQL_DBNAME=$4

# Directory containing the ensembl modules
ENSEMBL_DIR=$5

# Directory containing the sequence files
SEQUENCE_DIR=$6

### SCHEMA

# create database
createDBCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -e 'drop database if exists ${MYSQL_DBNAME}'"
echo $createDBCMD
eval $createDBCMD
createDBCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -e 'create database ${MYSQL_DBNAME}'"
echo $createDBCMD
eval $createDBCMD
createDBCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -e 'grant all on ${MYSQL_DBNAME}.* to ensembl_write'"
echo $createDBCMD
eval $createDBCMD
createDBCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -e 'grant select on ${MYSQL_DBNAME}.* to ensembl_read'"
echo $createDBCMD
eval $createDBCMD

# load core table
loadCoreSchemaCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -D ${MYSQL_DBNAME} < ${ENSEMBL_DIR}/ensembl/sql/table.sql"
echo $loadCoreSchemaCMD
eval $loadCoreSchemaCMD

# load pipeline table
loadPipelineSchemaCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -D ${MYSQL_DBNAME} < ${ENSEMBL_DIR}/ensembl-pipeline/sql/table.sql"
echo $loadPipelineSchemaCMD
eval $loadPipelineSchemaCMD

# populate production table
populateCMD="perl ${ENSEMBL_DIR}/ensembl-production/scripts/production_database/populate_production_db_tables.pl -h ${MYSQL_HOST} -u ${MYSQL_USER} --pass=${MYSQL_PASS} -d ${MYSQL_DBNAME} -mh ${MYSQL_HOST} -mu ${MYSQL_USER} --mpass=${MYSQL_PASS} -md sus_scrofa_core_85_102"
echo $populateCMD
eval $populateCMD


### ASSEMBLY

# step 0: convert files
# convert any ambiguities if needed
#eval "convertFastaFiles.sh ${MINIPIG_DIR}"

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
  agpCMD="perl /home/ensembl/genome-information-spot/ensembl/loader/fasta2agp.pl -name $i -i ${SEQUENCE_DIR}/converted/$i.fa -o ~/agp/$i"
  echo $agpCMD
  eval $agpCMD

  # step 2: create scaffolds
  scaffoldsCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/load_seq_region.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname ${MYSQL_DBNAME} -coord_system_name chromosome -rank 1 -default_version -agp_file ~/agp/$i/$i.agp"
  echo $scaffoldsCMD
  eval $scaffoldsCMD

  # step 3: create contigs
  contigsCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/load_seq_region.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname ${MYSQL_DBNAME} -coord_system_name contig -default_version -rank 3 -sequence_level -coord_system_version Minipig2012 -fasta_file ~/agp/$i/$i.contigs.fa"
  echo $contigsCMD
  eval $contigsCMD

  # step 4: create link between scaffold and contig
  #updateCMD="mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} --password=${MYSQL_PASS} -e \"update coord_system set version=NULL where name='contig';\" sus_scrofa_domesticus_core_85_2012"
  #echo $updateCMD
  #eval $updateCMD
  linkCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/load_agp.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname ${MYSQL_DBNAME} -assembled_name chromosome -component_name contig -agp_file ~/agp/$i/$i.agp"
  echo $linkCMD
  eval $linkCMD
done

toplevelCMD="perl ${ENSEMBL_DIR}/ensembl-pipeline/scripts/set_toplevel.pl -dbhost ${MYSQL_HOST} -dbuser ${MYSQL_USER} -dbpass ${MYSQL_PASS} -dbname ${MYSQL_DBNAME}"
echo $toplevelCMD
eval $toplevelCMD


