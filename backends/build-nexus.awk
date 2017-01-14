#!/bin/awk -f 

BEGIN {

    FS="\t"

    printf("define(__NAME__, %s)\n", name)
    printf("define(OUTDIR, %s)\n", dir)

}

$1 == "EMIT" { m[$2] = $3 }
$1 == "FUNC" { printf("define(FUNCTION_%s, %s)\n", $2, $3) }

END {
    manifold=""
    manifold_doc=""
    for(k in m){
       printf("define(LANG_%s, %s)", k, m[k])
       manifold = sprintf("%s__MANIFOLD__(%s)\n", manifold, k)
       manifold_doc = sprintf("%s    __MANIFOLD_DOC__(%s)\n", manifold_doc, k)
    }
    printf("define(__MANIFOLD_WRAPPERS__, %s)", manifold)
    printf("define(__MANIFOLD_DOCUMENTATION__, %s)", manifold_doc)
}
