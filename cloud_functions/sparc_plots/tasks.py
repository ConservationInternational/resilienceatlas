# -*- coding: utf-8 -*-

import os
import sys
import fnmatch
import shutil
import subprocess
import pathlib
import zipfile

from invoke import Collection, task

def read_requirements():
    """Return a list of runtime and list of test requirements"""
    with open('requirements.txt') as f:
        lines = f.readlines()
    lines = [ l for l in [ l.strip() for l in lines] if l ]
    divider = '# test requirements'

    try:
        idx = lines.index(divider)
    except ValueError:
        raise BuildFailure(
            'Expected to find "{}" in requirements.txt'.format(divider))

    not_comments = lambda s,e: [ l for l in lines[s:e] if l[0] != '#']
    return not_comments(0, idx), not_comments(idx+1, None)

@task(help={'clean': 'Clean out dependencies first',
            'pip': 'Path to pip (usually "pip" or "pip3"'})
def install_deps(c, clean=False, pip='pip'):
    '''install dependencies'''
    libraries_folder = os.path.abspath(c.libraries_folder)
    if clean and os.path.exists(libraries_folder):
        shutil.rmtree(libraries_folder)
    if sys.version_info[0] < 3:
        if not os.path.exists(libraries_folder):
            os.makedirs(libraries_folder)
    else:
        os.makedirs(libraries_folder, exist_ok=True)
    runtime, test = read_requirements()

    os.environ['PYTHONPATH'] = libraries_folder
    for req in runtime + test:
        subprocess.check_call([pip, 'install', '--upgrade', '--target', libraries_folder, req])


@task(help={'f': 'Name for package zipfile',
            'tests': 'Package tests with plugin'})
def package(c, f='package.zip', tests=False):
    with zipfile.ZipFile(f, 'w', zipfile.ZIP_DEFLATED) as zf:
        if not tests:
            c.excludes.extend(c.tests)
        _write_to_zip(zf, c.code_folder, c)
        _write_to_zip(zf, c.libraries_folder, c)


def _write_to_zip(zf, d, c):
    for root, dirs, files in os.walk(d):
        for f in _filter_excludes(root, files, c):
            f_path = pathlib.Path(os.path.join(root, f))
            zf.write(f_path, f_path.relative_to(d))
        _filter_excludes(root, dirs, c)


def _filter_excludes(root, items, c):
    excludes = set(c.excludes)
    skips = c.skip_exclude

    exclude = lambda p: any([fnmatch.fnmatch(p, e) for e in excludes])
    if not items:
        return []

    # to prevent descending into dirs, modify the list in place
    for item in list(items):  # copy list or iteration values change
        itempath = os.path.join(os.path.relpath(root), item)
        if exclude(itempath) and item not in skips:
            #debug('Excluding {}'.format(itempath))
            items.remove(item)
    return items


@task(help={'function': 'Name for lambda function',
            'f': 'Name for package zipfile',
            'tests': 'Package tests with plugin'})
def deploy(c, function=None, f='package.zip', tests=False):
    if not function:
        function = c.lambda_function

    package(c, f, tests)

    subprocess.check_call(['aws', 'lambda', 'update-function-code', '--profile', c.aws_profile, '--function-name', function, '--zip-file', 'fileb://' + f])

 
ns = Collection(install_deps, package, deploy)

ns.configure({
    'aws_profile': 'resilienceatlas',
    'lambda_function': 'sparc_plots',
    'code_folder': 'code',
    'libraries_folder': 'libraries',
    'excludes': [
        '.gitignore',
        '*.pyc'],
    # skip certain files inadvertently found by exclude pattern globbing
    'skip_exclude': [],
    'tests': ['test']
})
