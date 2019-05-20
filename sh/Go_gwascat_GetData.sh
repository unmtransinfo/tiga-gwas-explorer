#!/bin/sh
#############################################################################
### Go_gwascat_GetData.sh - Create CSV files for import to RDB.
### gt_stats.tsv is used by GWAX web app.
### NHGRI-EBI GWAS Catalog: http://www.ebi.ac.uk/gwas/
#############################################################################
### Jeremy Yang
#############################################################################
#
cwd=$(pwd)
#
SRCDATADIR="/home/data/gwascatalog/data"
DATADIR="${cwd}/data"
#
#Source files:
#gwasfile="${SRCDATADIR}/gwas_catalog_v1.0.1-studies_r2017-10-10.tsv"
gwasfile="${SRCDATADIR}/gwas_catalog_v1.0.2-studies_r2018-09-30.tsv"
#
#assnfile="${SRCDATADIR}/gwas_catalog_v1.0.1-associations_e90_r2017-10-10.tsv"
assnfile="${SRCDATADIR}/gwas_catalog_v1.0.2-associations_e94_r2018-09-30.tsv"
###
#Output files:
tsvfile_gwas="${DATADIR}/gwascat_gwas.tsv"
tsvfile_assn="${DATADIR}/gwascat_assn.tsv"
###
#Clean studies:
${cwd}/R/gwascat_gwas.R $gwasfile $tsvfile_gwas
#
###
#Clean, separate OR_or_beta into oddsratio, beta columns:
${cwd}/R/gwascat_assn.R $assnfile $tsvfile_assn
#
#############################################################################
#trait links:
traitfile="${DATADIR}/gwascat_trait.tsv"
#
#SNP to gene links:
snpgenefile="${DATADIR}/gwascat_snp2gene.tsv"
#
#############################################################################
### TRAITS:
####
printf "STUDY_ACCESSION\tMAPPED_TRAIT\tMAPPED_TRAIT_URI\n" >${traitfile}
#
cat $tsvfile_gwas \
	|sed -e '1d' \
	|perl -n perl/gwas2trait.pl \
	>>${traitfile}
#
#############################################################################
### REPORTED GENES:
#
printf "STUDY_ACCESSION\tGSYMB\tSNP\tREPORTED_OR_MAPPED\n" >${snpgenefile}
#
# "REPORTED_GENE(S),SNPS,STUDY_ACCESSION" (14, 22, 37)
###
cat $tsvfile_assn \
	|sed -e '1d' \
	|perl -n perl/assn2snpgene_reported.pl \
	>>${snpgenefile}
#
#############################################################################
### MAPPED GENES:
### Separate mapped into up-/down-stream.
# "m" - mapped within gene
# "mu" - mapped to upstream gene
# "md" - mapped to downstream gene
# "MAPPED_GENE(S),SNPS,STUDY_ACCESSION" (15, 22, 37)
###
cat $tsvfile_assn \
	|sed -e '1d' \
	|perl -n perl/assn2snpgene_mapped.pl \
	>>${snpgenefile}
#
#############################################################################
### PMIDs:
cat $tsvfile_gwas \
	|sed -e '1d' \
	|awk -F '\t' '{print $2}' \
	|sort -nu >$DATADIR/gwascat.pmid
#
${cwd}/python/pubmed_icite.py get \
	--i $DATADIR/gwascat.pmid \
	--o $DATADIR/gwascat_icite.tsv
#
#############################################################################
### Entrez gene IDs: UPSTREAM_GENE_ID, DOWNSTREAM_GENE_ID, SNP_GENE_IDS
cat $tsvfile_assn \
	|sed -e '1d' \
	|awk -F '\t' '{print $16}' \
	|egrep -v '(^$|^NA$)' \
	|sort -nu \
	>$DATADIR/gwascat_upstream.geneid
cat $tsvfile_assn \
	|sed -e '1d' \
	|awk -F '\t' '{print $17}' \
	|egrep -v '(^$|^NA$)' \
	|sort -nu \
	>$DATADIR/gwascat_downstream.geneid
cat $tsvfile_assn \
	|sed -e '1d' \
	|awk -F '\t' '{print $18}' \
	|egrep -v '(^$|^NA$)' \
	|perl -ne 'print join("\n",split(/, */))' \
	|sort -nu \
	>$DATADIR/gwascat_snp.geneid
cat \
	$DATADIR/gwascat_upstream.geneid \
	$DATADIR/gwascat_downstream.geneid \
	$DATADIR/gwascat_snp.geneid \
	|sort -nu \
	>$DATADIR/gwascat.geneid
#
#############################################################################
# Gene-trait statistics:
# gt_stats.tsv generated by this R script:
#
${cwd}/R/gwascat_gt_stats.R \
	$DATADIR/gwascat_gwas.tsv \
	$DATADIR/gwascat_assn.tsv \
	$DATADIR/gwascat_snp2gene.tsv \
	$DATADIR/gwascat_trait.tsv \
	$DATADIR/gwascat_icite.tsv \
	$DATADIR/tcrd_targets.csv \
	$DATADIR/gt_stats.tsv
#
