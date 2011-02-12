function [doppler_app1, doppler_app2] = doppler_shift_approx(pos_R, vel_R, pos_S, vel_S, time, rec_clock_drift, sat, Eph)

% SYNTAX:
%   [doppler_app1, doppler_app2] = doppler_shift_approx(pos_R, vel_R, pos_S, vel_S, time, rec_clock_drift, sat, Eph);
%
% INPUT:
%   pos_R = approximate rover position
%   vel_R = approximate rover velocity
%   pos_S = satellite position at transmission time
%   vel_S = satellite velocity at transmission time
%   time = signal transmission GPS time
%   sat = satellite id number
%   rec_clock_drift = receiver clock drift
%   Eph = satellite ephemerides matrix
%
% OUTPUT:
%   doppler_app1 = approximate doppler shift on L1
%   doppler_app2 = approximate doppler shift on L2
%
% DESCRIPTION:
%   Computation of an approximate value of the doppler shift observation.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.1.3 alpha
%
% Copyright (C) 2009-2011 Mirko Reguzzoni, Eugenio Realini
%----------------------------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%----------------------------------------------------------------------------------------------

global lambda1 lambda2 v_light

LOS  = pos_S - pos_R;             %receiver-satellite line-of-sight vector
LOSu = LOS / norm(LOS);           %receiver-satellite line-of-sight unit vector [= LOS / sqrt(LOS(1)^2 + LOS(2)^2 + LOS(3)^2)]
vrel = vel_S - vel_R;             %receiver-satellite relative velocity vector
radial_vel = dot(vrel,LOSu);      %receiver-satellite radial velocity [= vrel(1)*LOSu(1) + vrel(2)*LOSu(2) + vrel(3)*LOSu(3)]
k = find_eph(Eph, sat, time);
af2   = Eph(2,k);
af1   = Eph(20,k);
tom   = Eph(21,k);
dt = check_t(time - tom);
sat_clock_drift = af1 + 2*af2*dt; %satellite clock drift
doppler_app1 = -(radial_vel + v_light*(rec_clock_drift - sat_clock_drift)) / lambda1;
doppler_app2 = -(radial_vel + v_light*(rec_clock_drift - sat_clock_drift)) / lambda2;

