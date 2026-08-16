BEGIN {
  FS = OFS = "\t"
}

function trim(x) {
  sub(/^[[:space:]]+/, "", x)
  sub(/[[:space:]]+$/, "", x)
  return x
}

NR == 1 {
  sub(/\r$/, "", $0)
  print "GeneName", "FoldChange", "Pvalue"
  next
}

{
  sub(/\r$/, "", $0)

  # saltar líneas completamente vacías
  if ($0 ~ /^[[:space:]]*$/) next

  # exigir al menos 3 columnas
  if (NF < 3) next

  gene = trim($1)
  fc   = trim($2)
  pval = trim($3)

  # eliminar filas con columnas vacías o inválidas
  if (gene == "" || gene == "0" || gene == "#N/D") next
  if (fc   == "" || fc   == "NA" || fc   == "#N/D") next
  if (pval == "" || pval == "NA" || pval == "#N/D") next

  # opcional: exigir que FC y pvalue sean numéricos
  if (fc   !~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/) next
  if (pval !~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/) next

  # imprimir manteniendo genes repetidos
  print gene, fc, pval
}