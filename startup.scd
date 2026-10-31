// Run this in the SuperCollider IDE (select all, Ctrl+Enter) before evaluating Tidal code.
// If SuperDirt isn't installed yet, first run once:
//   Quarks.install("SuperDirt");  then recompile the class library (Ctrl+Shift+L).

(
s.reboot {
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
