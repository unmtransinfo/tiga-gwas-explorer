#!/bin/bash
###
# See https://github.com/IUIDSL/(iu_idsl_util,iu_idsl_jena)
###
cwd=$(pwd)
#
DATADIR=${cwd}/data
#
EFO_DIR="$HOME/../data/EFO/data"
#
OWLFILE="$EFO_DIR/efo.owl"
EFO_URL="https://github.com/EBISPOT/efo/releases/download/current/efo.owl"
wget -q -O $OWLFILE $EFO_URL
#
LIBDIR="$HOME/../app/lib"
#
###
java -jar $LIBDIR/iu_idsl_jena-0.0.1-SNAPSHOT-jar-with-dependencies.jar \
	-ontfile ${OWLFILE} -vv -ont2tsv -o ${DATADIR}/efo.tsv
#
###
# CYJS: Not needed now but maybe later?
java -jar $LIBDIR/iu_idsl_jena-0.0.1-SNAPSHOT-jar-with-dependencies.jar \
	-ontfile ${OWLFILE} -vv -ont2cyjs -o ${DATADIR}/efo.cyjs
###
# Edgelist and nodelist
java -jar $LIBDIR/iu_idsl_jena-0.0.1-SNAPSHOT-jar-with-dependencies.jar \
	-ontfile ${OWLFILE} -vv -ont2edgelist -o ${DATADIR}/efo_edgelist.tsv
java -jar $LIBDIR/iu_idsl_jena-0.0.1-SNAPSHOT-jar-with-dependencies.jar \
	-ontfile ${OWLFILE} -vv -ont2nodelist -o ${DATADIR}/efo_nodelist.tsv
#
###
#
cat $DATADIR/gwascat_trait.tsv \
	|sed -e '1d' |awk -F '\t' '{print $4}' |sort -u \
	>$DATADIR/gwascatalog.efoid
###
${cwd}/python/nx_analysis.py cluster --min_groupsize 2 --max_level 10 \
	--i_edge $DATADIR/efo_edgelist.tsv \
	--i_node_attr $DATADIR/efo_nodelist.tsv \
	--i_node_set $DATADIR/gwascatalog.efoid \
	--setname gwc --graphname "EFO" \
	--o $DATADIR/efo_groups.tsv
#
###
# To do:
#   * Groups file usable by TIGA app for marker color and selection.
#   * Associate child nodes with selected ancestor nodes, defining groups.
###
