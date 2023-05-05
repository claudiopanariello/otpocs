//Claudio Panariello
//
// On the possibility of cultivating shadows - PATCH
//
// cla.panariello@gmail.com
//
//////////////////// The patch needs CuePlayer, that can be installed as quark:
//////////////////// ---> Quarks.install("CuePlayer");
//////////////////// Then recompile SC.

// CHECK THE STARTUP

(
s.options.memSize = 2.pow(19); // <<<---------
s.options.blockSize = 256;
Server.local.options.numOutputBusChannels = 4;
Server.local.options.numInputBusChannels = 12;
//ServerOptions.devices
Server.default.options.inDevice_("Fireface 802 (23768408)");
Server.default.options.outDevice_("Fireface 802 (23768408)");
)

//Noot the server
s.boot;
s.meter;
Stethoscope.new(s, 4);

// CONES DEBUGGING

{Out.ar(0, SinOsc.ar(XLine.kr(20,2e4,10),0,0.7))}.play;
// Some white noise
4.do({|i| {Out.ar(i, WhiteNoise.ar(0.1))}.play})

4.do({|i| {Out.ar(i, SinOsc.ar(400, 0, 0.1))}.play})

// Test the cones sending some white noise
// set the amplifiers so their output sounds pretty much the same / are comparable.
({
	var numOut = 4;
	inf.do({
		|n|
		{Out.ar(n%numOut, WhiteNoise.ar(0.01)*EnvGen.kr(Env.perc, doneAction: 2))}.play;
		1.wait;
	})
}.fork;)

//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~
//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~
//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~//~~

/*
███████╗██╗   ██╗███╗   ██╗████████╗██╗  ██╗    ██████╗ ███████╗███████╗
██╔════╝╚██╗ ██╔╝████╗  ██║╚══██╔══╝██║  ██║    ██╔══██╗██╔════╝██╔════╝
███████╗ ╚████╔╝ ██╔██╗ ██║   ██║   ███████║    ██║  ██║█████╗  █████╗
╚════██║  ╚██╔╝  ██║╚██╗██║   ██║   ██╔══██║    ██║  ██║██╔══╝  ██╔══╝
███████║   ██║   ██║ ╚████║   ██║   ██║  ██║    ██████╔╝███████╗██║
╚══════╝   ╚═╝   ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝    ╚═════╝ ╚══════╝╚═╝

*/

(
~cp = CuePlayer.new; // the cue player
~cones = Array.fill(8, 0); //cones array (yes, I need 8 items)
~busIn = [11, 8, 10, 9]; // <<<---- !! check the input channels
~busOut = [0, 1, 2, 3]; // <<<---- !! check the output channels
//
(
SynthDef(\feedback, {
	arg gain = 0, busIn = 0, busOut = 0, lag = 0.5, rinf, rsup, amp_thresh = 0.2, centreFrequency = 100, rq = 0.5, impulseFrequency = 1, durGrain = 0.1, mix = 0, room = 1, relaxTime = 0.5, pitchRate = 0.99, choose1 = 0, choose2 = 1, windowsize = 4096, wipe = 0, lfFreq = 1, attack =  0.01, release = 0.1, urLag = 1;
	var in_mic, input, rms, control, envfol_in, lfnoise, bandpass, chain, trig1, realTrig1, grain, env, output, spectralFlatness, spectralCentroid, spectralEntropy;

	in_mic = LeakDC.ar(SoundIn.ar(busIn))*gain.lag3(0.5*urLag);
	input = Compander.ar(in_mic, in_mic); //input microfonico
	rms = RunningSum.rms(Amplitude.ar(input));
	control = (1-(rms.lag2(lag)));
	envfol_in = Lag.ar(rms, lag);

	lfnoise = LFNoise2.ar(lfFreq.lag3(0.1*urLag)).clip2.range(rinf.lag3(0.1*urLag), rsup.lag3(0.1*urLag));
	bandpass = BPF.ar(input, lfnoise, 0.1);

	chain = FFT(LocalBuf(windowsize, 1), bandpass);
	//spectralFlatness = SpecFlatness.kr(chain); //0 for pure sinusoid, 1 for noise
	//spectralCentroid = SpecCentroid.kr(chain); //indicator of the perceptual brightness of a signal
	//spectralEntropy = SpectralEntropy.kr(chain, 512, 1); // full spectrum's entropy
	chain = PV_BinScramble(chain, wipe, 1);
	bandpass = IFFT(chain);

	trig1 = envfol_in > amp_thresh; //trigger quando l'ampiezza supera "amp_thresh"
	realTrig1 = Trig1.ar((Timer.ar(trig1) > relaxTime.lag3(0.1))*trig1, relaxTime.lag3(0.1)); //per escludere trigger che avvengono entro un certo limite temporale: escludo tutti gli eventuali nuovi trigger che arrivano nei successivi 2 s
	//envfol_in.poll;
	//realTrig1.poll;

	grain = GrainIn.ar(
		numChannels: 1,
		trigger: Impulse.ar(impulseFrequency.lag3(1*urLag)), //Dust.ar(envfol_in.expexp(0.0001, 1.0, 80, 5)),
		dur: durGrain.lag3(1*urLag),//envfol_in.expexp(0.0001, 1.0, 0.1, 0.001),
		in: Mix.new([input*(1-choose1.lag3(0.1*urLag)), bandpass*choose1.lag3(0.1*urLag)])
	);

	env = EnvGen.ar(Env.asr(attack, 0.5, release), 1-realTrig1);
	//output = BPF.ar(grain, centreFrequency.lag3(1), rq.lag3(1))*control*env; //Lag3.kr(spectralFlatness*spectralCentroid.linexp(0, 10000, 7000, 5000), 2)
	output = BPF.ar(grain, centreFrequency.lag3(1*urLag), rq.lag3(1*urLag))*control*env;

	//SendReply.kr(Impulse.kr(40), '/lfnoise', lfnoise);

	Out.ar(busOut, Limiter.ar(FreeVerb.ar(bandpass, mix.lag3(2*urLag), room.lag3(2))*control, 0.7)*(1-choose2.lag3(0.1*urLag)));
	Out.ar(busOut, Limiter.ar(FreeVerb.ar(output, mix.lag3(2*urLag), room.lag3(2)))*choose2.lag3(0.1*urLag));
}).add;
)
)

////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////


/*
███████╗██╗   ██╗███████╗███╗   ██╗████████╗███████╗
██╔════╝██║   ██║██╔════╝████╗  ██║╚══██╔══╝██╔════╝
█████╗  ██║   ██║█████╗  ██╔██╗ ██║   ██║   ███████╗
██╔══╝  ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║   ██║   ╚════██║
███████╗ ╚████╔╝ ███████╗██║ ╚████║   ██║   ███████║
╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝

*/
// Evaluate entire section (it's ~700 lines), then evaluate the player gui after that.
(
//
/////////////////////////////////////////////////////// THE EVENTS
// Define CUE
~cp.put(1,
	CueInfo(
		cueTitle: "Next --> will trigger the first feedbacks",
		largeDisplayInfo: "Run the synths but no sound",
		function: {
			~cones[0] = Synth(\feedback, [\gain, 0, \busIn, ~busIn[0], \busOut, ~busOut[0], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \rinf, 277, \rsup, 277*2, \mix, 0.5, \choose1, 1, \choose2, 0]);
			~cones[1] = Synth(\feedback, [\gain, 0, \busIn, ~busIn[1], \busOut, ~busOut[1], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \rinf, 277, \rsup, 277*2, \mix, 0.5, \choose1, 1, \choose2, 0]);
			~cones[2] = Synth(\feedback, [\gain, 0, \busIn, ~busIn[2], \busOut, ~busOut[2], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \rinf, 277/2, \rsup, 277*2, \mix, 0.5, \choose1, 1, \choose2, 0]);
			~cones[3] = Synth(\feedback, [\gain, 0, \busIn, ~busIn[3], \busOut, ~busOut[3], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \rinf, 277/2, \rsup, 277*2, \mix, 0.5, \choose1, 1, \choose2, 0]);
		}
));
//
// Define CUE
~cp.put(2,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: "Trigger first feedbakcs",
		function: 	{ ~cones[0].set(\gain, 27, \urLag, 1);	}
));
//
// Define CUE
~cp.put(3,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: { ~cones[1].set(\gain, 27, \urLag, 1); }
));
//
// Define CUE
~cp.put(4,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 1, \urLag, 25);
			~cones[1].set(\gain, 1, \urLag, 25);
		}
));
//
~cp.put(5,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 30, \urLag, 1);
			~cones[1].set(\gain, 30, \urLag, 1);
		}
));
//
~cp.put(6,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\rsup, 700);
			~cones[1].set(\rsup, 700);
		}
));
//
~cp.put(7,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 0);
			~cones[1].set(\gain, 0);
		}
));
//
~cp.put(8,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 40, \rinf, 400, \rsup, 500, \lfFreq, 10);
			~cones[1].set(\gain, 40, \rinf, 400, \rsup, 500, \lfFreq, 10);
		}
));
//
~cp.put(9,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 35, \rinf, 100, \rsup, 700, \lfFreq, 5, \urLag, 8);
			~cones[1].set(\gain, 35, \rinf, 100, \rsup, 700, \lfFreq, 5, \urLag, 8);
		}
));
//
~cp.put(10,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\lfFreq, 2, \urLag, 4);
			~cones[1].set(\lfFreq, 2, \urLag, 4);
			~cones[2].set(\gain, 8, \lfFreq, 0.2, \rinf, 277/2, \rsup, 277*2, \urLag, 12);
			~cones[3].set(\gain, 7, \lfFreq, 0.2, \rinf, 277/2, \rsup, 277*2, \urLag, 12);
		}
));
//
~cp.put(11,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 25, \rinf, 800, \rsup, 920, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 150, \durGrain, 0.03, \q, 1, \amp_thresh, 0.007, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 1);
			~cones[1].set(\gain, 24, \rinf, 800, \rsup, 920, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 150, \durGrain, 0.03, \q, 1, \amp_thresh, 0.007, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 1);
		}
));
//
~cp.put(12,
	CueInfo(
		cueTitle: "Bar 54",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 30, \rinf, 400, \rsup, 500, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 135, \durGrain, 0.03, \q, 1, \amp_thresh, 0.001, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 2);
			~cones[1].set(\gain, 30, \rinf, 400, \rsup, 500, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 135, \durGrain, 0.03, \q, 1, \amp_thresh, 0.001, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 2);
			~cones[2].set(\gain, 0, \urLag, 15);
			~cones[3].set(\gain, 0, \urLag, 15);
		}
));


~cp.put(13,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 0, \urLag, 5);
			~cones[1].set(\gain, 0, \urLag, 5);
			~cones[2].set(\gain, 8, \lfFreq, 0.3, \rinf, 277, \rsup, 290, \urLag, 3);
			~cones[3].set(\gain, 7, \lfFreq, 0.3, \rinf, 277, \rsup, 290, \urLag, 3);
		}
));
//
~cp.put(14,
	CueInfo(
		cueTitle: "bar 53",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 32, \rinf, 400, \rsup, 500, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 140, \durGrain, 0.03, \q, 1, \amp_thresh, 0.001, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 0.1);
			~cones[1].set(\gain, 32, \rinf, 400, \rsup, 500, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 140, \durGrain, 0.03, \q, 1, \amp_thresh, 0.001, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 0.1);
			~cones[2].set(\gain, 0, \urLag, 7);
			~cones[3].set(\gain, 0, \urLag, 7);
		}
));

//
~cp.put(15,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 0, \urLag, 5);
			~cones[1].set(\gain, 0, \urLag, 5);
			~cones[2].set(\gain, 8, \lfFreq, 0.7, \rinf, 257, \rsup, 300, \urLag, 1);
			~cones[3].set(\gain, 7, \lfFreq, 0.7, \rinf, 257, \rsup, 300, \urLag, 1);
		}
));
//
~cp.put(16,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 32, \rinf, 400, \rsup, 500, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 160, \durGrain, 0.03, \q, 1, \amp_thresh, 0.001, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 0.1);
			~cones[1].set(\gain, 32, \rinf, 400, \rsup, 500, \lfFreq, 20, \centreFrequency, 880, \impulseFrequency, 160, \durGrain, 0.03, \q, 1, \amp_thresh, 0.001, \mix, 0.1, \release, 1, \relaxTime, 2, \choose1, 0.5, \choose2, 0.7, \urLag, 0.1);
			~cones[2].set(\gain, 0, \urLag, 5);
			~cones[3].set(\gain, 0, \urLag, 5);
		}
));
//
~cp.put(17,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[2].set(\gain, 8, \lfFreq, 1, \rinf, 257, \rsup, 500, \urLag, 1);
			~cones[3].set(\gain, 7, \lfFreq, 1, \rinf, 257, \rsup, 500, \urLag, 1);
		}
));
//
~cp.put(18,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[2].set(\gain, 0, \urLag, 1);
			~cones[3].set(\gain, 0, \urLag, 1);
		}
));
//
~cp.put(19,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 30, \rinf, 257, \rsup, 500, \urLag, 10, \choose1, 1, \choose2, 0, \mix, 0.5, \lfFreq, 2.9);
			~cones[1].set(\gain, 30, \rinf, 257, \rsup, 500, \urLag, 10, \choose1, 1, \choose2, 0, \mix, 0.5, \lfFreq, 2.3);
			~cones[2].set(\gain, 11, \rinf, 257, \rsup, 500, \urLag, 1, \choose1, 1, \choose2, 0, \mix, 0.5, \lfFreq, 1.7);
			~cones[3].set(\gain, 11, \rinf, 257, \rsup, 500, \urLag, 1, \choose1, 1, \choose2, 0, \mix, 0.5, \lfFreq, 1.3);
		}
));
//
~cp.put(20,
	CueInfo(
		cueTitle: "Bar 80",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 32, \rinf, 100, \rsup, 800, \urLag, 3.2, \lfFreq, 3.5);
			~cones[1].set(\gain, 32, \rinf, 100, \rsup, 800, \urLag, 4, \lfFreq, 5.1);
			~cones[2].set(\gain, 12, \urLag, 2);
			~cones[3].set(\gain, 12, \urLag, 2.3);
		}
));
//
~cp.put(21,
	CueInfo(
		cueTitle: "Bar 85",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 20 ,\lfFreq, 0.5, \urLag, 25);
			~cones[1].set(\gain, 20, \lfFreq, 0.5, \urLag, 25);
			~cones[2].set(\gain, 7, \lfFreq, 0.5, \urLag, 25);
			~cones[3].set(\gain, 7, \lfFreq, 0.5, \urLag, 25);
		}
));
//
~cp.put(22,
	CueInfo(
		cueTitle: "Bar 92",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 10 ,\lfFreq, 0.3, \urLag, 15);
			~cones[1].set(\gain, 10, \lfFreq, 0.3, \urLag, 15);
			~cones[2].set(\gain, 6, \lfFreq, 0.3, \urLag, 15);
			~cones[3].set(\gain, 6, \lfFreq, 0.3, \urLag, 15);
		}
));
//
~cp.put(23,
	CueInfo(
		cueTitle: "Bar 99 - Morbid, noxious",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 6, \gain, 9-i, \rinf, 100, \rsup, 277,  \choose1, 1, \choose2, 0, \mix, 0.5, \lfFreq, 0.1);})
		}
));
//
~cp.put(24,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 12-i, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(25,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 9-i, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(26,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 15-i, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(27,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 10-i, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(28,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 18-i, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(29,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 13-i, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(30,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 20-i, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(31,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 12, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(32,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 22, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(33,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 16, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(34,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 25, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(35,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 20, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(36,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 28, \rinf, 260, \rsup, 377);})
		}
));
//
~cp.put(37,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 22, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(38,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 32, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(39,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 25, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(40,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 35, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(41,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 27, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(42,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 40, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(43,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 30, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(44,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 47, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(45,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 35, \rinf, 100, \rsup, 277);})
		}
));
//
~cp.put(46,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 1, \gain, 60, \rinf, 260, \rsup, 277);})
		}
));
//
~cp.put(47,
	CueInfo(
		cueTitle: "Bar 131",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\urLag, 15, \gain, 0, \rinf, 100, \rsup, 100);})
		}
));
//
~cp.put(48,
	CueInfo(
		cueTitle: "Bar 141",
		largeDisplayInfo: " ",
		function: {
			~cones[2].set(\gain, 37, \rinf, 300, \rsup, 1000, \centreFrequency, 650, \impulseFrequency, 130, \durGrain, 0.024, \q, 1, \amp_thresh, 0.005, \mix, 0.2, \release, 1, \relaxTime, 5.1, \choose1, 1, \choose2, 1, \lfFreq, 4.2, \urLag, 2, \attack, 0.7);
			~cones[3].set(\gain, 37, \rinf, 300, \rsup, 800, \centreFrequency, 500, \impulseFrequency, 130, \durGrain, 0.024, \q, 1, \amp_thresh, 0.005, \mix, 0.2, \release, 1, \relaxTime, 4.7, \choose1, 1, \choose2, 1, \lfFreq, 4.3, \urLag, 2, \attack, 0.7);
		}
));
//
~cp.put(49,
	CueInfo(
		cueTitle: "Bar 152",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 30, \rinf, 5000, \rsup, 7000, \centreFrequency, 6000, \impulseFrequency, 130, \durGrain, 0.024, \q, 1, \amp_thresh, 0.01, \mix, 0.1, \release, 1.3, \relaxTime, 6.9, \choose1, 0, \choose2, 1, \lfFreq, 5, \urLag, 2, \attack, 0.01);
			~cones[1].set(\gain, 32, \rinf, 1000, \rsup, 5000, \centreFrequency, 3000, \impulseFrequency, 130, \durGrain, 0.024, \q, 1, \amp_thresh, 0.01, \mix, 0.2, \release, 2.1, \relaxTime, 5.8, \choose1, 0, \choose2, 1, \lfFreq, 5.1, \urLag, 2, \attack, 0.7);
			~cones[2].set(\gain, 40, \urLag, 1, \amp_thresh, 0.01, \relaxTime, 3.3);
			~cones[3].set(\gain, 40, \urLag, 1, \amp_thresh, 0.01, \relaxTime, 3.5);
		}
));
//
~cp.put(50,
	CueInfo(
		cueTitle: "Bar 159",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 33, \urLag, 1, \amp_thresh, 0.05, \relaxTime, 5.5, \impulseFrequency, 150);
			~cones[1].set(\gain, 35, \urLag, 1, \amp_thresh, 0.03, \attack, 0.01, \relaxTime, 4.7, \impulseFrequency, 150);
			~cones[2].set(\gain, 50, \urLag, 1, \amp_thresh, 0.02, \attack, 0.01);
			~cones[3].set(\gain, 50, \urLag, 1, \amp_thresh, 0.02, \attack, 0.01);
		}
));
//
~cp.put(51,
	CueInfo(
		cueTitle: "bar 162",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 35, \urLag, 1, \amp_thresh, 0.05, \relaxTime, 0.1, \impulseFrequency, 220);
			~cones[1].set(\gain, 37, \urLag, 1, \amp_thresh, 0.03, \attack, 0.01, \relaxTime, 2.4, \impulseFrequency, 200);
			~cones[2].set(\gain, 55, \urLag, 2.5, \amp_thresh, 0.05, \attack, 0.01, \impulseFrequency, 150);
			~cones[3].set(\gain, 55, \urLag, 2.5, \amp_thresh, 0.05, \attack, 0.01, \impulseFrequency, 150);
		}
));
//
~cp.put(52,
	CueInfo(
		cueTitle: "Bar 165",
		largeDisplayInfo: " ",
		function: {
			({1.do({
				2.do({|i| ~cones[i].set(\gain, 0, \urLag, 5)});
				2.do({|i| ~cones[i+2].set(\gain, 0, \urLag, 0.1)});
				0.5.wait;
				~cones[2].set(\gain, 6, \centreFrequency, 100, \impulseFrequency, 400, \durGrain, 0.2, \q, 1, \amp_thresh, 0.005, \mix, 0.005, \release, 2, \relaxTime, 3, \choose1, 0, \choose2, 1, \urLag, 0.5, \attack, 0.01);
				~cones[3].set(\gain, 6, \centreFrequency, 100, \impulseFrequency, 300, \durGrain, 0.2, \q, 1, \amp_thresh, 0.005, \mix, 0.005, \release, 2, \relaxTime, 3, \choose1, 0, \choose2, 1, \urLag, 0.5, \attack, 0.01);
				2.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				2.wait;
				// 53
				~cones[0].set(\gain, 0, \centreFrequency, 120, \impulseFrequency, 300, \durGrain, 0.25, \q, 1, \amp_thresh, 0.005, \mix, 0.005, \release, 2, \relaxTime, 3, \choose1, 0, \choose2, 1, \urLag, 1);
				~cones[1].set(\gain, 0, \centreFrequency, 120, \impulseFrequency, 300, \durGrain, 0.25, \q, 1, \amp_thresh, 0.005, \mix, 0.005, \release, 2, \relaxTime, 3, \choose1, 0, \choose2, 1, \urLag, 1);
				~cones[2].set(\gain, 6, \urLag, 0.5);
				~cones[3].set(\gain, 6, \urLag, 0.5);
				2.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				2.wait;
				//54
				~cones[0].set(\gain, 8, \urLag, 1);
				0.03.wait;
				~cones[1].set(\gain, 8, \urLag, 1);
				~cones[2].set(\gain, 5.5, \centreFrequency, 100, \impulseFrequency, 370, \urLag, 0.5);
				0.05.wait;
				~cones[3].set(\gain, 5.5, \centreFrequency, 100, \impulseFrequency, 250, \urLag, 0.5);
				2.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				2.wait;
				//55 Bar 169
				~cones[0].set(\gain, 7, \centreFrequency, 120, \impulseFrequency, 270, \urLag, 1);
				~cones[1].set(\gain, 7, \centreFrequency, 120, \impulseFrequency, 270, \urLag, 1);
				~cones[2].set(\gain, 5, \centreFrequency, 100, \impulseFrequency, 330, \urLag, 0.5);
				~cones[3].set(\gain, 5, \centreFrequency, 100, \impulseFrequency, 220, \urLag, 0.5);
				2.2.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				2.2.wait;
				//56 Bar 171
				~cones[3].set(\gain, 4.5, \centreFrequency, 100, \impulseFrequency, 200, \urLag, 0.5);
				0.06.wait;
				~cones[1].set(\gain, 6, \centreFrequency, 120, \impulseFrequency, 250, \urLag, 1);
				0.07.wait;
				~cones[0].set(\gain, 6, \centreFrequency, 120, \impulseFrequency, 250, \urLag, 1);
				0.12.wait;
				~cones[2].set(\gain, 4.5, \centreFrequency, 100, \impulseFrequency, 300, \urLag, 0.5);
				2.4.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				2.4.wait;
				//57
				~cones[1].set(\gain, 5, \centreFrequency, 120, \impulseFrequency, 200, \urLag, 1);
				0.1.wait;
				~cones[0].set(\gain, 5, \centreFrequency, 120, \impulseFrequency, 210, \urLag, 1);
				0.03.wait;
				~cones[3].set(\gain, 4, \centreFrequency, 100, \impulseFrequency, 180, \urLag, 0.5);
				0.07.wait;
				~cones[2].set(\gain, 4, \centreFrequency, 100, \impulseFrequency, 270, \urLag, 0.5);
				2.65.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				2.65.wait;
				//58
				~cones[2].set(\gain, 3.5, \centreFrequency, 100, \impulseFrequency, 250, \urLag, 0.5);
				0.1.wait;
				~cones[0].set(\gain, 4, \centreFrequency, 120, \impulseFrequency, 190, \urLag, 1);
				0.2.wait;
				~cones[3].set(\gain, 3.5, \centreFrequency, 100, \impulseFrequency, 170, \urLag, 0.5);
				0.05.wait;
				~cones[1].set(\gain, 4, \centreFrequency, 120, \impulseFrequency, 190, \urLag, 1);
				2.8.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				2.8.wait;
				//59
				~cones[0].set(\gain, 4, \centreFrequency, 120, \impulseFrequency, 180, \urLag, 1);
				0.05.wait;
				~cones[1].set(\gain, 4, \centreFrequency, 120, \impulseFrequency, 175, \urLag, 1);
				0.1.wait;
				~cones[2].set(\gain, 3, \centreFrequency, 100, \impulseFrequency, 230, \urLag, 0.5);
				0.2.wait;
				~cones[3].set(\gain, 3, \centreFrequency, 100, \impulseFrequency, 160, \urLag, 0.5);
				3.12.wait;
				4.do({|i| ~cones[i].set(\gain, 0, \urLag, 1)});
				3.12.wait;
				//60
				~cones[2].set(\gain, 2, \centreFrequency, 100, \impulseFrequency, 200, \urLag, 0.5);
				0.4.wait;
				~cones[1].set(\gain, 1, \centreFrequency, 120, \impulseFrequency, 250, \urLag, 1);
				0.2.wait;
				~cones[0].set(\gain, 2, \centreFrequency, 120, \impulseFrequency, 250, \urLag, 1);
				0.3.wait;
				~cones[3].set(\gain, 1, \centreFrequency, 100, \impulseFrequency, 200, \urLag, 0.5);
				"--->>> shaking lungo".postln;
			});}.fork;);
		}
));
//
~cp.put(53,
	CueInfo(
		cueTitle: "Bar  179",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i].set(\gain, 5, \impulseFrequency, 500, \urLag, 20, \relaxTime, 0.2)});
		}
));
//
~cp.put(54,
	CueInfo(
		cueTitle: " ",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 1, \impulseFrequency, 200, \urLag, 30);
			~cones[1].set(\gain, 0.7, \impulseFrequency, 200, \urLag, 30);
			~cones[2].set(\gain, 1, \impulseFrequency, 150, \urLag, 30);
			~cones[3].set(\gain, 0.5, \impulseFrequency, 150, \urLag, 30);
		}
));
//
~cp.put(55,
	CueInfo(
		cueTitle: "bar 189",
		largeDisplayInfo: " ",
		function: {
			~cones[0].set(\gain, 0, \urLag, 12);
		}
));
//
~cp.put(56,
	CueInfo(
		cueTitle: "bar 189",
		largeDisplayInfo: " ",
		function: {
			~cones[1].set(\gain, 0, \urLag, 10);
			~cones[0].free;
			~cones[4] = Synth(\feedback, [\busIn, ~busIn[0], \busOut, ~busOut[0], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \centreFrequency, 357, \impulseFrequency, 357, \durGrain, 0.063, \rq, 1, \rinf, 70, \rsup, 505, \mix, 0.261, \gain, 32.56, \amp_thresh, 0.01, \relaxTime, 1, \release, 1, \choose1, 1, \choose2, 0.03, \urLag, 100]);
		}
));
//
~cp.put(57,
	CueInfo(
		cueTitle: "bar 191",
		largeDisplayInfo: " ",
		function: {
			~cones[2].set(\gain, 0, \urLag, 10);
			~cones[1].free;
			~cones[5] = Synth(\feedback, [\busIn, ~busIn[1], \busOut, ~busOut[1], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \centreFrequency, 594.61, \impulseFrequency, 236.9, \durGrain, 0.048, \rq, 1, \rinf, 70, \rsup, 1669, \mix, 0.344, \gain, 20, \amp_thresh, 0.01, \relaxTime, 1, \release, 1,\choose1, 1, \choose2, 0.3, \urLag, 80]);
		}
));
//
~cp.put(58,
	CueInfo(
		cueTitle: "bar 193",
		largeDisplayInfo: " ",
		function: {
			~cones[3].set(\gain, 0, \urLag, 10);
			~cones[2].free;
			~cones[6] = Synth(\feedback, [\busIn, ~busIn[2], \busOut, ~busOut[2], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \centreFrequency, 639.33, \impulseFrequency, 167.7, \durGrain, 0.04, \rq, 1, \rinf, 70, \rsup, 1385, \mix, 0.241, \gain, 9, \amp_thresh, 0.01, \relaxTime, 1, \release, 1,\choose1, 1, \choose2, 0.3, \urLag, 70]);
		}
));
//
~cp.put(59,
	CueInfo(
		cueTitle: "bar 195",
		largeDisplayInfo: " ",
		function: {
			~cones[3].free;
			~cones[7] = Synth(\feedback, [\busIn, ~busIn[3], \busOut, ~busOut[3], \windowsize, 8192*2, \wipe, 0.1, \lfFreq, 0.2, \centreFrequency, 569, \impulseFrequency, 173.8, \durGrain, 0.041, \rq, 0.648, \rinf, 70, \rsup, 1149.3, \mix, 0.477, \gain, 9, \amp_thresh, 0.07, \relaxTime, 1, \release, 1,\choose1, 1, \choose2, 0.3, \urLag, 60]);
		}
));
//
~cp.put(60,
	CueInfo(
		cueTitle: "Fine (bar 281)",
		largeDisplayInfo: " ",
		function: {
			4.do({|i| ~cones[i+4].set(\gain, 0, \impulseFrequency, 50, \urLag, 8);})
		}
));
//
)

////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
██████╗ ██╗      █████╗ ██╗   ██╗███████╗██████╗      ██████╗ ██╗   ██╗██╗
██╔══██╗██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗    ██╔════╝ ██║   ██║██║
██████╔╝██║     ███████║ ╚████╔╝ █████╗  ██████╔╝    ██║  ███╗██║   ██║██║
██╔═══╝ ██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗    ██║   ██║██║   ██║██║
██║     ███████╗██║  ██║   ██║   ███████╗██║  ██║    ╚██████╔╝╚██████╔╝██║
╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝     ╚═════╝  ╚═════╝ ╚═╝

*/

(
~cp.gui(
	monitorInChannels: 4, // Monitor 4 input channels
	monitorOutChannels: 4, // Monitor 16 output channels
	options: (
		//monitorInOffset: ~busIn[0]-1, //offset input monitoring by ~busIn[0], so I can see properly the in channels
		infoDisplay: true, // Show the cue-title field.
		largeDisplay: true, // Show the big window displaying current cue-number.
		// Useful for the performers on stage.
		left: 1300, // Left bound of the CuePlayer window.
		top: 300, // Top bound of the CuePlayer window.
		shortcuts: true;
	)
);
);

s.record(numChannels:4)

//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//~//