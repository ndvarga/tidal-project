// =====================================================================
//  MIX-MATRIX for TidalCycles -- SuperCollider / SuperDirt side
// =====================================================================
//  Block 1 boots SuperDirt with 8 orbits, loads the Mix-Matrix samples
//  (downloaded by fetch_mixmatrix_samples.py) and adds the mm_* synths
//  that replace Strudel's oscillators and General-MIDI soundfonts.
//  Block 2 forwards a MIDI controller's knobs to Tidal.
//
//  Already start SuperDirt your own way? Then evaluate block 1 only up to
//  and including the ~mmSynths definition (skip the s.reboot part), and
//  after SuperDirt is running evaluate:
//      ~mmSynths.value;
//      ~dirt.loadSoundFiles(~mmSampleDir +/+ "*");
//  The mix needs at least 7 orbits (one per track).
// =====================================================================


// ---------------------------------------------------------------------
//  1. SuperDirt + samples + mm_* synths
// ---------------------------------------------------------------------
(
~mmSampleDir = "~/mixmatrix-samples".standardizePath;

// All mm_* synths share one set of controls (sent from Tidal):
//   matt mdec mlev mrel   envelope: attack, decay, sustain level, release
//   mhold                 note length in seconds (Tidal fills this in)
//   mpenv mpdec           pitch envelope: semitones, decay time
//   mvib mvibd            vibrato rate (Hz) and depth (semitones)
//   mfmi mfmh             FM index and harmonicity
//   mctf mres mfenv mfdec internal resonant filter with its own envelope
//                         (used for the acid bass; mctf 0 = off)
//   mtone                 0..1 brightness / character of each instrument
~mmSynths = {
	var numChannels = ~dirt.numChannels;
	var make = { |name, graph|
		SynthDef(name, { |out, pan = 0.5, freq = 440, sustain = 1, mhold = 0.5,
			matt = 0.005, mdec = 0.1, mlev = 1, mrel = 0.1,
			mpenv = 0, mpdec = 0.05, mvib = 0, mvibd = 0,
			mfmi = 0, mfmh = 1, mctf = 0, mres = 0.1, mfenv = 0, mfdec = 0.2, mtone = 0.5|
			var env, f, sig, cut;
			env = EnvGen.ar(Env([0, 1, mlev, mlev, 0],
				[matt, mdec, (mhold - matt - mdec).max(0), mrel], [0, -4, 0, -4]), doneAction: 2);
			f = freq * (2 ** ((mpenv * EnvGen.ar(Env.perc(0.0005, mpdec, 1, -4))) / 12));
			f = f * (2 ** ((SinOsc.kr(mvib) * mvibd) / 12));
			f = f + (SinOsc.ar(f * mfmh) * mfmi * f * mfmh);
			sig = graph.value(f, mtone, freq);
			cut = (mctf * (2 ** (mfenv * EnvGen.ar(Env.perc(0.002, mfdec, 1, -4))))).clip(30, 18000);
			sig = (sig * (mctf <= 0)) + (RLPF.ar(sig, cut, (1 - mres).clip(0.05, 1)) * (mctf > 0));
			OffsetOut.ar(out, DirtPan.ar(sig, numChannels, pan, env));
		}).add;
	};

	// --- plain oscillators (Strudel's sine/triangle/sawtooth/square/...)
	make.(\mm_sine,     { |f| SinOsc.ar(f) * 0.6 });
	make.(\mm_tri,      { |f| LFTri.ar(f) * 0.6 });
	make.(\mm_saw,      { |f| Saw.ar(f) * 0.45 });
	make.(\mm_square,   { |f| Pulse.ar(f, 0.5) * 0.4 });
	make.(\mm_pulse,    { |f, t| Pulse.ar(f, t.linlin(0, 1, 0.08, 0.5)) * 0.4 });
	make.(\mm_supersaw, { |f| Mix(Saw.ar(f * [0.991, 0.996, 1, 1.004, 1.009])) * 0.16 });
	make.(\mm_white,    { WhiteNoise.ar(0.5) });
	make.(\mm_pink,     { PinkNoise.ar(0.7) });

	// --- instruments standing in for the General-MIDI soundfonts
	make.(\mm_epiano, { |f, t, fr|   // FM tine electric piano
		var amp = EnvGen.ar(Env.perc(0.002, 1.2 + (2 * (1 - t)), 1, -5));
		var tine = SinOsc.ar(fr * 14, 0, fr * (0.5 + (2 * t)) * EnvGen.ar(Env.perc(0.001, 0.25)));
		((SinOsc.ar(f + tine) * 0.5) + (SinOsc.ar(f * 2) * 0.06)) * amp
	});
	make.(\mm_organ, { |f, t|        // drawbar organ
		Mix(SinOsc.ar(f * [0.5, 1, 2, 3, 4, 6], 0, [0.35, 0.5, 0.3, 0.15 * t, 0.12 * t, 0.08 * t])) * 0.45
	});
	make.(\mm_pluck, { |f, t, fr|    // plucked string (guitars, harp, pizzicato, dulcimer)
		var p = Pluck.ar(WhiteNoise.ar(0.7), Impulse.ar(0), 0.06, fr.reciprocal,
			1 + (t * 4), t.linlin(0, 1, 0.6, 0.15));
		LPF.ar(p, (fr * (3 + (t * 12))).min(16000)) * 0.9
	});
	make.(\mm_mallet, { |f, t|       // vibraphone, marimba, kalimba
		var ratios = [1, 3.93, 9.24];
		var amps = [1, 0.35 * t, 0.12 * t];
		var decays = [1.4 + t, 0.45, 0.15];
		Mix(SinOsc.ar(f * ratios, 0, amps) * decays.collect { |d| EnvGen.ar(Env.perc(0.002, d, 1, -4)) }) * 0.5
	});
	make.(\mm_bell, { |f, t|         // glockenspiel, celesta, music box, crystal
		var mod = SinOsc.ar(f * 3.5, 0, f * (1 + (2 * t)) * EnvGen.ar(Env.perc(0.001, 0.8)));
		SinOsc.ar(f + mod) * EnvGen.ar(Env.perc(0.001, 1.6 + t, 1, -4)) * 0.4
	});
	make.(\mm_pad, { |f, t|          // strings, pads, choirs (vowel is added in Tidal)
		var sig = Mix(Saw.ar(f * [0.993, 1, 1.007])) * 0.22;
		LPF.ar(sig, (f * (1.5 + (t * 6)) * (1 + (SinOsc.kr(0.15) * 0.2))).clip(80, 16000))
	});
	make.(\mm_bowed, { |f, t|        // violin, cello, contrabass
		var v = f * (1 + (SinOsc.kr(5.2) * 0.005));
		LPF.ar(Saw.ar(v) + (Saw.ar(v * 1.002) * 0.5), (f * (2 + (t * 6))).clip(80, 16000)) * 0.3
	});
	make.(\mm_brass, { |f, t|        // trumpet, brass section, synth brass, orchestra hit
		var fe = EnvGen.ar(Env.perc(0.05, 0.5));
		LPF.ar(Saw.ar(f) + (Saw.ar(f * 1.004) * 0.7),
			(f * (1.2 + (t * 1.5) + (fe * (2 + (t * 6))))).clip(80, 16000)) * 0.3
	});
	make.(\mm_reed, { |f, t|         // harmonica, accordion, sax, vocal lead
		var v = f * (1 + (SinOsc.kr(4.7) * 0.003));
		LPF.ar(Pulse.ar(v, 0.32) + (Saw.ar(v * 1.003) * 0.3), (f * (2 + (t * 6))).clip(80, 16000)) * 0.32
	});
	make.(\mm_flute, { |f, t|        // flute, pan flute, shakuhachi, ocarina, whistle, bottle
		var v = f * (1 + (SinOsc.kr(5) * 0.004));
		(SinOsc.ar(v) * 0.5) + (SinOsc.ar(v * 2) * 0.08)
			+ (BPF.ar(WhiteNoise.ar, (f * 2).clip(100, 15000), 0.3) * (0.05 + (0.2 * t)))
	});
	make.(\mm_bass, { |f, t|         // electric, fretless, slap and upright bass
		var fe = EnvGen.ar(Env.perc(0.003, 0.3));
		(SinOsc.ar(f) * 0.6) + (LPF.ar(Saw.ar(f), (f * (1.5 + (fe * (2 + (t * 8))))).clip(40, 12000)) * 0.35)
	});
	"Mix-Matrix: mm_* synths ready".postln;
};

// Full path so scsynth is found when sclang runs from a VS Code terminal.
// Short (8.3) form of C:\Program Files\SuperCollider-3.12.1\scsynth.exe: a quoted
// path breaks once device names add more quotes to the cmd.exe line.
Server.program = "C:\\PROGRA~1\\SUPERC~1.1\\scsynth.exe";

s.reboot {
	// Without this, Windows' default (the DDJ-FLX6's outputs) is used.
	// For the controller's master/headphone outs use "MME : Line (DDJ-FLX6)".
	s.options.outDevice = "MME : Speakers (Realtek(R) Audio)";
	s.options.inDevice = "MME : Microphone (Realtek(R) Audio)";
	s.options.numBuffers = 1024 * 256;
	s.options.memSize = 8192 * 32;
	s.options.numWireBufs = 128;
	s.options.maxNodes = 1024 * 32;
	s.options.numOutputBusChannels = 2;
	s.options.numInputBusChannels = 2;
	s.waitForBoot {
		~dirt.stop;                       // stop an earlier instance, if any
		~dirt = SuperDirt(2, s);
		~dirt.loadSoundFiles;             // the standard Dirt-Samples
		if (File.exists(~mmSampleDir)) {
			~dirt.loadSoundFiles(~mmSampleDir +/+ "*");
		} {
			("Mix-Matrix: no samples at " ++ ~mmSampleDir
				++ " -- run fetch_mixmatrix_samples.py first").warn;
		};
		s.sync;
		~dirt.start(57120, 0 ! 8);        // 8 orbits: one per track, plus one spare
		~mmSynths.value;
	};
};
);


// ---------------------------------------------------------------------
//  2. MIDI controller -> Tidal  (sends /ctrl "<cc number>" <0..1>)
// ---------------------------------------------------------------------
//  Tidal reads these with cF; the CC numbers are set in mix-matrix.tidal.
//  Evaluate once per session (re-running MIDIClient.init can duplicate
//  ports on Linux, so it is only initialised the first time).
(
~mmMidiDevice  = "DDJ";      // EDIT ME: any part of your controller's name ("" = every input)
~mmMidiChannel = nil;     // nil = any channel, or 0-15 to listen to one channel only
~mmTidal = NetAddr("127.0.0.1", 6010);
if (MIDIClient.initialized.not) { MIDIClient.init };
MIDIClient.sources.do { |src|
	if (~mmMidiDevice.isEmpty
		or: { src.device.containsi(~mmMidiDevice) }
		or: { src.name.containsi(~mmMidiDevice) }) {
		MIDIIn.connect(0, src);
		("Mix-Matrix: listening to " ++ src.device ++ " / " ++ src.name).postln;
	};
};
// Same names as startup.scd: "cc<number>" and "ch<channel>cc<number>"
// (channel counted from 1), e.g. the DDJ-FLX6 filter knob is "ch7cc25".
// ~mmMidiPost = true prints each knob move as the name to use in cF, e.g.
//   MIDI ch7cc25 = 0.984  (val 125)
// Set it to false (and re-run this block) once you have found your knobs.
~mmMidiPost = true;
MIDIdef.cc(\mixMatrixCC, { |val, num, chan|
	if (~mmMidiChannel.isNil or: { chan == ~mmMidiChannel }) {
		~mmTidal.sendMsg("/ctrl", "cc" ++ num, val / 127);
		~mmTidal.sendMsg("/ctrl", "ch" ++ (chan + 1) ++ "cc" ++ num, val / 127);
		if (~mmMidiPost) {
			("MIDI ch" ++ (chan + 1) ++ "cc" ++ num ++ " = "
				++ (val / 127).round(0.001) ++ "  (val " ++ val ++ ")").postln;
		};
	};
});
)
