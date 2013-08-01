%--------------------------*--. --- --. .--. ...*---------------------------------------------
%
%                    %%%%%  %%%%%   %%%%%  %%%%% %%%%%
%                    %      %   %   %      %   % %
%                    %  %%% %   %   %  %%% %%%%% %%%%%
%                    %   %  %   %   %   %  %         %
%                    %%%%%  %%%%%   %%%%%  %     %%%%%
%
%
%----------------------------------------------------------------------------------------------
%                           goGPS v0.4.1 beta
%
% Copyright (C) 2009-2013 Mirko Reguzzoni, Eugenio Realini
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
%---------------------------------------------------------------------------------------------

% clear all the variables in the workspace
clearvars
clearvars -global goGUI goIni goObj

% close all windows
close all

% clear the command prompt
%clc

% close all the opened files
fclose('all');

% disable warnings
warning off;

% include all subdirectories
addpath(genpath(pwd));

%----------------------------------------------------------------------------------------------
% INTERFACE TYPE DEFINITION
%----------------------------------------------------------------------------------------------

mode_user = 1;  % user interface type
% mode_user=0 --> use text interface
% mode_user=1 --> use GUI

%----------------------------------------------------------------------------------------------
% INTERFACE STARTUP
%----------------------------------------------------------------------------------------------

global order o1 o2 o3 h_antenna cutoff weights

% Set global variable for goGPS obj mode
clearvars -global goObj goIni;
global goObj;
% For future development the flag goObs will guide a possible migration to the
% use of generic objects (such as goObservations) able to automatically manage
% multiple modes
goObj = 0;  % this variable is set in the interface.

if (mode_user == 1)

    if (~isunix || (ismac && verLessThan('matlab', '7.14')))
        [mode, mode_vinc, mode_data, mode_ref, flag_ms_pos, flag_ms, flag_ge, flag_cov, flag_NTRIP, flag_amb, ...
            flag_skyplot, flag_plotproc, flag_var_dyn_model, flag_stopGOstop, flag_SP3, flag_SBAS, flag_IAR, ...
            filerootIN, filerootOUT, filename_R_obs, filename_M_obs, ...
            filename_nav, filename_ref, pos_M_man, protocol_idx] = gui_goGPS;
    elseif (ismac)
        [mode, mode_vinc, mode_data, mode_ref, flag_ms_pos, flag_ms, flag_ge, flag_cov, flag_NTRIP, flag_amb, ...
            flag_skyplot, flag_plotproc, flag_var_dyn_model, flag_stopGOstop, flag_SP3, flag_SBAS, flag_IAR, ...
            filerootIN, filerootOUT, filename_R_obs, filename_M_obs, ...
            filename_nav, filename_ref, pos_M_man, protocol_idx] = gui_goGPS_unix_mac;
    else %linux
        [mode, mode_vinc, mode_data, mode_ref, flag_ms_pos, flag_ms, flag_ge, flag_cov, flag_NTRIP, flag_amb, ...
            flag_skyplot, flag_plotproc, flag_var_dyn_model, flag_stopGOstop, flag_SP3, flag_SBAS, flag_IAR, ...
            filerootIN, filerootOUT, filename_R_obs, filename_M_obs, ...
            filename_nav, filename_ref, pos_M_man, protocol_idx] = gui_goGPS_unix_linux;
    end

    global goIni;
    if (isempty(mode))
        return
    end
else

    %-------------------------------------------------------------------------------------------
    % DEFINITION OF THE FUNCTIONING MODE (TEXT INTERFACE)
    %-------------------------------------------------------------------------------------------

    mode = goGNSS.MODE_PP_LS_C_SA;   % functioning mode    
    
    mode_vinc = 0;    % navigation mode
    % mode_vinc=0 --> without linear constraint
    % mode_vinc=1 --> with linear constraint

    mode_data = 1;    % data loading mode
    % mode_data=0 --> RINEX data
    % mode_data=1 --> goGPS binary data

    mode_ref = 0;     % reference path mode
    % mode_ref=0 --> do not use a reference path
    % mode_ref=1 --> use a reference path (plot it and use it for statistics)

    flag_ms_pos = 1;     % read master station position from RTCM or RINEX header

    flag_ms = 0;         % plot master station position --> no=0, yes=1

    flag_ge = 0;         % use google earth --> no=0, yes=1

    flag_cov = 0;        % plot error ellipse --> no=0, yes=1

    flag_NTRIP = 1;      % use NTRIP --> no=0, yes=1

    flag_amb = 0;        % plot ambiguities (only in post-processing)

    flag_skyplot = 1;    % draw skyplot and SNR graph (save CPU) --> no=0, yes=1

    flag_plotproc = 1;   % plot while processing

    flag_stopGOstop = 0; % use a stop-go-stop procedure for direction estimation --> no=0, yes=1
    
    flag_var_dyn_model = 0; % variable dynamic model --> no=0, yes=1
    
    flag_SBAS = 0;          % apply SBAS corrections --> no=0, yes=1
    
    flag_IAR = 1;           % try to solve integer ambiguities by LAMBDA method --> no=0, yes=1

    %----------------------------------------------------------------------------------------------
    % USER-DEFINED SETTINGS
    %----------------------------------------------------------------------------------------------

    %User-defined global settings
    global_settings;

    %Check availability of Instrument Control Toolbox
    if goGNSS.isRT()
        try
            instrhwinfo;
        catch
            error('Instrument Control Toolbox is needed to run goGPS in real-time mode.');
        end
    end
end

%-------------------------------------------------------------------------------------------
% GO goGPS - here the computations start
%-------------------------------------------------------------------------------------------

%load multi-constellation settings and initialize 'constellations' struct
GPS_flag = goIni.getData('Constellations','GPS');
GLO_flag = goIni.getData('Constellations','GLONASS');
GAL_flag = goIni.getData('Constellations','Galileo');
BDS_flag = goIni.getData('Constellations','BeiDou');
QZS_flag = goIni.getData('Constellations','QZSS');
SBS_flag = goIni.getData('Constellations','SBAS');
[constellations] = goGNSS.initConstellation(GPS_flag, GLO_flag, GAL_flag, BDS_flag, QZS_flag, SBS_flag);
nSatTot = constellations.nEnabledSat;
if (nSatTot == 0)
    fprintf('No constellations selected, setting default: GPS-only processing\n');
    [constellations] = goGNSS.initConstellation(1, 0, 0, 0, 0, 0);
    nSatTot = constellations.nEnabledSat;
end

%initialization of global variables/constants
global_init;

% start evaluating computation time
tic

%-------------------------------------------------------------------------------------------
% REFERENCE PATH LOAD
%-------------------------------------------------------------------------------------------

if (mode_ref == 1)

    d = dir(filename_ref);

    if ~isempty(d)
        load(filename_ref, 'ref_path', 'mat_path');

        %adjust the reference path according to antenna height
        [ref_phi, ref_lam, ref_h] = cart2geod(ref_path(:,1),ref_path(:,2),ref_path(:,3));
        ref_h = ref_h + h_antenna;
        [ref_X, ref_Y, ref_Z] = geod2cart(ref_phi, ref_lam, ref_h, a_GPS, f_GPS);
        ref_path = [ref_X , ref_Y , ref_Z];

    else
        ref_path = [];
        mat_path = [];
    end

else
    ref_path = [];
    mat_path = [];
end

%----------------------------------------------------------------------------------------------
% FILE READING
%----------------------------------------------------------------------------------------------

if goGNSS.isPP(mode) % post-processing
    
    SP3 = [];

    if (mode_data == 0)

        if (flag_SP3)
            %display message
            fprintf('Reading SP3 file...\n');
            
            SP3 = load_SP3(filename_nav, time_GPS, week_R, constellations);
        end

        %display message
        fprintf('Reading RINEX files...\n');
        
        if goGNSS.isSA(mode) % absolute positioning

%[pr1_R, pr1_M, ph1_R, ph1_M, pr2_R, pr2_M, ph2_R, ph2_M,     dop1_R, dop1_M, dop2_R, dop2_M, snr1_R, snr1_M,     snr2_R, snr2_M, time_GPS, time_R, time_M, week_R, week_M,     date_R, date_M, pos_R, pos_M, Eph, iono, interval] =     goGNSS.loadRINEX(filename_nav, filename_R_obs, [], constellations, flag_SP3);
%[pr1_R, pr1_M, ph1_R, ph1_M, pr2_R, pr2_M, ph2_R, ph2_M,     dop1_R, dop1_M, dop2_R, dop2_M, snr1_R, snr1_M,     snr2_R, snr2_M, time_GPS, time_R, time_M, week_R, week_M,     date_R, date_M, pos_R, pos_M, Eph, iono, interval] =     load_RINEX(filename_nav, filename_R_obs, [], constellations, flag_SP3);
            [pr1_R, pr1_M, ph1_R, ph1_M, pr2_R, pr2_M, ph2_R, ph2_M, ...
                dop1_R, dop1_M, dop2_R, dop2_M, snr1_R, snr1_M, ...
                snr2_R, snr2_M, time_GPS, time_R, time_M, week_R, week_M, ...
                date_R, date_M, pos_R, pos_M, Eph, iono, interval] = ...
                load_RINEX(filename_nav, filename_R_obs, [], constellations, flag_SP3);
            
            %goWaitBar
            goWB = goWaitBar(length(time_GPS));
            goWB.titleUpdate('Pre-processing rover...');
            
            %pre-processing
            fprintf('Pre-processing rover observations...\n');
            [pr1_R, ph1_R, pr2_R, ph2_R, dtR, dtRdot, bad_sats_R] = pre_processing_clock(time_GPS, time_R, [], pr1_R, ph1_R, pr2_R, ph2_R, dop1_R, dop2_R, snr1_R, Eph, SP3, iono, nSatTot, goWB);
            
            goWB.close();

        else %relative positioning

            [pr1_R, pr1_M, ph1_R, ph1_M, pr2_R, pr2_M, ph2_R, ph2_M, ...
                dop1_R, dop1_M, dop2_R, dop2_M, snr1_R, snr1_M, ...
                snr2_R, snr2_M, time_GPS, time_R, time_M, week_R, week_M, ...
                date_R, date_M, pos_R, pos_M, Eph, iono, interval] = ...
                load_RINEX(filename_nav, filename_R_obs, filename_M_obs, constellations, flag_SP3);
            
            %goWaitBar
            goWB = goWaitBar(length(time_GPS));
            goWB.titleUpdate('Pre-processing rover...');
            
            %pre-processing
            fprintf('Pre-processing rover observations...\n');
            [pr1_R, ph1_R, pr2_R, ph2_R, dtR, dtRdot, bad_sats_R] = pre_processing_clock(time_GPS, time_R, [], pr1_R, ph1_R, pr2_R, ph2_R, dop1_R, dop2_R, snr1_R, Eph, SP3, iono, nSatTot, goWB);
            
            goWB.close();
            
            %goWaitBar
            goWB = goWaitBar(length(time_GPS));
            goWB.titleUpdate('Pre-processing master...');
            
            fprintf('Pre-processing master observations...\n');
            [pr1_M, ph1_M, pr2_M, ph2_M, dtM, dtMdot, bad_sats_M] = pre_processing_clock(time_GPS, time_M, [], pr1_M, ph1_M, pr2_M, ph2_M, dop1_M, dop2_M, snr1_M, Eph, SP3, iono, nSatTot, goWB);
            
            goWB.close();
        end

%         %read surveying mode
%         if (flag_stopGOstop == 0)
%             fid_dyn = fopen([filerootIN '_dyn_00.bin'],'r+'); 
%             order = double(fread(fid_dyn,length(time_GPS),'uint8'));
%             fclose(fid_dyn);
%         end
        
        %TEMP
        snr_R = snr1_R;
        snr_M = snr1_M;
        date  = date_R;

        if (~flag_SP3)
            %remove satellites without ephemerides
            delsat = setdiff(1:nSatTot,unique(Eph(30,:)));
            pr1_R(delsat,:) = 0;
            pr1_M(delsat,:) = 0;
            pr2_R(delsat,:) = 0;
            pr2_M(delsat,:) = 0;
            ph1_R(delsat,:) = 0;
            ph1_M(delsat,:) = 0;
            ph2_R(delsat,:) = 0;
            ph2_M(delsat,:) = 0;
            dop1_R(delsat,:) = 0;
            dop1_M(delsat,:) = 0;
            dop2_R(delsat,:) = 0;
            dop2_M(delsat,:) = 0;
            snr_R(delsat,:) = 0;
            snr_M(delsat,:) = 0;
        end
        
        %remove flagged satellites (rover)
        if (exist('bad_sats_R','var') && any(bad_sats_R))
            pos = find(bad_sats_R);
            pr1_R(pos,:) = 0;
            pr1_M(pos,:) = 0;
            pr2_R(pos,:) = 0;
            pr2_M(pos,:) = 0;
            ph1_R(pos,:) = 0;
            ph1_M(pos,:) = 0;
            ph2_R(pos,:) = 0;
            ph2_M(pos,:) = 0;
            dop1_R(pos,:) = 0;
            dop1_M(pos,:) = 0;
            dop2_R(pos,:) = 0;
            dop2_M(pos,:) = 0;
            snr_R(pos,:) = 0;
            snr_M(pos,:) = 0;
        end
        
        %remove flagged satellites (master)
        if (exist('bad_sats_M','var') && any(bad_sats_M))
            pos = find(bad_sats_M);
            pr1_R(pos,:) = 0;
            pr1_M(pos,:) = 0;
            pr2_R(pos,:) = 0;
            pr2_M(pos,:) = 0;
            ph1_R(pos,:) = 0;
            ph1_M(pos,:) = 0;
            ph2_R(pos,:) = 0;
            ph2_M(pos,:) = 0;
            dop1_R(pos,:) = 0;
            dop1_M(pos,:) = 0;
            dop2_R(pos,:) = 0;
            dop2_M(pos,:) = 0;
            snr_R(pos,:) = 0;
            snr_M(pos,:) = 0;
        end

        %%reverse the path
        %pr1_R = pr1_R(:,end:-1:1);
        %pr1_M = pr1_M(:,end:-1:1);
        %ph1_R = ph1_R(:,end:-1:1);
        %ph1_M = ph1_M(:,end:-1:1);
        %pr2_R = pr2_R(:,end:-1:1);
        %pr2_M = pr2_M(:,end:-1:1);
        %ph2_R = ph2_R(:,end:-1:1);
        %ph2_M = ph2_M(:,end:-1:1);
        %dop1_R = dop1_R(:,end:-1:1);
        %dop1_M = dop1_M(:,end:-1:1);
        %dop2_R = dop2_R(:,end:-1:1);
        %dop2_M = dop2_M(:,end:-1:1);
        %snr_R = snr_R(:,end:-1:1);
        %snr_M = snr_M(:,end:-1:1);

        %time_GPS = time_GPS(end:-1:1);
        %date = date(end:-1:1,:);
        
    else %mode_data == 1
        
        %read data from goGPS saved files
        [time_GPS, week_R, time_R, time_M, pr1_R, pr1_M, ph1_R, ph1_M, dop1_R, snr_R, snr_M, ...
            pos_M, Eph, iono, delay, loss_R, loss_M] = load_goGPSinput(filerootIN);

        %goWaitBar
        goWB = goWaitBar(length(time_GPS));
        goWB.titleUpdate('Pre-processing rover...');

        %pre-processing
        fprintf('Pre-processing rover observations...\n');
        [pr1_R, ph1_R, ~, ~, dtR, dtRdot, bad_sats_R] = pre_processing_clock(time_GPS, time_R, [], pr1_R, ph1_R, zeros(size(pr1_R)), zeros(size(ph1_R)), dop1_R, zeros(size(dop1_R)), snr_R, Eph, SP3, iono, size(pr1_R,1), goWB);

        goWB.titleUpdate('Pre-processing master...');

        fprintf('Pre-processing master observations...\n');
        [pr1_M, ph1_M, ~, ~, dtM, dtMdot, bad_sats_M] = pre_processing_clock(time_GPS, time_M, [], pr1_M, ph1_M, zeros(size(pr1_M)), zeros(size(ph1_M)), zeros(size(dop1_R)), zeros(size(dop1_R)), snr_M, Eph, SP3, iono, size(pr1_M,1), goWB);

        goWB.close();
        
        %interval between epochs
        interval = median(time_GPS(2:end) - time_GPS(1:end-1));

        %read surveying mode
%         if (flag_stopGOstop == 0)
%             fid_dyn = fopen([filerootIN '_dyn_00.bin'],'r+'); 
%             order = double(fread(fid_dyn,length(time_GPS),'uint8'));
%             fclose(fid_dyn);
%         end

        %remove epochs without ephemerides
        while (sum(Eph(:,:,1)) == 0)
            time_R(1)    = [];                         %GPS time
            time_M(1)    = [];                         %GPS time
            week_R(1)    = [];                         %GPS week
            pr1_R(:,1)   = [];                         %code observations
            pr1_M(:,1)   = [];                         %code observations
            ph1_R(:,1)   = [];                         %phase observations
            ph1_M(:,1)   = [];                         %phase observations
            dop1_R(:,1)  = [];                         %Doppler observations
            snr_R(:,1)   = [];                         %signal-to-noise ratio
            snr_M(:,1)   = [];                         %signal-to-noise ratio
            pos_M(:,1)   = [];                         %master position
            Eph(:,:,1)   = [];                         %ephemerides
            iono(:,1)    = [];                         %ionosphere parameters
            delay(1)     = [];                         %delays
            loss_R(1)    = [];                         %rover losses
            loss_M(1)    = [];                         %master losses
        end
        
        %if the goGPS binary data were saved without master station, use
        %time_R as reference time
        if(~any(pr1_M(:)))
            time_GPS = time_R;
        else
            %reference GPS time
            time_GPS = time_GPS(1) + (0 : interval : (length(time_M)-1)*interval)';
        end

        %date
        date = gps2date(week_R, time_GPS);

        %other variables
        pos_R = zeros(3,1);
        dop1_M = zeros(size(pr1_M));
        pr2_M = zeros(size(pr1_M));
        pr2_R = zeros(size(pr1_R));
        ph2_M = zeros(size(ph1_M));
        ph2_R = zeros(size(ph1_R));
        dop2_M = zeros(size(dop1_M));
        dop2_R = zeros(size(dop1_R));

        %complete/partial path
        tMin = 1;
        tMax = 1e30;
        tMin = max(tMin,1);
        tMax = min(tMax,length(time_GPS));
        time_GPS = time_GPS(tMin:tMax);
        time_R = time_R(tMin:tMax);
        time_M = time_M(tMin:tMax);
        week_R = week_R(tMin:tMax);
        pr1_R = pr1_R(:,tMin:tMax);
        pr1_M = pr1_M(:,tMin:tMax);
        ph1_R = ph1_R(:,tMin:tMax);
        ph1_M = ph1_M(:,tMin:tMax);
        pr2_R = pr2_R(:,tMin:tMax);
        pr2_M = pr2_M(:,tMin:tMax);
        ph2_R = ph2_R(:,tMin:tMax);
        ph2_M = ph2_M(:,tMin:tMax);
        dop1_R = dop1_R(:,tMin:tMax);
        dop2_R = dop2_R(:,tMin:tMax);
        snr_R = snr_R(:,tMin:tMax);
        snr_M = snr_M(:,tMin:tMax);
        pos_M = pos_M(:,tMin:tMax);
        Eph = Eph(:,:,tMin:tMax);
        iono = iono(:,tMin:tMax);
        delay = delay(tMin:tMax);
        loss_R = loss_R(tMin:tMax);
        loss_M = loss_M(tMin:tMax);
        date = date(tMin:tMax,:);
    end

    %if absolute post-processing positioning
    if goGNSS.isSA(mode) % absolute positioning

        %if SBAS corrections are requested
        if (flag_SBAS)
            
            %----------------------------------------------------------------------------------------------
            % LOAD SBAS DATA (EGNOS EMS FILES)
            %----------------------------------------------------------------------------------------------
            
            %NOTE: if SBAS corrections are not requested by the user or not available, the
            %      'sbas' structure will be initialized to zero/empty arrays and it will not
            %      have any effect on the positioning
            
            %try first to read .ems files already available
            [sbas] = load_ems('../data/EMS', week_R, time_R);
            
            %if .ems files are not available or not sufficient, try to download them
            if (isempty(sbas))
                
                %EGNOS PRNs
                prn = [120, 124, 126];
                
                %download
                for p = 1 : length(prn)
                    [file_ems] = download_ems(prn(p), [week_R(1) week_R(end)], [time_R(1) time_R(end)]);
                    if (~isempty(file_ems))
                        break
                    end
                end
                
                %try again to read .ems files
                [sbas] = load_ems('../data/EMS', week_R, time_R);
            end
            
            %check if the survey is within the EMS grids
            if (~isempty(sbas))
                [ems_data_available] = check_ems_extents(time_R, pr1_R, snr_R, Eph, iono, sbas);
            end
        end
        
        %if SBAS corrections are not requested or not available
        if (~flag_SBAS || isempty(sbas) || ~ems_data_available)

            %initialization
            sbas = [];
            
            %if SBAS corrections are requested but not available
            if (flag_SBAS && isempty(sbas))
                fprintf('Switching back to standard (not SBAS-corrected) processing.\n')
            end
        end
    else
        sbas = [];
    end

    %if relative post-processing positioning (i.e. with master station)
    if goGNSS.isDD(mode) && goGNSS.isPP(mode)
        %master station position management
        if (flag_ms_pos) & (sum(abs(pos_M)) ~= 0)
            if (size(pos_M,2) == 1)
                pos_M(1,1:length(time_GPS)) = pos_M(1);
                pos_M(2,1:length(time_GPS)) = pos_M(2);
                pos_M(3,1:length(time_GPS)) = pos_M(3);
            end
        else
            pos_M(1,1:length(time_GPS)) = pos_M_man(1);
            pos_M(2,1:length(time_GPS)) = pos_M_man(2);
            pos_M(3,1:length(time_GPS)) = pos_M_man(3);
            fprintf('Warning: master position fixed to user-defined values:\n');
            fprintf(' X=%.4f m, Y=%.4f m, Z=%.4f m\n', pos_M_man(1,1), pos_M_man(2,1), pos_M_man(3,1));
        end

        %if master station data are not available
        if (~any(pr1_M(:)))
            
            %switch from relative to absolute positioning...
            mode = mode - 10;
            
            %...and warn the user
            if (mode_user == 1)
                if (flag_var_dyn_model)
                    uiwait(msgbox('Warning: master data not available, forcing STAND-ALONE mode. Variable dynamic model is not supported in stand-alone mode.','','modal'));
                else
                    uiwait(msgbox('Warning: master data not available, forcing STAND-ALONE mode.','','modal'));
                end
            else
                if (flag_var_dyn_model)
                    fprintf('Warning: master data not available, forcing stand-alone mode. Variable dynamic model is not supported in stand-alone mode.\n');
                else
                    fprintf('Warning: master data not available, forcing stand-alone mode.\n');
                end
            end
        end
    end

else %real-time
    
    %disable Doppler-based cycle-slips detection
    flag_doppler_cs = 0;

    %initialize master position variable
    if (flag_ms_pos)
        pos_M = [];
    else
        pos_M = pos_M_man;
    end

    %for the Kalman filter execution in real-time
    dop1_M = zeros(nSatTot,1);
    pr2_M  = zeros(nSatTot,1);
    pr2_R  = zeros(nSatTot,1);
    ph2_M  = zeros(nSatTot,1);
    ph2_R  = zeros(nSatTot,1);
    dop2_M = zeros(nSatTot,1);
    dop2_R = zeros(nSatTot,1);
end

%check if the dataset was surveyed with a variable dynamic model
d = dir([filerootIN '_dyn_00.bin']);
if (goGNSS.isPP(mode) && (flag_stopGOstop || flag_var_dyn_model) && isempty(d))
    disp('Warning: dataset was not surveyed with a variable dynamic model:');
    disp(' Switching off variable dynamic model mode...');
    flag_var_dyn_model = 0;
end

%boolean vector for removing unused epochs in LS processing
if (goGNSS.isPP(mode))
    unused_epochs = zeros(size(time_GPS));
end

%----------------------------------------------------------------------------------------------
% POST-PROCESSING (ABSOLUTE POSITIONING): LEAST SQUARES ON CODE
%----------------------------------------------------------------------------------------------

if (mode == goGNSS.MODE_PP_LS_C_SA)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = nSatTot;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;
    
    plot_t = 1;
    
    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');

    for t = 1 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph(Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end
        
        sbas_t = find_sbas(sbas, t);

        goGPS_LS_SA_code(time_GPS(t), pr1_R(:,t), pr2_R(:,t), snr_R(:,t), Eph_t, SP3, iono, sbas_t, 1);

        if (t == 1)
            fwrite(fid_sat, nSatTot, 'int8');
            fwrite(fid_conf, nSatTot, 'int8');
        end
        
        if ~isempty(Xhat_t_t) & ~isnan([Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)])
            Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
            Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
            fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
            fwrite(fid_sat, [zeros(nSatTot,1); azR; zeros(nSatTot,1); elR; zeros(nSatTot,1); distR], 'double');
            fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
            fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');
            
            if (flag_plotproc)
                if (t == 1), goWB.shiftDown(); end
                if (flag_cov == 0)
                    if (flag_ge == 1), rtplot_googleearth (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
                    rtplot_matlab (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                else
                    if (flag_ge == 1), rtplot_googleearth_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                    rtplot_matlab_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                end
                if (flag_skyplot == 1)
                    rtplot_skyplot (plot_t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,t), Eph_t, SP3);
                else
                    rttext_sat (plot_t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                end
                plot_t = plot_t + 1;
                pause(0.01);
            end
        else
            unused_epochs(t) = 1;
        end
        
        if ((t == 1) & (~flag_plotproc))
            fprintf('Processing...\n');
        end
        
        goWB.goTime(t);
    end
    
    goWB.close();

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);
    
%----------------------------------------------------------------------------------------------
% POST-PROCESSING (ABSOLUTE POSITIONING): KALMAN FILTER ON CODE
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_KF_C_SA)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = nSatTot;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;
    
    kalman_initialized = 0;
    while (~kalman_initialized)
        if (isempty(time_GPS))
            fprintf('It was not possible to initialize the Kalman filter.\n');
            return
        end
        
        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(1), nSatTot);
        else
            Eph_t = Eph(:,:,1);
        end
        
        sbas_t = find_sbas(sbas, 1);
        
        kalman_initialized = goGPS_KF_SA_code_init(pos_R, time_GPS(1), pr1_R(:,1), pr2_R(:,1), snr_R(:,1), Eph_t, SP3, iono, sbas_t, 1);
        
        if (~kalman_initialized)
            time_GPS(1) = []; week_R(1) = [];
            pr1_R(:,1) = []; pr1_M(:,1) = []; ph1_R(:,1) = []; ph1_M(:,1) = []; dop1_R(:,1) = []; dop1_M(:,1) = [];
            pr2_R(:,1) = []; pr2_M(:,1) = []; ph2_R(:,1) = []; ph2_M(:,1) = []; dop2_R(:,1) = []; dop2_M(:,1) = [];
            snr_R(:,1) = []; snr_M(:,1) = [];
        end
    end

    Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
    Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
    fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
    fwrite(fid_sat, nSatTot, 'int8');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
    fwrite(fid_conf, [nSatTot; conf_sat; conf_cs; pivot], 'int8');

    if (flag_plotproc)
        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(1,:)), end;
            rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
            rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
        end
        if (flag_skyplot == 1)
            rtplot_skyplot (1, azR, elR, conf_sat, pivot, Eph_t, SP3);
            rtplot_snr (snr_R(:,1), Eph_t, SP3);
        else
            rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot, Eph_t, SP3);
        end
    else
        fprintf('Processing...\n');
    end
    
    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end

        goGPS_KF_SA_code_loop(time_GPS(t), pr1_R(:,t), pr2_R(:,t), snr_R(:,t), Eph_t, SP3, iono, sbas_t, 1);

        Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
        Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
        fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_plotproc)
            if (t == 2), goWB.shiftDown(); end
            if (flag_cov == 0)
                if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
                rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
            else
                if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
            end
            if (flag_skyplot == 1)
                rtplot_skyplot (t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                rtplot_snr (snr_R(:,t), Eph_t, SP3);
            else
                rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
            end
            pause(0.01);
        end
        
        goWB.goTime(t);
    end

    goWB.close();

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);
    
%----------------------------------------------------------------------------------------------
% POST-PROCESSING (ABSOLUTE POSITIONING): LEAST SQUARES ON CODE AND PHASE   (DISABLED IN GUI)
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_LS_CP_SA)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = nSatTot;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;
    
    plot_t = 1;
    
    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');

    for t = 1 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end
        
        sbas_t = find_sbas(sbas, t);

        goGPS_LS_SA_code_phase(time_GPS(t), pr1_R(:,t), pr2_R(:,t), ph1_R(:,t), ph2_R(:,t), snr_R(:,t), Eph_t, SP3, iono, sbas_t, 1);

        if (t == 1)
            fwrite(fid_sat, nSatTot, 'int8');
            fwrite(fid_conf, nSatTot, 'int8');
        end
        
        if ~isempty(Xhat_t_t) & ~isnan([Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)])
            fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
            fwrite(fid_sat, [zeros(nSatTot,1); azR; zeros(nSatTot,1); elR; zeros(nSatTot,1); distR], 'double');
            fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
            fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');
            
            if (flag_plotproc)
                if (t == 1), goWB.shiftDown(); end
                if (flag_cov == 0)
                    if (flag_ge == 1), rtplot_googleearth (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
                    rtplot_matlab (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                else
                    if (flag_ge == 1), rtplot_googleearth_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                    rtplot_matlab_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                end
                if (flag_skyplot == 1)
                    rtplot_skyplot (plot_t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,t), Eph_t, SP3);
                else
                    rttext_sat (plot_t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                end
                plot_t = plot_t + 1;
                pause(0.01);
            else
                if (t == 1)
                    fprintf('Processing...\n');
                end
            end
        else
            unused_epochs(t) = 1;
        end
        
        goWB.goTime(t);
    end

    goWB.close();

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);
    
%----------------------------------------------------------------------------------------------
% VARIOMETRIC APPROACH FOR VELOCITY ESTIMATION STAND-ALONE ENGINE
%----------------------------------------------------------------------------------------------
    
elseif (mode == goGNSS.MODE_PP_LS_CP_VEL)
    
    fid_kal = fopen([filerootOUT '_kal_00.txt'],'w');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');
    
    nN = nSatTot;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;
    
    plot_t = 1;
    time_step = goIni.getTimeStep();   %time step to perform the difference between phase observations
    fprintf('TimeStep used is %d epochs\n', time_step);
    % External loop to show bar update every 15 epochs
    stepUpdate = 15;
    goWB = goWaitBar((length(time_GPS)-(time_step))/stepUpdate);
    goWB.titleUpdate('Variometric approach running...');
    ind=0;
    for tExt = 1:stepUpdate:(length(time_GPS)-(time_step))
        for t = tExt:min(tExt+stepUpdate-1,length(time_GPS)-(time_step))
            if (mode_data == 0)
                Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
                Eph_t1 = rt_find_eph (Eph, time_GPS(t+time_step), nSatTot);
            else
                Eph_t = Eph(:,:,t+time_step);
                Eph_t1 = Eph(:,:,t+time_step);
            end
            
            goGPS_LS_SA_variometric(time_GPS(t),time_GPS(t+time_step),pr1_R(:,t),  pr1_R(:,t+time_step),  pr2_R(:,t),pr2_R(:,t+time_step), ph1_R(:,t), ph1_R(:,t+time_step),ph2_R(:,t), ph2_R(:,t+time_step), snr_R(:,t), snr_R(:,t+time_step), Eph_t, Eph_t1,[],[], [],[], [],[], iono, sbas, 1,time_step);
            Xhat_t_t(1:6)=-Xhat_t_t(1:6)./(interval.*time_step);
            if ~isempty(Xhat_t_t) & ~isnan([Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)])
                Xhat_t_t_dummy = [Xhat_t_t];
                ind=ind+1;
                vel_pos(ind,:)=Xhat_t_t;
                Cee_dummy = Cee;
                %         fprintf(fid_kal,'%10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f\n', Xhat_t_t );
                if (t == 1)
                    fwrite(fid_sat, nSatTot, 'int8');
                    fwrite(fid_conf, nSatTot, 'int8');
                end
                fwrite(fid_sat, [zeros(nSatTot,1); azR; zeros(nSatTot,1); elR; zeros(nSatTot,1); distR], 'double');
                fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
                fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');
                
                %if (flag_plotproc)
                %    if (flag_cov == 0)
                %        if (flag_ge == 1), rtplot_googleearth (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
                %        rtplot_matlab (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                %    else
                %        if (flag_ge == 1), rtplot_googleearth_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                %        rtplot_matlab_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                %    end
                %    if (flag_skyplot == 1)
                %        rtplot_skyplot (plot_t, azR, elR, conf_sat, pivot);
                %        rtplot_snr (snr_R(:,t));
                %    else
                %        rttext_sat (plot_t, azR, elR, snr_R(:,t), conf_sat, pivot);
                %    end
                %    plot_t = plot_t + 1;
                %    %pause(0.01);
                %end
            else
                unused_epochs(t) = 1;
            end
        end
        goWB.goTime(tExt/stepUpdate);
    end
    goDX=cumsum(vel_pos(:,1)).*(interval.*time_step);
    goDY=cumsum(vel_pos(:,3)).*(interval.*time_step);
    goDZ=cumsum(vel_pos(:,5)).*(interval.*time_step);
    %jumps=0.*goDX;
    jumps=(find(vel_pos(:,2)==-9999));
    jumps=[0; jumps; length(goDX)-1];
    mX = zeros(length(jumps)-1,1);
    mY = zeros(length(jumps)-1,1);
    mZ = zeros(length(jumps)-1,1);
    lastX=0;
    lastY=0;
    lastZ=0;
    for epo=1:length(jumps)-1;
        if (jumps(epo+1)-jumps(epo))~=1;
            mX(epo) = mean(vel_pos(jumps(epo)+1:jumps(epo+1)-1,7));
            mY(epo) = mean(vel_pos(jumps(epo)+1:jumps(epo+1)-1,8));
            mZ(epo) = mean(vel_pos(jumps(epo)+1:jumps(epo+1)-1,9));
            lastX = goDX(jumps(epo)+1:jumps(epo+1)-1) - mean(goDX(jumps(epo)+1:jumps(epo+1)-1)) + mX(epo);
            lastY = goDY(jumps(epo)+1:jumps(epo+1)-1) - mean(goDY(jumps(epo)+1:jumps(epo+1)-1)) + mY(epo);
            lastZ = goDZ(jumps(epo)+1:jumps(epo+1)-1) - mean(goDZ(jumps(epo)+1:jumps(epo+1)-1)) + mZ(epo);
            goDX(jumps(epo)+1:jumps(epo+1)-1)= lastX;
            goDY(jumps(epo)+1:jumps(epo+1)-1)= lastY;
            goDZ(jumps(epo)+1:jumps(epo+1)-1)= lastZ;
        elseif (jumps(epo) ~= 0)
            mX(epo) = mean(vel_pos(jumps(epo)+1:jumps(epo+1)-1,7));
            mY(epo) = mean(vel_pos(jumps(epo)+1:jumps(epo+1)-1,8));
            mZ(epo) = mean(vel_pos(jumps(epo)+1:jumps(epo+1)-1,9));
            goDX(jumps(epo)) = lastX(end);
            goDY(jumps(epo)) = lastY(end);
            goDZ(jumps(epo)) = lastZ(end);
        end
    end
    flag = find(diff(goDX) > 100);
    goDX(flag)=goDX(flag-1);
    goDY(flag)=goDY(flag-1);
    goDZ(flag)=goDZ(flag-1);
    %goDX=goDX-goDX(1)+(vel_pos(1,7));
    %goDY=goDY-goDY(1)+(vel_pos(1,8));
    %goDZ=goDZ-goDZ(1)+(vel_pos(1,9));
    [phiX, lamX, hX] = cart2geod(goDX,goDY,goDZ);
    vel_pos(:,7)=goDX;
    vel_pos(:,8)=goDY;
    vel_pos(:,9)=goDZ;
    vel_pos(:,10)=phiX.*180/pi;
    vel_pos(:,11)=lamX.*180/pi;
    vel_pos(:,12)=hX;

    for epo=1:length(goDX)
        
        xENU(epo,:) = global2localPos(vel_pos(epo,7:9)', vel_pos(1,7:9)');
        vENU(epo,:) = global2localVel(vel_pos(epo,1:2:5)', [phiX(epo), lamX(epo)]'.*180/pi);
        velpos(epo,:)=[vel_pos(epo,:), vENU(epo,:), time_GPS(epo)];
        
        fprintf(fid_kal,'%10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f %10.5f \n',velpos(epo,:));
    end
    
%     figure
%     plot(xENU(:,1))
%     hold on
%     plot(xENU(:,2),'r')
%     plot(xENU(:,3),'g')
%     title('Displacement (blue=E; red=N; green=U)')
    
    figure
    plot(vENU(:,1))
    hold on
    plot(vENU(:,2),'r')
    plot(vENU(:,3),'g')
    title('Velocity (blue=E; red=N; green=U)')
    
    goWB.close();
    
    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);
    
    time_GPS = time_GPS(1:end-time_step);
    week_R = week_R(1:end-time_step);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING (ABSOLUTE POSITIONING): KALMAN FILTER ON CODE AND PHASE
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_KF_CP_SA)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');
    
    kalman_initialized = 0;
    while (~kalman_initialized)
        if (isempty(time_GPS))
            fprintf('It was not possible to initialize the Kalman filter.\n');
            return
        end
        
        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(1), nSatTot);
        else
            Eph_t = Eph(:,:,1);
        end
        
        sbas_t = find_sbas(sbas, 1);
        
        kalman_initialized = goGPS_KF_SA_code_phase_init(pos_R, time_GPS(1), pr1_R(:,1), ph1_R(:,1), dop1_R(:,1), pr2_R(:,1), ph2_R(:,1), dop2_R(:,1), snr_R(:,1), Eph_t, SP3, iono, sbas_t, 1, flag_IAR);
        
        if (~kalman_initialized)
            time_GPS(1) = []; week_R(1) = [];
            pr1_R(:,1) = []; pr1_M(:,1) = []; ph1_R(:,1) = []; ph1_M(:,1) = []; dop1_R(:,1) = []; dop1_M(:,1) = [];
            pr2_R(:,1) = []; pr2_M(:,1) = []; ph2_R(:,1) = []; ph2_M(:,1) = []; dop2_R(:,1) = []; dop2_M(:,1) = [];
            snr_R(:,1) = []; snr_M(:,1) = [];
        end
    end

    fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
    fwrite(fid_sat, nSatTot, 'int8');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
    fwrite(fid_conf, [nSatTot; conf_sat; conf_cs; pivot], 'int8');

    if (flag_plotproc)
        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(1,:)), end;
            rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
            rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
        end
        if (flag_amb == 1)
            rtplot_amb (1, window, Xhat_t_t(o3+1:o3+nSatTot), sqrt(diag(Cee(o3+1:o3+nSatTot,o3+1:o3+nSatTot))), conf_cs)
        else
            if (flag_skyplot == 1)
                rtplot_skyplot (1, azR, elR, conf_sat, pivot, Eph_t, SP3);
                rtplot_snr (snr_R(:,1), Eph_t, SP3);
            else
                rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot, Eph_t, SP3);
            end
        end
    else
        fprintf('Processing...\n');
    end
    
    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end
        
        sbas_t = find_sbas(sbas, t);

        [check_on, check_off, check_pivot, check_cs] = goGPS_KF_SA_code_phase_loop(time_GPS(t), pr1_R(:,t), ph1_R(:,t), dop1_R(:,t), pr2_R(:,t), ph2_R(:,t), dop2_R(:,t), snr_R(:,t), Eph_t, SP3, iono, sbas_t, 1, flag_IAR);

        fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_plotproc)
            if (t == 2), goWB.shiftDown(); end
            if (flag_cov == 0)
                if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), date(t,:)), end;
                rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
            else
                if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], zeros(3,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
            end
            if (flag_amb == 1)
                rtplot_amb (t, window, Xhat_t_t(o3+1:o3+nSatTot), sqrt(diag(Cee(o3+1:o3+nSatTot,o3+1:o3+nSatTot))), conf_cs);
                pause(0.1);
            else
                if (flag_skyplot == 1)
                    rtplot_skyplot (t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,t), Eph_t, SP3);
                else
                    rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                end
                pause(0.01);
            end
        end
        
        goWB.goTime(t);
    end
    
    goWB.close();

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);
    
%----------------------------------------------------------------------------------------------
% POST-PROCESSING (RELATIVE POSITIONING): LEAST SQUARES ON CODE DOUBLE DIFFERENCES
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_LS_C_DD)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = nSatTot;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;
    
    plot_t = 1;
    
    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');

    for t = 1 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end

        goGPS_LS_DD_code(time_GPS(t), pos_M(:,t), pr1_R(:,t), pr1_M(:,t), pr2_R(:,t), pr2_M(:,t), snr_R(:,t), snr_M(:,t), Eph_t, SP3, iono, 1);

        if (t == 1)
            fwrite(fid_sat, nSatTot, 'int8');
            fwrite(fid_conf, nSatTot, 'int8');
        end
        
        if ~isempty(Xhat_t_t) & ~isnan([Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)])
            Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
            Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
            fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
            fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
            fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
            fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');
            
            if (flag_plotproc)
                if (t == 1), goWB.shiftDown(); end
                if (flag_cov == 0)
                    if (flag_ge == 1), rtplot_googleearth (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
                    rtplot_matlab (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                else
                    if (flag_ge == 1), rtplot_googleearth_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                    rtplot_matlab_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                end
                if (flag_skyplot == 1)
                    rtplot_skyplot (plot_t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,t), Eph_t, SP3);
                else
                    rttext_sat (plot_t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                end
                plot_t = plot_t + 1;
                pause(0.01);
            end
        else
            unused_epochs(t) = 1;
        end
      
        if ((t == 1) & (~flag_plotproc))
            fprintf('Processing...\n');
        end
        
        goWB.goTime(t);
    end
    
    goWB.close();

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING (RELATIVE POSITIONING): KALMAN FILTER ON CODE DOUBLE DIFFERENCES
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_KF_C_DD)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = nSatTot;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;
    
    kalman_initialized = 0;
    while (~kalman_initialized)
        if (isempty(time_GPS))
            fprintf('It was not possible to initialize the Kalman filter.\n');
            return
        end
        
        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(1), nSatTot);
        else
            Eph_t = Eph(:,:,1);
        end
        
        kalman_initialized = goGPS_KF_DD_code_init(pos_R, pos_M(:,1), time_GPS(1), pr1_R(:,1), pr1_M(:,1), pr2_R(:,1), pr2_M(:,1), snr_R(:,1), snr_M(:,1), Eph_t, SP3, iono, 1);
        
        if (~kalman_initialized)
            pos_M(:,1) = []; time_GPS(1) = []; week_R(1) = [];
            pr1_R(:,1) = []; pr1_M(:,1) = []; ph1_R(:,1) = []; ph1_M(:,1) = []; dop1_R(:,1) = []; dop1_M(:,1) = [];
            pr2_R(:,1) = []; pr2_M(:,1) = []; ph2_R(:,1) = []; ph2_M(:,1) = []; dop2_R(:,1) = []; dop2_M(:,1) = [];
            snr_R(:,1) = []; snr_M(:,1) = []; dtMdot(1) = [];
        end
    end

    Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
    Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
    fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
    fwrite(fid_sat, nSatTot, 'int8');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
    fwrite(fid_conf, [nSatTot; conf_sat; conf_cs; pivot], 'int8');

    if (flag_plotproc)
        if (flag_cov == 0)
            if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), date(1,:)), end;
            rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
        else
            if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
            rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path);
        end
        if (flag_skyplot == 1)
            rtplot_skyplot (1, azR, elR, conf_sat, pivot, Eph_t, SP3);
            rtplot_snr (snr_R(:,1), Eph_t, SP3);
        else
            rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot, Eph_t, SP3);
        end
    else
        fprintf('Processing...\n');
    end

    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');
    
    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end

        [check_on, check_off, check_pivot, check_cs] = goGPS_KF_DD_code_loop(pos_M(:,t), time_GPS(t), pr1_R(:,t), pr1_M(:,t), pr2_R(:,t), pr2_M(:,t), snr_R(:,t), snr_M(:,t), Eph_t, SP3, iono, 1);

        Xhat_t_t_dummy = [Xhat_t_t; zeros(nN,1)];
        Cee_dummy = [Cee zeros(o3,nN); zeros(nN,o3) zeros(nN,nN)];
        fwrite(fid_kal, [Xhat_t_t_dummy; Cee_dummy(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_plotproc)
            if (t == 2), goWB.shiftDown(); end
            if (flag_cov == 0)
                if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
                rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
            else
                if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
            end
            if (flag_skyplot == 1)
                rtplot_skyplot (t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                rtplot_snr (snr_R(:,t), Eph_t, SP3);
            else
                rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
            end
            pause(0.01);
        end
        
        goWB.goTime(t);
    end
    
    goWB.close();

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%----------------------------------------------------------------------------------------------
% POST-PROCESSING (RELATIVE POSITIONING): LEAST SQUARES ON CODE AND PHASE DOUBLE DIFFERENCES
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_LS_CP_DD_L)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

    nN = nSatTot;
    check_on = 0;
    check_off = 0;
    check_pivot = 0;
    check_cs = 0;
    
    plot_t = 1;

    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');
    
    for t = 1 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end

        goGPS_LS_DD_code_phase(time_GPS(t), pos_M(:,t), pr1_R(:,t), pr1_M(:,t), pr2_R(:,t), pr2_M(:,t), ph1_R(:,t), ph1_M(:,t), ph2_R(:,t), ph2_M(:,t), snr_R(:,t), snr_M(:,t), Eph_t, SP3, iono, 1, flag_IAR);
        
        if ~isempty(Xhat_t_t) & ~isnan([Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)])
            fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
            if (t == 1)
                fwrite(fid_sat, nSatTot, 'int8');
                fwrite(fid_conf, nSatTot, 'int8');
            end
            fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
            fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
            fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');
            
            if (flag_plotproc)
                if (t == 1), goWB.shiftDown(); end
                if (flag_cov == 0)
                    if (flag_ge == 1), rtplot_googleearth (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
                    rtplot_matlab (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                else
                    if (flag_ge == 1), rtplot_googleearth_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                    rtplot_matlab_cov (plot_t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path);
                end
                if (flag_skyplot == 1)
                    rtplot_skyplot (plot_t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,t), Eph_t, SP3);
                else
                    rttext_sat (plot_t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                end
                plot_t = plot_t + 1;
                pause(0.01);
            end
        else
            unused_epochs(t) = 1;
        end
      
        if ((t == 1) & (~flag_plotproc))
            fprintf('Processing...\n');
        end
        
        goWB.goTime(t);
    end

    goWB.close();
    
    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);

%--------------------------------------------------------------------------------------------------------------------
% POST-PROCESSING (RELATIVE POSITIONING): KALMAN FILTER ON CODE AND PHASE DOUBLE DIFFERENCES WITHOUT LINE CONSTRAINT
%--------------------------------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_KF_CP_DD) & (mode_vinc == 0)

    if (flag_var_dyn_model == 0)

        fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
        fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
        fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
        fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');

        kalman_initialized = 0;
        while (~kalman_initialized)
            if (isempty(time_GPS))
                fprintf('It was not possible to initialize the Kalman filter.\n');
                return
            end

            if (mode_data == 0)
                Eph_t = rt_find_eph (Eph, time_GPS(1), nSatTot);
            else
                Eph_t = Eph(:,:,1);
            end

            kalman_initialized = goGPS_KF_DD_code_phase_init(pos_R, pos_M(:,1), time_GPS(1), pr1_R(:,1), pr1_M(:,1), ph1_R(:,1), ph1_M(:,1), dop1_R(:,1), dop1_M(:,1), pr2_R(:,1), pr2_M(:,1), ph2_R(:,1), ph2_M(:,1), dop2_R(:,1), dop2_M(:,1), snr_R(:,1), snr_M(:,1), Eph_t, SP3, iono, 1, dtMdot(1), flag_IAR);
            
            if (~kalman_initialized)
                pos_M(:,1) = []; time_GPS(1) = []; week_R(1) = [];
                pr1_R(:,1) = []; pr1_M(:,1) = []; ph1_R(:,1) = []; ph1_M(:,1) = []; dop1_R(:,1) = []; dop1_M(:,1) = [];
                pr2_R(:,1) = []; pr2_M(:,1) = []; ph2_R(:,1) = []; ph2_M(:,1) = []; dop2_R(:,1) = []; dop2_M(:,1) = [];
                snr_R(:,1) = []; snr_M(:,1) = []; dtMdot(1) = [];
            end
        end

        fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
        fwrite(fid_sat, nSatTot, 'int8');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [nSatTot; conf_sat; conf_cs; pivot], 'int8');

        if (flag_plotproc)
            if (flag_cov == 0)
                if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), date(1,:)), end;
                rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
            else
                if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
                rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
            end
            if (flag_amb == 1)
                rtplot_amb (1, window, Xhat_t_t(o3+1:o3+nSatTot), sqrt(diag(Cee(o3+1:o3+nSatTot,o3+1:o3+nSatTot))), conf_cs)
            else
                if (flag_skyplot == 1)
                    rtplot_skyplot (1, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,1), Eph_t, SP3);
                else
                    rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot, Eph_t, SP3);
                end
            end
        else
            fprintf('Processing...\n');
        end
        
        %goWaitBar
        goWB = goWaitBar(length(time_GPS));
        goWB.titleUpdate('Processing...');

        for t = 2 : length(time_GPS)

            if (mode_data == 0)
                Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
            else
                Eph_t = Eph(:,:,t);
            end

            [check_on, check_off, check_pivot, check_cs] = goGPS_KF_DD_code_phase_loop(pos_M(:,t), time_GPS(t), pr1_R(:,t), pr1_M(:,t), ph1_R(:,t), ph1_M(:,t), dop1_R(:,t), dop1_M(:,t), pr2_R(:,t), pr2_M(:,t), ph2_R(:,t), ph2_M(:,t), dop2_R(:,t), dop2_M(:,t), snr_R(:,t), snr_M(:,t), Eph_t, SP3, iono, 1, dtMdot(t), flag_IAR);

            fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
            fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
            fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
            fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

            if (flag_plotproc)
                if (t == 2), goWB.shiftDown(); end
                if (flag_cov == 0)
                    if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
                    rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
                else
                    if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                    rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
                end
                if (flag_amb == 1)
                    rtplot_amb (t, window, Xhat_t_t(o3+1:o3+nSatTot), sqrt(diag(Cee(o3+1:o3+nSatTot,o3+1:o3+nSatTot))), conf_cs);
                    pause(0.1);
                else
                    if (flag_skyplot == 1)
                        rtplot_skyplot (t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                        rtplot_snr (snr_R(:,t), Eph_t, SP3);
                    else
                        rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                    end
                    pause(0.01);
                end
            end
            
            goWB.goTime(t);
        end
        
        goWB.close();

        fclose(fid_kal);
        fclose(fid_sat);
        fclose(fid_dop);
        fclose(fid_conf);

    else
        
        fid_dyn = fopen([filerootIN '_dyn_00.bin'],'r+');
        fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
        fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
        fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
        fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');
        
        kalman_initialized = 0;
        while (~kalman_initialized)
            if (isempty(time_GPS))
                fprintf('It was not possible to initialize the Kalman filter.\n');
                return
            end

            if (mode_data == 0)
                Eph_t = rt_find_eph (Eph, time_GPS(1), nSatTot);
            else
                Eph_t = Eph(:,:,1);
            end
            
            flag_dyn = 1;
            order = fread(fid_dyn,1,'uint8');
            
            kalman_initialized = goGPS_KF_DD_code_phase_init_model(pos_R, pos_M(:,1), time_GPS(1), pr1_R(:,1), pr1_M(:,1), ph1_R(:,1), ph1_M(:,1), dop1_R(:,1), dop1_M(:,1), pr2_R(:,1), pr2_M(:,1), ph2_R(:,1), ph2_M(:,1), dop2_R(:,1), dop2_M(:,1), snr_R(:,1), snr_M(:,1), Eph_t, SP3, iono, order, 1, dtMdot(1), flag_IAR);
            
            if (~kalman_initialized)
                pos_M(:,1) = []; time_GPS(1) = []; week_R(1) = [];
                pr1_R(:,1) = []; pr1_M(:,1) = []; ph1_R(:,1) = []; ph1_M(:,1) = []; dop1_R(:,1) = []; dop1_M(:,1) = [];
                pr2_R(:,1) = []; pr2_M(:,1) = []; ph2_R(:,1) = []; ph2_M(:,1) = []; dop2_R(:,1) = []; dop2_M(:,1) = [];
                snr_R(:,1) = []; snr_M(:,1) = []; dtMdot(1) = [];
            end
        end

        if (flag_stopGOstop == 1)
            index = 1;
            X_init = Xhat_t_t([1 o1+1 o2+1]);
            X_ENU = global2localPos(Xhat_t_t([1 o1+1 o2+1]), X_init);
            E0(index,1) = X_ENU(1,1);
            N0(index,1) = X_ENU(2,1);
            Cee_ENU = global2localCov(Cee([1 o1+1 o2+1],[1 o1+1 o2+1],:), X_init);
            sigmaq_E0(index,1) = Cee_ENU(1,1);
            sigmaq_N0(index,1) = Cee_ENU(2,2);
            sigma_EN0(index,1) = Cee_ENU(1,2);
            mDIR = 0; qDIR = 0; angleDIR = 0;
            sigma_angleDIR = 0;
            P1 = [E0(index), N0(index)]; P2 = P1;
            P1_ENU = [P1(1); P1(2); X_ENU(3,1)];
            P2_ENU = [P2(1); P2(2); X_ENU(3,1)];
            P1_GLB = local2globalPos(P1_ENU, X_init);
            P2_GLB = local2globalPos(P2_ENU, X_init);
            [P1_UTM_E, P1_UTM_N] = cart2plan(P1_GLB(1), P1_GLB(2), P1_GLB(3));
            [P2_UTM_E, P2_UTM_N] = cart2plan(P2_GLB(1), P2_GLB(2), P2_GLB(3));
        end
        
        fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
        fwrite(fid_sat, nSatTot, 'int8');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
        fwrite(fid_conf, [nSatTot; conf_sat; conf_cs; pivot], 'int8');
        
        if (flag_plotproc)
            if (flag_cov == 0)
                if (flag_ge == 1), rtplot_googleearth (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), date(1,:)), end;
                if (flag_stopGOstop == 1)
                    rtplot_matlab_stopGOstop (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), [P1_UTM_E, P1_UTM_N], [P2_UTM_E, P2_UTM_N], flag_ms, ref_path, mat_path, flag_dyn, flag_amb);
                else
                    rtplot_matlab (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
                end
            else
                if (flag_ge == 1), rtplot_googleearth_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(1,:)), end;
                if (flag_stopGOstop == 1)
                    rtplot_matlab_cov_stopGOstop (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), [P1_UTM_E, P1_UTM_N], [P2_UTM_E, P2_UTM_N], flag_ms, ref_path, mat_path, flag_dyn, flag_amb);
                else
                    rtplot_matlab_cov (1, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,1), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
                end
            end
            if (flag_amb == 1)
                rtplot_amb (1, window, Xhat_t_t(o3+1:o3+nSatTot), sqrt(diag(Cee(o3+1:o3+nSatTot,o3+1:o3+nSatTot))), conf_cs)
            else
                if (flag_skyplot == 1)
                    rtplot_skyplot (1, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,1), Eph_t, SP3);
                else
                    rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot, Eph_t, SP3);
                end
            end
        else
            fprintf('Processing...\n');
        end
        
        %goWaitBar
        goWB = goWaitBar(length(time_GPS));
        goWB.titleUpdate('Processing...');
        
        for t = 2 : length(time_GPS)
            
            if (mode_data == 0)
                Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
            else
                Eph_t = Eph(:,:,t);
            end
            
            order0 = order;
            order = fread(fid_dyn,1,'uint8');
            
            [check_on, check_off, check_pivot, check_cs] = goGPS_KF_DD_code_phase_loop_model(pos_M(:,t), time_GPS(t), pr1_R(:,t), pr1_M(:,t), ph1_R(:,t), ph1_M(:,t), dop1_R(:,t), dop1_M(:,t), pr2_R(:,t), pr2_M(:,t), ph2_R(:,t), ph2_M(:,t), dop2_R(:,t), dop2_M(:,t), snr_R(:,t), snr_M(:,t), Eph_t, SP3, iono, order, 1, dtMdot(t), flag_IAR);
            
            if (flag_stopGOstop == 1)
                if (order > order0)
                    flag_dyn = 2;
                end
                if (order < order0)
                    flag_dyn = 3;
                    index = index+1;
                end
                if (order == 2)
                    index = index+1;
                end
                X_ENU = global2localPos(Xhat_t_t([1 o1+1 o2+1]), X_init);
                E0(index,1) = X_ENU(1,1);
                N0(index,1) = X_ENU(2,1);
                Cee_ENU = global2localCov(Cee([1 o1+1 o2+1],[1 o1+1 o2+1],:), X_init);
                sigmaq_E0(index,1) = Cee_ENU(1,1);
                sigmaq_N0(index,1) = Cee_ENU(2,2);
                sigma_EN0(index,1) = Cee_ENU(1,2);
                if (index == 1)
                    mDIR = 0; qDIR = 0; angleDIR = 0;
                    P1 = [E0(index), N0(index)]; P2 = P1;
                    P1_ENU = [P1(1); P1(2); X_ENU(3,1)];
                    P2_ENU = [P2(1); P2(2); X_ENU(3,1)];
                else
                    [mDIR, qDIR, sigmaq_mDIR, sigmaq_qDIR] = LSinterp(E0, N0, sigmaq_E0, sigmaq_N0, sigma_EN0);
                    m1 = -(sigmaq_N0(1)   - mDIR*sigma_EN0(1))   / (mDIR*sigmaq_E0(1)   - sigma_EN0(1));
                    m2 = -(sigmaq_N0(end) - mDIR*sigma_EN0(end)) / (mDIR*sigmaq_E0(end) - sigma_EN0(end));
                    X1 = (m1*E0(1)   + qDIR - N0(1))   / (m1-mDIR);
                    X2 = (m2*E0(end) + qDIR - N0(end)) / (m2-mDIR);
                    P1 = [X1, mDIR*X1+qDIR ];   % projecting according to error covariance
                    P2 = [X2, mDIR*X2+qDIR ];
                    P1_ENU = [P1(1); P1(2); X_ENU(3,1)];
                    P2_ENU = [P2(1); P2(2); X_ENU(3,1)];
                    angleDIR = atan2(P2(1)-P1(1),P2(2)-P1(2)) * 180/pi;
                    sigma_angleDIR = 1/(1+mDIR^2) * sqrt(sigmaq_mDIR) * 180/pi;
                    % sigma_angleDIR = atan(sqrt(sigmaq_mDIR));
                end
                P1_GLB = local2globalPos(P1_ENU, X_init);
                P2_GLB = local2globalPos(P2_ENU, X_init);
                [P1_UTM_E, P1_UTM_N] = cart2plan(P1_GLB(1), P1_GLB(2), P1_GLB(3));
                [P2_UTM_E, P2_UTM_N] = cart2plan(P2_GLB(1), P2_GLB(2), P2_GLB(3));
                pause(0.05)
            end
            
            fwrite(fid_kal, [Xhat_t_t; Cee(:)], 'double');
            fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
            fwrite(fid_dop, [PDOP; HDOP; VDOP; KPDOP; KHDOP; KVDOP], 'double');
            fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');
            
            if (flag_plotproc)
                if (t == 2), goWB.shiftDown(); end
                if (flag_cov == 0)
                    if (flag_ge == 1), rtplot_googleearth (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), date(t,:)), end;
                    if (flag_stopGOstop == 1)
                        rtplot_matlab_stopGOstop (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), [P1_UTM_E, P1_UTM_N], [P2_UTM_E, P2_UTM_N], flag_ms, ref_path, mat_path, flag_dyn, flag_amb);
                    else
                        rtplot_matlab (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
                    end
                else
                    if (flag_ge == 1), rtplot_googleearth_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), date(t,:)), end;
                    if (flag_stopGOstop == 1)
                        rtplot_matlab_cov_stopGOstop (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), [P1_UTM_E, P1_UTM_N], [P2_UTM_E, P2_UTM_N], flag_ms, ref_path, mat_path, flag_dyn, flag_amb);
                    else
                        rtplot_matlab_cov (t, [Xhat_t_t(1); Xhat_t_t(o1+1); Xhat_t_t(o2+1)], pos_M(:,t), Cee([1 o1+1 o2+1],[1 o1+1 o2+1]), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
                    end
                end
                if (flag_amb == 1)
                    rtplot_amb (t, window, Xhat_t_t(o3+1:o3+nSatTot), sqrt(diag(Cee(o3+1:o3+nSatTot,o3+1:o3+nSatTot))), conf_cs);
                    pause(0.1);
                else
                    if (flag_skyplot == 1)
                        rtplot_skyplot (t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                        rtplot_snr (snr_R(:,t), Eph_t, SP3);
                    else
                        rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                    end
                    pause(0.01);
                end
            end
            goWB.goTime(t);
        end
        
        goWB.close();
        
        if (flag_stopGOstop == 1)
            %azimuth computation
            if (angleDIR < 0)
                angleDIR = angleDIR + 360;
            end
            
            %conversion to sexagesimal degrees
            angleDIR_deg = floor(angleDIR);
            min_dec = (angleDIR-angleDIR_deg)*60;
            angleDIR_min = floor(min_dec);
            angleDIR_sec = (min_dec - angleDIR_min)*60;
            %---------------------------------
            sigma_angleDIR_deg = floor(sigma_angleDIR);
            min_dec = (sigma_angleDIR-sigma_angleDIR_deg)*60;
            sigma_angleDIR_min = floor(min_dec);
            sigma_angleDIR_sec = (min_dec - sigma_angleDIR_min)*60;
            
            fprintf('\n')
            fprintf('Estimated azimuth = %d deg %d min %6.3f sec\n', angleDIR_deg, angleDIR_min, angleDIR_sec);
            fprintf('Standard deviation  = %d deg %d min %6.3f sec\n', sigma_angleDIR_deg, sigma_angleDIR_min, sigma_angleDIR_sec);
            fprintf('\n')
        end
        
        fclose(fid_dyn);
        fclose(fid_kal);
        fclose(fid_sat);
        fclose(fid_dop);
        fclose(fid_conf);
    end

%--------------------------------------------------------------------------------------------------------------------
% POST-PROCESSING (RELATIVE POSITIONING): KALMAN FILTER ON CODE AND PHASE DOUBLE DIFFERENCES WITH LINE CONSTRAINT
%--------------------------------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_PP_KF_CP_DD) & (mode_vinc == 1)

    fid_kal = fopen([filerootOUT '_kal_00.bin'],'w+');
    fid_sat = fopen([filerootOUT '_sat_00.bin'],'w+');
    fid_dop = fopen([filerootOUT '_dop_00.bin'],'w+');
    fid_conf = fopen([filerootOUT '_conf_00.bin'],'w+');
    
    %repeat more than once the reference loop
    %(this constrained mode works only for circuits)
    ref_loop = [ref_path; ref_path];
    
    kalman_initialized = 0;
    while (~kalman_initialized)
        if (isempty(time_GPS))
            fprintf('It was not possible to initialize the Kalman filter.\n');
            return
        end
        
        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(1), nSatTot);
        else
            Eph_t = Eph(:,:,1);
        end
        
        kalman_initialized = goGPS_KF_DD_code_phase_init_vinc(pos_R, pos_M(:,1), time_GPS(1), pr1_R(:,1), pr1_M(:,1), ph1_R(:,1), ph1_M(:,1), dop1_R(:,1), dop1_M(:,1), pr2_R(:,1), pr2_M(:,1), ph2_R(:,1), ph2_M(:,1), dop2_R(:,1), dop2_M(:,1), snr_R(:,1), snr_M(:,1), Eph_t, SP3, iono, 1, ref_loop, dtMdot(1));
        
        if (~kalman_initialized)
            pos_M(:,1) = []; time_GPS(1) = []; week_R(1) = [];
            pr1_R(:,1) = []; pr1_M(:,1) = []; ph1_R(:,1) = []; ph1_M(:,1) = []; dop1_R(:,1) = []; dop1_M(:,1) = [];
            pr2_R(:,1) = []; pr2_M(:,1) = []; ph2_R(:,1) = []; ph2_M(:,1) = []; dop2_R(:,1) = []; dop2_M(:,1) = [];
            snr_R(:,1) = []; snr_M(:,1) = []; dtMdot(1) = [];
        end
    end

    fwrite(fid_kal, [Xhat_t_t; Yhat_t_t; Cee(:)], 'double');
    fwrite(fid_sat, nSatTot, 'int8');
    fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
    fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
    fwrite(fid_conf, [nSatTot; conf_sat; conf_cs; pivot], 'int8');

    if (flag_plotproc)
        if (flag_ge == 1), rtplot_googleearth (1, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,1), date(1,:)), end;
        rtplot_matlab (1, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,1), 0, 0, 0, 0, flag_ms, ref_path, mat_path, flag_amb);
        if (flag_amb == 1)
            rtplot_amb (1, window, Xhat_t_t(o1+1:o1+nSatTot), sqrt(diag(Cee(o1+1:o1+nSatTot,o1+1:o1+nSatTot))), conf_cs);
        else
            if (flag_skyplot == 1)
                rtplot_skyplot (1, azR, elR, conf_sat, pivot, Eph_t, SP3);
                rtplot_snr (snr_R(:,1), Eph_t, SP3);
            else
                rttext_sat (1, azR, elR, snr_R(:,1), conf_sat, pivot, Eph_t, SP3);
            end
        end
    else
        fprintf('Processing...\n');
    end
    
    %goWaitBar
    goWB = goWaitBar(length(time_GPS));
    goWB.titleUpdate('Processing...');

    for t = 2 : length(time_GPS)

        if (mode_data == 0)
            Eph_t = rt_find_eph (Eph, time_GPS(t), nSatTot);
        else
            Eph_t = Eph(:,:,t);
        end

        [check_on, check_off, check_pivot, check_cs] = goGPS_KF_DD_code_phase_loop_vinc(pos_M(:,t), time_GPS(t), pr1_R(:,t), pr1_M(:,t), ph1_R(:,t), ph1_M(:,t), dop1_R(:,t), dop1_M(:,t), pr2_R(:,t), pr2_M(:,t), ph2_R(:,t), ph2_M(:,t), dop2_R(:,t), dop2_M(:,t), snr_R(:,t), snr_M(:,t), Eph_t, SP3, iono, 1, ref_loop, dtMdot(t));

        fwrite(fid_kal, [Xhat_t_t; Yhat_t_t; Cee(:)], 'double');
        fwrite(fid_sat, [azM; azR; elM; elR; distM; distR], 'double');
        fwrite(fid_dop, [PDOP; HDOP; VDOP; 0; 0; 0], 'double');
        fwrite(fid_conf, [conf_sat; conf_cs; pivot], 'int8');

        if (flag_plotproc)
            if (t == 2), goWB.shiftDown(); end
            if (flag_ge == 1), rtplot_googleearth (t, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,t), date(t,:)), end;
            rtplot_matlab (t, [Yhat_t_t(1); Yhat_t_t(2); Yhat_t_t(3)], pos_M(:,t), check_on, check_off, check_pivot, check_cs, flag_ms, ref_path, mat_path, flag_amb);
            if (flag_amb == 1)
                rtplot_amb (t, window, Xhat_t_t(o1+1:o1+nSatTot), sqrt(diag(Cee(o1+1:o1+nSatTot,o1+1:o1+nSatTot))), conf_cs);
                pause(0.1);
            else
                if (flag_skyplot == 1)
                    rtplot_skyplot (t, azR, elR, conf_sat, pivot, Eph_t, SP3);
                    rtplot_snr (snr_R(:,t), Eph_t, SP3);
                else
                    rttext_sat (t, azR, elR, snr_R(:,t), conf_sat, pivot, Eph_t, SP3);
                end
                pause(0.01);
            end
        end
        
        goWB.goTime(t);
    end
    
    goWB.close();

    fclose(fid_kal);
    fclose(fid_sat);
    fclose(fid_dop);
    fclose(fid_conf);
    
%----------------------------------------------------------------------------------------------
% REAL-TIME: ROVER MONITORING
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_RT_R_MON)
    goGPS_rover_monitor(filerootOUT, protocol_idx, flag_var_dyn_model, flag_stopGOstop, goIni.getCaptureRate());

%----------------------------------------------------------------------------------------------
% REAL-TIME: MASTER MONITORING
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_RT_M_MON)

    goGPS_master_monitor(filerootOUT, flag_NTRIP);

%----------------------------------------------------------------------------------------------
% REAL-TIME: ROVER AND MASTER MONITORING
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_RT_RM_MON)

    goGPS_realtime_monitor(filerootOUT, protocol_idx, flag_NTRIP, flag_ms_pos, flag_var_dyn_model, flag_stopGOstop, pos_M);

%----------------------------------------------------------------------------------------------
% REAL-TIME: KALMAN FILTER ON PHASE AND CODE DOUBLE DIFFERENCES WITH/WITHOUT A CONSTRAINT
%----------------------------------------------------------------------------------------------

elseif (mode == goGNSS.MODE_RT_NAV)

    goGPS_realtime(filerootOUT, protocol_idx, mode_vinc, flag_ms, flag_ge, flag_cov, flag_NTRIP, flag_ms_pos, flag_skyplot, flag_plotproc, flag_var_dyn_model, flag_stopGOstop, ref_path, mat_path, pos_M, dop1_M, pr2_M, pr2_R, ph2_M, ph2_R, dop2_M, dop2_R);
end

if (goGNSS.isPP(mode)) %remove unused epochs from time_GPS (for LS modes)
    time_GPS(unused_epochs == 1) = [];
    week_R(unused_epochs == 1) = [];
end

%----------------------------------------------------------------------------------------------
% INPUT/OUTPUT DATA FILE READING
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time)
if goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)
    %stream reading
    % [time_GPS, week_R, time_R, time_M, pr1_R, pr1_M, ph1_R, ph1_M, snr_R, snr_M, ...
    %  pos_M, Eph, iono, loss_R, loss_M, stream_R, stream_M] = load_stream(filerootIN);

    %---------------------------------

    %observation file (OBS) and ephemerides file (EPH) reading
    if (mode == goGNSS.MODE_RT_NAV)
        [time_GPS, week_R, time_R, time_M, pr1_R, pr1_M, ph1_R, ph1_M, dop1_R, snr_R, snr_M, ...
            pos_M, Eph, iono, delay, loss_R, loss_M] = load_goGPSinput(filerootOUT);
    end

    %---------------------------------

    %reading of the files with Kalman filter results
    [Xhat_t_t, Yhat_t_t, Cee, azM, azR, elM, elR, distM, distR, ...
        conf_sat, conf_cs, pivot, PDOP, HDOP, VDOP, KPDOP, ...
        KHDOP, KVDOP] = load_goGPSoutput(filerootOUT, mode, mode_vinc);
    
    %variable saving for final graphical representations
    nObs = size(Xhat_t_t,2);
    pos_KAL = zeros(3,nObs);
    pos_REF = zeros(3,nObs);
    stat_SC = zeros(2,nObs);
    if (any(fixed_solution))
        fixed_amb = fixed_solution;
    else
        fixed_amb = zeros(1,nObs);
        succ_rate = zeros(1,nObs);
    end
    estim_amb = zeros(nSatTot,nObs);
    sigma_amb = zeros(nSatTot,nObs);
    for i = 1 : nObs
        if (mode == goGNSS.MODE_PP_KF_CP_DD & mode_vinc == 1)
            pos_KAL(:,i) = [Yhat_t_t(1,i); Yhat_t_t(2,i); Yhat_t_t(3,i)];
            estim_amb(:,i) = Xhat_t_t(o1+1:o1+nSatTot,i);
            sigma_amb(:,i) = sqrt(diag(Cee(o1+1:o1+nSatTot,o1+1:o1+nSatTot,i)));
        else
            pos_KAL(:,i) = [Xhat_t_t(1,i); Xhat_t_t(o1+1,i); Xhat_t_t(o2+1,i)];
            estim_amb(:,i) = Xhat_t_t(o3+1:o3+nSatTot,i);
            sigma_amb(:,i) = sqrt(diag(Cee(o3+1:o3+nSatTot,o3+1:o3+nSatTot,i)));
        end
        %if relative positioning (i.e. with master station)
        if goGNSS.isDD(mode) && goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)
            pos_REF(:,i) = [pos_M(1,i); pos_M(2,i); pos_M(3,i)];
        else
            pos_REF(:,i) = pos_KAL(:,1);
        end
    end
end

%----------------------------------------------------------------------------------------------
% OUTPUT FILE SAVING (TEXT FILE)
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time)
if goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)
    %display information
    fprintf('Writing output file...\n');
    %cartesian coordinates (X,Y,Z)
    X_KAL = pos_KAL(1,:)';
    Y_KAL = pos_KAL(2,:)';
    Z_KAL = pos_KAL(3,:)';

    %coordinate transformation (geodetic)
    [phi_KAL, lam_KAL, h_KAL] = cart2geod(X_KAL, Y_KAL, Z_KAL);
    phi_KAL = phi_KAL * 180/pi;
    lam_KAL = lam_KAL * 180/pi;

    %coordinate transformation (UTM)
    [EAST_UTM, NORTH_UTM, h_UTM, utm_zone] = cart2plan(X_KAL, Y_KAL, Z_KAL);

    %if relative positioning (i.e. with master station)    
    if goGNSS.isDD(mode) || (mode == goGNSS.MODE_RT_NAV)
        X_ENU = global2localPos(pos_KAL, pos_REF);
        EAST_KAL  = X_ENU(1,:)';
        NORTH_KAL = X_ENU(2,:)';
        UP_KAL    = X_ENU(3,:)';
        
        EAST  = EAST_KAL;
        NORTH = NORTH_KAL;
    else
        EAST_KAL  = zeros(size(EAST_UTM));
        NORTH_KAL = zeros(size(NORTH_UTM));
        UP_KAL    = zeros(size(h_UTM));
        
        EAST  = EAST_UTM;
        NORTH = NORTH_UTM;
    end
    
    %if no Kalman filter is used or if the positioning is constrained
    if (mode_vinc == 1) | (mode == goGNSS.MODE_PP_LS_C_SA) | (mode == goGNSS.MODE_PP_LS_CP_SA) | (mode == goGNSS.MODE_PP_LS_C_DD) | (mode == goGNSS.MODE_PP_LS_CP_DD_L)
        %initialization to -9999 (no data available)
        KHDOP(1:nObs) = -9999;
    end
    N = [];
    h_ortho(1:nObs) = -9999;
    
    %time formatting
    [tow] = weektime2tow(week_R, time_GPS);
    
    %date formatting
    date = gps2date(week_R, tow);
    date(:,1) = two_digit_year(date(:,1));

    %file saving
    fid_out = fopen([filerootOUT '_position.txt'], 'wt');
    fprintf(fid_out, '    Date        GPS time        GPS week         GPS tow        Latitude       Longitude     h (ellips.)          ECEF X          ECEF Y          ECEF Z       UTM North        UTM East         h(AMSL)        UTM zone            HDOP           KHDOP     Local North      Local East         Local H   Ambiguity fix  Success rate\n');
    for i = 1 : nObs
        if (geoid.ncols ~= 0)
            %geoid ondulation interpolation
            N = grid_bilin_interp(lam_KAL(i), phi_KAL(i), geoid.grid, geoid.ncols, geoid.nrows, geoid.cellsize, geoid.Xll, geoid.Yll, -9999);
            %orthometric height
            h_ortho(i) = h_KAL(i) - N;
        end

        %file writing
        fprintf(fid_out, '%02d/%02d/%02d    %02d:%02d:%06.3f% 16d% 16.3f% 16.8f% 16.8f% 16.3f% 16.3f% 16.3f% 16.3f% 16.3f% 16.3f% 16.3f% 16s% 16.3f% 16.3f% 16.3f% 16.3f% 16.3f% 16d% 16.4f\n', date(i,1), date(i,2), date(i,3), date(i,4), date(i,5), date(i,6), week_R(i), tow(i), phi_KAL(i), lam_KAL(i), h_KAL(i), X_KAL(i), Y_KAL(i), Z_KAL(i), NORTH_UTM(i), EAST_UTM(i), h_ortho(i), utm_zone(i,:), HDOP(i), KHDOP(i), NORTH_KAL(i), EAST_KAL(i), UP_KAL(i), fixed_amb(i), succ_rate(i));
    end
    fclose(fid_out);
    
    % Save in matlab format all the outputs
    save([filerootOUT '_position.mat'], 'date', 'week_R', 'tow', 'phi_KAL', 'lam_KAL', 'h_KAL', 'X_KAL', 'Y_KAL', 'Z_KAL', 'NORTH_UTM', 'EAST_UTM', 'utm_zone', 'HDOP', 'KHDOP', 'NORTH_KAL', 'EAST_KAL', 'UP_KAL', 'fixed_amb', 'succ_rate');
end

%----------------------------------------------------------------------------------------------
% REPORT FILE (PDF)
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time)
if (goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)) && (~isempty(EAST))
    %display information
    fprintf('Writing report file (PDF)...\n');

    f = figure('Name','goGPS processing report','NumberTitle','off','PaperOrientation','portrait','PaperUnits','centimeters','PaperType','A4');
    paperSize = get(f,'PaperSize');
    set(f,'PaperPosition',[1,1,paperSize(1)-1,paperSize(2)-1]);

    %settings
    f1 = subplot(7,3,1);
    set(f1,'Visible','off');
    switch mode
        case 1
            text(0,1.00,sprintf('Mode: code\n        stand-alone'));
            text(0,0.75,sprintf('Kalman filter: no'));
        case 2
            text(0,1.00,sprintf('Mode: code\n        stand-alone'));
            text(0,0.75,sprintf('Kalman filter: yes'));
        case 3
            text(0,1.00,sprintf('Mode: code and phase\n        stand-alone'));
            text(0,0.75,sprintf('Kalman filter: no'));
        case 4
            text(0,1.00,sprintf('Mode: code and phase\n        stand-alone'));
            text(0,0.75,sprintf('Kalman filter: yes'));
        case 11
            text(0,1.00,sprintf('Mode: code\n        double difference'));
            text(0,0.75,sprintf('Kalman filter: no'));
        case 12
            text(0,1.00,sprintf('Mode: code\n        double difference'));
            text(0,0.75,sprintf('Kalman filter: yes'));
        case 13
            text(0,1.00,sprintf('Mode: code and phase\n        double difference'));
            text(0,0.75,sprintf('Kalman filter: no'));
        case 14
            text(0,1.00,sprintf('Mode: code and phase\n        double difference'));
            text(0,0.75,sprintf('Kalman filter: yes'));
        case 24
            text(0,1.00,sprintf('Mode: code and phase\n        double difference'));
            text(0,0.75,sprintf('Kalman filter: yes'));
    end
    if (mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV)
        switch order
            case 1
                text(0,0.50,sprintf('Dynamics: static'));
            case 2
                text(0,0.50,sprintf('Dynamics: constant\n            velocity'));
            case 3
                text(0,0.50,sprintf('Dynamics: constant\n            acceleration'));
        end
    end
    text(0,0.25,sprintf('Cutoff: %d deg', cutoff));
    switch weights
        case 0
            text(0,0,sprintf('Weights: no weights'));
        case 1
            text(0,0,sprintf('Weights: elevation'));
        case 2
            text(0,0,sprintf('Weights: SNR'));
        case 3
            text(0,0,sprintf('Weights: elevation\n           and SNR'));
    end
    
    %trajectory plotting
    f3 = subplot(7,3,[2 3 5 6 8 9 11 12]);
    %if relative positioning (i.e. with master station)
    if (goGNSS.isDD(mode) || mode == goGNSS.MODE_RT_NAV)
        EAST_O = 0; NORTH_O = 0;
    else
        EAST_O = EAST_UTM(1); NORTH_O = NORTH_UTM(1);
    end
    plot(EAST-EAST_O, NORTH-NORTH_O, '.r');
    axis equal
    xlabel('EAST [m]'); ylabel('NORTH [m]'); grid on;
    hold on
    if (o1 == 1) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
        %static positioning solution plotting
        plot(EAST(end)-EAST_O, NORTH(end)-NORTH_O, '*b');
%        %covariance propagation
%        Cee_ENU = global2localCov(Cee([1 o1+1 o2+1],[1 o1+1 o2+1],end), Xhat_t_t([1 o1+1 o2+1],end));
        
        legend('Positioning (KF)','Final position','Location','SouthOutside');
    else
        legend('Positioning','Location','SouthOutside');
    end
    
    if (mode == goGNSS.MODE_PP_LS_C_SA | mode == goGNSS.MODE_PP_LS_CP_SA | mode == goGNSS.MODE_PP_LS_CP_DD_L | mode == goGNSS.MODE_PP_LS_C_DD)
        EAST_R = mean(EAST);
        NORTH_R = mean(NORTH);
        h_R = mean(h_KAL);
        plot(EAST_R-EAST_O, NORTH_R-NORTH_O, '*b');
    end
    
        %coordinate transformation (UTM)
    [EAST_REF, NORTH_REF, h_REF, utm_zone] = cart2plan(pos_REF(1,1), pos_REF(2,1), pos_REF(3,1));
        
    %plot(EAST_M-EAST_O, NORTH_M-NORTH_O, 'xc', 'LineWidth', 2);

    %statistics
    f2 = subplot(7,3,[4 7 10]);
    set(f2,'Visible','off');
    if (o1 == 1) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
        text(0,0.95,'----------------');
        text(0,0.90,'Final position (UTM)');
        text(0,0.83,sprintf('E: %.3f m', EAST_UTM(end)));
        text(0,0.78,sprintf('N: %.3f m', NORTH_UTM(end)));
        text(0,0.73,sprintf('h(ell.): %.3f m', h_KAL(end)));
%         text(0,0.62,'----------------');
%         text(0,0.57,'Position estimation error');
%         text(0,0.50,sprintf('E: %.4f m', Cee_ENU(1,1)));
%         text(0,0.45,sprintf('N: %.4f m', Cee_ENU(2,2)));
%         text(0,0.40,sprintf('U: %.4f m', Cee_ENU(3,3)));
    end
    
    if (mode == goGNSS.MODE_PP_LS_C_DD || mode == goGNSS.MODE_PP_LS_CP_DD_L)
        text(0,0.95,'----------------');
        text(0,0.90,'Baseline (mean)');
        text(0,0.83,sprintf('E: %.3f m', mean(EAST_KAL)));
        text(0,0.78,sprintf('N: %.3f m', mean(NORTH_KAL)));
        text(0,0.73,sprintf('h: %.3f m', mean(UP_KAL)));
    else
    text(0,0.62,'----------------');
    text(0,0.57,'Plot false origin (UTM)');
    text(0,0.50,sprintf('E: %.3f m', EAST_O));
    text(0,0.45,sprintf('N: %.3f m', NORTH_O));
    end

    %satellite number
    f4 = subplot(7,3,[13 14 15]);
    nsat = sum(abs(conf_sat),1);
    plot(nsat); grid on;
    title('Number of satellites');
    
    %EAST plot
    f5 = subplot(7,3,[16 17 18]);
    plot(EAST-EAST_O); grid on
    hold on
    pos = find(pivot == 0);
    if (~isempty(pos))
        plot(pos, EAST(pivot == 0)-EAST_O,'.y');
    end
    if (o1 == 1) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
        plot([1, nObs], [EAST(end)-EAST_O EAST(end)-EAST_O],'r');
        title('East coordinates (blue); Not processed / dynamics only (yellow); Final positioning (red)');
    else
        title('East coordinates (blue); Not processed / dynamics only (yellow)');
    end

    %NORTH plot
    f6 = subplot(7,3,[19 20 21]);
    plot(NORTH-NORTH_O); grid on
    hold on
    pos = find(pivot == 0);
    if (~isempty(pos))
        plot(pos, NORTH(pivot == 0)-NORTH_O,'.y');
    end
    if (o1 == 1) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
        plot([1, nObs], [NORTH(end)-NORTH_O NORTH(end)-NORTH_O],'r');
        title('North coordinates (blue); Not processed / dynamics only (yellow); Final positioning (red)');
    else
        title('North coordinates (blue); Not processed / dynamics only (yellow)');
    end
    
    %print PDF
    print(f, '-dpdf', [filerootOUT '_report']);
    
    %remove figure
    close(f)
end

%----------------------------------------------------------------------------------------------
% NMEA FILE SAVING
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time)
if goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)
    %display information
    fprintf('Writing NMEA file...\n');
    %file saving
    fid_nmea = fopen([filerootOUT '_NMEA.txt'], 'wt');
    %date formatting
    date = gps2date(week_R, time_GPS);
    date(:,1) = two_digit_year(date(:,1));

    for i = 1 : nObs

        %active satellites
        sat = find(abs(conf_sat(:,i)));
        %number of active satellites
        nsat = length(sat);
        %visible satellites
        vsat = find(elR(:,i) > 0);

        %NMEA string generation
        GGAstring = NMEA_GGA_gen(pos_KAL(:,i), nsat, time_GPS(i), HDOP(i), mode);
        if (pivot(i) ~= 0)
            RMCstring = NMEA_RMC_gen(pos_KAL(:,i), date(i,:));
            GSVstring = NMEA_GSV_gen(vsat, elR(vsat,i), azR(vsat,i), snr_R(vsat,i), constellations);
            GSAstring = NMEA_GSA_gen(sat, PDOP(i), HDOP(i), VDOP(i), 'M', '3');
            if (mode_vinc == 0) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
                PGGPKstring = NMEA_PGGPK_gen(sat, KPDOP(i), KHDOP(i), KVDOP(i), 'S');
            end
        else
            GSAstring = NMEA_GSA_gen(sat, PDOP(i), HDOP(i), VDOP(i), 'M', '1');
            if (mode_vinc == 0) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
                PGGPKstring = NMEA_PGGPK_gen(sat, KPDOP(i), KHDOP(i), KVDOP(i), 'D');
            end
        end

        %NMEA file write
        fprintf(fid_nmea, [GGAstring '\n']);
        if (pivot(i) ~= 0)
            fprintf(fid_nmea, [RMCstring '\n']);
            fprintf(fid_nmea, [GSVstring '\n']);
        end
        fprintf(fid_nmea, [GSAstring '\n']);
        if (mode_vinc == 0) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
            fprintf(fid_nmea, [PGGPKstring '\n']);
        end
    end
    fclose(fid_nmea);
end

%----------------------------------------------------------------------------------------------
% GOOGLE EARTH FILE SAVING (KML FILE)
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time)
if goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)
    %display information
    fprintf('Writing KML file...\n');
    %"clampToGround" plots the points attached to the ground
    %"absolute" uses the height defined in the tag <coordinates>;
    %N.B. Google Earth uses orthometric heights
    z_pos = 'clampToGround';
    %z_pos = 'absolute';
    %URL to load the icon for the points
    iconR = 'http://maps.google.com/mapfiles/kml/pal2/icon26.png';
    iconM = 'http://maps.google.com/mapfiles/kml/shapes/square.png';
    iconP = 'http://maps.google.com/mapfiles/kml/shapes/square.png';
    good_point_colorR = 'fff5005a';
    bad_point_colorR = 'ff0000ff';
    dyn_point_colorR = 'ff00ffff';
    point_colorM = 'ff00ffff';
    point_colorP = 'ff32cd32';
    %point size
    scaleR = 0.2;
    scaleM = 0.8;
    scaleP = 0.8;
    %line color and thickness (rover track)
    line_colorR = 'fff5005a';
    line_widthR = 1;
    %line color and thickness (stop-go-stop direction)
    line_colorG = 'ff0000ff';
    line_widthG = 4;
    %label color
    label_colorM = point_colorM;
    label_colorP = point_colorP;
    %label size
    label_scaleM = 0.7;
    label_scaleP = 0.7;
    %initialization
    phiM = zeros(1, nObs);
    lamM = zeros(1, nObs);
    hM = zeros(1, nObs);
    
    %threshold on KHDOP
    if (o1 == 1)
        KHDOP_thres = median(KHDOP);
    else
        KHDOP_thres = 2;
    end

    %if relative positioning (i.e. with master station)
    if (goGNSS.isDD(mode) || mode == goGNSS.MODE_RT_NAV)
        %master station coordinates
        for i = 1 : nObs
            if (sum(abs(pos_M(:,i))) ~= 0)
                XM = pos_M(1,i);
                YM = pos_M(2,i);
                ZM = pos_M(3,i);
                
                %conversion from cartesian to geodetic coordinates
                [phiM(i), lamM(i), hM(i)] = cart2geod(XM, YM, ZM);
                
                %conversion from radians to degrees
                lamM(i) = lamM(i)*180/pi;
                phiM(i) = phiM(i)*180/pi;
            else
                lamM(i) = 0;
                phiM(i) = 0;
                hM(i) = 0;
            end
        end
    end
    
    pos = find(filerootOUT == '/');
    kml_name = filerootOUT(pos(end)+1:end);

    %file saving (Google Earth KML)
    fid_kml = fopen([filerootOUT '.kml'], 'wt');
    fprintf(fid_kml, '<?xml version="1.0" encoding="UTF-8"?>\n');
    fprintf(fid_kml, '<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">\n');
    fprintf(fid_kml, '<Document>\n');
    fprintf(fid_kml, '\t<name>%s</name>\n', [kml_name '.kml']);
    fprintf(fid_kml, '\t<snippet>created by goGPS</snippet>\n');
    fprintf(fid_kml, '\t\t<Style id="go1">\n');
    fprintf(fid_kml, '\t\t\t<IconStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',good_point_colorR);
    fprintf(fid_kml, '\t\t\t\t<scale>%.2f</scale>\n',scaleR);
    fprintf(fid_kml, '\t\t\t\t<Icon>\n');
    fprintf(fid_kml, '\t\t\t\t\t<href>%s</href>\n',iconR);
    fprintf(fid_kml, '\t\t\t\t</Icon>\n');
    fprintf(fid_kml, '\t\t\t</IconStyle>\n');
    fprintf(fid_kml, '\t\t</Style>\n');
    fprintf(fid_kml, '\t\t<Style id="go2">\n');
    fprintf(fid_kml, '\t\t\t<IconStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',bad_point_colorR);
    fprintf(fid_kml, '\t\t\t\t<scale>%.2f</scale>\n',scaleR);
    fprintf(fid_kml, '\t\t\t\t<Icon>\n');
    fprintf(fid_kml, '\t\t\t\t\t<href>%s</href>\n',iconR);
    fprintf(fid_kml, '\t\t\t\t</Icon>\n');
    fprintf(fid_kml, '\t\t\t</IconStyle>\n');
    fprintf(fid_kml, '\t\t</Style>\n');
    fprintf(fid_kml, '\t\t<Style id="go3">\n');
    fprintf(fid_kml, '\t\t\t<IconStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',dyn_point_colorR);
    fprintf(fid_kml, '\t\t\t\t<scale>%.2f</scale>\n',scaleR);
    fprintf(fid_kml, '\t\t\t\t<Icon>\n');
    fprintf(fid_kml, '\t\t\t\t\t<href>%s</href>\n',iconR);
    fprintf(fid_kml, '\t\t\t\t</Icon>\n');
    fprintf(fid_kml, '\t\t\t</IconStyle>\n');
    fprintf(fid_kml, '\t\t</Style>\n');
    fprintf(fid_kml, '\t\t<Style id="master">\n');
    fprintf(fid_kml, '\t\t\t<IconStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',point_colorM);
    fprintf(fid_kml, '\t\t\t\t<colorMode>normal</colorMode>\n');
    fprintf(fid_kml, '\t\t\t\t<scale>%.2f</scale>\n',scaleM);
    fprintf(fid_kml, '\t\t\t\t<Icon>\n');
    fprintf(fid_kml, '\t\t\t\t\t<href>%s</href>\n',iconM);
    fprintf(fid_kml, '\t\t\t\t</Icon>\n');
    fprintf(fid_kml, '\t\t\t</IconStyle>\n');
    fprintf(fid_kml, '\t\t\t<LabelStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',label_colorM);
    fprintf(fid_kml, '\t\t\t\t<scale>%s</scale>\n',label_scaleM);
    fprintf(fid_kml, '\t\t\t</LabelStyle>\n');
    fprintf(fid_kml, '\t\t</Style>\n');
    fprintf(fid_kml, '\t\t<Style id="ppos">\n');
    fprintf(fid_kml, '\t\t\t<IconStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',point_colorP);
    fprintf(fid_kml, '\t\t\t\t<colorMode>normal</colorMode>\n');
    fprintf(fid_kml, '\t\t\t\t<scale>%.2f</scale>\n',scaleP);
    fprintf(fid_kml, '\t\t\t\t<Icon>\n');
    fprintf(fid_kml, '\t\t\t\t\t<href>%s</href>\n',iconP);
    fprintf(fid_kml, '\t\t\t\t</Icon>\n');
    fprintf(fid_kml, '\t\t\t</IconStyle>\n');
    fprintf(fid_kml, '\t\t\t<LabelStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',label_colorP);
    fprintf(fid_kml, '\t\t\t\t<scale>%s</scale>\n',label_scaleP);
    fprintf(fid_kml, '\t\t\t</LabelStyle>\n');
    fprintf(fid_kml, '\t\t</Style>\n');
    fprintf(fid_kml, '\t\t<Style id="goLine1">\n');
    fprintf(fid_kml, '\t\t\t<LineStyle>\n');
    fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',line_colorR);
    fprintf(fid_kml, '\t\t\t\t<width>%d</width>\n',line_widthR);
    fprintf(fid_kml, '\t\t\t</LineStyle>\n');
    fprintf(fid_kml, '\t\t</Style>\n');
    if (flag_stopGOstop & goGNSS.isPP(mode)) %stop-go-stop and post-processing
        fprintf(fid_kml, '\t\t<Style id="goLine2">\n');
        fprintf(fid_kml, '\t\t\t<LineStyle>\n');
        fprintf(fid_kml, '\t\t\t\t<color>%s</color>\n',line_colorG);
        fprintf(fid_kml, '\t\t\t\t<width>%d</width>\n',line_widthG);
        fprintf(fid_kml, '\t\t\t</LineStyle>\n');
        fprintf(fid_kml, '\t\t</Style>\n');
    end
    if (goGNSS.isDD(mode) || mode == goGNSS.MODE_RT_NAV) %relative positioning
        for i = 1 : length(phiM)
            if (lamM(i) ~= 0 | phiM(i) ~= 0 | hM(i) ~= 0)
                if (i == 1) | (lamM(i)~=lamM(i-1) | phiM(i)~=phiM(i-1) | hM(i)~=hM(i-1))
                    fprintf(fid_kml, '\t\t<Placemark>\n');
                    fprintf(fid_kml, '\t\t\t<name>Master station</name>\n');
                    fprintf(fid_kml, '\t\t\t<description><![CDATA[ <i>Latitude:</i> %.8f &#176;<br/> <i>Longitude:</i> %.8f &#176;<br/> <i>Elevation (ellips.):</i> %.1f m<br/>]]></description>\n',phiM(i),lamM(i),hM(i));
                    fprintf(fid_kml, '\t\t\t<styleUrl>#master</styleUrl>\n');
                    fprintf(fid_kml, '\t\t\t<Point>\n');
                    fprintf(fid_kml, '\t\t\t\t<altitudeMode>%s</altitudeMode>\n',z_pos);
                    fprintf(fid_kml, '\t\t\t\t<coordinates>%.8f,%.8f,%.3f</coordinates>\n',lamM(i),phiM(i),h_ortho(i));
                    fprintf(fid_kml, '\t\t\t</Point>\n');
                    fprintf(fid_kml, '\t\t</Placemark>\n');
                end
            end
        end
    end
    fprintf(fid_kml, '\t\t<Placemark>\n');
    fprintf(fid_kml, '\t\t<name>Rover track</name>\n');
    fprintf(fid_kml, '\t\t\t<styleUrl>#goLine1</styleUrl>\n');
    fprintf(fid_kml, '\t\t\t<LineString>\n');
    fprintf(fid_kml, '\t\t\t\t<coordinates>\n\t\t\t\t\t');
    for i = 1 : nObs
        fprintf(fid_kml, '%.8f,%.8f,0 ',lam_KAL(i),phi_KAL(i));
    end
    fprintf(fid_kml, '\n\t\t\t\t</coordinates>\n');
    fprintf(fid_kml, '\t\t\t</LineString>\n');
    fprintf(fid_kml, '\t\t</Placemark>\n');
    if (flag_stopGOstop & flag_var_dyn_model & mode == goGNSS.MODE_PP_KF_CP_DD)
        
        [P1Lat, P1Lon] = cart2geod(P1_GLB(1), P1_GLB(2), P1_GLB(3));
        [P2Lat, P2Lon] = cart2geod(P2_GLB(1), P2_GLB(2), P2_GLB(3));
        
        fprintf(fid_kml, '\t\t<Placemark>\n');
        fprintf(fid_kml, '\t\t<name>Estimated direction</name>\n');
        fprintf(fid_kml, '\t\t\t<styleUrl>#goLine2</styleUrl>\n');
        fprintf(fid_kml, '\t\t\t<LineString>\n');
        fprintf(fid_kml, '\t\t\t\t<coordinates>\n\t\t\t\t\t');
        fprintf(fid_kml, '%.8f,%.8f,0 ',P1Lon*180/pi,P1Lat*180/pi);
        fprintf(fid_kml, '%.8f,%.8f,0 ',P2Lon*180/pi,P2Lat*180/pi);
        fprintf(fid_kml, '\n\t\t\t\t</coordinates>\n');
        fprintf(fid_kml, '\t\t\t</LineString>\n');
        fprintf(fid_kml, '\t\t</Placemark>\n');
    end
    fprintf(fid_kml, '\t\t<Folder>\n');
    fprintf(fid_kml, '\t\t<name>Rover positioning</name>\n');
    for i = 1 : nObs
        fprintf(fid_kml, '\t\t<Placemark>\n');
        if (pivot(i) == 0)
            fprintf(fid_kml, '\t\t\t<styleUrl>#go3</styleUrl>\n');
        elseif (KHDOP(i)>KHDOP_thres)
            fprintf(fid_kml, '\t\t\t<styleUrl>#go2</styleUrl>\n');
        else
            fprintf(fid_kml, '\t\t\t<styleUrl>#go1</styleUrl>\n');
        end
        fprintf(fid_kml, '\t\t\t<Point>\n');
        fprintf(fid_kml, '\t\t\t\t<altitudeMode>%s</altitudeMode>\n',z_pos);
        fprintf(fid_kml, '\t\t\t\t<coordinates>%.8f,%.8f,%.3f</coordinates>\n',lam_KAL(i),phi_KAL(i),h_KAL(i));
        fprintf(fid_kml, '\t\t\t</Point>\n');
        fprintf(fid_kml, '\t\t</Placemark>\n');
    end
    fprintf(fid_kml, '\t\t</Folder>\n');

    if (mode_vinc == 0) && ((mode == goGNSS.MODE_PP_KF_C_SA) || (mode == goGNSS.MODE_PP_KF_CP_SA) || (mode == goGNSS.MODE_PP_KF_C_DD) || (mode == goGNSS.MODE_PP_KF_CP_DD) || (mode == goGNSS.MODE_RT_NAV))
        if (o1 == 1) & (nObs ~= 0)
            %static positioning coordinates
            phiP = phi_KAL(end);
            lamP = lam_KAL(end);
            hP   = h_KAL(end);

            fprintf(fid_kml, '\t\t<Placemark>\n');
            fprintf(fid_kml, '\t\t\t<name>Static positioning</name>\n');
            fprintf(fid_kml, '\t\t\t<description><![CDATA[ <i>Latitude:</i> %.8f &#176;<br/> <i>Longitude:</i> %.8f &#176;<br/> <i>Elevation (ellips.):</i> %.1f m<br/>]]></description>\n',phiP,lamP,hP);
            fprintf(fid_kml, '\t\t\t<styleUrl>#ppos</styleUrl>\n');
            fprintf(fid_kml, '\t\t\t<Point>\n');
            fprintf(fid_kml, '\t\t\t\t<altitudeMode>%s</altitudeMode>\n',z_pos);
            fprintf(fid_kml, '\t\t\t\t<coordinates>%.8f,%.8f,%.3f</coordinates>\n',lamP,phiP,hP);
            fprintf(fid_kml, '\t\t\t</Point>\n');
            fprintf(fid_kml, '\t\t</Placemark>\n');
        end
    end
    fprintf(fid_kml, '</Document>\n</kml>');
    fclose(fid_kml);

end


%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE ESTIMATED ERROR COVARIANCE (AND TEXT FILE SAVING)
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time, not constrained)
if ((goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)) && (~isempty(EAST)) && (mode_vinc == 0))

    %display information
    fprintf('Writing estimated error covariance files...\n');
    %covariance propagation
    Cee_XYZ = Cee([1 o1+1 o2+1],[1 o1+1 o2+1],:);
    Cee_ENU = global2localCov(Cee([1 o1+1 o2+1],[1 o1+1 o2+1],:), Xhat_t_t([1 o1+1 o2+1],:));
    
    if (flag_cov == 1)
        %trajectory plotting
        figure
        plot(EAST, NORTH, '.r'); axis equal
        xlabel('EAST [m]'); ylabel('NORTH [m]'); grid on;
        
        hold on
        for i = 1 : size(Cee_ENU,3)         % ellipse definition
            T = chol(Cee_ENU(1:2,1:2,i));   % Cholesky decomposition
            n = size(x_circle,1);
            x_ellipse = zeros(n,2);         % pre-allocation
            for j = 1 : n                   % ellipse definition
                x_ellipse(j,:) = x_circle(j,:) * T + [EAST(i), NORTH(i)];
            end
            he = plot(x_ellipse(:,1),x_ellipse(:,2),'b');
            if (any(fixed_amb) && fixed_amb(i) == 0)
                set(he,'Color',[0.8 0.5 0])
            end
        end
        hold off
    end

    %file saving (XYZ covariance)
    fid_cov = fopen([filerootOUT '_cov_XYZ.txt'], 'wt');
    fprintf(fid_cov, '      XX              XY              XZ              YY              YZ              ZZ\n');
    for i = 1 : length(phi_KAL)
        fprintf(fid_cov, '   %.3f% 16.3f% 16.3f% 16.3f% 16.3f% 16.3f\n', Cee_XYZ(1,1,i), Cee_XYZ(1,2,i), ...
            Cee_XYZ(1,3,i), Cee_XYZ(2,2,i), Cee_XYZ(2,3,i), Cee_XYZ(3,3,i));
    end
    fclose(fid_cov);
    
    %file saving (ENU covariance)
    fid_cov = fopen([filerootOUT '_cov_ENU.txt'], 'wt');
    fprintf(fid_cov, 'EastEast       EastNorth          EastUp      NorthNorth         NorthUp            UpUp\n');
    for i = 1 : length(phi_KAL)
        fprintf(fid_cov, '   %.3f% 16.3f% 16.3f% 16.3f% 16.3f% 16.3f\n', Cee_ENU(1,1,i), Cee_ENU(1,2,i), ...
            Cee_ENU(1,3,i), Cee_ENU(2,2,i), Cee_ENU(2,3,i), Cee_ENU(3,3,i));
    end
    fclose(fid_cov);

end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE ESTIMATED COORDINATES TIME SERIES
%----------------------------------------------------------------------------------------------

if (mode ~= goGNSS.MODE_PP_LS_CP_VEL) && (goGNSS.isPP(mode))    
    figure
    epochs = (time_GPS-time_GPS(1))/interval;
    ax = zeros(3,1);
    ax(1) = subplot(3,1,1); hold on; grid on
    ax(2) = subplot(3,1,2); hold on; grid on
    ax(3) = subplot(3,1,3); hold on; grid on
    xlabel('epoch')
    
    %if relative positioning (i.e. with master station)
    if (goGNSS.isDD(mode) || mode == goGNSS.MODE_RT_NAV)
        
        subplot(ax(1))
        plot(epochs, EAST,'.'); title('EAST'); ylabel('[m]')
        subplot(ax(2))
        plot(epochs, NORTH,'.'); title('NORTH'); ylabel('[m]')
        subplot(ax(3))
        plot(epochs, UP_KAL,'.'); title('UP'); ylabel('[m]')
        
        pos = find(fixed_amb == 1);
        plot(ax(1), epochs(pos), EAST(pos),'xr')
        plot(ax(2), epochs(pos), NORTH(pos),'xr')
        plot(ax(3), epochs(pos), UP_KAL(pos),'xr')
        
    else
        subplot(ax(1))
        plot(epochs, EAST_UTM,'.'); title('EAST UTM'); ylabel('[m]')
        subplot(ax(2))
        plot(epochs, NORTH_UTM,'.'); title('NORTH UTM'); ylabel('[m]')
        subplot(ax(3))
        plot(epochs, h_KAL,'.'); title('ellipsoidal height'); ylabel('[m]')
        
        pos = find(fixed_amb == 1);
        plot(ax(1), epochs(pos), EAST_UTM(pos),'xr')
        plot(ax(2), epochs(pos), NORTH_UTM(pos),'xr')
        plot(ax(3), epochs(pos), h_KAL(pos),'xr')
    end
    
    pos = find(pivot == 0);
    plot(ax(1), epochs(pos), EAST(pos),'.y')
    plot(ax(2), epochs(pos), NORTH(pos),'.y')
    plot(ax(3), epochs(pos), h_KAL(pos),'.y')
    
    linkaxes(ax,'x')
end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE REFERENCE TRAJECTORY
%----------------------------------------------------------------------------------------------

% %if any positioning was done (either post-processing or real-time, but constrained)
% if ((goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)) && mode_ref == 1)
%     [EAST_ref, NORTH_ref, h_ref] = cart2plan(ref_path(:,1), ref_path(:,2),ref_path(:,3));
% 
%     %reference data plot
%     plot(EAST_ref, NORTH_ref, 'm', 'LineWidth', 2)
% 
%     hold off
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE 2D TRAJECTORY
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time, not constrained)
if ((goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)) && (~isempty(EAST)))
    %2D plot
    figure
    plot(EAST, NORTH, '.r');
    xlabel('EAST [m]'); ylabel('NORTH [m]'); grid on
end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE 3D TRAJECTORY
%----------------------------------------------------------------------------------------------

%if any positioning was done (either post-processing or real-time, not constrained)
if ((goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)) && (~isempty(EAST)))
    
%     %3D plot (XYZ)
%     figure
%     plot3(X_KAL, Y_KAL, Z_KAL, '.r');
%     xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]'); grid on
    
    %3D plot (ENU)
    figure
    plot3(EAST, NORTH, h_KAL, '.r');
    xlabel('EAST [m]'); ylabel('NORTH [m]'); zlabel('h [m]'); grid on
end

% %----------------------------------------------------------------------------------------------
% % REPRESENTATION OF THE 2D TRAJECTORY on Google Maps
% %----------------------------------------------------------------------------------------------
% 
% %if any positioning was done (either post-processing or real-time, not constrained)
% if ((goGNSS.isPP(mode) || (mode == goGNSS.MODE_RT_NAV)) && (~isempty(lam_KAL)))
%     %2D plot
%     figure
%     plot(lam_KAL, phi_KAL, '.r');
%     xlabel('lon [deg]'); ylabel('lat [deg]');
%     plot_google_map('MapType','hybrid');
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE VISIBLE SATELLITES CONFIGURATION
%----------------------------------------------------------------------------------------------

% if (mode == goGNSS.MODE_PP_KF_CP_DD)
%
%    %figure
%    %imagesc(abs(conf_sat)), grid;
%    %colormap(1-gray);
%
%    figure
%    subplot('position',[0.1 0.35 0.8 0.55]);
%    hold on; grid on;
%    title('Satellite configuration')
%    for i = 1 : nSatTot
%       index = find(abs(conf_sat(i,:)) == 1);
%       index_cs = intersect(index, find(conf_cs(i,:) == 1));
%       index_pivot = intersect(index, find(pivot == i));
%       if ~isempty(index)
%          plot(index,i*ones(size(index)),'b.-');
%          plot(index_pivot,i*ones(size(index_pivot)),'r.');
%          plot(index_cs,i*ones(size(index_cs)),'g.');
%       end
%    end
%    axis([1 size(conf_sat,2) 0.5 32.5])
%    hold off;
%    clear i index index_cs index_pivot
%
%    subplot('position',[0.1 0.1 0.8 0.2]);
%    hold on; grid on;
%    s1 = sum(abs(conf_sat));
%    plot(s1,'b.-');
%    s2 = [0; pivot(2:end) - pivot(1:end-1)];
%    plot(find(s2>0),s1(s2>0),'r.')
%    s3 = sum(conf_cs);
%    plot(find(s3>0),s3(s3>0),'g.');
%    axis([1 size(conf_sat,2) 0 max(s1)])
%    hold off;
%    clear s1 s2 s3
%
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF AZIMUTH, ELEVATION AND DISTANCE FOR VISIBILE SATELLITES
%----------------------------------------------------------------------------------------------

% if (mode == goGNSS.MODE_PP_KF_CP_DD)
%
%    coltab = jet(2*nSatTot);
% 
%    f1 = figure; hold on; grid on; title('Azimuth')
%    f2 = figure; hold on; grid on; title('Elevation')
%    f3 = figure; hold on; grid on; title('Distance')
%    k = 1;
%    for i = 1 : nSatTot
%       index = find(abs(conf_sat(i,:)) == 1)';
%       if ~isempty(index)
%          %azimuth
%          figure(f1)
%          h = plot(index,azR(i,index),'b.'); grid on;
%          set(h,'Color',coltab(2*i-1,:));
%          %elevation
%          figure(f2)
%          h = plot(index,elR(i,index),'r.');
%          set(h,'Color',coltab(2*i-1,:));
%          %distance
%          figure(f3)
%          h = plot(index,distR(i,index)*1e-6,'g.');
%          set(h,'Color',coltab(2*i-1,:));
%          %legend
%          list{k} = num2str(i);
%          k = k+1;
%       end
%    end
%    figure(f1); hold off; legend(list)
%    figure(f2); hold off; legend(list)
%    figure(f3); hold off; legend(list)
%    clear f1 f2 f3
%    clear i k h
%    clear coltab
%
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE S/N RATIO FOR MASTER AND ROVER
%----------------------------------------------------------------------------------------------

% if (mode == goGNSS.MODE_PP_KF_CP_DD)
%
%    coltab = jet;
%    coltab = [1 1 1; coltab([1 16 32 48 56],:)];
%
%    figure
%    subplot(2,1,1);
%    imagesc(snr_R.*abs(conf_sat),[-0.5 60.5]);
%    title('Rover S/N ratio');
%    axis xy; colormap(coltab);
%    h = colorbar; set(h,'YTick',0:10:60);
%    subplot(2,1,2);
%    imagesc(snr_M.*abs(conf_sat),[-0.5 60.5]);
%    title('Master S/N ratio');
%    axis xy; colormap(coltab);
%    h = colorbar; set(h,'YTick',0:10:60);
%
%    clear h coltab
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF THE COMBINATIONS OF ESTIMATED AMBIGUITIES
%----------------------------------------------------------------------------------------------

% if (mode == goGNSS.MODE_PP_KF_CP_DD) | (mode == goGNSS.MODE_PP_KF_CP_SA)
% 
%    for i = 1 : nSatTot
%       index = find(conf_sat(i,:) == 1)';
%       index_cs = find(conf_cs(i,:) == 1)';
%       if ~isempty(index)
%          j = [1; find(index(2:end) - index(1:end-1) > 1)+1];
%          figure
%          %combination of estimated ambiguities
%          plot(index,estim_amb(i,index),'b.-'); grid on;
%          hold on
%          %cycle-slip
%          plot(index_cs,estim_amb(i,index_cs),'mo');
%          %combination of estimated ambiguities for new satellites
%          plot(index(j),estim_amb(i,index(j)),'g.');
%          %acceptance interval
%          plot(index, estim_amb(i,index) + sigma_amb(i,index),'r:');
%          plot(index, estim_amb(i,index) - sigma_amb(i,index),'r:');
%          hold off
%          title(['Combination of estimated ambiguities between PIVOT and SATELLITE ',num2str(i)]);
%       end
%    end
% 
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF LAMBDA1*L1-P1
%----------------------------------------------------------------------------------------------

% %rover
% for i = 1 : nSatTot
%     index = find(conf_sat(i,:) == 1)';
%     if ~isempty(index)
%         figure
%         plot(index,lambda1*ph1_R(i,index)-pr1_R(i,index),'b.-'); grid on;
%         title(['ROVER: lambda1*L1-P1 for SATELLITE ',num2str(i)]);
%     end
% end
% 
% %master
% for i = 1 : nSatTot
%     index = find(conf_sat(i,:) == 1)';
%     if ~isempty(index)
%         figure
%         plot(index,lambda1*ph1_M(i,index)-pr1_M(i,index),'b.-'); grid on;
%         title(['MASTER: lambda1*L1-P1 for SATELLITE ',num2str(i)]);
%     end
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF CODE AND PHASE DOUBLE DIFFERENCES
%----------------------------------------------------------------------------------------------

% %code
% for i = 1 : nSatTot
%     index = find(conf_sat(i,:) == 1)';
%     index_pivot = intersect(index, find(pivot == i));
%     if ~isempty(index) & (length(index) ~= length(index_pivot))
%         figure
%         title(['CODE DOUBLE DIFFERENCES between SATELLITE ',num2str(i),'and PIVOT']);
%         hold on
%         grid on
%         for j = 1 : length(time_GPS)
%             if (conf_sat(i,j) & i ~= pivot(j))
%                 plot(j,(pr1_R(i,j)-pr1_M(i,j))-(pr1_R(pivot(j),j)-pr1_M(pivot(j),j)),'b.');
%             end
%         end
%     end
% end
% 
% %phase
% for i = 1 : nSatTot
%     index = find(conf_sat(i,:) == 1)';
%     index_pivot = intersect(index, find(pivot == i));
%     if ~isempty(index) & (length(index) ~= length(index_pivot))
%         figure
%         title(['PHASE DOUBLE DIFFERENCES between SATELLITE ',num2str(i),'and PIVOT']);
%         hold on
%         grid on
%         for j = 1 : length(time_GPS)
%             if (conf_sat(i,j) & i ~= pivot(j))
%                 plot(j,(ph1_R(i,j)-ph1_M(i,j))-(ph1_R(pivot(j),j)-ph1_M(pivot(j),j)),'b.');
%             end
%         end
%     end
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF PSEUDORANGE AND PHASE MEASUREMENT
%----------------------------------------------------------------------------------------------

% %rover pseudorange
% for i = 1 : nSatTot
%     index = find(pr1_R(i,:) ~= 0)';
%     if ~isempty(index)
%         figure
%         plot(index,pr1_R(i,index),'b.-'); grid on;
%         title(['ROVER: PSEUDORANGE for SATELLITE ',num2str(i)]);
%     end
% end
% %rover phase measurement
% for i = 1 : nSatTot
%     index = find(ph1_R(i,:) ~= 0)';
%     if ~isempty(index)
%         figure
%         plot(index,ph1_R(i,index),'b.-'); grid on;
%         title(['ROVER: PHASE MEASUREMENT for SATELLITE ',num2str(i)]);
%     end
% end
% 
% %master pseudorange
% for i = 1 : nSatTot
%     index = find(pr1_M(i,:) ~= 0)';
%     if ~isempty(index)
%         figure
%         plot(index,pr1_M(i,index),'b.-'); grid on;
%         title(['MASTER: PSEUDORANGE for SATELLITE ',num2str(i)]);
%     end
% end
% %master phase measurement
% for i = 1 : nSatTot
%     index = find(ph1_M(i,:) ~= 0)';
%     if ~isempty(index)
%         figure
%         plot(index,ph1_M(i,index),'b.-'); grid on;
%         title(['MASTER: PHASE MEASUREMENT for SATELLITE ',num2str(i)]);
%     end
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF PSEUDORANGE DERIVATIVES
%----------------------------------------------------------------------------------------------

% %rover
% for i = 1 : nSatTot
%     index = find(pr1_R(i,:) ~= 0)';
%     if ~isempty(index)
%         pr = pr1_R(i,index);
%         j = 1;
%         diff_index = 0;
%         while (j <= length(index) & diff_index ~= 1)
%             diff_index = index(j+1) - index(j);
%             interval = time_R(index(j+1)) - time_R(index(j));
%             j = j + 1;
%         end
%         pr_der1 = zeros(length(index)-1,1);
%         pr_der2 = zeros(length(index)-2,1);
%         pr_der3 = zeros(length(index)-3,1);
%         for j = 1 : length(index)-1
%             if (index(j+1) == index(j) + 1)
%                 pr_der1(j) = (pr(j+1)-pr(j))/interval;
%             else
%                 if (j > 1)
%                     pr_der1(j) = pr_der1(j-1);
%                 end
%             end
%             if (j <= length(index)-2)
%                 if (index(j+2) == index(j) + 2)
%                     pr_der2(j) = (pr(j+2)-2*pr(j+1)+pr(j))/interval^2;
%                 else
%                     if (j > 1)
%                         pr_der2(j) = pr_der2(j-1);
%                     end
%                 end
%             end
%             if (j <= length(index)-3)
%                 if (index(j+3) == index(j) + 3)
%                     pr_der3(j) = (pr(j+3)-3*pr(j+2)+3*pr(j+1)-pr(j))/interval^3;
%                 else
%                     if (j > 1)
%                         pr_der3(j) = pr_der3(j-1);
%                     end
%                 end
%             end
%         end
%         pos = find(pr_der1 == 0);
%         pr_der1(pos) = [];
%         pr_der2(pos) = [];
%         index(pos) = [];
%         figure
%         plot(index(1:end-1), pr_der1,'b.');
%         title(['ROVER: PSEUDORANGE FIRST DERIVATIVE for SATELLITE ',num2str(i)]);
%         figure
%         plot(index(1:end-2), pr_der2,'b.');
%         title(['ROVER: PSEUDORANGE SECOND DERIVATIVE for SATELLITE ',num2str(i)]);
%         figure
%         plot(index(1:end-3), pr_der3,'b.');
%         title(['ROVER: PSEUDORANGE THIRD DERIVATIVE for SATELLITE ',num2str(i)]);
%     end
% end
% 
% %master
% for i = 1 : nSatTot
%     index = find(pr1_M(i,:) ~= 0)';
%     if ~isempty(index)
%         pr = pr1_M(i,index);
%         j = 1;
%         diff_index = 0;
%         while (j <= length(index) & diff_index ~= 1)
%             diff_index = index(j+1) - index(j);
%             interval = time_M(index(j+1)) - time_M(index(j));
%             j = j + 1;
%         end
%         pr_der1 = zeros(length(index)-1,1);
%         pr_der2 = zeros(length(index)-2,1);
%         for j = 1 : length(index)-1
%             if (index(j+1) == index(j) + 1)
%                 pr_der1(j) = (pr(j+1)-pr(j))/interval;
%             else
%                 if (j > 1)
%                     pr_der1(j) = pr_der1(j-1);
%                 end
%             end
%             if (j <= length(index)-2)
%                 if (index(j+2) == index(j) + 2)
%                     pr_der2(j) = (pr(j+2)-2*pr(j+1)+pr(j))/interval^2;
%                 else
%                     if (j > 1)
%                         pr_der2(j) = pr_der2(j-1);
%                     end
%                 end
%             end
%         end
%         pos = find(pr_der1 == 0);
%         pr_der1(pos) = [];
%         pr_der2(pos) = [];
%         index(pos) = [];
%         figure
%         plot(index(1:end-1), pr_der1,'b.');
%         title(['MASTER: PSEUDORANGE FIRST DERIVATIVE for SATELLITE ',num2str(i)]);
%         figure
%         plot(index(1:end-2), pr_der2,'b.');
%         title(['MASTER: PSEUDORANGE SECOND DERIVATIVE for SATELLITE ',num2str(i)]);
%     end
% end

%----------------------------------------------------------------------------------------------
% REPRESENTATION OF PHASE RANGE DERIVATIVES
%----------------------------------------------------------------------------------------------

% %rover
% for i = 1 : nSatTot
%     index = find(ph1_R(i,:) ~= 0)';
%     if ~isempty(index)
%         ph = ph1_R(i,index);
%         j = 1;
%         diff_index = 0;
%         while (j <= length(index) & diff_index ~= 1)
%             diff_index = index(j+1) - index(j);
%             interval = time_R(index(j+1)) - time_R(index(j));
%             j = j + 1;
%         end
%         ph_der1 = zeros(length(index)-1,1);
%         ph_der2 = zeros(length(index)-2,1);
%         for j = 1 : length(index)-1
%             if (index(j+1) == index(j) + 1)
%                 ph_der1(j) = (ph(j+1)-ph(j))/interval;
%             else
%                 if (j > 1)
%                     ph_der1(j) = ph_der1(j-1);
%                 end
%             end
%             if (j <= length(index)-2)
%                 if (index(j+2) == index(j) + 2)
%                     ph_der2(j) = (ph(j+2)-2*ph(j+1)+ph(j))/interval^2;
%                 else
%                     if (j > 1)
%                         ph_der2(j) = ph_der2(j-1);
%                     end
%                 end
%             end
%         end
%         pos = find(ph_der1 == 0);
%         ph_der1(pos) = [];
%         ph_der2(pos) = [];
%         index(pos) = [];
%         figure
%         plot(index(1:end-1), ph_der1,'b-');
%         title(['ROVER: PHASE FIRST DERIVATIVE for SATELLITE ',num2str(i)]);
%         figure
%         plot(index(1:end-2), ph_der2,'b-');
%         title(['ROVER: PHASE SECOND DERIVATIVE for SATELLITE ',num2str(i)]);
%     end
% end
% 
% %master
% for i = 1 : nSatTot
%     index = find(ph1_M(i,:) ~= 0)';
%     if ~isempty(index)
%         ph = ph1_M(i,index);
%         j = 1;
%         diff_index = 0;
%         while (j <= length(index) & diff_index ~= 1)
%             diff_index = index(j+1) - index(j);
%             interval = time_M(index(j+1)) - time_M(index(j));
%             j = j + 1;
%         end
%         ph_der1 = zeros(length(index)-1,1);
%         ph_der2 = zeros(length(index)-2,1);
%         for j = 1 : length(index)-1
%             if (index(j+1) == index(j) + 1)
%                 ph_der1(j) = (ph(j+1)-ph(j))/interval;
%             else
%                 if (j > 1)
%                     ph_der1(j) = ph_der1(j-1);
%                 end
%             end
%             if (j <= length(index)-2)
%                 if (index(j+2) == index(j) + 2)
%                     ph_der2(j) = (ph(j+2)-2*ph(j+1)+ph(j))/interval^2;
%                 else
%                     if (j > 1)
%                         ph_der2(j) = ph_der2(j-1);
%                     end
%                 end
%             end
%         end
%         pos = find(ph_der1 == 0);
%         ph_der1(pos) = [];
%         ph_der2(pos) = [];
%         index(pos) = [];
%         figure
%         plot(index(1:end-1), ph_der1,'b-');
%         title(['MASTER: PHASE FIRST DERIVATIVE for SATELLITE ',num2str(i)]);
%         figure
%         plot(index(1:end-2), ph_der2,'b-');
%         title(['MASTER: PHASE SECOND DERIVATIVE for SATELLITE ',num2str(i)]);
%     end
% end

%----------------------------------------------------------------------------------------------
% STATISTICS COMPUTATION AND VISUALIZATION
%----------------------------------------------------------------------------------------------

if goGNSS.isPP(mode) && (mode_vinc == 0) && (~isempty(ref_path)) && (~isempty(EAST_KAL))
    %coordinate transformation
    [EAST_REF, NORTH_REF, h_REF] = cart2plan(ref_path(:,1), ref_path(:,2), ref_path(:,3));

    ref = [EAST_REF NORTH_REF h_REF];

    [dist2D, proj] = ref_2d_projection(ref,EAST,NORTH); %#ok<NASGU>

    fprintf('\n');
    fprintf('-------- STATISTICS ------------');
    fprintf('\n');
    fprintf('Mean2D: %7.4f m\n',mean(dist2D));
    fprintf('Std2D:  %7.4f m\n',std(dist2D,1));
    fprintf('RMS2D:  %7.4f m\n\n',sqrt(std(dist2D)^2+mean(dist2D)^2));

    [dist3D,proj] = ref_3d_projection(ref,EAST,NORTH,h_KAL);

    fprintf('Mean3D: %7.4f m\n',mean(dist3D));
    fprintf('Std3D:  %7.4f m\n',std(dist3D,1));
    fprintf('RMS3D:  %7.4f m\n',sqrt(std(dist3D)^2+mean(dist3D)^2));
    fprintf('--------------------------------\n\n');
end

%----------------------------------------------------------------------------------------------

% close all the opened files
fclose('all');

%re-enable MATLAB warnings
warning on

%evaluate computation time
toc
