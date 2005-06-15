baseline(m, length).
longhand(metre, m).
longhand(meter, m).

baseline(g, mass). /* kg is derived from this by multiplier */
longhand(gramme, g).
longhand(gram, g).
longhand(kilogramme, kg).
longhand(kilogram, kg).

baseline(s, time).
longhand(second, s).

baseline(k, temperature).
longhand(kelvin, k).

baseline(rad, angle).
longhand(radian, rad).

unit_definition(deg,rad*180/3.1415927).
longhand(degree, deg).

unit_definition(l, m*m*m/1000).
longhand(litre, l).
longhand(liter, l).

unit_definition(gal, litre*454609/100000). /* not in USA */
longhand(gallon, gal).

unit_definition(pint,	gal/8).

unit_definition(minute,	s*60).
unit_definition(h,	minute*60).
longhand(hour, h).
unit_definition(day,	h*24).
unit_definition(week,	day*7).
unit_definition(month,	year/12).
unit_definition(year,	day*365). /* not quite right */

longhand(millimetre, mm).
longhand(centimetre, cm).
longhand(kilometre, km).
unit_definition(inch,	m*254/10000).
unit_definition(ft,	inch*12).
longhand(foot, ft).
unit_definition(yard,	foot*3).
unit_definition(mile,   yard*1760).

unit_definition(a, 10000*m*m).
longhand(are, a).
longhand(hectare, ha).

unit_definition(lb, kg*45359237/100000000). /* avoirdupois */
longhand(pound, lb).
unit_definition(oz,	lb/16).
longhand(ounce, oz).
unit_definition(stone,	lb*14).
unit_definition(cwt,	stone*8).
longhand(hundredweight, cwt).
unit_definition(ton,	cwt*20).

unit_definition('N',	kg*m/s/s).
longhand(newton, 'N').
unit_definition(dyne,	g*cm/s/s).
unit_definition(gravity,	(m/s/s)*(98/10)). 
	/* Acceleration due to gravity */
unit_definition(kgf,	kg*gravity).
unit_definition(lbf,	lb*gravity).

unit_definition('J',	'N'*m).
longhand(joule, 'J').
unit_definition(cal,	'J'*41868/10000).
longhand(calorie, cal).
longhand(kilocalorie, kcal).

unit_definition('W', 'J'/s).
unit_definition('Wh', 'W'*h). /* energy to power and back again, wtfn? */

longhand(watt, 'W').
longhand(kilowatt, kW).

unit_definition(bar, kgf/cm/cm).
unit_definition(psi, lbf/inch/inch).
unit_definition('Pa', newton/metre/metre).
unit_definition(percent, 0.01).
