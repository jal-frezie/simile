# help messages for EnvFunctions.pl. Jonathan Massheder.
set msgs(gasConst) "gasConst(): returns the universal gas constant, 8.3144 (J mol^-1 K^-1)"
set msgs(accelGrav) "accelGrav(): returns the acceleration due to gravity, 9.8067 (m s^2)"
set msgs(vonKarman) "vonKarman(): returns von Karman's constant for logarithmic wind profiles, \
        0.41 (dimensionless)"

set msgs(molMassH2O) "molMassH2O(): returns the molecular mass of water, 18 (g mol^-1)"
set msgs(molMassCO2) "molMassCO2(): returns the molecular mass CO2 44 (g mol^-1)"
set msgs(molMassDryAir) "molMassDryAir(): returns the molecular mass dry air 28.964 (g mol^-1)"

set msgs(spHtAir)     "spHtAir(): returns the specific heat capacity of dry air, 1.012 (J g^-1 K^-1)"
set msgs(spHtWaterVap) "spHtWaterVap(): returns the specific heat capacity of water vapour, 1.88 (J g^-1 K^-1)"
set msgs(spHtCO2)     "spHtCO2(): returns the specific heat capacity of CO2, --> 0.85 (J g^-1 K^-1)"

set msgs(satVapPress) "satVapPress(T): returns saturation vapour pressure in kPa at temperature T (Celcius). \
        Tetens' formula from Montieth and Unsworth 1990 Principles of \
        Environmental Physics p10 adapted for T in deg C \
        Values are within 1 Pa upto 35 deg C"
set msgs(latentHtH2O) "latentHtH2O(Temp): returns the latent heat of vapourisation of water at \
        temperature, Temp, degrees C in J g^-1. Calculated from a regression of values in Monteith and \
        Unsworth 1990 Principles of Environmental Physics"
set msgs(molDensOfAir) "molDensOfAir(T, P): returns the molar volume of air in mol m^-3 \
        at temperature, T (K), and pressure, P (Pa), using the ideal gas equation."
set msgs(incrSVPwithT) "incrSVPwithT(T): returns the increase of saturated vapour pressure \
        with temperature in Pa K^-1, at temperatureT (K)"

# unfinshed