// Run this in the SuperCollider IDE (select all, Ctrl+Enter) before evaluating Tidal code.
// If SuperDirt isn't installed yet, first run once:
//   Quarks.install("SuperDirt");  then recompile the class library (Ctrl+Shift+L).

(
// Full path so scsynth is found when sclang runs from a VS Code terminal.
// Short (8.3) form of C:\Program Files\SuperCollider-3.12.1\scsynth.exe: a quoted
// path breaks once the device names below add more quotes to the cmd.exe line.
Server.program = "C:\\PROGRA~1\\SUPERC~1.1\\scsynth.exe";

s.reboot {
    // Without this, Windows' default (the DDJ-FLX6's outputs) is used.
    // To hear through the controller's master/headphone outs instead, use
    // "MME : Line (DDJ-FLX6)".
    s.options.outDevice = "MME : Speakers (Realtek(R) Audio)";
    s.options.inDevice = "MME : Microphone (Realtek(R) Audio)";
    s.options.numBuffers = 1024 * 256;
    s.options.memSize = 8192 * 32;
    s.options.numWireBufs = 2048;
    s.options.maxNodes = 1024 * 32;
    s.options.numOutputBusChannels = 2;
    s.options.numInputBusChannels = 2;
    s.waitForBoot {
        ~dirt = SuperDirt(2, s);
        ~dirt.loadSoundFiles;
        s.sync;
        ~dirt.start(57120, 0 ! 12);
    };
};
);

// MIDI -> Tidal controller bridge.
// Run this in the SuperCollider IDE after startup.scd (select all, Ctrl+Enter).
// Every CC is forwarded to Tidal twice with a 0-1 value:
//   "cc<number>"            e.g. cF 0 "cc74"
//   "ch<channel>cc<number>" e.g. cF 0 "ch1cc23"  (channel counted from 1)
// Use the channel form for controllers like the DDJ-FLX6, where each deck sends
// the same CC numbers on its own channel.
//
// Don't know which CC your knob sends? Uncomment the trace line, turn the knob,
// read "chan" (add 1) and "num" in the post window, then comment it out again.

(
MIDIClient.init;
MIDIIn.connectAll;

~tidal = NetAddr("127.0.0.1", 6010);

MIDIdef.cc(\tidalCC, { |val, num, chan|
    ~tidal.sendMsg("/ctrl", "cc" ++ num, val / 127);
    ~tidal.sendMsg("/ctrl", "ch" ++ (chan + 1) ++ "cc" ++ num, val / 127);
});

MIDIFunc.trace(true);
"MIDI CCs -> Tidal on port 6010".postln;
);
