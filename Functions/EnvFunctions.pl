% Some Environmental physics functions
% Jonathan Massheder, Simulistics Ltd
% NOT FOR RELEASE 

% MUST BE VERIFIED

% universal gas constant (J mol^-1 K^-1)
gasConst(_) --> (8.3144). 

% acceleration due to gravity ( m s^2)
accelGrav(_) --> (9.8067).

%von Karman's constant - logarithmic wind profiles
vonKarman(_) --> (0.41).

%molecular masses (g mol^-1)
molMassH2O(_) --> (18).
molMassCO2(_) --> (44).
molMassDryAir(_) --> (28.964).

% specific heat capacities (J g^-1 K^-1)
spHtAir(_) --> (1.012).  
spHtWaterVap(_) --> (1.88).
spHtCO2(_) --> (0.85).

% Function satVapPress(Temp)
% Returns the saturated vapour pressure, svp, in kPa for the       
% temperature, Temp, in degrees C by                                  
% Tetens' formula from Montieth and Unsworth 1990 Principles of    
% Environmental Physics p10 adapted for T in deg C                 
% Values are within 1 Pa upto 35 deg C                             
satVapPress(Temp) --> 0.611 * exp(17.27 * (Temp) / (Temp + 237.15)).

% Function LatentHtH2O(Temp)
% returns the Latent heat of vapourisation of water at             
% temperature, Temp, degrees C in J g^-1                              
% Calculated from a regression of values in Monteith and Unsworth  
% 1990 Principles of Environmental Physics                         
latentHtH2O(Temp) --> (-2.336364 * Temp + 2500.627).

% molecular density of air (gas equation) 
% Temp temperature (K), Pressure (Pa)
molDensOfAir(Temp, Press) --> (Press) / (gasConst(_) * Temp).

% Function IncrSVPwithT (Temp)
% Returns the increase of SVP with temperature (Pa K^-1) 
% at temperature, Temp, (K)                                        
incrSVPwithT(Temp) -->
     1000.0 * (latentHtH2O(Temp) * molMassH2O(_) * svp(Temp)) /
                        (gasConst(_) * Temp*Temp+273.15).

% pressureWithAltitude (kPa)
% 1976 U.S. Standard atmosphere below 11000 m and ignoring geopotential height
% Altitude (m)
% result kPa
pressureWithAltitude(Altitude) -->
 101.35 * pow( (288.0/(288.0 - 0.0065*Altitude)) , -5.255877).

%function AltitudeFromPressure(Pressure : single) : single;
% Pressure {kPa}
% returns altitude where standard pressure equals Pressure {m}
altitudeFromPressure(Pressure) -->
 (1.0 - pow( (Pressure/101.35), 0.190284)) * (145366.45*0.3048).

% From Maestra utils.for
% beta function, 0 < R < 1
beta(A,B,C,R) -->
      if R = 0.0 then R=0.0000001,
      if R = 1.0 then R=0.9999999,
      A * (R^B) * ((1.0-R)^C).

% find the smaller root of a quadratic
quadraticSmaller(A,B,C) -->
  (- B - sqrt(B*B - 4.0*A*C)) / (2.0*A).

% find the larger root of a quadratic
quadraticLarger(A,B,C) -->
  (- B + sqrt(B*B - 4.0*A*C)) / (2.0*A).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Functions from:
% Meteorology Today For Scientists and Engineers:
% A Technical Companian Book. 
% Roland B. Stull. 1995 West Publishing  Co.

% Average radius of the earth (km)
averageRadiusOfEarth --> (6356.766).

% Mean horizontal windspeed (m/s) from U and V velocity components
% U (m/s) is from west to east, V (m/s) is from south to north
meanMeanHorizWindSpeedFromMetUandV(U,V) -->
  sqrt(U^2+V^2).

% Wind direction as a bearing in degrees from north (clockwise) 
% from U and V horizontal wind velocity components. 
% U is the east to west component (m/s) and
% V is the south to north component (m/s)
windDirectionFromMetUandV(U,V) -->
  180/pi(0)*atan2(V,U)+180.

% Return U (m/s): the east to west horizontal wind velocity component
% given the horizontal windspeed, M (m/s), and 
% wind direction, A (degrees clockwise from north)
uFromWindSpeedAndDirection(M,A) -->
  -(M*sin(a*180/pi(0))).

% Return V (m/s): the east to west horizontal wind velocity component
% given the horizontal windspeed, M (m/s), and 
% wind direction, A (degrees clockwise from north)
vFromWindSpeedAndDirection(M,A) -->
  -(M*cos(a*180/pi(0))).

% Ideal Gas Law
% P is pressure (Pa), T is Temperature (K), V is volume (m^3), N is moles

% Molar volume (mol m^-3) (mole density rather than mass density)
% P is pressure (Pa), Temperature (K)
molarVolume(P,T) -->
  P/(gasConst(_)*T).

pressureFromMolesTempPress(N,T,V) --> ( N*gasConst(_)*T/V ).

tempFromPressVolMoles(P,V,N) --> ( P*V/(N*gasConst(_)) ).

volumeFromMolesTempPress(N,T,P) --> ( N*gasConst(_)*T/P ).

molesFromPressVolTemp(P,V,T) --> ( P*V/(gasConst(_)*T) ).



