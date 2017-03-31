#!/usr/bin/env python3

import argparse
import sys
import os
import subprocess
import shutil

import lil
import nexus
from util import err

from grammar.R import RGrammar
from grammar.sh import ShGrammar
from grammar.py import PyGrammar
             
from mogrifier.R import RMogrifier
from mogrifier.sh import ShMogrifier
from mogrifier.py import PyMogrifier

__version__ = '0.0.0'
__prog__ = 'morloc'

def parser():

    if len(sys.argv) > 1:
        argv = sys.argv[1:]
    else:
        argv = ['-h']

    parser = argparse.ArgumentParser(
        description="Compile a Morloc program",
        usage="morloc [options] MORLOC_SCRIPT"
    )
    parser.add_argument(
        '-o', '--nexus-name',
        default="manifold-nexus.py",
        help="Set the name of the manifold nexus"
    )
    parser.add_argument(
        '-v', '--version',
        help='Display version',
        action='version',
        version='%(prog)s {}'.format(__version__)
    )
    parser.add_argument(
        '-r', '--run',
        help='Compile and call CMD in one step, delete temporary files'
    )
    parser.add_argument(
        'f',
        help="Morloc source file"
    )
    parser.add_argument(
        '-t', '--typecheck',
        help="Typecheck the Morloc script (do not build)",
        action='store_true',
        default=False
    )
    parser.add_argument(
        '-l', '--lil-only',
        help="Only run frontend, print Morloc Intermediate Language",
        action='store_true',
        default=False
    )
    parser.add_argument(
        '-m', '--print-manifolds',
        help="Print summaries of all manifolds",
        action='store_true',
        default=False
    )
    parser.add_argument(
        '-x', '--execution-path',
        help="Folder for caches and scripts"
    )
    parser.add_argument(
        '-k', '--clobber',
        help="Overwrite execution path directory",
        action='store_true',
        default=False
    )
    parser.add_argument(
        '--valgrind',
        help="Compile with valgrind",
        action='store_true',
        default=False
    )
    parser.add_argument(
        '--memtest',
        help="Compile with valgrind and --leak-check=full",
        action='store_true',
        default=False
    )
    parser.add_argument(
        '--token-dump',
        help="Print the lexer tokens",
        action='store_true',
        default=False
    )
    parser.add_argument(
        '--table-dump',
        help="Dump the parser symbol table",
        action='store_true',
        default=False
    )
    args = parser.parse_args(argv)
    return(args)


def get_outdir(home, exe_path=None):
    morloc_tmp = "%s/tmp" % home
    try:
        os.mkdir(morloc_tmp)
    except FileExistsError:
        pass
    outdir = None
    if exe_path:
        outdir=os.path.expanduser(exe_path)
        try:
            os.mkdir(outdir)
        except PermissionError:
            err("PermissionError: cannot mkdir '%s'" % outdir)
        except FileNotFoundError:
            err("Cannot create directory '%s'" % outdir)
        except FileExistsError:
            if not args.clobber:
                err("Directory '%s' already exists" % outdir)
    else:
        for i in range(500):
            try:
                outdir=os.path.join(morloc_tmp, "morloc_%s" % i)
                os.mkdir(outdir)
                break
            except FileExistsError:
                pass
        else:
            err("Too many temporary directories (see ~/.morloc/tmp)")
    return os.path.abspath(outdir)

def build_project(raw_lil, outdir, home):

    exports   = lil.get_exports(raw_lil)
    source    = lil.get_src(raw_lil)
    manifolds = lil.get_manifolds(raw_lil)
    languages = set([l.lang for m,l in manifolds.items()])

    # This allows simple programs to be run without an explicit
    # export clause. "m0" will be the first manifold that appears
    # in the script.
    if not exports and manifolds:
        exports["m0"] = "main"

    manifold_nexus = nexus.build_manifold_nexus(
        languages = languages,
        exports   = exports,
        manifolds = manifolds,
        outdir    = outdir,
        home      = home,
        version   = __version__,
        prog      = __prog__
    )

    for lang in languages:
        try:
            src = source[lang]
        except KeyError:
            src = ""

        if lang == "sh":
            grm = ShGrammar(src, manifolds, outdir, home)
            mog = ShMogrifier(manifolds)
        elif lang == "R":
            grm = RGrammar(src, manifolds, outdir, home)
            mog = RMogrifier(manifolds)
        elif lang == "py":
            grm = PyGrammar(src, manifolds, outdir, home)
            mog = PyMogrifier(manifolds)
        else:
            err("'%s' is not a supported language" % lang)

        pool = grm.make(
            uni2nat=mog.build_uni2nat(),
            nat2uni=mog.build_nat2uni()
        )

        pool_filename = os.path.join(outdir, "call.%s" % lang)
        with open(pool_filename, 'w') as f:
            print(pool, file=f)
            os.chmod(pool_filename, 0o755)

    if any([m.cache for m in manifolds.values()]):
        try:
            os.mkdir(os.path.join(outdir, "cache"))
        except FileExistsError:
            # Only make the cache if it doesn't already exist
            pass

    with open(args.nexus_name, 'w') as f:
        print(manifold_nexus, file=f, end="")

    os.chmod(args.nexus_name, 0o755)

def get_lil(args):
    flags = []
    if args.typecheck:
        flags.append('-c')
    if args.token_dump:
        flags.append('-t')
    if args.table_dump:
        flags.append('-d')

    compilant = lil.compile_morloc(
        args.f,
        flags    = flags,
        valgrind = args.valgrind,
        memtest  = args.memtest
    )

    return (compilant.stdout, compilant.stderr, compilant.returncode)


if __name__ == '__main__':

    args = parser()

    raw_lil, err_lil, exitcode = get_lil(args)

    if err_lil:
        print(err_lil, file=sys.stderr, end="")
        if args.typecheck:
            sys.exit(1)

    if exitcode != 0:
        err("Failed to compile Morloc", code=exitcode)

    if args.lil_only:
        for line in raw_lil:
            print(line, end="")
        sys.exit(0)

    morloc_home = os.path.expanduser("~/.morloc")

    outdir = get_outdir(morloc_home, args.execution_path)

    build_project(raw_lil=raw_lil, outdir=outdir, home=morloc_home)

    if args.print_manifolds:
        for k,m in manifolds.items():
            m.print()
        sys.exit(0)

    if args.run:
        result = subprocess.run(
            ["./manifold-nexus.py", args.run],
            stderr=subprocess.PIPE,
            stdout=subprocess.PIPE,
            encoding='utf-8'
        )
        print(result.stdout, end="")
        print(result.stderr, end="")
        shutil.rmtree(outdir)
        os.remove("manifold-nexus.py")
        sys.exit(result.returncode)