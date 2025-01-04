/////// osc
SinOsc osc => ADSR env => dac;
env => NRev reverb => dac;
0.25 => osc.gain;
(1::ms, 100::ms, 0, 1::ms) => env.set;
0.1 => reverb.mix;

"224.0.0.1" => string hostname;
6449 => int port;
OscIn oscIn;
port => oscIn.port;
OscMsg oscMsg;
oscIn.addAddress("/oscCom");

// overall mode number based on how many times the button has been pushed
0 => int mode;
1 => int movement;
60 => int noteOSC;
-1 => int prevNoteOSC;
float leftHeight; float leftX; float leftY;
float rightHeight; float rightX; float rightY;
float leftDifVert; float rightDifVert;
float leftDif; float rightDif;

time lastPressed; // controlled by Stigma


// turnoff switches
int switch1, switch2, switch3;
true => switch1 => switch2 => switch3;


// instruments
string instrument[7];
"boyschoir.wav" => instrument[0];
"cello.wav" => instrument[1];
"cinema.wav" => instrument[2];
"horn.wav" => instrument[3];
"japanflute.wav" => instrument[4];
"mixchoir.wav" => instrument[5];
"naflute.wav" => instrument[6];



//////////EVERYTHING NON-MUSIC//////////////////////
fun void oscRcv()
{
    while (true)
    {
        <<< "waiting for an OSC message..." >>>;
        oscIn => now;
        while (oscIn.recv(oscMsg) != 0)
        {
            oscMsg.getInt(0) => movement;
            oscMsg.getInt(1) => mode;
            oscMsg.getInt(2) => noteOSC;
            <<< "movement and mode", movement, mode >>>;
            100::ms => now;
        }
    }
}


// Keyboard
KBHit kb;
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


fun void keyboardctrl()
{
    while( true )
    {
        // wait on event
        kb => now;
        // loop through 1 or more keys
        <<< "controlling with keyboard" >>>;
        while( kb.more() )
        {
            // set filtre freq
            kb.getchar() => int c;
            if (c == 119) 
            {
                if (movement < 3) movement++;
                0 => mode;
            }
            else if (c == 115) 
            {
                if (movement > 1) movement--;
                0 => mode;
            }
            else if (c == 97) mode--;
            else if (c == 100) mode++;
            
            // print int value
            <<< "ascii:", c >>>;
            <<< "movement", movement, "mode", mode >>>;
        }
        0.05::second => now;
    }
}

// gametrack
GameTrak gt;
Ambience ab;
Ambience ab2;
Ambience ab3;

Arpeggiator arp;

Rain rn;
Wind wn;
Xylo xy;
Finale fin;

// gametrak control
spork ~ gametrak();
//osc
spork ~ oscRcv();
// keyboard control
spork ~ keyboardctrl();

//music
spork ~ ab.ambience(ab.cands1, 1);
spork ~ ab2.ambience(ab.cands2, 2);
spork ~ ab3.ambience(ab.cands3, 3);

spork ~ arp.arpeggiate(arp.notes1, arp.bassNotes1, 2);

spork ~ xy.starlight(3);
spork ~ wn.windblows(3);
spork ~ rn.ctrlRain(3);
//spork ~ fin.finale();


// main loop
while( true )
{
    <<< leftHeight, rightHeight, leftDif, rightDif >>>;
    gt.axis[5] => rightHeight;
    gt.axis[2] => leftHeight;
    Math.sqrt(Math.pow((gt.axis[0]-gt.lastAxis[0]), 2) + Math.pow((gt.axis[1]-gt.lastAxis[1]), 2)) => leftDif;
    Math.sqrt(Math.pow((gt.axis[3]-gt.lastAxis[3]), 2) + Math.pow((gt.axis[4]-gt.lastAxis[4]), 2)) => rightDif;
    Math.sqrt(Math.pow((gt.axis[5]-gt.lastAxis[5]), 2)) => rightDifVert;
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
        }
    }
}


class Ambience
{
    SndBuf amb[4] => ADSR ambAdsr => Gain ambGain => NRev ambRev => ResonZ ambReson => dac;
    -1 => int prevMode;
    me.dir() + "ambient0.wav" => amb[0].read; 
    ambAdsr.set(100::ms, 150::ms, 0.8, 100::ms);
    1 => amb[0].loop;
    0 => amb[0].pos;
    1 => amb[0].gain;
    0.05 => ambRev.mix;
    1 => amb[0].rate;
    [0, 5, 0, 1, 0, 5, 0, 1, 4, 5, 4, -5, 0] @=> int cands1[];
    [0, 7, 4, 5, 7, 0, 0, 0] @=> int cands2[];
    [0, 7, 4, 5, 7, 2, 0, 7, 4, 5, 7, 12, 12, 12, 12, 12, 12] @=> int cands3[];
    //[ 1, 2, 3, 4, 5]  [7, 8, 9, 10]   [12, 13, 14, 15, 16]
    
    fun void ambience(int cands[], int movementCondition)
    {
        while (true)
        {
            if (movement != movementCondition)
            {
                muteGain(ambGain, 50);
            }
            else // (movement == movementCondition)
            {
                if (rightHeight < 0.1) muteGain(ambGain, 50);
            
                else if (ambRev.gain() < 0.1) adjustGain(ambGain, 1, 50);
                
                else
                {
                    Math.max(0, (rightHeight - 0.1) * 5)  => ambGain.gain;
                    if (prevMode != mode)
                    {
                        Math.pow(2, cands[mode % cands.size()]/12.0) => float bass;
                        ambAdsr.keyOff();
                        ambAdsr.releaseTime();
                        bass => amb[0].rate;
                        mode => prevMode;
                    }
                    ambAdsr.keyOn();
                }
            }
            0.05::second => now;
        }
    }
}

class Arpeggiator
{
    // channel 0
    SinOsc lfo0 => TriOsc petal0 => ADSR e => Gain arpGain => NRev arpRev => ResonZ resonz0 => dac;
    // set ADSR
    e.set( 50::ms, 50::ms, .9, 500::ms );
    3 => lfo0.freq;
    2 => petal0.sync;
    0.1 => arpRev.mix;
    1.0 => arpRev.gain;
    40 => resonz0.freq;
    [0, 4, 7, 11, 12] @=> int notes1[];
    [62, 69, 66, 67, 69, 62, 62] @=> int bassNotes1[];
    -1 => int prevNote;
    -1 => int curNote;
    fun void arpeggiate(int notes[], int bassNotes[], int movementCondition)
    {
        0 => int curr;
        while (true)
        {
           mode => int curMode;
           if (movementCondition != movement)
           {
                if (arpGain.gain() > 0.05)
                {
                    muteGain(arpGain, 50);
                }
           }
           else // correct movement
           {
               if (leftHeight < 0.1)
               {
                    muteGain(arpGain, 50);
               }
               else if (arpGain.gain() < 0.05)
                   {
                       adjustGain(arpGain, 1, 50);
                   }
               else
               {
                    Math.min(notes.size() - 1, Math.floor((leftHeight - 0.1) / 0.5 * (notes.size() - 1))) $ int => int arpNote;
                    bassNotes[mode % bassNotes.size()] + notes[ arpNote ] => curNote;
                
                   if (curNote != prevNote)
                   {
                        e.keyOff();
                        e.releaseTime();
                        Std.mtof(curNote) => petal0.freq;
                        e.keyOn();
                        curNote => prevNote;
                   } 
               }
           }
           
           0.1::second => now;
        }
    }
}

class Xylo
{
    ModalBar bar => Gain xylogain => NRev xylorev => ResonZ xylorez => dac;
    0.1 => xylorev.mix;
    1 => bar.gain;
    2 => xylorev.gain;
    // scale
    [0, 4, 7, 11] @=> int scale[];
    fun void starlight(int movementCondition)
    {
        // infinite time loop
        while( true )
        {
            if (movementCondition != movement)
            {
                muteGain(xylogain, 50);
            }
            else
            {
                if (rightHeight > 0.6 && leftHeight > 0.6)
                {
                    if (xylogain.gain() < 0.1)
                    {
                        spork ~ adjustGain(xylogain, 6, 3000);
                    }
                    <<< "starlight" >>>;
                    // ding!
                    4 => bar.preset;
                    Math.random2f( 0.5, 0.6 ) => bar.stickHardness;
                    Math.random2f( 0.5, 0.7 ) => bar.strikePosition;
                    Math.random2f( 0.01, 0.1 ) => bar.vibratoGain;
                    0.01 => bar.vibratoFreq;
                    Math.random2f( 0.7, 0.9 ) => bar.volume;
                    Math.random2f( .8, 1 ) => bar.directGain;
                    Math.random2f( .7, .95 ) => bar.masterGain;
                    // set freq
                    scale[Math.random2(0,scale.size()-1)] => int winner;
                    74 + Math.random2(0,1)*12 + winner => Std.mtof => bar.freq;
                    // go
                    if (Math.random2f(0, 1.0) < 0.7)
                    {
                        .85 => bar.noteOn;
                    }
                }
            }
            // advance time
            .33::second => now;
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
    0.0 => windgain.gain;
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
    fun void windblows (int movementCondition)
    {
        spork ~ wind_gain();
        // infinite time-loop
        while( true )
        {
            if (movement != movementCondition)
            {
                if (windgain.gain() > 0.05) muteGain(windgain, 50);
            }
            else // correct movement
            {
                if (leftHeight < 0.12)
                {
                    if (windgain.gain() > 0.05) muteGain(windgain, 50);
                }
                else if (leftHeight > 0.63 && rightHeight > 0.63)
                {
                    muteGain(windgain, 600);
                    5::second => now;
                    windgain =< dac;
                    <<< "muting wind gain completely" >>>;
                }
                else
                {
                    if (leftDif > 0.03)
                    {
                        windgain.gain() => float curWindGain;
                        Math.min(0.6, curWindGain + leftDif * 2.5) => float newWindGain;
                        adjustGain(windgain, newWindGain, 20);
                        100::ms => now;
                    }
                    else if (windgain.gain() > 0)
                    {
                        windgain.gain() - 0.01 => float nextWindGain;
                        nextWindGain => windgain.gain;
                    }
                }
            }
            100::ms => now;
        }
    }
}

class Rain
{
    SndBuf rainbuf => NRev rainrev => Gain raingain => dac;
    me.dir() + "rain.wav" => rainbuf.read;
    0.05 => rainrev.mix;
    1 => rainrev.gain;
    1 => rainbuf.loop;
    0 => raingain.gain;
    fun void ctrlRain(int movementcon)
    {
        while (true)
        {
            if (movement != movementcon) muteGain(raingain, 50);
            else if (leftHeight > 0.63 && rightHeight > 0.63)
            {
                muteGain(raingain, 600);
                5::second => now;
                raingain =< dac;
                <<< "muting rain gain completely" >>>;
            }
            else
            {
                if (rightHeight < 0.1) muteGain(raingain, 50);
                else
                {
                    raingain.gain() => float curRainGain;
                    curRainGain * 0.33 + (rightHeight - 0.1) * 2 * 0.67 => float newGain;
                    adjustGain(raingain, newGain, 250); 
                }
            }
            0.02::second => now;
        }
    }
}

class Finale
{
    SndBuf inst => ADSR finAdsr => NRev finRev => ResonZ finRes => Gain instGain => Gain finGain => dac;
    finAdsr.set(100::ms, 100::ms, 0.99, 100::ms);
    0.1 => finRev.mix;
    0 => finGain.gain;

    // controlling current mode;
    -1 => int prevFinNote;

    // set which instrument (this is set)
    Math.random2(0, 6) => int which;
    me.dir() + instrument[which] => inst.read;

    // set when to introduce
    Math.random2(7, 10) => int when;


    // [0, 7, 4, 5, 7, 2, 0, 7, 4, 5, 7, 12, 12, 12, 12, 12, 12] @=> int cands3[];
    // //[ 1, 2, 3, 4, 5]  [7, 8, 9, 10]   [12, 13, 14, 15, 16]
    fun void finale()
    {
        while (true)
        {
            if (movement == 3)
            {
                if (leftHeight < 0.6 && rightHeight < 0.6)
                {
                    if (finGain.gain() > 0.05) muteGain(finGain, 50);
                }
                else if (mode == 6)
                {
                    if (finGain.gain() < 0.1) adjustGain(finGain, 1, 50);
                }
                else if (mode == 12) play(0);
                else if (mode == 13) play(7);
                else if (mode == 14) play(4);
                else if (mode == 15) play(5);
                else if (mode == 16) play(7);
                
            }
            0.05::second => now;
        }
    }

    fun void play(int bassNote)
    {
        if (bassNote != prevFinNote)
        {
            finAdsr.keyOff();
            Math.pow(2, bassNote/12.0) => float bass;
            bass => inst.rate;
            finAdsr.releaseTime();
        }
        finAdsr.keyOn();
    }

}





//gain adjust helpers
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
