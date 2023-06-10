0 => int mode;
1 => int movement;
float leftHeight; float leftX; float leftY;
float rightHeight; float rightX; float rightY;

// differences
float leftDifVert; float rightDifVert;
float leftDif; float rightDif;
time lastPressed;


// z axis deadzone
0 => float DEADZONE;
// which joystick
0 => int device;
// how many times did we press the button
0 => int buttonPress;
//

KBHit kb;


// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;
// HID objects
Hid trak;
HidMsg msg;

// computer key input, with sound


// // patch
// //SinOsc f => dac;
// // set the filter's pole radius
// // initialize float variable
// 0.0 => float v;
// // set filter gain
// .5 => f.gain;

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

class Solo
{
    SndBuf choir[4] => ADSR soloEnv => NRev nrev0 => Gain choirgain;
    me.dir() + "choird.wav" => choir[0].read;
    soloEnv.set( 30::ms, 100::ms, .5, 30::ms );
    1 => choir[0].loop;
    0 => choir[0].pos;
    1 => choir[0].rate;
    [0, 7, 4, 5, 7, 2,  0, 7, 4, 5, 7, 8,   0, 7, 4, 5, 7, 2,  0, 7, 4, 5, 7, 8,  7, 0,   7, 0,   4, 0,   2, 0, 4] @=> int notes1[];
    [0, 2, 4, 5, 7, 8] @=> int cands1[];
    -1 => int prevpos;
    0 => int curNote;
    // 0 , 2,    4,  5,   7 ,  8
    // 0.1, 0.2, 0.3 0.4, 0.5, 0.6
    fun void vocalise(int notes[], int cands[], int movementCondition)
    {
        
        while(true)
        {
            if (movement != movementCondition)
            {
                muteGain(choirgain, 50);
                break;
            }
            else
            {
                // Height determines current position
                Math.min(cands.size() - 1, (rightHeight / 0.63 * cands.size())) $ int => int curpos;
                if (rightHeight < 0.01)
                {
                    muteGain(choirgain, 50);
                }
                // if rightHeight isn't too low, turn up the volume
                else if (choirgain.gain() < 0.01)
                {
                    adjustGain(choirgain, 1.0, 20);
                }
                else
                {
                    // based on the current position, 
                    if (curpos != prevpos)
                    {
                        // change note if the keys are fulfilled
                        if (curNote+1 < notes.size() && cands[curpos] == notes[curNote+1])
                        {
                            soloEnv.keyOff();
                            soloEnv.releaseTime() => now;
                            Math.pow(2, (cands[curpos]/12.0)) + 0.02 => choir[0].rate;
                            100 => choir[0].pos;
                            curpos => prevpos;
                            curNote++;
                            
                        }
                        soloEnv.keyOn();
                    }                
                }
            }
            // pass time
            0.03::second => now;
        }
    }
}

// gametrack
GameTrak gt;

// Solo
Solo solo;
Xylo xy;
Arpeggiator arp;

Ambience ab2;
Ambience ab3;

Ambience ab5;
Ambience ab6;
Rain rn;
Wind wn;

// spork control
spork ~ gametrak();
spork ~ solo.vocalise(solo.notes1, solo.cands1, 1);
spork ~ ab2.ambience(ab2.cands2, 2);
spork ~ ab3.ambience(ab3.cands3, 3);
spork ~ solo.vocalise(solo.notes1, solo.cands1, 4);
spork ~ ab5.ambience(ab5.cands2, 5);
spork ~ ab6.ambience(ab6.cands3, 6);
spork ~ xy.starlight();
spork ~ arp.arpeggiate(arp.notes1, arp.bassNotes1, 2);
spork ~ wn.windblows(3);
spork ~ rn.ctrlRain(3);
spork ~ keyboardctrl();


// kb
// spork ~ kbtest();

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

// fun void kbtest()
// {
//     // time-loop
//     while( true )
//     {
//         // wait on event
//         kb => now;
        

//         // loop through 1 or more keys
//         while( kb.more() )
//         {
//             // set filtre freq
//             kb.getchar() => int c => Std.mtof => f.freq;
//             // print int value
//             <<< "ascii:", c >>>;
//         }
//         0.1::second => now;
//     }
// }

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


class Thunder
{
    SndBuf thunder => Gain thundergain => NRev thunderrev => dac;
    me.dir() + "thunder.wav" => thunder.read;
    1 => thunder.loop;
    1 => thunder.rate;
    0.1 => thunderrev.mix;
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
            
            Std.fabs( Math.sin( g ) ) => n.gain;
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
                0 => windgain.gain;
            }
            else
            {
                if (leftDif > 0.005)
                {
                    leftDif * 10 => windgain.gain;
                }
                else
                {
                    0 => windgain.gain;
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
                0 => raingain.gain;
            }
            else
            {
                1 => raingain.gain;
                if (rightHeight > 0.3)
                {
                    (rightHeight - 0.3) * 2 => rainrev.gain; 
                }
                else
                {
                    0 => rainrev.gain;
                }
            }
            
            0.03::second => now;
        }
    }
    
}