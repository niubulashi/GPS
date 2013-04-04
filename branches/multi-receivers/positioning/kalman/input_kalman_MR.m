function [A, probs_pr1, probs_ph1, prapp_pr1, prapp_ph1, probs_pr2, probs_ph2, prapp_pr2, prapp_ph2] = input_kalman_MR(Xb_approx, XS, pr1_R, ph1_R, pr1_M, ph1_M, pr2_R, ph2_R, pr2_M, ph2_M, err_tropo_R, err_iono_R, err_tropo_M, err_iono_M, distR_approx, distM, sat, pivot, attitude_approx, geometry, F_Ai, F_PR_DD, F_s_X)

% SYNTAX:
%   [A, probs_pr1, probs_ph1, prapp_pr1, prapp_ph1, probs_pr2, probs_ph2, prapp_pr2, prapp_ph2] = input_kalman(XR_approx, XS, pr1_R, ph1_R, pr1_M, ph1_M, pr2_R, ph2_R, pr2_M, ph2_M, err_tropo_R, err_iono_R, err_tropo_M, err_iono_M, distR_approx, distM, sat, pivot);
%
% INPUT:
%   XR_approx = receiver approximate position (X,Y,Z)
%   XS = satellite position (X,Y,Z)
%   pr1_R = ROVER-SATELLITE code pseudorange (carrier L1)
%   ph1_R = ROVER-SATELLITE phase observations (carrier L1)
%   pr1_M = MASTER-SATELLITE code pseudorange (carrier L1)
%   ph1_M = MASTER-SATELLITE phase observations (carrier L1)
%   pr2_R = ROVER-SATELLITE code pseudorange (carrier L2)
%   ph2_R = ROVER-SATELLITE phase observations (carrier L2)
%   pr2_M = MASTER-SATELLITE code pseudorange (carrier L2)
%   ph2_M = MASTER-SATELLITE phase observations (carrier L2)
%   err_tropo_R = ROVER-SATELLITE tropospheric error
%   err_iono_R  = ROVER-SATELLITE ionospheric error
%   err_tropo_M = MASTER-SATELLITE tropospheric error
%   err_iono_M  = MASTER-SATELLITE ionospheric error
%   distR_approx = ROVER-SATELLITE approximate range
%   distM = MASTER-SATELLITE range
%   sat = configuration of visible satellites
%   pivot = pivot satellite
%
% OUTPUT:
%   A = parameters obtained from the linearization of the observation equation,
%       e.g. ((xR-xS)/prRS)-((xR-xP)/prRP)
%   probs_pr1 = observed code double differences (carrier L1)
%   probs_ph1 = observed phase double differences (carrier L1)
%   prapp_pr1 = approximate code double differences (carrier L1)
%   prapp_ph1 = approximate phase double differences (carrier L1)
%   probs_pr2 = observed code double differences (carrier L2)
%   probs_ph2 = observed phase double differences (carrier L2)
%   prapp_pr2 = approximate code double differences (carrier L2)
%   prapp_ph2 = approximate phase double differences (carrier L2)
%
% DESCRIPTION:
%   This function computes the parameters needed to apply the Kalman filter.
%   Transition matrix that link state variables to GPS observations.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.3.1 beta
%
% Copyright (C) 2009-2012 Mirko Reguzzoni, Eugenio Realini
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

%variable initialization
global lambda1 lambda2

%pivot search
pivot_index = find(pivot == sat);




%number of observations
nRec=size(pr1_R,2);
n = 2*size(pr1_R,1)*(nRec);

%number of unknown parameters
m = 3 + (n/2) + 3; % must be corrected later for the pivot pivot ambiguity


% %approximate receiver-satellite distance
% distR_approx=NaN(n/2/(nRec),nRec);


%Xb_approx=mean([XR_approx(:,1,1), XR_approx(:,1,2),XR_approx(:,1,3)],2);
[phi_b_apriori, lam_b_apriori, h_b_apriori] = cart2geod(Xb_approx(1), Xb_approx(2), Xb_approx(3));




A=zeros(n,m);

%design matrix , known term vector, observation vector (code)
for i=1:nRec
    for j=1:size(pr1_R,1)
        A(j+(i-1)*size(pr1_R,1),1:6)=F_Ai(XS(j,1), XS(pivot_index,1), Xb_approx(1), XS(j,2), XS(pivot_index,2), Xb_approx(2), XS(j,3), XS(pivot_index,3), Xb_approx(3), lam_b_apriori, phi_b_apriori, attitude_approx(2), attitude_approx(1), geometry(1,i), geometry(2,i), attitude_approx(3), geometry(3,i));
        %b=[b;F_PR_DD(XM(1),XS(j,1), XS(pivot_index,1), Xb_approx(1), XM(2), XS(j,2), XS(pivot_index,2), Xb_approx(2), XM(3), XS(j,3), XS(pivot_index,3), Xb_approx(3), lam_b_apriori, phi_b_apriori, attitude(2), attitude(1), geometry(1,i), geometry(2,i), attitude(3), geometry(3,i)) + ...
        %    (err_tropo_R(j,i) - err_tropo_M(j,1)) - (err_tropo_R(pivot_index,i)  - err_tropo_M(pivot_index,1)) + ...
        %    (err_iono_R(j,i)  - err_iono_M(j,1))  - (err_iono_R(pivot_index,i)   - err_iono_M(pivot_index,1))];
        %y0=[y0; (pr_R(j,i) - pr_M(j,1)) - (pr_R(pivot_index,i) - pr_M(pivot_index,1))];
    end
end

%design matrix , known term vector, observation vector (phase)
for i=1:nRec
    for j=1:size(pr1_R,1)
        A(nRec*size(pr1_R,1)+j+(i-1)*size(pr1_R,1),1:6)=F_Ai(XS(j,1), XS(pivot_index,1), Xb_approx(1), XS(j,2), XS(pivot_index,2), Xb_approx(2), XS(j,3), XS(pivot_index,3), Xb_approx(3), lam_b_apriori, phi_b_apriori, attitude_approx(2), attitude_approx(1), geometry(1,i), geometry(2,i), attitude_approx(3), geometry(3,i));
%         b=[b;F_PR_DD(XM(1),XS(j,1), XS(pivot_index,1), Xb_approx(1), XM(2), XS(j,2), XS(pivot_index,2), Xb_approx(2), XM(3), XS(j,3), XS(pivot_index,3), Xb_approx(3), lam_b_apriori, phi_b_apriori, attitude(2), attitude(1), geometry(1,i), geometry(2,i), attitude(3), geometry(3,i)) + ...
%             (err_tropo_R(j,i) - err_tropo_M(j,1)) - (err_tropo_R(pivot_index,i)  - err_tropo_M(pivot_index,1)) - ...
%             (err_iono_R(j,i)  - err_iono_M(j,1))  + (err_iono_R(pivot_index,i)   - err_iono_M(pivot_index,1))];
%         y0=[y0; lambda*((ph_R(j,i) - ph_M(j,1)) - (ph_R(pivot_index,i) - ph_M(pivot_index,1)))];
        A(nRec*size(pr1_R,1)+j+(i-1)*size(pr1_R,1),6+(i-1)*size(pr1_R,1)+j)=-lambda1;
    
    end
end


%remove pivot-pivot lines
A(pivot_index:size(pr1_R,1):end, :) = [];
A(            :, 6+pivot_index:size(pr1_R,1):end)= [];
[n,m]=size(A);


%observed pseudoranges
probs_pr1=[];
probs_ph1=[];
probs_pr2=[];
probs_ph2=[];  % sistemare la doppia frequenza!
for i=1:nRec
    probs_pr1_i  = (pr1_R(:,i) - pr1_M) - (pr1_R(pivot_index,i) - pr1_M(pivot_index));  %observed pseudorange DD (L1 code)
    probs_ph1_i  = (lambda1 * ph1_R(:,i) - lambda1 * ph1_M) - (lambda1 * ph1_R(pivot_index,i) - lambda1 * ph1_M(pivot_index)); %observed pseudorange DD (L1 phase)
    
    %remove pivot-pivot lines
    probs_pr1_i(pivot_index) = [];
    probs_ph1_i(pivot_index) = [];
    
    probs_pr1=[probs_pr1;probs_pr1_i];
    probs_ph1=[probs_ph1;probs_ph1_i];
end


prapp_pr=[];
prapp_pr1=[];
prapp_ph1=[];
prapp_pr2=[];
prapp_ph2=[];

for i=1:nRec
    prapp_pr_i  =              (distR_approx(:,i) - distM)      - (distR_approx(pivot_index,i) - distM(pivot_index));       %approximate pseudorange DD
    prapp_pr_i  = prapp_pr_i + (err_tropo_R(:,i) - err_tropo_M) - (err_tropo_R(pivot_index,i)  - err_tropo_M(pivot_index)); %tropospheric error DD
    prapp_pr1_i = prapp_pr_i + (err_iono_R(:,i)  - err_iono_M)  - (err_iono_R(pivot_index,i)   - err_iono_M(pivot_index));  %ionoshperic error DD (L1 code)
    prapp_ph1_i = prapp_pr_i - (err_iono_R(:,i)  - err_iono_M)  - (err_iono_R(pivot_index,i)   - err_iono_M(pivot_index));  %ionoshperic error DD (L1 phase)
    
    %remove pivot-pivot lines
    prapp_pr1_i(pivot_index) = [];
    prapp_ph1_i(pivot_index) = [];

    prapp_pr1=[prapp_pr1;prapp_pr1_i];
    prapp_ph1=[prapp_ph1;prapp_ph1_i];
    
end

% 
% %approximate pseudoranges
% prapp_pr  =            (distR_approx - distM)      - (distR_approx(pivot_index) - distM(pivot_index));       %approximate pseudorange DD
% prapp_pr  = prapp_pr + (err_tropo_R - err_tropo_M) - (err_tropo_R(pivot_index)  - err_tropo_M(pivot_index)); %tropospheric error DD
% prapp_pr1 = prapp_pr + (err_iono_R  - err_iono_M)  - (err_iono_R(pivot_index)   - err_iono_M(pivot_index));  %ionoshperic error DD (L1 code)
% prapp_ph1 = prapp_pr - (err_iono_R  - err_iono_M)  - (err_iono_R(pivot_index)   - err_iono_M(pivot_index));  %ionoshperic error DD (L1 phase)
% prapp_pr2 = prapp_pr + (lambda2/lambda1)^2 * ((err_iono_R - err_iono_M) - (err_iono_R(pivot_index) - err_iono_M(pivot_index)));  %ionoshperic error DD (L2 code)
% prapp_ph2 = prapp_pr - (lambda2/lambda1)^2 * ((err_iono_R - err_iono_M) - (err_iono_R(pivot_index) - err_iono_M(pivot_index)));  %ionoshperic error DD (L2 phase)



























% 
% %design matrix
% A = [((XR_approx(1) - XS(:,1)) ./ distR_approx) - ((XR_approx(1) - XS(pivot_index,1)) / distR_approx(pivot_index)), ... %column for X coordinate
%      ((XR_approx(2) - XS(:,2)) ./ distR_approx) - ((XR_approx(2) - XS(pivot_index,2)) / distR_approx(pivot_index)), ... %column for Y coordinate
%      ((XR_approx(3) - XS(:,3)) ./ distR_approx) - ((XR_approx(3) - XS(pivot_index,3)) / distR_approx(pivot_index))];    %column for Z coordinate
% 
% %observed pseudoranges
% probs_pr1  = (pr1_R - pr1_M) - (pr1_R(pivot_index) - pr1_M(pivot_index));  %observed pseudorange DD (L1 code)
% probs_pr2  = (pr2_R - pr2_M) - (pr2_R(pivot_index) - pr2_M(pivot_index));  %observed pseudorange DD (L2 code)
% probs_ph1  = (lambda1 * ph1_R - lambda1 * ph1_M) - (lambda1 * ph1_R(pivot_index) - lambda1 * ph1_M(pivot_index)); %observed pseudorange DD (L1 phase)
% probs_ph2  = (lambda2 * ph2_R - lambda2 * ph2_M) - (lambda2 * ph2_R(pivot_index) - lambda2 * ph2_M(pivot_index)); %observed pseudorange DD (L2 phase)
% 
% %approximate pseudoranges
% prapp_pr  =            (distR_approx - distM)      - (distR_approx(pivot_index) - distM(pivot_index));       %approximate pseudorange DD
% prapp_pr  = prapp_pr + (err_tropo_R - err_tropo_M) - (err_tropo_R(pivot_index)  - err_tropo_M(pivot_index)); %tropospheric error DD
% prapp_pr1 = prapp_pr + (err_iono_R  - err_iono_M)  - (err_iono_R(pivot_index)   - err_iono_M(pivot_index));  %ionoshperic error DD (L1 code)
% prapp_ph1 = prapp_pr - (err_iono_R  - err_iono_M)  - (err_iono_R(pivot_index)   - err_iono_M(pivot_index));  %ionoshperic error DD (L1 phase)
% prapp_pr2 = prapp_pr + (lambda2/lambda1)^2 * ((err_iono_R - err_iono_M) - (err_iono_R(pivot_index) - err_iono_M(pivot_index)));  %ionoshperic error DD (L2 code)
% prapp_ph2 = prapp_pr - (lambda2/lambda1)^2 * ((err_iono_R - err_iono_M) - (err_iono_R(pivot_index) - err_iono_M(pivot_index)));  %ionoshperic error DD (L2 phase)
% 
% %remove pivot-pivot lines
% A(pivot_index, :)      = [];
% probs_pr1(pivot_index) = [];
% probs_ph1(pivot_index) = [];
% probs_pr2(pivot_index) = [];
% probs_ph2(pivot_index) = [];
% prapp_pr1(pivot_index) = [];
% prapp_ph1(pivot_index) = [];
% prapp_pr2(pivot_index) = [];
% prapp_ph2(pivot_index) = [];
