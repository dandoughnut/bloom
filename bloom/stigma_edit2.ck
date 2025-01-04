//OSC
OscOut oscOut;
"224.0.0.1" => string hostname;
6449 => int port;
oscOut.dest(hostname, port);

//movement and mode
1 => int movement;
0 => int mode;
-1 => int prevMode;
60 => int noteOSC;

//values
float leftHeight; float leftX; float leftY;
float rightHeight; float rightX; float rightY;

// differences
float leftDifVert; float rightDifVert;
float leftDif; float rightDif;

// lastPressed for button control
time lastPressed;

//DeadZone
// z axis deadzone
0 => float DEADZONE;
// which joystick
0 => int device;
// how many times did we press the button
0 => int buttonPress;

// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// HID objects & input objects
Hid trak;
HidMsg msg;
KBHit kb;

// keyboard control for movements
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
                0 => mode;
            }
            else if (c == 115)
            {
                movement--;
                0 => mode;
            }
            else if (c == 97)
            {
                mode--;
            }
            else if (c == 100)
            {
                mode++;
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

// gametrack
GameTrak gt;

// Classes
Solo solo1;

Ambience ab1;
Ambience ab2;
Ambience ab3;

Thunder t;
Rain rn;
Wind wn;
Xylo xy;
Finale fin;
Finale fin2;



// spork control
spork ~ gametrak();
spork ~ oscSend();
spork ~ solo1.vocalise(solo1.notes1, solo1.cands1, 1, 0.63);

// spork ~ ab1.ambience(ab1.cands1, 1);
// spork ~ ab2.ambience(ab2.cands2, 2);
// spork ~ ab3.ambience(ab3.cands3, 3);


spork ~ wn.windblows(3);
spork ~ rn.ctrlRain(3);

// spork ~ t.thunders(3);
spork ~ xy.starlight(3);
// spork ~ fin.finale();
// spork ~ fin2.lastNote();

//osc


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
    // advance time
    100::ms => now;
}

fun void oscSend()
{
    while(true)
    {
        oscOut.start("/oscCom");
        movement => oscOut.add;
        mode => oscOut.add;
        noteOSC => oscOut.add;
        oscOut.send();
        200::ms => now;
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

class Solo
{
    SndBuf choir[4] => ADSR soloEnv => NRev nrev0 => Gain choirgain => dac;
    me.dir() + "choird.wav" => choir[0].read;
    soloEnv.set( 30::ms, 100::ms, .5, 30::ms );
    1 => choir[0].loop;
    0 => choir[0].pos;
    1 => choir[0].rate;
    [0, 7, 4, 5, 7, 2,  0, 7, 4, 5, 7, 8,   0, 7, 4, 5, 7, 2,  0, 7, 4, 5, 7, 8,  7, 0,   7, 0,   4, 0,   2, 0, 4] @=> int notes1[];
    [0, 2, 4, 5, 7, 8] @=> int cands1[];
    [0, 7, 4, 5, 7, 2,  0, 7, 4, 5, 7, 9,   0, 7, 4, 5, 7, 11,  0, 7, 4, 5, 7, 12,  14,  16] @=> int notes4[];
    [0, 2, 4, 5, 7, 9, 11, 12, 14, 16] @=> int cands4[];
    -1 => int prevpos;
    0 => int curNote;
    // 0 , 2,    4,  5,   7 ,  8
    // 0.1, 0.2, 0.3 0.4, 0.5, 0.6
    fun void vocalise(int notes[], int cands[], int movementCondition, float maxThreshold)
    {
        
        while(true)
        {
            if (movement != movementCondition)
            {
                if (choirgain.gain() > 0.05) muteGain(choirgain, 50);
            }
            else
            {
                // Height determines current position
                Math.min(cands.size() - 1, (rightHeight / maxThreshold * cands.size())) $ int => int curpos;
                if (rightHeight < 0.05)
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

class Thunder
{
    SndBuf thunder => Gain thundergain => NRev thunderrev => dac;
    me.dir() + "thunder.wav" => thunder.read;
    1 => thunder.rate;
    0.1 => thunderrev.mix;
    0 => thundergain.gain;
    1 => int thunderYet;
    0 => int thunderSwitch;
    fun void thunders(int movementCondition)
    {
        while (true)
        {
            if (movement == movementCondition) 
            
            {
                if (rightHeight > 0.65 && leftHeight > 0.65)
                {
                    1 => thunderSwitch;
                }
                else if (rightHeight < 0.5 && leftHeight < 0.5 && thunderYet == 1)
                {
                    1 => thundergain.gain;
                    0 => thunder.pos;
                    0 => thunderYet;
                    2::second => now;
                    muteGain(thundergain, 100);
                    0.1::second => now;
                }
            }
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

class Finale
{
    SndBuf inst => ADSR finAdsr => NRev finRev => ResonZ finRes => Gain finGain => dac;
    // SndBuf inst => NRev finRev => ResonZ finRes => Gain finGain => dac;
    finAdsr.set(10::ms, 100::ms, 0.99, 50::ms);
    0.1 => finRev.mix;
    0 => finGain.gain;
    1 => inst.loop;

    // controlling current mode;
    -1 => int prevFinNote;
    0 => int introduced;

    // set which instrument (this is set)
    me.dir() + "choird.wav" => inst.read;
    
    // set when to introduce
    Math.random2(7, 10) => int introTime;
    Math.random2f(0.5, 3.5) => float delayTime;

    // [0, 7, 4, 5, 7, 2, 0, 7, 4, 5, 7, 12, 12, 12, 12, 12, 12] @=> int cands3[];
    // //[ 1, 2, 3, 4, 5]  [7, 8, 9, 10]   [12, 13, 14, 15, 16]
    fun void finale()
    {
        while (true)
        {
            if (movement == 3)
            {
                if (leftHeight < 0.5 && rightHeight < 0.5)
                {
                    if (finGain.gain() > 0.05) muteGain(finGain, 500);
                }
                else 
                {
                    if (mode >= 6)
                    {
                        if (finGain.gain() < 0.05) adjustGain(finGain, 10, 50);
                        
                        else if (mode == 12) play(0);
                        else if (mode == 13) play(7);
                        else if (mode == 14) play(4);
                        else if (mode == 15) play(5);
                        else if (mode == 16) play(7);
                    }  
                    
                }
                
            }
            else
            {
                if (finGain.gain() > 0.05) muteGain(finGain, 50);
            }
            0.05::second => now;
        }
    }

    fun void lastNote()
    {
        while (true)
        {
            if (movement == 3)
            {
                if (leftHeight < 0.5 && rightHeight < 0.5)
                {
                    if (finGain.gain() > 0.05) muteGain(finGain, 500);
                }
                else 
                {
                    if (mode == 16)
                    {
                        if (finGain.gain() < 0.05) adjustGain(finGain, 8, 1);
                        play(0);
                    }  
                }
            }
            else
            {
                if (finGain.gain() > 0.05) muteGain(finGain, 50);
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
            bassNote => prevFinNote;
            finAdsr.releaseTime();
            0 => inst.pos;
        }
        finAdsr.keyOn();
    }

}