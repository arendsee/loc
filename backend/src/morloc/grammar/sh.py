from grammar.base_grammar import Grammar

class ShGrammar(Grammar):
    def __init__(
        self,
        source,
        manifolds,
        outdir,
        home
    ):
        self.source    = source
        self.manifolds = manifolds
        self.outdir    = outdir
        self.home      = home
        self.TRUE      = "true"
        self.FALSE     = "false"
        self.lang      = "sh"
        self.INDENT = 4
        self.SEP    = ' '
        self.BIND   = ' '
        self.AND    = ' && '
        self.LIST   = ' {value} '
        self.POOL   = '''\
#!/usr/bin/env bash

outdir={outdir}

{type_map}

{source}

{manifolds}

{nat2uni}

{uni2nat}

manifold_exists() {{
    type $1 | grep -q function
}}
if manifold_exists $1
then
    fun=show_$1
    shift
    $fun $@
else
    exit 1
fi'''
        self.TYPE_MAP = '''# typemap no longer needed'''
        self.TYPE_MAP_PAIR    = "    [{key}]='{type}'"
        self.TYPE_ACCESS      = '${{typemap[{mid}]}}'
        self.CAST_NAT2UNI     = 'show_{key} {key}'
        self.CAST_UNI2NAT     = 'read_{key} {key}'
        self.NATIVE_MANIFOLD = '''\
{mid} () {{
# {comment}
{blk}
}}
'''
        self.NATIVE_MANIFOLD_BLK = '''\
{hook0}
{cache}
{hook1}\
'''
        self.SIMPLE_MANIFOLD = '''
{mid} () {{
# {comment}
{blk}
}}
'''
        self.SIMPLE_MANIFOLD_BLK = '''\
{function} {arguments}\
'''
        self.UID_WRAPPER  = '''\
{mid}_uid=0
wrap_{mid} () {{
{blk}
}}
'''
        self.UID_WRAPPER_BLK  = '''\
{mid}_uid=$(( {mid}_uid + 1 ))
{mid} $@ ${mid}_uid\
'''
        self.UID          = '${nth}'
        self.MARG_UID     = '{marg} {uid}'
        self.WRAPPER_NAME = 'wrap_{mid}'
        self.FOREIGN_MANIFOLD = '''\
{mid} () {{
# {comment}
{blk}
}}
'''
        self.FOREIGN_MANIFOLD_BLK = '''\
{comment}\
read_{mid} <($outdir/call.{foreign_lang} {mid}{arg_rep})\
'''
        self.CACHE = '''\
if {cache}_chk {mid}{uid}
then
{if_blk}
else
{else_blk}
fi
'''
        self.CACHE_IF = '''\
{hook8}
{cache}_get {mid}{uid}
{hook9}
'''
        self.CACHE_ELSE = '''\
{hook2}
{validate}
{hook3}
( cat "$outdir/{mid}_tmp" ; rm "$outdir/{mid}_tmp" )\
'''
        self.DATCACHE_ARGS = ""
        self.DO_VALIDATE = '''\
if [[ {checks} ]]
then
{if_blk}
else
{else_blk}
fi
'''
        self.RUN_BLK = '''\
{hook4}
{function} {arguments} > "$outdir/{mid}_tmp"
{cache_put}
{hook5}\
'''
        self.RUN_BLK_VOID = '''\
{hook4}
{function} {arguments} > /dev/null
> "$outdir/{mid}_tmp"
{cache_put}
{hook5}\
'''
        self.FAIL_BLK = '''\
{hook6}
{fail}> "$outdir/{mid}_tmp"
{cache_put}
{hook7}\
'''
        self.FAIL_BLK_VOID = '''\
{hook6}
{fail} > /dev/null
echo "{msg}" >&2
> "$outdir/{mid}_tmp"
{cache_put}
{hook7}\
'''
        self.FAIL = '''{fail} {marg_uid} '''
        self.DEFAULT_FAIL = ""
        self.NO_VALIDATE = '''\
{hook4}
{function} {arguments}{wrapper} > "$outdir/{mid}_tmp"
{cache_put}
{hook5}'''
        self.CACHE_PUT = '''\
{cache}_put {mid} "$outdir/{mid}_tmp"{other_args}
'''
        self.MARG          = '${i}'
        self.ARGUMENTS     = '{fargs} {inputs}'
        self.MANIFOLD_CALL = '{operator}({hmid} {marg_uid})'
        self.CHECK_CALL    = '$({hmid} {marg_uid}) == "true"'
        self.HOOK          = '''\
# {comment}
{hmid} {marg_uid} 1>&2\
'''

    def make_simple_manifold_blk(self, m):
        return self.SIMPLE_MANIFOLD_BLK.format(
            function  = m.func,
            arguments = self.make_arguments(m)
        )

    def make_input_manifold(self, m, pos, val, typ):
        if(typ in ("Int", "Num", "String", "File", "Bool")):
            op = '$'
        else:
            op = '<'
        return self.MANIFOLD_CALL.format(
            hmid=val,
            operator=op,
            marg_uid = self.make_marg_uid(m)
        )

    def make_do_validate_if(self, m):
        if m.type == "Void":
            template = self.RUN_BLK_VOID
        else:
            template = self.RUN_BLK

        return template.format(
            mid       = m.mid,
            hook4     = self.make_hook(m, 4),
            hook5     = self.make_hook(m, 5),
            function  = m.func,
            arguments = self.make_arguments(m),
            cache_put = self.make_cache_put(m)
        )

    def make_foreign_manifold_blk(self, m):
        arg_rep = ""
        comment = []
        for i in range(int(m.narg)):
            comment.append('# $%s : arg' % str(i+1)) 
            i_str = str(i+1)
            arg_rep += ' "$%s"' % i_str
        if m.narg:
            i = str(int(m.narg)+1)
            comment.append('# $%s : uid' % i) 
            arg_rep += ' $%s' % i
        comment = '\n'.join(comment)
        if comment:
            comment += '\n'

        return self.FOREIGN_MANIFOLD_BLK.format(
            comment=comment,
            foreign_lang=m.lang,
            mid=m.mid,
            arg_rep=arg_rep
        )