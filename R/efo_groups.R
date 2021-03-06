#!/usr/bin/env Rscript
###
# Higher level groupings could provide UI visual channel for trait classification.
# General groupings can include child trait-gene associations as needed for expected behavior.
# https://igraph.org/r/
###
library(readr)
library(data.table, quietly=T)
library(igraph, quietly=T)
#
message(paste(commandArgs(), collapse=" "))
args <- commandArgs(trailingOnly=TRUE)
condition <- ifelse((length(args)>1), args[1], "mood disorder")
efofile <- ifelse((length(args)>1), args[2], "data/efo.tsv")
groupfile <- ifelse((length(args)>0), args[3], "data/efo_groups.tsv")
ofile <- ifelse((length(args)>2), args[4], "data/efo_subgraph.graphml")

message(sprintf("Condition: \"%s\"", condition))
message(sprintf("EFO file: \"%s\"", efofile))
message(sprintf("EFO group file: \"%s\"", groupfile))
message(sprintf("Output file: \"%s\"", ofile))

###
# File from nx_analysis.py.
efo_groups <- read_delim(groupfile, "\t", col_types=cols(.default=col_character(), level=col_integer(), N_sub=col_integer(), N_sub_gwc=col_integer(), in_gwc=col_logical()))
setDT(efo_groups)
setorder(efo_groups, level, -N_sub)
#
###
# Here we consider parentage. For a given query trait, all child traits should be
# considered for associated genes. But which query traits are allowed? How high level?
# Need statistics mapping all EFO to GWAS Catalog with parentage considered.
#
efo <- read_delim(efofile, "\t", col_types=cols(.default=col_character()))
setDT(efo)
efo_node <- efo[node_or_edge == "node", .(id, uri, label, comment)]
efo_node[['ontology']] <- sub("_.*$", "", efo_node$id)
efo_counts <- efo_node[, .N, by="ontology"][order(-N)]
for (i in 1:min(10, nrow(efo_counts))) {
  message(sprintf("%2d. %12s: %4d / %4d (%4.1f%%)", i, efo_counts$ontology[i], efo_counts$N[i], sum(efo_counts$N), 100*efo_counts$N[i]/sum(efo_counts$N)))
}
message(sprintf("%2d-%2d. %9s: %4d / %4d (%4.1f%%)", i+1, nrow(efo_counts), "OTHER", sum(efo_counts$N[i+1:nrow(efo_counts)], na.rm=T), sum(efo_counts$N), 
          100*sum(efo_counts$N[i+1:nrow(efo_counts)], na.rm=T)/sum(efo_counts$N)))
#
efo <- efo[node_or_edge == "edge", .(source, target, label)]
#igraph better with integer vertex IDs?
efo_node[['vId']] <- 1:nrow(efo_node)
efo <- merge(efo, efo_node[, .(uri, sourceId=vId)], by.x="source", by.y="uri", all.x=T, all.y=F)
efo <- merge(efo, efo_node[, .(uri, targetId=vId)], by.x="target", by.y="uri", all.x=T, all.y=F)
efoGraph <- igraph::graph_from_edgelist(as.matrix(efo[(!is.na(sourceId) & !is.na(targetId)), .(sourceId, targetId)]), directed=T)
message(sprintf("Graph (%sDIRECTED): vertices: %d; edges: %d", ifelse(is_directed(efoGraph), "", "NOT_"), vcount(efoGraph), ecount(efoGraph)))
efoGraph <- set_vertex_attr(efoGraph, "name", V(efoGraph), efo_node$id)
efoGraph <- set_vertex_attr(efoGraph, "description", V(efoGraph), efo_node$label)
efoGraph <- set_vertex_attr(efoGraph, "uri", V(efoGraph), efo_node$uri)
efoGraph <- set_vertex_attr(efoGraph, "efoId", V(efoGraph), efo_node$id)
efoGraph <- set_vertex_attr(efoGraph, "ontology", V(efoGraph), efo_node$ontology)
ontocolor <- function(ont) {
  ifelse(ont=="EFO", "#CCCCFF",
  ifelse(ont=="Orphanet", "green",
  ifelse(ont=="MONDO", "orange",
  ifelse(ont=="CHEBI", "pink",
  ifelse(ont=="NCBITaxon", "yellow",
  ifelse(ont=="HP", "cyan",
  ifelse(ont=="UBERON", "aqua",
         "#CCCCCC")))))))
}
efoGraph <- set_vertex_attr(efoGraph, "color", V(efoGraph), ontocolor(efo_node$ontology))

# Plot subgraph. BFS finds all subclasses.
#
efoId <- efo_node[label == condition]$id
message(sprintf("Query condition: \"%s\" (%s)", condition, efoId))
bfs_this <- igraph::bfs(efoGraph, V(efoGraph)[efo_node[label == condition]$vId], neimode="out", unreachable=F)
subg <- induced_subgraph(efoGraph, bfs_this$order[1:sum(!is.na(bfs_this$order))])
message(sprintf("Graph (%sDIRECTED): vertices: %d; edges: %d", ifelse(is_directed(subg), "", "NOT_"), vcount(subg), ecount(subg)))
tkplot(subg, canvas.width=800, canvas.height=600, layout=layout_as_tree, vertex.label=sprintf("%s\n%s", V(subg)$efoId, V(subg)$description), 
       vertex.frame.color="#6666AA", vertex.size=30, edge.color="#6666AA", edge.width=2, edge.arrow.size=1,
       edge.label="has_subclass")

# CYJS not supported. (Can do igraph_utils.py graph2cyjs)
subg <- set_vertex_attr(subg, "name", V(subg), sprintf("%s: %s", V(subg)$efoId, V(subg)$description))
write_graph(subg, ofile, format="graphml")
