SndBuf dan => dac;

string instrument[7];
"boyschoir.wav" => instrument[0];
"cello.wav" => instrument[1];
"cinema.wav" => instrument[2];
"horn.wav" => instrument[3];
"japanflute.wav" => instrument[4];
"mixchoir.wav" => instrument[5];
"naflute.wav" => instrument[6];

// 0.05 => r.mix;
0 => int which;
while (true)
{
    Math.random2(0, 7) => int n;
    <<< n >>>;
    1::second => now;
}
