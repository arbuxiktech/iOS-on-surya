#!/usr/bin/env python3
"""Extract and identify flattened device-tree overlays from Android dtbo.img.

Usage: extract-dtbo.py DTBO.img OUTDIR [--pick N]

The Android DT table header and entries are big-endian. Extracted blobs are
written as rom-N.dtbo. The root model, compatible strings and Qualcomm board
IDs are printed to help identify candidates; they are not automatically
merged with a base DTB.
"""
import argparse
import os
import struct
import sys

DT_TABLE_MAGIC = 0xd7b7ab1e
FDT_MAGIC = 0xd00dfeed
FDT_HEADER_SIZE = 40


def root_properties(blob):
    if len(blob) < FDT_HEADER_SIZE:
        raise ValueError('truncated FDT header')
    (magic, total, off_struct, off_strings, _off_rsv, _version,
     _last_compatible, _boot_cpuid, size_strings, size_struct) = struct.unpack_from('>10I', blob)
    if magic != FDT_MAGIC or total > len(blob) or total < FDT_HEADER_SIZE:
        raise ValueError('invalid FDT header')
    if off_struct + size_struct > total or off_strings + size_strings > total:
        raise ValueError('FDT structure or strings block is out of bounds')

    struct_end = off_struct + size_struct
    strings = blob[off_strings:off_strings + size_strings]
    pos = off_struct
    depth = 0
    props = {}
    while pos + 4 <= struct_end:
        token, = struct.unpack_from('>I', blob, pos)
        pos += 4
        if token == 1:  # FDT_BEGIN_NODE
            end = blob.find(b'\0', pos, struct_end)
            if end < 0:
                raise ValueError('unterminated FDT node name')
            pos = (end + 4) & ~3
            depth += 1
        elif token == 2:  # FDT_END_NODE
            depth -= 1
            if depth == 0:
                break
        elif token == 3:  # FDT_PROP
            if pos + 8 > struct_end:
                raise ValueError('truncated FDT property header')
            length, name_offset = struct.unpack_from('>II', blob, pos)
            pos += 8
            if pos + length > struct_end or name_offset >= len(strings):
                raise ValueError('FDT property is out of bounds')
            name_end = strings.find(b'\0', name_offset)
            if name_end < 0:
                raise ValueError('unterminated FDT property name')
            name = strings[name_offset:name_end].decode('ascii', 'replace')
            value = blob[pos:pos + length]
            pos = (pos + length + 3) & ~3
            if depth == 1:
                props[name] = value
        elif token == 4:  # FDT_NOP
            continue
        elif token == 9:  # FDT_END
            break
        else:
            raise ValueError('unknown FDT structure token 0x%x' % token)
    return props


def string_list(value):
    if not value or value[-1] != 0:
        return ()
    return tuple(part.decode('ascii', 'replace') for part in value[:-1].split(b'\0'))


def cells(value):
    if not value or len(value) % 4:
        return ()
    return tuple(struct.unpack('>%dI' % (len(value) // 4), value))


def format_cells(value):
    values = cells(value)
    return '<' + ' '.join('0x%x' % item for item in values) + '>' if values else '-'


def extract(image_path, out_dir, pick):
    with open(image_path, 'rb') as source:
        image = source.read()
    if len(image) < 32:
        sys.exit('dtbo image is shorter than its table header')
    (magic, total_size, header_size, entry_size, count,
     entries_offset, _page_size, _version) = struct.unpack_from('>8I', image)
    if magic != DT_TABLE_MAGIC:
        sys.exit('not an Android DT table image (bad magic)')
    if total_size > len(image) or total_size < header_size or header_size < 32:
        sys.exit('invalid Android DT table size')
    if entry_size < 32 or entries_offset + count * entry_size > total_size:
        sys.exit('invalid Android DT table entry bounds')
    if pick is not None and not 0 <= pick < count:
        sys.exit('--pick must be an index from 0 through %d' % (count - 1))

    os.makedirs(out_dir, exist_ok=True)
    indices = [pick] if pick is not None else range(count)
    print('%d overlay %s in Android DT table:' % (count, 'entry' if count == 1 else 'entries'))
    for index in indices:
        entry = struct.unpack_from('>8I', image, entries_offset + index * entry_size)
        dt_size, dt_offset, dt_id, dt_rev = entry[:4]
        if dt_offset + dt_size > total_size or dt_size < FDT_HEADER_SIZE:
            sys.exit('entry %d is outside the Android DT table' % index)
        blob = image[dt_offset:dt_offset + dt_size]
        if struct.unpack_from('>I', blob)[0] != FDT_MAGIC:
            sys.exit('entry %d does not start with FDT magic' % index)
        try:
            props = root_properties(blob)
        except ValueError as error:
            sys.exit('entry %d: %s' % (index, error))

        model = next(iter(string_list(props.get('model', b''))), '')
        compatible = ','.join(string_list(props.get('compatible', b'')))
        msm_id = format_cells(props.get('qcom,msm-id', b''))
        board_id = format_cells(props.get('qcom,board-id', b''))
        path = os.path.join(out_dir, 'rom-%d.dtbo' % index)
        with open(path, 'wb') as output:
            output.write(blob)
        print('  rom-%-2d %7d bytes  id 0x%x rev 0x%x  msm-id %-24s board-id %-20s %s [%s]' % (
            index, dt_size, dt_id, dt_rev, msm_id, board_id,
            model or '(no model)', compatible or 'no compatible'))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('image', help='Android dtbo.img')
    parser.add_argument('out', help='directory for extracted overlays')
    parser.add_argument('--pick', type=int, help='extract only overlay N')
    args = parser.parse_args()
    extract(args.image, args.out, args.pick)


if __name__ == '__main__':
    main()
