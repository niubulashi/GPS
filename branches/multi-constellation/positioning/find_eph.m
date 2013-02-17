function icol = find_eph(Eph, sat, time)

% SYNTAX:
%   icol = find_eph(Eph, sat, time);
%
% INPUT:
%   Eph = ephemerides matrix
%   sat = satellite index
%   time = GPS time
%
% OUTPUT:
%   icol = column index for the selected satellite
%
% DESCRIPTION:
%   Selection of the column corresponding to the specified satellite
%   (with respect to the specified GPS time) in the ephemerides matrix.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.3.1 beta
%
% Copyright (C) Kai Borre
% Kai Borre and C.C. Goad 11-26-96
%
% Adapted by Mirko Reguzzoni, Eugenio Realini, 2009
%----------------------------------------------------------------------------------------------

isat = find(Eph(30,:) == sat);
n = size(isat,2);
if (n == 0)
    icol = [];
    return
end
icol = isat(1);
% time = check_t(time);
dtmin = Eph(18,icol) - time;
for t = isat
    dt = Eph(18,t) - time;
    if (abs(dt) < abs(dtmin))
        icol = t;
        dtmin = dt;
    end
end

%maximum interval from ephemeris reference time
dtmax = 3600;
switch (char(Eph(31,icol)))
    case 'R' %GLONASS
        dtmax = 900;
    case 'J' %QZSS
        dtmax = 900;
end
if (abs(dtmin) > dtmax)
    icol = [];
    return
end

%check satellite health
if (Eph(27,icol) ~= 0 && ~strcmp(char(Eph(31,icol)),'J')) %the second condition is temporary (QZSS health flag is kept on for tests)
    icol = [];
    return
end
