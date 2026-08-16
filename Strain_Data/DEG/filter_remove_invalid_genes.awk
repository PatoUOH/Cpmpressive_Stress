BEGIN{
  FS = OFS = "\t"
}
NR == 1 {
  sub(/\r$/, "", $0)
  print
  next
}
{
  #normaliza: quita espacios y CR al final de la línea
  sub(/\r$/, "", $0)
  #recorta espacios en la primera columna, por si acaso
  gsub(/^[ \t]+|[ \t]+$/, "", $1)
}
#si la primera columna es 0 o #N/D, descarta la fila
$1 == "0" || $1 == "#N/D" { next }

#imprime el resto
{ print }
