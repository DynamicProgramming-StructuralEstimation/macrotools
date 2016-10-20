%% OILFIRM_BAYESIAN  Optimal oil extraction problem by Bayesian firm 
%
% Consider a firm with perfect access to financial markets with opportunity
% cost the gross interest rate R and exploits a natural resource optimally.
% Suppose the exogenous price pt takes n discrete values and that the 
% transition probabilities are governed by a Markov transition matrix 
% which the oil firm has to learn. 
% The states are assumed to be observable, but the transition probability
% is unknown. Our agent learns about them using Bayes's theorem.
clear all

%% Model parameters 
Pj = [22.4787 56.8691];      % [pl ph]   values of each state
%Pj = [42.4787 56.8691];      % [pl ph]   values of each state
tj = [58.66   62.13];        % [tsl tsh] periods in each state
q  = [1-1/tj(1) 1-1/tj(2)];  % [qll qhh] prob. of staying in each state
R  = (1.035)^(.25);          % Gross real interest rate. Discount = R^-1
En = 25;                     % expected oil reserves (in periods)
p  = (1/Pj(2))*Pj;           % price normalization ph==1
Q = [ q(1)  1-q(1); 
      1-q(2)  q(2) ]
%Q= [0.25 0.75;0.75 0.25];  
  
Ep = p*ergdist(Q);         % expected oil price (normalized to 1)

%% Model calibration
x2s   = 1/En;
kappa = (-Ep*(1/R-1))/(2*x2s*(1-1/R)+(1/R)*x2s*x2s);
Ex    = max([(-2*kappa*(1-1/R)+sqrt((2*kappa*(1-1/R))^2-4/R*kappa*Ep*(1/R-1)))/(2*(1/R)*kappa);
             (-2*kappa*(1-1/R)-sqrt((2*kappa*(1-1/R))^2-4/R*kappa*Ep*(1/R-1)))/(2*(1/R)*kappa)]);
Es    = En*Ex;
d     = Ex;             

% Parameters of the true oil process assume an AR(1)
smax   = 2;           % possible oil reserves 

%% Construct state space PxS
s      = (0.0001:d/40:smax)';              ns = length(s);  
[P,S]  = gridmake(p',s);                   n  = length(S);

%% Profit function and feasible extraction x<=o
x   = zeros(n,ns);
pie = zeros(n,ns);
np  = length(p);            
 
for i=1:ns*np
    for j=1:ns
        x(i,j) = (S(i)-s(j)+d);
        if x(i,j)>=0 && x(i,j)<=S(i)+d           
          pie(i,j) = P(i)*x(i,j)-kappa*((x(i,j))^2/(S(i)));
        else
          pie(i,j) = -inf;
        end
    end
end
  
%% Rational Expectations Perfect Information problem  
  
QRE = kron(speye(ns,ns),repmat(Q,ns,1));
[v,x,pstar] = solvedp(pie,QRE,R^-1,'policy');  clear Pr u c;
  
X  = S + d - s(x);   % optimal extraction
f  = ergdist(pstar);  
Es = f'*s(x); 
Ex = f'*X;  
profit = f'*(P.*X-kappa*(X.^2)./S); 
value  = f'*(P.*S);
    
fprintf('\nRational Expectations Perfect Information (REPI) Means\n') 
fprintf('   Expected price        = %5.2f\n'  ,Ep)
fprintf('   Mg extraction cost    = %5.2f\n'  ,kappa)
fprintf('   Stock                 = %5.2f\n'  ,Es)
fprintf('   Value of stock        = %5.2f\n'  ,value)  
fprintf('   Extraction            = %5.2f\n'  ,Ex)
fprintf('   Discoveries           = %5.2f\n'  ,d)
fprintf('   Reserves (in periods) = %5.2f\n'  ,Es/Ex)
fprintf('   Profits               = %5.2f\n'  ,profit)  

%% Bayesian Learning problem

% Simulate the price Markov chain
J    = 5;
T    = 10;                   % Sample size
t    = 1:T+1;
R1   = ones(1,T+1);
R2   = 2*ones(1,T+1);

ip_t = [R1(t<=J) R2(t>J)];
p_t  = p(ip_t);             % maps position i to vector of prices p

%% Solve the Bayesian learning problem

% Declare vectors for storage

spathBL = zeros(T,2);    spathRE = zeros(T,2);    
xpathBL = zeros(T,2);    xpathRE = zeros(T,2);     
 

% Set the initial counters

n0  = [0.0014 0.0014; 0.0014 0.0014];  % complete surprise
%n0 = Q;                                 % perfect previous knowledge

Qt = betabinomial(ip_t,n0);            % Q_t TPM's for t=1,...,T
 
iBL = getindex([p_t(1) Es],[P S]); 
iRE = iBL; 


for t=1:T
    iBLold = iBL;
    iREold = iRE;
    
    QBL = kron(speye(ns,ns),repmat(Qt(:,:,t),ns,1));

    [vBL,xBL,HBL]  = solvedp(pie,QBL,R^-1,'policy');
    [vRE,xRE,HRE]  = solvedp(pie,QRE,R^-1,'policy');

    [spathBL(t,:), xpathBL(t,:)] = ddpsimul(HBL,iBLold,1,xBL);
    [spathRE(t,:), xpathRE(t,:)] = ddpsimul(HRE,iREold,1,xRE);

    iBL = getindex([p_t(t+1) S(spathBL(t,2))],[P S]); 
    iRE = getindex([p_t(t+1) S(spathRE(t,2))],[P S]); 
    
    fprintf('\n Bayesian Learning  -       BL      RE\n') 
    fprintf('   Period                 %5.0f  %5.0f\n'  ,t, t)    
    fprintf('   Oil price              %5.3f  %5.3f\n'  ,p_t(t), p_t(t))    
    fprintf('   Stock                  %5.3f  %5.3f\n'  ,S(spathBL(t,2)), S(spathRE(t,2)))
    fprintf('   Extraction             %5.3f  %5.3f\n'  ,S(spathBL(t,1))+d-s(xpathBL(t,1)),S(spathRE(t,1))+d-s(xpathRE(t,1)))
end
  
pt  = p_t(1:T)';
stBL  = S(spathBL(:,1));                  stRE  = S(spathRE(:,1));
xtBL  = stBL+d-s(xpathBL(:,1));           xtRE  = stRE+d-s(xpathRE(:,1));
prtBL = pt.*xtBL-kappa*(xtBL.^2)./stBL;   prtRE = pt.*xtRE-kappa*(xtRE.^2)./stRE;

%% Some plots 

% Reshaping
vr = reshape(v,np,ns)';
Xr = reshape(X,np,ns)';
fr = reshape(f,np,ns)';
Fr = cumsum(fr);

% Plot Bayesian Simulation
figure(1);
  subplot(2,2,1), plot(pt); title('Oil price');
  subplot(2,2,2), plot([stBL stRE]); title('Reserves');
  subplot(2,2,3), plot([xtBL xtRE]); title('Extraction');
  subplot(2,2,4), plot([prtBL prtRE]); title('Profits'); 

% Plot optimal policy
figure(2); 
  h=plot(s,Xr); % set(h,'FaceColor',[.75 .75 .75])
  axis([0 max(s) -inf inf]);
  title('Optimal Extraction Policy');
  xlabel('Oil Reserves'); ylabel('Oil Extraction');
  if np==2; legend('Low oil prices','High oil prices'); end

% Plot optimal value function
figure(3); plot(s,vr); 
  title('Optimal Value Function');
  xlabel('Oil Reserves'); ylabel('Value');
  if np==2; legend('Low oil prices','High oil prices'); end

% Compute steady state distribution of oil reserves
figure(4); 
  h=plot(fr); 
  title('Steady State Density');
  xlabel('Oil Reserves'); ylabel('Probability'); 
  if np==2; legend('Low oil prices','High oil prices'); end
  
% Compute steady state distribution of oil reserves
figure(5); 
  h=plot(Fr); 
  title('Steady State Distribution');
  xlabel('Oil Reserves'); ylabel('Probability'); 
  if np==2; legend('Low oil prices','High oil prices'); end
   