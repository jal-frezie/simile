% leapYear true if it is else false
leapYear( Year ) -->
  if (fmod(Year, 100) == 0) then
     (fmod(Year, 400) == 0)
   else
     (fmod(Year, 4) == 0).

% dayOfYear
dayOfYear(Year,Month,Day) -->
  EndOfPrevMonth  =  [0,31,59,90,120,151,181,212,243,273,304,334],
  DOY=element(EndOfPrevMonth,Month)+Day, 
  choose(leapYear(Year), choose(Month>1,DOY + 1,DOY),DOY).

% Microsoft applications, and hence, most other Windows applications use a floating point number to represent 
% date and time as number of days from the beginning of 30 December 1989. The integral part of the float is 
% the date and the fractional part is time of day.
encodeDateTime(Year,Month,Day,Hour,Minute,Second) -->
	firstDayOfMonth=[1,32,60,91,121,152,182,213,244,274,305,335],
	StartFractionOfDay=(Hour+(Minute+Second/60)/60)/24,
	years_since_1900=Year-1900,
	numLeapYrs=int((years_since_1900-1)/4),
	Date=365*years_since_1900+numLeapYrs+element(firstDayOfMonth,Month)+Day+StartFractionOfDay,
	if 4*int(Year/4)==Year and Month>=3 then Date+1 
	else Date.

% dateTime 
% Use encodeDateTime function to to get a DateTime value for the calendar date and time of the start
% of the simulation and pass (influence) this as the parameter to dateTime
dateTime(StartDateTime) -->
	StartDateTime+time(_).

% 
julianDate(Year,Month,Day) -->
	firstDayOfMonth=[0,31,59,90,120,151,181,212,243,273,304,334],
	years_since_0=Year+4712,
	numLeapYrs=int((years_since_0-1)/4),
        Years=choose(Year>=1583,
		365*years_since_0+numLeapYrs-10-int((Year-1501)/100)+int((Year-1201)/400),
		365*years_since_0+numLeapYrs),
	Date=Years+element(firstDayOfMonth,Month)+Day,		
	if Year==1582 and ((Month==10 and Day>=15) or Month>=11) then Date-10.0
	elseif 4*int(Year/4)==Year and Month>=3 then Date+1 
	else Date.

% Return the date (integral) part of a date time value 
% - it is the  number of days from the beginning of 30 December 1989.
datePart(DateTime) -->
	int(DateTime).

% Return the time fractional part of a date time value as the fraction of a day
timePart(DateTime) -->
	DateTime - datePart(DateTime).

% hour
hour(TimePart) -->
	int(TimePart*24).

% minute
minute(TimePart) -->
	int(fmod(TimePart*24*60,60)).

% second
second(TimePart) -->
	fmod(TimePart*24*60*60,60).

% day
% month
month(DatePart) -->
	DatePart - int(DatePart/365)+1899.
% year
year(DatePart) -->
	int(DatePart/365)+1899.





