# help messages for Time.pl. Jonathan Massheder.
# UNFINISHED
set msgs(leapYear) "leapYear(Year): returns true if the year is a leap year and false if not."

set msgs(dayOfYear) "dayOfYear(Year,Month,Day): returns the day of year 1 to 365 or 366 if \
        Year is a leap year, Month is the month number and Day is the day of the month."

set msgs(encodeDateTime) "encodeDateTime(Year,Month,Day,Hour,Minute,Second): returns \
        a floating point number representing date and time as the\
        number of days from the beginning of 30 December 1989. The integral part of \
        the number is the date and the fractional part is time of day. \
        This is compatible with most Microsoft applications."

set msgs(dateTime) "dateTime(StartDateTime): returns a calendar date and time value (see \
        encodeDateTime) for the current simulation time. StartDateTime is a calendar date and time \
        value for the start of the simulation. Use encodeDateTime function to to get a DateTime \
        value for the calendar date and time of the start of the simulation \
        and pass (influence) this as the parameter to dateTime."

set msgs(julianDate) "julianDate(Year,Month,Day): returns days since noon \
        1 January 4713 BC. Used in astronomy."

set msgs(datePart) "datePart(DateTime): returns the date (integral) part of a date time value \
        - it is the  number of days from the beginning of 30 December 1989."


set msgs(timePart) "timePart(DateTime): returns the time fractional part of a date time value as \
        the fraction of a day"

