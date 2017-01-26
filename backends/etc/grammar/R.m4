m4_changequote(`<[', `]>')

m4_define(<[R_ARG_LIST]>, <[m4_ifelse($1, <[1]>, <[x$1]>, <[R_ARG_LIST(m4_decr($1))<[,]> x$1]>)]>)m4_dnl
m4_define(<[ARG_LIST]>, <[m4_ifelse($1, <[0]>, <[]>, <[R_ARG_LIST($1), uid]>)]>)m4_dnl
m4_dnl
m4_define(<[UID_ARG]>, <[m4_ifelse(NARG_$1, <[0]>, <[]>, <[, uid=uid]>)]>)

m4_define(<[MAKE_UID]>, 
$1_uid <- 0
wrap_$1 <- function ( <[ARG_LIST(NARG_$1)]> ) {
    $1_uid <<- $1_uid + 1
    uid <- $1_uid
    $1 ( <[ARG_LIST(NARG_$1)]>)
}
)

m4_define(<[UID_WRAP]>, wrap_$1)

m4_define(<[NTH_ARG]>, x$1)

m4_define(<[PROLOGUE]>,
    <[#!/usr/bin/Rscript --vanilla]>
    <[library(readr)]>
)

m4_define(<[NATIVE_MANIFOLD]>,
    $1 <- function(<[ARG_LIST(NARG_$1)]>){
        HOOK0_$1
        CACHE_$1
        HOOK1_$1
        RETURN
    }
)

m4_define(<[UNIVERSAL_MANIFOLD]>,
    $1 <- function(<[ARG_LIST(NARG_$1)]>){
        HOOK0_$1
        CACHE_$1
        HOOK1_$1
        RETURN
    }
)

m4_define(<[FOREIGN_MANIFOLD]>,
    $2 <- function(<[ARG_LIST(NARG_$2)]>){
        d <- system("./call.$1 $2", intern = TRUE)
        READ(TYPE_$2)
        d <- read_tsv(d)
        if(ncol(d) == 1){
            d <- d[[1]]
        }
        d
    }
)

m4_define(<[READ]>, )

m4_define(<[RETURN]>, <[b]>)


m4_define(<[DO_CACHE]>,
    if(BASECACHE_$1<[<[_chk]>]>("$1"<[UID_ARG($1)]>)){
        HOOK8_$1
        b = BASECACHE_$1<[<[_get]>]>("$1"<[UID_ARG($1)]>)
        HOOK9_$1
    } else {
        HOOK2_$1
        VALIDATE_$1
        HOOK3_$1
    }
)

m4_define(<[NO_CACHE]>,
    HOOK2_$1
    VALIDATE_$1
    HOOK3_$1
)


m4_define(<[DO_VALIDATE]>,
    if(CHECK_$1){
        CORE($1)
    } else {
        HOOK6_$1
        b <- FAIL_$1 <[()]>
        CACHE_PUT_$1
        HOOK7_$1
    }
)

m4_define(<[NO_VALIDATE]>, CORE($1))

m4_define(<[CORE]>,
    HOOK4_$1
    b <- FUNC_$1 ( INPUT_$1 ARG_INP_$1 ARG_$1 )
    CACHE_PUT_$1
    HOOK5_$1
)

m4_define(<[DO_CACHE_PUT]>, BASECACHE_$1 ("$1", b <[UID_ARG($1)]>))

m4_define(<[NO_CACHE_PUT]>, )

m4_define(<[CALL]>, $1 (<[ARG_LIST(NARG_$2)]>))

m4_define(<[HOOK]>, $1 (<[ARG_LIST(NARG_$2)]>))

m4_define(<[CHECK]>, $1 (<[ARG_LIST(NARG_$2)]>))

m4_define(<[NOTHING]>, NULL)

m4_define(<[SIMPLE_FAIL]>, null)

m4_define(<[NO_PUT]>, )

m4_define(<[DO_PUT]>, BASECACHE_$1<[<[_put]>]>("$1", b <[UID_ARG($1)]>))

m4_define(<[EPILOGUE]>,

args <- commandArgs(TRUE)
m <- args[1]

if(exists(m)){
  f = get(m)
  d <- f()
  if(is.data.frame(d)){
      write_tsv(d, path="/dev/stdout")
  } else {
      write_lines(d, path="/dev/stdout")
  }
} else {
  quit(status=1)
}

)
