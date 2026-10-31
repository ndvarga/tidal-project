#!/usr/bin/env python3
"""Fetch the samples the Tidal version of Mix-Matrix needs.

Downloads every sample folder the songs use (drum machines, VCSL percussion,
and the hyperpop / UK garage / fretless / Dirt-Samples instruments that the
Strudel version loaded from GitHub) into one folder that SuperDirt loads:

    ~/mixmatrix-samples/<sound name>/<NN>_<file>

Folder names match the sound names used in mix-matrix.tidal, and the NN_
prefix keeps the original sample order, so "conga:12" picks the same file as
it did in Strudel.

Usage:   python3 fetch_mixmatrix_samples.py [target folder]
Needs Python 3.8+, no extra packages. If ffmpeg is installed, MP3/OGG files
are converted to WAV (older SuperCollider builds cannot read MP3).
Re-running skips files that are already there.
"""
import concurrent.futures as cf
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request

TARGET = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else '~/mixmatrix-samples')

# Strudel's default sample maps (github.com/felixroos/dough-samples)
DOUGH = 'https://raw.githubusercontent.com/felixroos/dough-samples/main/'
SAMPLE_MAPS = [DOUGH + 'tidal-drum-machines.json', DOUGH + 'vcsl.json']

HYPERPOP = 'https://raw.githubusercontent.com/itsaandy/strudel-samples/main/hyperpop/'
UKG = 'https://raw.githubusercontent.com/itsaandy/strudel-samples/main/ukg/'
FRETLESS = 'https://raw.githubusercontent.com/cleary/samples-flbass/main/'
DIRT = 'https://raw.githubusercontent.com/tidalcycles/Dirt-Samples/master/'

# Sounds the Strudel version mapped by hand from GitHub repos (same files, same order)
EXPLICIT = {
    'hp_kick':   (HYPERPOP, ['kick/cute_c.wav', 'kick/plucky_drive_c.wav', 'kick/metallic_drive_c.wav']),
    'hp_snare':  (HYPERPOP, ['snare/smack.wav', 'snare/spring.wav', 'snare/snap.wav']),
    'hp_hh':     (HYPERPOP, ['hh/tight.wav', 'hh/lazer.wav', 'hh/knife.wav']),
    'hp_vox':    (HYPERPOP, ['vox/hey.wav', 'vox/hah.wav', 'vox/yah.wav', 'vox/hiccup.wav', 'vox/huh.wav']),
    'hp_bass':   (HYPERPOP, ['synth/pluck_bass_fs.wav']),
    'hp_bubble': (HYPERPOP, ['synth/bubble_c.wav']),
    'hp_coin':   (HYPERPOP, ['synth/coin_c.wav']),
    'hp_string': (HYPERPOP, ['synth/string_c.wav']),
    'ug_kick':   (UKG, ['kick/butter.wav', 'kick/punchy.wav', 'kick/deep_follow.wav']),
    'ug_clap':   (UKG, ['clap/garage.wav', 'clap/crunch.wav']),
    'ug_snare':  (UKG, ['snare/rim_garage.wav', 'snare/jungle.wav']),
    'ug_hh':     (UKG, ['hh/subtle.wav', 'hh/ukg.wav', 'hh/tech.wav']),
    'ug_oh':     (UKG, ['oh/short.wav', 'oh/tsunami_tamb.wav']),
    'ug_vox':    (UKG, ['vox/ah.wav', 'vox/baker_haha_dry.wav']),
    'ug_tops':   (UKG, ['tops/vibez_135.wav', 'tops/summer_135.wav']),
    'ug_fx':     (UKG, ['fx/rewind_135.wav', 'fx/siren_liver.wav', 'fx/upsweep_slow.wav', 'fx/tape_spinback.wav']),
    'ug_womp':   (UKG, ['bass/fm_womp_dmin.wav']),
    'ug_wata':   (UKG, ['bass/wata_d.wav']),
    'fl_bass':   (FRETLESS, ['00_c2_finger_long_neck.wav', '07_c3_finger_long_neck.wav']),
    'ds_moog':   (DIRT, ['moog/004_Mighty%20Moog%20G2.wav', 'moog/005_Mighty%20Moog%20G3.wav',
                         'moog/006_Mighty%20Moog%20G4.wav']),
    'ds_gtr':    (DIRT, ['gtr/0001_cleanC.wav']),
    'ds_rave':   (DIRT, ['rave/AREUREADY.wav']),
}

# Every sample folder the songs use that SuperDirt's own Dirt-Samples lacks
NEEDED = [
    "AkaiMPC60_bd",
    "AkaiMPC60_hh",
    "AkaiMPC60_oh",
    "AkaiMPC60_rim",
    "AkaiMPC60_sd",
    "KorgM1_bd",
    "KorgM1_cp",
    "KorgM1_hh",
    "KorgM1_misc",
    "KorgM1_oh",
    "KorgM1_sd",
    "KorgMinipops_bd",
    "KorgMinipops_hh",
    "KorgMinipops_misc",
    "KorgMinipops_oh",
    "KorgMinipops_sd",
    "LinnDrum_bd",
    "LinnDrum_cp",
    "LinnDrum_hh",
    "LinnDrum_lt",
    "LinnDrum_oh",
    "LinnDrum_sd",
    "LinnDrum_tb",
    "LinnLM1_bd",
    "LinnLM1_cp",
    "LinnLM1_hh",
    "LinnLM1_oh",
    "LinnLM1_sd",
    "LinnLM1_sh",
    "LinnLM1_tb",
    "RolandTR505_bd",
    "RolandTR505_cb",
    "RolandTR505_cp",
    "RolandTR505_hh",
    "RolandTR505_oh",
    "RolandTR505_rim",
    "RolandTR505_sd",
    "RolandTR808_bd",
    "RolandTR808_cb",
    "RolandTR808_cp",
    "RolandTR808_hh",
    "RolandTR808_rim",
    "RolandTR808_sd",
    "RolandTR909_bd",
    "RolandTR909_cp",
    "RolandTR909_hh",
    "RolandTR909_ht",
    "RolandTR909_lt",
    "RolandTR909_mt",
    "RolandTR909_oh",
    "RolandTR909_rim",
    "RolandTR909_sd",
    "agogo",
    "anvil",
    "bassdrum1",
    "bassdrum2",
    "belltree",
    "bongo",
    "brakedrum",
    "cabasa",
    "cajon",
    "clap",
    "clash2",
    "conga",
    "cowbell",
    "darbuka",
    "ds_gtr",
    "ds_moog",
    "ds_rave",
    "fingercymbal",
    "fl_bass",
    "flexatone",
    "framedrum",
    "gong",
    "gong2",
    "guiro",
    "hp_bass",
    "hp_bubble",
    "hp_coin",
    "hp_hh",
    "hp_kick",
    "hp_snare",
    "hp_string",
    "hp_vox",
    "marktrees",
    "oceandrum",
    "ratchet",
    "shaker_large",
    "shaker_small",
    "slapstick",
    "sleighbells",
    "slitdrum",
    "snare_rim",
    "sus_cymbal",
    "sus_cymbal2",
    "tambourine",
    "timpani",
    "timpani_roll",
    "triangles",
    "ug_clap",
    "ug_fx",
    "ug_hh",
    "ug_kick",
    "ug_oh",
    "ug_snare",
    "ug_tops",
    "ug_vox",
    "ug_wata",
    "ug_womp",
    "vibraslap",
    "wineglass_slow",
    "woodblock"
]

NOTE_INDEX = {'c': 0, 'd': 2, 'e': 4, 'f': 5, 'g': 7, 'a': 9, 'b': 11}


def note_number(name):
    """'Ds3', 'f#2', 'bb1' -> a number for ordering pitched sample maps."""
    m = re.match(r'([a-gA-G])([#sbf]*)(-?\d*)$', name)
    if not m:
        return 0
    acc = sum(1 if ch in '#s' else -1 for ch in m.group(2))
    return NOTE_INDEX[m.group(1).lower()] + acc + 12 * int(m.group(3) or 3)


def urls_from_map(sample_map):
    """Strudel sample map -> {name: [url, ...]} (lists keep their order;
    pitched maps are ordered from low to high)."""
    base = sample_map.get('_base', '')
    out = {}
    for name, val in sample_map.items():
        if name.startswith('_'):
            continue
        if isinstance(val, str):
            paths = [val]
        elif isinstance(val, list):
            paths = val
        elif isinstance(val, dict):
            paths = [val[k] for k in sorted(val, key=note_number)]
            paths = [p if isinstance(p, str) else p[0] for p in paths]
        else:
            continue
        out[name] = [p if p.startswith('http') else base + p for p in paths]
    return out


def fetch(url):
    safe = urllib.parse.quote(url, safe=':/%?=&')
    req = urllib.request.Request(safe, headers={'User-Agent': 'mixmatrix-fetch'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def save(job):
    folder, index, url, ffmpeg = job
    base = urllib.parse.unquote(url.rsplit('/', 1)[-1])
    stem, ext = os.path.splitext(base)
    original = os.path.join(folder, '%02d_%s%s' % (index, stem, ext))
    wav = os.path.join(folder, '%02d_%s.wav' % (index, stem))
    if os.path.exists(original) or os.path.exists(wav):
        return 'skip'
    with open(original, 'wb') as fh:
        fh.write(fetch(url))
    if ffmpeg and ext.lower() in ('.mp3', '.ogg'):
        done = subprocess.run([ffmpeg, '-loglevel', 'quiet', '-y', '-i', original, wav],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if done.returncode == 0:
            os.remove(original)
        else:
            if os.path.exists(wav):
                os.remove(wav)
            return 'kept'      # conversion failed: keep the original file
    return 'new'


def main():
    ffmpeg = shutil.which('ffmpeg')
    available = {}
    for url in SAMPLE_MAPS:
        print('reading', url)
        available.update(urls_from_map(json.loads(fetch(url))))
    for name, (base, paths) in EXPLICIT.items():
        available[name] = [base + p for p in paths]

    jobs, missing = [], []
    for name in NEEDED:
        if name not in available:
            missing.append(name)
            continue
        folder = os.path.join(TARGET, name)
        os.makedirs(folder, exist_ok=True)
        jobs += [(folder, i, u, ffmpeg) for i, u in enumerate(available[name])]

    print('downloading %d files into %s ...' % (len(jobs), TARGET))
    counts, failed = {'new': 0, 'skip': 0, 'kept': 0}, []
    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(save, j): j for j in jobs}
        for fut in cf.as_completed(futures):
            try:
                counts[fut.result()] += 1
            except Exception as err:  # keep going; report at the end
                failed.append((futures[fut][2], err))
    print('done: %d downloaded, %d already present, %d failed' % (counts['new'] + counts['kept'], counts['skip'], len(failed)))
    if counts['kept']:
        print('note: %d MP3/OGG files could not be converted and were kept as they are' % counts['kept'])
    for url, err in failed[:20]:
        print('  failed:', url, '-', err)
    if missing:
        print('not found in any sample map (these sounds will be silent):', ', '.join(missing))
    if not ffmpeg:
        print('note: ffmpeg not found, so any MP3 files were kept as MP3; if SuperDirt cannot load '
              'them, install ffmpeg and run this script again.')


if __name__ == '__main__':
    main()
