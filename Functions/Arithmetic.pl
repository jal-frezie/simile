% returns the sign of a number, -1 if negative or 1 if positive
sgn(real) --> choose(real==0,1,int(real/abs(real))).

% Added for XMILE

% Value of infinity
inf('') --> -log(0).

% delay functions
delay1(input,delay) --> delayf(input,delay,1,input).
delay1(input,delay,initial) --> delayf(input,delay,1,initial).
delay3(input,delay) --> delayf(input,delay,3,input).
delay3(input,delay,initial) --> delayf(input,delay,3,initial).
delayn(input,delay,n) --> delayf(input,delay,n,input).
delayn(input,delay,n,initial) --> delayf(input,delay,n,initial).

forcst(input,averaging,horizon) -->
    input*(1+trendf(input,averaging,0)*horizon).
forcst(input,averaging,horizon,initial) -->
    input*(1+trendf(input,averaging,initial)*horizon).

smth1(input,averaging) --> smthf(input,averaging,1,input).
smth1(input,averaging,initial) --> smthf(input,averaging,1,initial).
smth3(input,averaging) --> smthf(input,averaging,3,input).
smth3(input,averaging,initial) --> smthf(input,averaging,3,initial).
smthn(input,averaging,n) --> smthf(input,averaging,n,input).
smthn(input,averaging,n,initial) --> smthf(input,averaging,n,initial).

trend(input,averaging) --> trendf(input,averaging,0).
trend(input,averaging,initial) --> trendf(input,averaging,initial).

% test input functions
pulse(magnitude, initial, interval) -->
    if interval==0 then pulse(magnitude, initial)
    elseif (time()-initial)/interval >=0 and fmod(time(),interval)<dt()
        then magnitude/dt()
    else 0.

pulse(magnitude, initial) -->
    if time()-initial<dt()
        then magnitude/dt()
    else 0.

ramp(slope,start_time) -->
    slope*max(0,time()-start_time).

step(height,start_time) -->
    choose(time()>=start_time,height,0).

