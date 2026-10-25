#!/usr/bin/env python3
"""Add Beryllium Adreno 630 or Surya Adreno 618 firmware to an Apple Device Tree.

Examples:
  adt-gpufw.py IN.adt OUT.adt --fw DIR [--zap DIR]
  adt-gpufw.py IN.adt OUT.adt --board surya --fw dtb/surya/firmware/gpu --zap dtb/surya/firmware/gpu

Both boards use a /sweet-gpu node. Beryllium uses a630_gmu.bin and a630_zap.*;
Surya uses the stock a618_gmu.bin and signed a615_zap.*. Both currently use
a630_sqe.fw. The firmware and resulting ADT contain Qualcomm binaries; keep
 them out of Git.
"""
import argparse
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import adt  # noqa: E402


BOARDS = {
    'beryllium': {'gmu': 'a630_gmu.bin', 'sqe': 'a630_sqe.fw', 'zap': 'a630_zap'},
    'surya': {'gmu': 'a618_gmu.bin', 'sqe': 'a630_sqe.fw', 'zap': 'a615_zap'},
}


def read_file(directory, name):
    with open(os.path.join(directory, name), 'rb') as stream:
        return stream.read()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('inp')
    ap.add_argument('out')
    ap.add_argument('--board', choices=sorted(BOARDS), default='beryllium', help='GPU firmware naming set (default: beryllium)')
    ap.add_argument('--fw', required=True, help="directory containing this board's GMU and SQE firmware")
    ap.add_argument('--zap', help="directory containing this board's signed ZAP MDT and bNN segments")
    a = ap.parse_args()
    names = BOARDS[a.board]
    root, _ = adt.parse(adt.load(a.inp))
    root.children = [c for c in root.children if c.name != 'sweet-gpu']
    n = adt.Node()
    n.props.append(('name', 0, b'sweet-gpu\0'))
    n.props.append(('gmu-firmware', 0, read_file(a.fw, names['gmu'])))
    n.props.append(('sqe-firmware', 0, read_file(a.fw, names['sqe'])))
    if a.zap:
        prefix = names['zap']
        n.props.append(('zap-mdt', 0, read_file(a.zap, prefix + '.mdt')))
        pattern = os.path.join(a.zap, prefix + '.b[0-9][0-9]')
        for filename in sorted(glob.glob(pattern)):
            suffix = os.path.basename(filename)[-3:]
            n.props.append(('zap-' + suffix, 0, read_file(a.zap, os.path.basename(filename))))
    root.children.append(n)
    with open(a.out, 'wb') as stream:
        stream.write(adt.serialize(root))
    print('%s: /sweet-gpu with %s' % (a.out, ', '.join('%s (%d)' % (p, len(v)) for p, _, v in n.props[1:])))


if __name__ == '__main__':
    main()
