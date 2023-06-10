///////
// overall mode number based on how many times the button has been pushed
0 => int mode;
1 => int movement;
float leftHeight; float leftX; float leftY;
float rightHeight; float rightX; float rightY;

// differences
float leftDifVert; float rightDifVert;
float leftDif; float rightDif;
time lastPressed;

KBHit kb;

///////


// z axis deadzone
0 => float DEADZONE;
// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;
// HID objects
Hid trak;
HidMsg msg;



// open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();
// print
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}



// gametrack
GameTrak gt;
Xylo xy;
Arpeggiator arp;
Arpeggiator arp2;
Ambience ab;
Ambience ab2;
Ambience ab3;
Rain rn;
Wind wn;
Ambience ab4;
Ambience ab5;
Ambience ab6;


fun void muteGain(Gain g, int n)
{
    adjustGain(g, 0, n);
}

fun void adjustGain(Gain g, float target, int n)
{
    g.gain() => float curGain;
    (target - curGain) / n => float add;
    repeat(n)
    {
        add +=> curGain;
        curGain => g.gain;
        5::ms => now;
    }
}


fun void keyboardctrl()
{
    while( true )
    {
        // wait on event
        kb => now;
        

        // loop through 1 or more keys
        while( kb.more() )
        {
            // set filtre freq
            kb.getchar() => int c;
            if (c == 119)
            {
                movement++;
            }
            else if (c == 115)
            {
                movement--;
            }
            else if (c == 97)
            {
                mode++;
            }
            else if (c == 100)
            {
                mode--;
            }

            // print int value
            <<< "ascii:", c >>>;
            <<< "movement", movement, "mode", mode >>>;
        }
        0.05::second => now;
    }
}


class Arpeggiator 
{
    // channel 0
    SinOsc lfo0 => TriOsc petal0 => ADSR e => Gain g0 => NRev nrev0 => ResonZ resonz0 => dac;
    // set ADSR
    e.set( 10::ms, 8::ms, .5, 500::ms );
    3 => lfo0.freq;
    2 => petal0.sync;
    0.4 => nrev0.mix;
    1.0 => nrev0.gain;
    40 => resonz0.freq;
    [0, 4, 7, 11, 12] @=> int notes1[];
    [62, 64, 62, 64, 65, 67, 62, 64, 62, 64, 65, 67] @=> int bassNotes1[];
    [0, 4, 7, 11, 12 + 0, 12 + 4, 12 + 7, 12 + 11, 24] @=> int notes3[];
    [62, 64, 62, 64, 65, 67, 62, 64, 62, 64, 65, 67] @=> int bassNotes3[];
    -1 => int prevNote;
    -1 => int curNote;
    fun void arpeggiate(int notes[], int bassNotes[], int movementCondition)
    {
        0 => int curr;

        while (movement < movementCondition + 1)
        {
           mode => int curMode;
           if (leftHeight < 0.02 || movement != movementCondition)
           {
                0.0 => g0.gain;
           }
           else
           {
               // if gain is zero, increase gain
               if (g0.gain() < 0.01)
               {
                    0.5 => g0.gain; 
               }
               if (leftHeight > 0.45)
               {
                    bassNotes[mode % bassNotes.size()] + notes[notes.size() - 1] => curNote;
                    if (curNote != prevNote)
                    {
                        Std.mtof(curNote) => petal0.freq;
                        e.keyOn();
                    }
                    
               }
               else
               {
                    bassNotes[mode % bassNotes.size()] + notes[ Math.floor(leftHeight / 0.45 * (notes.size() - 1)) $ int ] => curNote;
                    if (curNote != prevNote)
                    {
                        Std.mtof(curNote) => petal0.freq;
                        e.keyOn();
                    }
                    
               }
               curNote => prevNote;
           }
           
           0.1::second => now;
        }
    }
}




spork ~ ab.ambience(ab.cands1, 1);
spork ~ ab2.ambience(ab.cands2, 2);
spork ~ ab3.ambience(ab.cands3, 3);
spork ~ ab4.ambience(ab.cands1, 4);
spork ~ ab5.ambience(ab.cands2, 5);
spork ~ ab6.ambience(ab.cands3, 6);
spork ~ xy.starlight();
spork ~ arp.arpeggiate(arp.notes1, arp.bassNotes1, 2);
spork ~ arp2.arpeggiate(arp2.notes3, arp2.bassNotes3, 5);
spork ~ wn.windblows(3);
spork ~ rn.ctrlRain(3);
spork ~ keyboardctrl();

// spork control
spork ~ gametrak();

// main loop
while( true )
{
    // print 6 continuous axes -- XYZ values for left and right
    // <<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2], gt.axis[3],gt.axis[4],gt.axis[5] >>>;
    // also can map gametrak input to audio parameters around here
    // note: gt.lastAxis[0]...gt.lastAxis[5] hold the previous XYZ values
    gt.axis[5] => rightHeight;
    gt.axis[2] => leftHeight;
    Math.sqrt(Math.pow((gt.axis[0]-gt.lastAxis[0]), 2) + Math.pow((gt.axis[1]-gt.lastAxis[1]), 2)) => leftDif;
    Math.sqrt(Math.pow((gt.axis[5]-gt.lastAxis[5]), 2)) => rightDifVert;
    // <<< leftDif >>>;
    // advance time
    100::ms => now;
}

// gametrack handling
fun void gametrak()
{
    while( true )
    {
        // wait on HidIn as event
        trak => now;
        
        // messages received
        while( trak.recv( msg ) )
        {
            // joystick axis motion
            if( msg.isAxisMotion() )
            {            
                // check which
                if( msg.which >= 0 && msg.which < 6 )
                {
                    // check if fresh
                    if( now > gt.currTime )
                    {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        1 - ((msg.axisPosition + 1) / 2) - DEADZONE => gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                // delete potentially
                if (now - lastPressed < 0.3::second)
                {
                    movement++;
                    0 => mode;
                    <<< "PRESSED TWICE, current movement", movement>>>;
                    <<< now - lastPressed >>>;
                    
                } 
                else
                {
                    mode + 1 => mode;
                    <<< "button", msg.which, "down", "mode", mode >>>;
                }   
                
                now => lastPressed;
                

            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                <<< "button", msg.which, "up" >>>;
            }
        }
    }
}

class Ambience
{
    SndBuf amb[4] => Gain g0 => ResonZ resonz0 => NRev nrev0 => dac;
    me.dir() + "ambient0.wav" => amb[0].read;
    -1 => int prevMode;
    1 => amb[0].loop;
    0 => amb[0].pos;
    0.2 => nrev0.mix;
    1 => amb[0].rate;
    [0, 5, 0, 1, 0, 5, 0, 1, 4, 5, 4, -5, 0] @=> int cands1[];
    // [62, 64, 62, 64, 65, 67,   62, 64, 62, 64, 65, 67] 
    [0, 2, 0, 2, 3, 5,         0, 2, 0, 2, 3, 5] @=> int cands2[];
    [0, 2, 0, 2, 3, 5,         0, 2, 0, 2, 3, 5] @=> int cands3[];
    fun void ambience(int cands[], int movementCondition)
    {
        while (movement < movementCondition + 1)
        {
            if (movement != movementCondition)
            {
                0 => nrev0.gain;
            }
            else
            {
                if (nrev0.gain() < 0.1)
                {
                    1 => nrev0.gain;
                }
                
                if (prevMode != mode) 
                {
                    Math.pow(2, cands[mode % cands.size()]/12.0) => amb[0].rate; 
                    mode => prevMode;
                }
                
                if (rightHeight < 0.03)
                {
                    0 => g0.gain;
                }
                else
                {
                    (rightHeight - 0.03)  => g0.gain;
                    
                }
            }
            
            0.05::second => now;
        }
        
    }
}

class Xylo
{
    ModalBar bar => NRev xylorev => ResonZ xylorez => dac;
    0.1 => xylorev.mix;


    // scale
    [0, 4, 7, 11] @=> int scale[];

    fun void starlight()
    {
        // infinite time loop
        while( true )
        {
            
            if (rightHeight > 0.6 && leftHeight > 0.6)
            {
                <<< "starlight" >>>;
                // ding!
                4 => bar.preset;
                Math.random2f( 0.5, 0.6 ) => bar.stickHardness;
                Math.random2f( 0.5, 0.6 ) => bar.strikePosition;
                Math.random2f( 0.01, 0.02 ) => bar.vibratoGain;
                0.01 => bar.vibratoFreq;
                Math.random2f( 0.1, 0.2 ) => bar.volume;
                Math.random2f( .5, 1 ) => bar.directGain;
                Math.random2f( .5, .6 ) => bar.masterGain;

                // print
                <<< "---", "" >>>;
                <<< "preset:", bar.preset() >>>;
                <<< "stick hardness:", bar.stickHardness() >>>;
                <<< "strike position:", bar.strikePosition() >>>;
                <<< "vibrato gain:", bar.vibratoGain() >>>;
                <<< "vibrato freq:", bar.vibratoFreq() >>>;
                <<< "volume:", bar.volume() >>>;
                <<< "direct gain:", bar.directGain() >>>;
                <<< "master gain:", bar.masterGain() >>>;

                // set freq
                scale[Math.random2(0,scale.size()-1)] => int winner;
                74 + Math.random2(0,1)*12 + winner => Std.mtof => bar.freq;
                // go
                if (Math.random2f(0, 1.0) < 0.4)
                {
                    .6 => bar.noteOn;
                }
                

                // advance time
                
            }
            .2::second => now;
            
        }
    }
    
}




class Wind
{
    // noise generator, biquad filter, dac (audio output) 
    Noise n => BiQuad f => Gain windgain => dac;
    // set biquad pole radius
    .99 => f.prad;
    // set biquad gain
    .05 => f.gain;
    // set equal zeros 
    1 => f.eqzs;
    // our float
    0.0 => float t;
    0 => windgain.gain;
    // concurrent control
    fun void wind_gain( )
    {
        0.0 => float g; 
        // time loop to ramp up the gain / oscillate
        while( true )
        {
            Std.fabs( Math.sin( g ) ) / 2 => n.gain;
            g + .001 => g;
            10::ms => now;
        }
    }
    // run wind_gain on anothre shred
    fun void windblows(int movementCondition)
    {
        spork ~ wind_gain();
        // infinite time-loop
        while( movement < movementCondition + 1 )
        {
            if (movement != movementCondition)
            {
                muteGain(windgain, 50);
            }
            else if (leftHeight < 0.01)
            {
                muteGain(windgain, 50);
            }
            else
            {
                if (leftDif > 0.03)
                {
                    windgain.gain() => float curWindGain;
                    Math.min(0.3, curWindGain + leftDif) => windgain.gain;
                }
                else
                {
                    if (windgain.gain() > 0)
                    {
                        windgain.gain() - 0.01 => float nextWindGain;
                        
                        nextWindGain => windgain.gain;
                        
                    }
                    
                }            
                // sweep the filter resonant frequency
                100.0 + Std.fabs(Math.sin(t)) * 1000.0 => f.pfreq;
                t + .01 => t;
            }
            // advance time
            100::ms => now;
        }
    }
}

class Rain
{
    SndBuf rainbuf => Gain raingain => NRev rainrev => dac;
    me.dir() + "rain.wav" => rainbuf.read;
    0.05 => rainrev.mix;
    0 => rainrev.gain;
    1 => rainbuf.loop;
    fun void ctrlRain(int movementcon)
    {
        while (true)
        {
            if (movement != movementcon)
            {
                muteGain(raingain, 50);
            }
            else
            {
                if (rightHeight < 0.05)
                {
                    muteGain(raingain, 50);
                }
                else
                {
                    if (rightDifVert > 0.05)
                    {
                        raingain.gain() => float curRainGain;
                        curRainGain + Math.min(rightDifVert, 0.05) => raingain.gain; 
                    }
                    else
                    {
                        raingain.gain() - 0.002 => float targetRainGain;
                        targetRainGain => raingain.gain;
                    }
                }
                
            }
            0.02::second => now;
        }
    }
}




// class GranSynth 
// {
//     "piano.wav" => string FILENAME;
//     // get file name, if one specified as input x0argument
//     if( me.args() > 0 ) me.arg(0) => FILENAME;

//     // overall volume
//     1 => float MAIN_VOLUME;
//     // grain duration base
//     50::ms => dur GRAIN_LENGTH;
//     // factor relating grain duration to ramp up/down time
//     .5 => float GRAIN_RAMP_FACTOR;
//     // playback rate
//     1 => float GRAIN_PLAY_RATE;
//     // grain position (0 start; 1 end)
//     0 => float GRAIN_POSITION;
//     // grain position randomization
//     .001 => float GRAIN_POSITION_RANDOM;
//     // grain jitter (0 == periodic fire rate)
//     1 => float GRAIN_FIRE_RANDOM;

//     // max lisa voices
//     30 => int LISA_MAX_VOICES;
//     // load file into a LiSa (use one LiSa per sound)
//     load( FILENAME ) @=> LiSa @ lisa;

//     // patch it
//     PoleZero blocker => NRev reverb => dac;
//     // connect
//     lisa.chan(0) => blocker;

//     // reverb mix
//     .05 => reverb.mix;
//     // pole location to block DC and ultra low frequencies
//     .99 => blocker.blockZero;


//     // HID objects
//     Hid hi;
//     HidMsg msg;

//     KBHit kb;


//     // which joystick
//     0 => int device;
//     // get from command line
//     if( me.args() ) me.arg(0) => Std.atoi => device;

//     // open joystick 0, exit on fail
//     if( !hi.openKeyboard( device ) ) me.exit();
//     // log
//     <<< "keyboard '" + hi.name() + "' ready", "" >>>;

//     // keycodes (for MacOS; may need to change for other systems)
//     49 => int KEY_DASH;
//     50 => int KEY_EQUAL;
//     51 => int KEY_COMMA;
//     52 => int KEY_PERIOD;
//     53 => int KEY_RIGHT;
//     54 => int KEY_LEFT;
//     55 => int KEY_DOWN;
//     56 => int KEY_UP;

//     // spork it
//     spork ~ print();
//     spork ~ keb();

//     // main loop
//     while( true )
//     {
//         // fire a grain
//         fireGrain();
//         // amount here naturally controls amount of overlap between grains
//         (GRAIN_LENGTH / 2 + Math.random2f(0,GRAIN_FIRE_RANDOM)::ms)/2 => now;
//     }

//     // fire!
//     fun void fireGrain()
//     {
//         // grain length
//         GRAIN_LENGTH => dur grainLen;
//         // ramp time
//         GRAIN_LENGTH * GRAIN_RAMP_FACTOR => dur rampTime;
//         // play pos
//         GRAIN_POSITION + Math.random2f(0,GRAIN_POSITION_RANDOM) => float pos;
//         // a grain
//         if( lisa != null && pos >= 0 )
//             spork ~ grain( lisa, pos * lisa.duration(), grainLen, rampTime, rampTime, 
//             GRAIN_PLAY_RATE );
//     }

//     // grain sporkee
//     fun void grain( LiSa @ lisa, dur pos, dur grainLen, dur rampUp, dur rampDown, float rate )
//     {
//         // get a voice to use
//         lisa.getVoice() => int voice;

//         // if available
//         if( voice > -1 )
//         {
//             // set rate
//             lisa.rate( voice, rate );
//             // set playhead
//             lisa.playPos( voice, pos );
//             // ramp up
//             lisa.rampUp( voice, rampUp );
//             // wait
//             (grainLen - rampUp) => now;
//             // ramp down
//             lisa.rampDown( voice, rampDown );
//             // wait
//             rampDown => now;
//         }
//     }

//     // print
//     fun void print()
//     {
//         // time loop
//         while( true )
//         {
//             // values
//             <<< "pos:", GRAIN_POSITION, "random:", GRAIN_POSITION_RANDOM,
//                 "rate:", GRAIN_PLAY_RATE, "size:", GRAIN_LENGTH/second >>>;
//             // advance time
//             100::ms => now;
//         }
//     }

//     // keyboard
//     fun void keb()
//     {
//         // infinite event loop
//         while( true )
//         {
//             // wait on (kb) as event
//             kb => now;
            
//             // messages received
//             while( kb.more() )
//             {
//                 // button donw
//                 kb.getchar() => int c;
//                 if( c == KEY_LEFT )
//                 {
//                     .005 -=> GRAIN_PLAY_RATE;
//                     if( GRAIN_PLAY_RATE < 0 ) 0 => GRAIN_PLAY_RATE;
//                 }
//                 else if( c == KEY_RIGHT )
//                 {
//                     .005 +=> GRAIN_PLAY_RATE;
//                     if( GRAIN_PLAY_RATE > 2 ) 2 => GRAIN_PLAY_RATE;
//                 }
//                 else if( c == KEY_DOWN )
//                 {
//                     .01 -=> GRAIN_POSITION;
//                     if( GRAIN_POSITION < 0 ) 0 => GRAIN_POSITION;
//                 }
//                 else if( c == KEY_UP )
//                 {
//                     .01 +=> GRAIN_POSITION;
//                     if( GRAIN_POSITION > 1 ) 1 => GRAIN_POSITION;
//                 }
//                 else if( c == KEY_COMMA )
//                 {
//                     .95 *=> GRAIN_LENGTH;
//                     if( GRAIN_LENGTH < 1::ms ) 1::ms => GRAIN_LENGTH;
//                 }
//                 else if( c == KEY_PERIOD )
//                 {
//                     1.05 *=> GRAIN_LENGTH;
//                     if( GRAIN_LENGTH > 1::second ) 1::second => GRAIN_LENGTH;
//                 }
//                 else if( c == KEY_DASH )
//                 {
//                     .9 *=> GRAIN_POSITION_RANDOM;
//                     if( GRAIN_POSITION_RANDOM < .000001 ) .000001 => GRAIN_POSITION_RANDOM;
//                 }
//                 else if( c == KEY_EQUAL )
//                 {
//                     1.1 *=> GRAIN_POSITION_RANDOM;
//                     if( GRAIN_POSITION_RANDOM > 1 ) 1 => GRAIN_POSITION_RANDOM;
//                 }
                
//             }
//         }
//     }

//     // load file into a LiSa
//     fun LiSa load( string filename )
//     {
//         // sound buffer
//         SndBuf buffy;
//         // load it
//         filename => buffy.read;
        
//         // new LiSa
//         LiSa lisa;
//         // set duration
//         buffy.samples()::samp => lisa.duration;
        
//         // transfer values from SndBuf to LiSa
//         for( 0 => int i; i < buffy.samples(); i++ )
//         {
//             // args are sample value and sample index
//             // (dur must be integral in samples)
//             lisa.valueAt( buffy.valueAt(i), i::samp );        
//         }
        
//         // set LiSa parameters
//         lisa.play( false );
//         lisa.loop( false );
//         lisa.maxVoices( LISA_MAX_VOICES );
        
//         return lisa;
//     }

// }