% Script to investigate the instantaneous pulse assumption
%%% 2019-04-19 - Automatically copmute the FWHM. Use alpha parameter for
%%% Gausswin=3 to be consistent throughout paper.

%%% Test the SSFP simulations

tissuepars = init_tissue('ic');


%%% Set up sequence

%%% generate some pulses
flips = d2r([1:2:30 35:5:80]);
nf = length(flips);
tau = 2e-3;
TR = 5e-3;
b1_rms = 5;
delta = 7e3;
dt = 10e-6;
gauss_alpha = 3; %<-- width parameter for pulses

pulses = {};
b1sqrd = {};
b1pulse= {};
for ii=1:nf
    % 3 bands
    [pulses{ii,1},b1sqrd{ii,1},b1pulse{ii,1},TBP] = gen_MB_pulse(flips(ii),tau,TR,b1_rms,delta,'3','alpha',gauss_alpha,'dt',dt); 
    % 2 bands
    [pulses{ii,2},b1sqrd{ii,2},b1pulse{ii,2},TBP] = gen_MB_pulse(flips(ii),tau,TR,b1_rms,delta,'2+','alpha',gauss_alpha,'dt',dt);
end


%% bSSFP steady state

%%% Extra pars needed for SSFP
dphi=0;


% loop over the different flips
Mssfp = zeros([nf 3 3]); % Flips, #bands, type of simulation

Delta_Hz = [-delta 0 delta];
for ii=1:nf
    
    %%% ===== Instantaneous Assumption  ======    
    %%% Symmetric (3-band) case
    [Mssfp(ii,3,1)] = ssSSFP_ihMT(flips(ii),b1sqrd{ii,1},Delta_Hz,TR,tau,dphi,tissuepars);
    %%% Asymmetric (2-band) case
    [Mssfp(ii,2,1)] = ssSSFP_ihMT(flips(ii),b1sqrd{ii,2},Delta_Hz,TR,tau,dphi,tissuepars);
    %%% Single band case
    Mssfp(ii,1,1) =ssSSFP_ihMT(flips(ii),b1sqrd{ii,1}.*[0 1 0],Delta_Hz,TR,tau,dphi,tissuepars);
    
    %%% ===== Full integration  ======
    %%% Symmetric (3-band) case
    [Mssfp(ii,3,2)] = ssSSFP_ihMT_integrate(b1pulse{ii,1},dt,Delta_Hz,TR,dphi,tissuepars);
    %%% Asymmetric (2-band) case
    [Mssfp(ii,2,2)] = ssSSFP_ihMT_integrate(b1pulse{ii,2},dt,Delta_Hz,TR,dphi,tissuepars);
    %%% Single band case
    Mssfp(ii,1,2) =ssSSFP_ihMT_integrate(b1pulse{ii,1}.*[0 1 0],dt,Delta_Hz,TR,dphi,tissuepars);

    %%% ===== Bieri Scheffler correction
    
    % compute new R2
    tissuepars_mod = Bieri_Scheffler_finite_correction(TBP,tau,TR,tissuepars);

    %%% Symmetric (3-band) case
    [Mssfp(ii,3,3)] = ssSSFP_ihMT(flips(ii),b1sqrd{ii,1},Delta_Hz,TR,tau,dphi,tissuepars_mod);
    %%% Asymmetric (2-band) case
    [Mssfp(ii,2,3)] = ssSSFP_ihMT(flips(ii),b1sqrd{ii,2},Delta_Hz,TR,tau,dphi,tissuepars_mod);
    %%% Single band case
    Mssfp(ii,1,3) =ssSSFP_ihMT(flips(ii),b1sqrd{ii,1}.*[0 1 0],Delta_Hz,TR,tau,dphi,tissuepars_mod);
    
end

%% Repeat above, but for SPGR, miss out correction on here

% loop over the different flips
Mspgr = zeros([nf 3 2]); % Flips, #bands, type of simulation

Delta_Hz = [-delta 0 delta];
for ii=1:nf
    
    %%% ===== Instantaneous Assumption  ======    
    %%% Symmetric (3-band) case
    [Mspgr(ii,3,1)] = ssSPGR_ihMT(flips(ii),b1sqrd{ii,1},Delta_Hz,TR,tau,tissuepars);
    %%% Asymmetric (2-band) case
    [Mspgr(ii,2,1)] = ssSPGR_ihMT(flips(ii),b1sqrd{ii,2},Delta_Hz,TR,tau,tissuepars);
    %%% Single band case
    Mspgr(ii,1,1) =ssSPGR_ihMT(flips(ii),b1sqrd{ii,1}.*[0 1 0],Delta_Hz,TR,tau,tissuepars);
    
    %%% ===== Full integration  ======
    %%% Symmetric (3-band) case
    [Mspgr(ii,3,2)] = ssSPGR_ihMT_integrate(b1pulse{ii,1},dt,Delta_Hz,TR,tissuepars);
    %%% Asymmetric (2-band) case
    [Mspgr(ii,2,2)] = ssSPGR_ihMT_integrate(b1pulse{ii,2},dt,Delta_Hz,TR,tissuepars);
    %%% Single band case
    Mspgr(ii,1,2) =ssSPGR_ihMT_integrate(b1pulse{ii,1}.*[0 1 0],dt,Delta_Hz,TR,tissuepars);

    
end




%% Now consider a fixed flip angle, look at different pulse duration and dipolar relaxation time

%%% generate some pulses
flipangle = d2r(60);

% range of tau and dipolar T1
n=16;
tau = linspace(0.4e-3,2.5e-3,n);
T1D = logspace(-4,-2,n);

TR = 5e-3;
b1_rms = 5;
delta = 7e3;
dt = 10e-6;

pulses = {};
b1sqrd = {};
b1pulse= {};
for ii=1:n
    % 3 bands
    [pulses{ii,1},b1sqrd{ii,1},b1pulse{ii,1}] = gen_MB_pulse(flipangle,tau(ii),TR,b1_rms,delta,'3','alpha',gauss_alpha,'dt',dt); 
    % 2 bands
    [pulses{ii,2},b1sqrd{ii,2},b1pulse{ii,2}] = gen_MB_pulse(flipangle,tau(ii),TR,b1_rms,delta,'2+','alpha',gauss_alpha,'dt',dt);
end


%%% Now compute a grid of points
Mssfp_all = zeros([n n 3 3]); % T1D, tau, method, number of bands

for ii=1:n

    % generate new tissue parameter set
    tmp = init_tissue('ic');
    tmp.semi.R1D = 1/T1D(ii);

    % Now loop over pulses (i.e. different tau)
    for jj=1:n
        
        %==== Standard Steady state method ====
        %%% Symmetric (3-band) case
        Mssfp_all(ii,jj,1,1) = ssSSFP_ihMT(flipangle,b1sqrd{jj,1},Delta_Hz,TR,tau(jj),dphi,tmp);
        %%% Asymmetric (2-band) case
        Mssfp_all(ii,jj,1,2) = ssSSFP_ihMT(flipangle,b1sqrd{jj,2},Delta_Hz,TR,tau(jj),dphi,tmp);
        %%% Single band case
        Mssfp_all(ii,jj,1,3) =ssSSFP_ihMT(flipangle,b1sqrd{jj,1}.*[0 1 0],Delta_Hz,TR,tau(jj),dphi,tmp);
        
        %==== Full integration ====
        %%% Symmetric (3-band) case
        Mssfp_all(ii,jj,2,1) = ssSSFP_ihMT_integrate(b1pulse{jj,1},dt,Delta_Hz,TR,dphi,tmp);
        %%% Asymmetric (2-band) case
        Mssfp_all(ii,jj,2,2) = ssSSFP_ihMT_integrate(b1pulse{jj,2},dt,Delta_Hz,TR,dphi,tmp);
        %%% Single band case
        Mssfp_all(ii,jj,2,3) =ssSSFP_ihMT_integrate(b1pulse{jj,1}.*[0 1 0],dt,Delta_Hz,TR,dphi,tmp);
        
        %=== Bieri Scheffler Correction
        tmpC = Bieri_Scheffler_finite_correction(TBP,tau(jj),TR,tmp);

        %%% Symmetric (3-band) case
        Mssfp_all(ii,jj,3,1) = ssSSFP_ihMT(flipangle,b1sqrd{jj,1},Delta_Hz,TR,tau(jj),dphi,tmpC);
        %%% Asymmetric (2-band) case
        Mssfp_all(ii,jj,3,2) = ssSSFP_ihMT(flipangle,b1sqrd{jj,2},Delta_Hz,TR,tau(jj),dphi,tmpC);
        %%% Single band case
        Mssfp_all(ii,jj,3,3) =ssSSFP_ihMT(flipangle,b1sqrd{jj,1}.*[0 1 0],Delta_Hz,TR,tau(jj),dphi,tmpC);
        
       disp([ii jj]) 
    end
end


%% Now do the SPGR version - for Ernst angle (7.1)
flipangle = acos(exp(-TR*tissuepars.free.R1));
fprintf(1,'flip is %1.1f\n',r2d(flipangle));
pulses = {};
b1sqrd = {};
b1pulse= {};
for ii=1:n
    % 3 bands
    [pulses{ii,1},b1sqrd{ii,1},b1pulse{ii,1}] = gen_MB_pulse(flipangle,tau(ii),TR,b1_rms,delta,'3','alpha',gauss_alpha,'dt',dt); 
    % 2 bands
    [pulses{ii,2},b1sqrd{ii,2},b1pulse{ii,2}] = gen_MB_pulse(flipangle,tau(ii),TR,b1_rms,delta,'2+','alpha',gauss_alpha,'dt',dt);
end


Mspgr_all = zeros([n n 2 3]); % T1D, tau, method, number of bands

for ii=1:n

    % generate new tissue parameter set
    tmp = init_tissue('ic');
    tmp.semi.R1D = 1/T1D(ii);

    % Now loop over pulses (i.e. different tau)
    for jj=1:n
        
        %==== Standard Steady state method ====
        %%% Symmetric (3-band) case
        Mspgr_all(ii,jj,1,1) = ssSPGR_ihMT(flipangle,b1sqrd{jj,1},Delta_Hz,TR,tau(jj),tmp);
        %%% Asymmetric (2-band) case
        Mspgr_all(ii,jj,1,2) = ssSPGR_ihMT(flipangle,b1sqrd{jj,2},Delta_Hz,TR,tau(jj),tmp);
        %%% Single band case
        Mspgr_all(ii,jj,1,3) =ssSPGR_ihMT(flipangle,b1sqrd{jj,1}.*[0 1 0],Delta_Hz,TR,tau(jj),tmp);
        
        %==== Full integration ====
        %%% Symmetric (3-band) case
        Mspgr_all(ii,jj,2,1) = ssSPGR_ihMT_integrate(b1pulse{jj,1},dt,Delta_Hz,TR,tmp);
        %%% Asymmetric (2-band) case
        Mspgr_all(ii,jj,2,2) = ssSPGR_ihMT_integrate(b1pulse{jj,2},dt,Delta_Hz,TR,tmp);
        %%% Single band case
        Mspgr_all(ii,jj,2,3) =ssSPGR_ihMT_integrate(b1pulse{jj,1}.*[0 1 0],dt,Delta_Hz,TR,tmp);
        
        
        
       disp([ii jj]) 
    end
end



%%
figfp(1)

for ii=1:3
    subplot(2,3,ii)
%     imsjm((abs(M(:,:,2,ii))-abs(M(:,:,1,ii)))./abs(M(:,:,2,ii)),[0 0.1])
    [cc,hh]=contourf(1e3*tau,T1D,100*abs(abs(Mssfp_all(:,:,2,ii))-abs(Mssfp_all(:,:,1,ii)))./abs(Mssfp_all(:,:,2,ii)),0:1:10);
    title(sprintf('%d band, error',ii))
    set(gca,'Yscale','log')
    grid on
    caxis([0 10])
    hh.LineColor = [1 1 1];
    
    xlabel('Pulse duration \tau (ms)')
    ylabel('Dipolar relaxation time T_{1D}^s (s)')
    
    subplot(2,3,ii+3)
    [cc,hh]=contourf(1e3*tau,T1D,100*abs(abs(Mssfp_all(:,:,2,ii))-abs(Mssfp_all(:,:,3,ii)))./abs(Mssfp_all(:,:,2,ii)),0:1:10);
    title(sprintf('%d band, error with correction',ii))
    set(gca,'Yscale','log')
    caxis([0 10])
    xlabel('Pulse duration \tau (ms)')
    ylabel('Dipolar relaxation time T_{1D}^s (s)')
    hh.LineColor = [1 1 1];
    grid on
       

    colormap hot
end

cc = colorbar;
cc.Position = [0.93 0.3 0.02 0.5];

figfp(2)
nb = [1 2 3];
for ii=1:3
    subplot(1,3,ii)
    [cc,hh]=contourf(1e3*tau,T1D,100*abs(abs(Mspgr_all(:,:,2,ii))-abs(Mspgr_all(:,:,1,ii)))./abs(Mspgr_all(:,:,2,ii)),0:1:10);
    title(sprintf('%d band, error',ii))
    set(gca,'Yscale','log')
    grid on
    caxis([0 10])
    hh.LineColor = [1 1 1];
    
    xlabel('Pulse duration \tau (ms)')
    ylabel('Dipolar relaxation time T_{1D}^s (s)')
    
    colormap hot
end

cc = colorbar;
cc.Position = [0.93 0.3 0.02 0.5];



%% Make a big figure

figfp(100)

nr = 3;
nc = 4;

%%% Plots
subplot(nr,nc,1)
plot(r2d(flips),squeeze(abs(Mspgr(:,2,:))),'linewidth',1.5)
grid on
pl=get(gca,'children');
pl(1).Color = [0 0 0];
legend('Instantaneous, Eq.[4]','Full integration')
ylim([0 0.05])
ylabel('Signal/M_0')
xlabel('flip, deg')
title('SPGR (2+ Bands)')

subplot(nr,nc,nc+1)
plot(r2d(flips),squeeze(abs(Mssfp(:,2,:))),'linewidth',1.5)
grid on
pl=get(gca,'children');
pl(1).LineStyle='-.';
pl(1).Color = [1 0.2 0.2];
pl(2).Color = [0 0 0];
ll=legend('Instantaneous, Eq.[5]','Full integration','Bieri-Scheffler correction');
ll.Position = [0.1032 0.1338 0.1700 0.0967];
ylim([0 0.12])
ylabel('Signal/M_0')
xlabel('flip, deg')
title('bSSFP (2+ Bands)')

%%% Now SPGR, no correction
titls = {'Single Band','2+ Bands','3 Bands'};
for ii=1:3    
    subplot(nr,nc,ii+1)
    [cc,hh]=contourf(1e3*tau,T1D,100*abs(abs(Mspgr_all(:,:,2,ii))-abs(Mspgr_all(:,:,1,ii)))./abs(Mspgr_all(:,:,2,ii)),0:2:10);
    hh.LineWidth = 1.5;
    clabel(cc,hh,'Color',[1 1 1]);
    title(titls{ii})
    set(gca,'Yscale','log')
    grid on
    caxis([0 10])
    hh.LineColor = [1 1 1];
    
    %xlabel('Pulse duration \tau (ms)')
    xlabel('\tau, ms')
    ylabel('T_{1D}^s (s)')
end

%%% SSFP, with and without correction
for ii=1:3    
    subplot(nr,nc,ii+1+nc)
    [cc,hh]=contourf(1e3*tau,T1D,100*abs(abs(Mssfp_all(:,:,2,ii))-abs(Mssfp_all(:,:,1,ii)))./abs(Mssfp_all(:,:,2,ii)),0:2:10);
    hh.LineWidth = 1.5;
    clabel(cc,hh,'Color',[1 1 1]);
    
    %title(sprintf('%d band, error',ii))
    set(gca,'Yscale','log')
    grid on
    caxis([0 10])
    hh.LineColor = [1 1 1];
    
   % xlabel('Pulse duration \tau (ms)')
    ylabel('T_{1D}^s (s)')
    
    % Bieri Scheffler correction
    subplot(nr,nc,ii+1+2*nc)
    [cc,hh]=contourf(1e3*tau,T1D,100*abs(abs(Mssfp_all(:,:,2,ii))-abs(Mssfp_all(:,:,3,ii)))./abs(Mssfp_all(:,:,2,ii)),0:2:10);
    %title(sprintf('%d band, error',ii))
    hh.LineWidth = 1.5;
    clabel(cc,hh,'Color',[1 1 1]);
    set(gca,'Yscale','log')
    grid on
    caxis([0 10])
    hh.LineColor = [1 1 1];
    
    %xlabel('Pulse duration \tau (ms)')
    xlabel('\tau, ms')
    ylabel('T_{1D}^s (s)')
    
    
end
% colormap hot

setpospap([100 100 1100 535])

gg = get(gcf,'children');

% Reposition everything
gg(13).Position = [0.06    0.59    0.22    0.35];
gg(11).Position = [0.06    0.11    0.22    0.35];

% plots
ix = [9 8 7];
ix2 = [6 4 2];
ix3 = [5 3 1];

for ii=1:3
    gg(ix(ii)).Position = [0.40+(ii-1)*0.185 0.68 0.13 0.2];
    gg(ix2(ii)).Position = [0.40+(ii-1)*0.185 0.35 0.13 0.2];
    gg(ix3(ii)).Position = [0.40+(ii-1)*0.185 0.08 0.13 0.2];
end

%%% text labels
axes(gg(13))
text(140,0.055,'Percentage error from instantaneous approximation','fontsize',13,'fontweight','bold');

text(90,0.02,'SPGR','rotation',90,'fontsize',14,'fontweight','bold')
text(97,0.012,'instantaneous','rotation',90,'fontsize',13,'fontweight','bold')


text(90,-0.045,'bSSFP','rotation',90,'fontsize',14,'fontweight','bold')
text(97,-0.035,'instantaneous','rotation',90,'fontsize',13,'fontweight','bold')
text(97,-0.067,'corrected','rotation',90,'fontsize',13,'fontweight','bold')

text(310,-0.02,'nrmse(%)','rotation',0,'fontsize',13,'fontweight','bold')


%%% Color bar
axes(gg(1))
cc = colorbar;
cc.Position = [0.9338 0.4850 0.0152 0.2500];

print -dpng -r300 figs/instantaneous_approx_fig.png